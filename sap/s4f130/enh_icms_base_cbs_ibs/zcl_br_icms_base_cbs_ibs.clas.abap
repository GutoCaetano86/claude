"! <p class="shorttext synchronized" lang="pt">Reforma Tributária: CBS/IBS na base do ICMS (SD/MM)</p>
"! Chamada pela enhancement ZENH_BR_ICMS_BC_CBS_IBS no início de
"! CL_TAX_CALC_BR->CALCULATE_TAXES. Soma o valor de CBS/IBS do item ao valor
"! líquido do passo de cálculo em curso, conforme o modo de preço do módulo.
"!
"! Configuração 100% na STVARV (nada fixo no código), separada por módulo:
"!   ZBR_ICMS_BC_CBS_IBS_ATIVO     (Parâmetro) = 'X' liga a regra (geral)
"!   ZBR_ICMS_BC_CBS_IBS_MODO_SD   (Parâmetro) = 'B' bruto / 'L' líquido
"!   ZBR_ICMS_BC_CBS_IBS_MODO_MM   (Parâmetro) = 'B' bruto / 'L' líquido
"!   ZBR_ICMS_BC_CBS_IBS_KSCHL_SD  (Seleção)   = condições SD cujo KWERT entra
"!   ZBR_ICMS_BC_CBS_IBS_KSCHL_MM  (Seleção)   = condições MM cujo KWERT entra
"!     Ex. S4F/130: SD (RVABRA/ZBRA01) CBS3/IB3S/IB3M;
"!                  MM (TAXBRA) BXCB/BXBS/BXBM - CBS1/IB1S/IB1M têm KBETR 100%
"!                  fixo, o valor do imposto fica nas BX* (passos 180-182).
"!   Módulo sem modo válido ou sem lista de condições = regra desligada nele.
"!
"! Modos (N = líquido, C = CBS+IBS, t = alíquota efetiva do ICMS):
"!   L - líquido mantido, preço com ICMS sobe: BC = (N + C) / (1 - t)
"!   B - preço com ICMS mantido, líquido absorve: BC = N / (1 - t) + C
"! Passos da CL_TAX_CALC_BR (J_1BTXCOND):
"!   CALCULATE_TAX       SD: ICMI, forma o preço (NETWR + ICMS), com gross-up
"!                       MM: BX01, passo único, com gross-up
"!   CALCULATE_INCL_2ND  SD: IBRX, base já inclui ICMS (sem gross-up)
"! O ajuste é feito sobre o NET_AMOUNT que o standard preparou para o passo
"! (no ICMI o KAWRT da linha é a quantidade).
CLASS zcl_br_icms_base_cbs_ibs DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_amount TYPE p LENGTH 12 DECIMALS 6.

    CONSTANTS:
      c_kappl_sd    TYPE kappl VALUE 'V',
      c_kappl_mm    TYPE kappl VALUE 'TX',
      c_modo_bruto  TYPE char1 VALUE 'B',
      c_modo_liquid TYPE char1 VALUE 'L'.

    "! Regra ativa para o módulo? (switch geral, modo e lista preenchidos)
    "! @parameter iv_kappl  | Aplicação do cálculo: V = SD, TX = MM
    CLASS-METHODS is_active
      IMPORTING iv_kappl         TYPE kappl
      RETURNING VALUE(rv_active) TYPE abap_bool.

    "! Soma CBS + IBS (UF + Mun.) do item
    "! @parameter iv_kappl   | Aplicação do cálculo: V = SD, TX = MM
    "! @parameter it_komv    | KOMV do item (MT_KOMV da CL_TAX_CALC_BR)
    "! @parameter rv_amount  | CBS + IBS do item
    CLASS-METHODS get_cbs_ibs_amount
      IMPORTING iv_kappl         TYPE kappl
                it_komv          TYPE tax_xkomv_tab
      RETURNING VALUE(rv_amount) TYPE ty_amount.

    "! Valor líquido do passo ajustado conforme o modo, uma única vez por passo
    "! @parameter io_calc       | Instância da CL_TAX_CALC_BR (ME)
    "! @parameter iv_kappl      | Aplicação do cálculo (MS_KOMK-KAPPL)
    "! @parameter iv_cond_code  | Código do passo (GET_CONDITION_CODE)
    "! @parameter iv_kposn      | Item (MS_KOMP-KPOSN)
    "! @parameter iv_kschl      | Condição que chamou o cálculo (MS_KOMV_FRM-KSCHL)
    "! @parameter iv_icms_rate  | Alíquota efetiva do gross-up (fração, ex. 0,17)
    "! @parameter iv_net_amount | NET_AMOUNT preparado pelo standard neste passo
    "! @parameter it_komv       | KOMV do item
    "! @parameter rv_net_amount | NET_AMOUNT ajustado
    CLASS-METHODS adjust_net_amount
      IMPORTING io_calc              TYPE REF TO object
                iv_kappl             TYPE kappl
                iv_cond_code         TYPE j_1btxcode
                iv_kposn             TYPE kposn
                iv_kschl             TYPE kscha
                iv_icms_rate         TYPE ty_amount
                iv_net_amount        TYPE kawrt
                it_komv              TYPE tax_xkomv_tab
      RETURNING VALUE(rv_net_amount) TYPE kawrt.

  PRIVATE SECTION.
    CONSTANTS:
      c_tvarv_ativo    TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_ATIVO',
      c_tvarv_modo_sd  TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_MODO_SD',
      c_tvarv_modo_mm  TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_MODO_MM',
      c_tvarv_kschl_sd TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_KSCHL_SD',
      c_tvarv_kschl_mm TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_KSCHL_MM',
      c_code_incl_2nd  TYPE j_1btxcode VALUE 'CALCULATE_INCL_2ND'.

    TYPES ty_r_kschl TYPE RANGE OF kscha.

    " Configuração por módulo
    TYPES: BEGIN OF ty_cfg,
             kappl   TYPE kappl,
             modo    TYPE char1,
             r_kschl TYPE ty_r_kschl,
           END OF ty_cfg.

    " Último valor ajustado por instância / item / passo
    TYPES: BEGIN OF ty_memo,
             calc  TYPE REF TO object,
             kposn TYPE kposn,
             kschl TYPE kscha,
             net   TYPE kawrt,
           END OF ty_memo.

    CLASS-DATA:
      gv_loaded TYPE abap_bool,
      gv_ativo  TYPE abap_bool,
      gt_cfg    TYPE STANDARD TABLE OF ty_cfg WITH DEFAULT KEY,
      gt_memo   TYPE STANDARD TABLE OF ty_memo WITH DEFAULT KEY.

    CLASS-METHODS load_config.

    CLASS-METHODS load_module
      IMPORTING iv_kappl      TYPE kappl
                iv_tvarv_modo TYPE rvari_vnam
                iv_tvarv_list TYPE rvari_vnam.

    CLASS-METHODS get_cfg
      IMPORTING iv_kappl      TYPE kappl
      RETURNING VALUE(rs_cfg) TYPE ty_cfg.
ENDCLASS.



CLASS zcl_br_icms_base_cbs_ibs IMPLEMENTATION.

  METHOD is_active.
    load_config( ).
    rv_active = xsdbool( gv_ativo = abap_true
                     AND get_cfg( iv_kappl )-r_kschl IS NOT INITIAL ).
  ENDMETHOD.


  METHOD get_cbs_ibs_amount.
    load_config( ).
    DATA(ls_cfg) = get_cfg( iv_kappl ).

    " Range vazio no WHERE selecionaria a KOMV inteira: sem lista, não soma
    IF ls_cfg-r_kschl IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_komv ASSIGNING FIELD-SYMBOL(<ls_komv>)
         WHERE kschl IN ls_cfg-r_kschl
           AND kinak IS INITIAL.          "Ignora condição inativa
      rv_amount = rv_amount + abs( <ls_komv>-kwert ).
    ENDLOOP.
  ENDMETHOD.


  METHOD adjust_net_amount.
    DATA lv_add TYPE ty_amount.

    rv_net_amount = iv_net_amount.

    " CALCULATE_TAXES pode rodar 2x no mesmo passo sem o standard refazer o
    " NET_AMOUNT (ADJUST_ICMS_DUE_MINPRICE, nota 2141500): se o valor recebido
    " é o que este método devolveu da última vez, o ajuste já está dentro.
    READ TABLE gt_memo ASSIGNING FIELD-SYMBOL(<ls_memo>)
         WITH KEY calc  = io_calc
                  kposn = iv_kposn
                  kschl = iv_kschl.
    IF sy-subrc = 0 AND <ls_memo>-net = iv_net_amount.
      RETURN.
    ENDIF.

    DATA(lv_cbs_ibs) = get_cbs_ibs_amount( iv_kappl = iv_kappl
                                           it_komv  = it_komv ).

    IF iv_cond_code = c_code_incl_2nd.
      " Base já inclui o ICMS (IBRX): soma direta nos dois modos
      lv_add = lv_cbs_ibs.

    ELSEIF get_cfg( iv_kappl )-modo = c_modo_liquid.
      " Líquido: CBS/IBS entra antes do gross-up, o preço com ICMS sobe
      lv_add = lv_cbs_ibs.

    ELSEIF iv_kappl = c_kappl_sd.
      " Bruto SD: passo de preço (ICMI) fica como no standard; o CBS/IBS
      " entra só no IBRX, sobre o preço com ICMS já formado
      lv_add = 0.

    ELSE.
      " Bruto MM: passo único com gross-up. Somar C x (1 - t) ao líquido faz
      " a base sair N / (1 - t) + C, ou seja, preço com ICMS + CBS/IBS
      lv_add = lv_cbs_ibs * ( 1 - iv_icms_rate ).
    ENDIF.

    rv_net_amount = iv_net_amount + lv_add.

    IF <ls_memo> IS ASSIGNED.
      <ls_memo>-net = rv_net_amount.
    ELSE.
      APPEND VALUE #( calc  = io_calc
                      kposn = iv_kposn
                      kschl = iv_kschl
                      net   = rv_net_amount ) TO gt_memo.
    ENDIF.
  ENDMETHOD.


  METHOD load_config.
    IF gv_loaded = abap_true.
      RETURN.
    ENDIF.
    gv_loaded = abap_true.

    " Chave liga/desliga geral
    SELECT SINGLE low FROM tvarvc
      WHERE name = @c_tvarv_ativo
        AND type = 'P'
        AND numb = '0000'
      INTO @DATA(lv_ativo).
    gv_ativo = xsdbool( lv_ativo = abap_true ).

    load_module( iv_kappl      = c_kappl_sd
                 iv_tvarv_modo = c_tvarv_modo_sd
                 iv_tvarv_list = c_tvarv_kschl_sd ).

    load_module( iv_kappl      = c_kappl_mm
                 iv_tvarv_modo = c_tvarv_modo_mm
                 iv_tvarv_list = c_tvarv_kschl_mm ).
  ENDMETHOD.


  METHOD load_module.
    DATA ls_cfg TYPE ty_cfg.

    ls_cfg-kappl = iv_kappl.

    SELECT SINGLE low FROM tvarvc
      WHERE name = @iv_tvarv_modo
        AND type = 'P'
        AND numb = '0000'
      INTO @ls_cfg-modo.

    " Sem modo válido o módulo fica desligado
    IF ls_cfg-modo <> c_modo_bruto AND ls_cfg-modo <> c_modo_liquid.
      RETURN.
    ENDIF.

    SELECT sign, opti AS option, low, high FROM tvarvc
      WHERE name = @iv_tvarv_list
        AND type = 'S'
        AND low <> @space
      INTO CORRESPONDING FIELDS OF TABLE @ls_cfg-r_kschl.

    IF ls_cfg-r_kschl IS NOT INITIAL.
      APPEND ls_cfg TO gt_cfg.
    ENDIF.
  ENDMETHOD.


  METHOD get_cfg.
    READ TABLE gt_cfg INTO rs_cfg WITH KEY kappl = iv_kappl.
  ENDMETHOD.

ENDCLASS.

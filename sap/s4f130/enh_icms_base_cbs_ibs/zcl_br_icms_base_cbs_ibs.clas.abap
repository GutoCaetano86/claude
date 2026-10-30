"! <p class="shorttext synchronized" lang="pt">Reforma Tributária: CBS/IBS na base do ICMS (SD/MM)</p>
"! Inclui o CBS/IBS do item SOMENTE na base do ICMS (IPI e PIS/COFINS ficam
"! sem CBS/IBS). Chamada por duas enhancements em CL_TAX_CALC_BR->CALCULATE_TAXES:
"!   ZENH_BR_ICMS_BC_CBS_IBS      (início) - ADJUST_NET_AMOUNT
"!   ZENH_BR_ICMS_BC_CBS_IBS_FIM  (fim)    - GET_ICMS_BASE_INCREMENT
"!
"! Configuração 100% na STVARV (nada fixo no código), separada por módulo:
"!   ZBR_ICMS_BC_CBS_IBS_ATIVO     (Parâmetro) = 'X' liga a regra (geral)
"!   ZBR_ICMS_BC_CBS_IBS_MODO_MM   (Parâmetro) = 'L' líquido / 'B' ou vazio bruto
"!   ZBR_ICMS_BC_CBS_IBS_KSCHL_SD  (Seleção)   = condições SD de CBS/IBS
"!   ZBR_ICMS_BC_CBS_IBS_KSCHL_MM  (Seleção)   = condições MM de CBS/IBS
"!     Ex. S4F/130: SD (RVABRA/ZBRA01) CBS3/IB3S/IB3M;
"!                  MM (TAXBRA) BXCB/BXBS/BXBM - CBS1/IB1S/IB1M têm KBETR 100%
"!                  fixo, o valor do imposto fica nas BX* (passos 180-182).
"!   Módulo sem lista de condições = regra desligada nele.
"!   SD não tem modo na STVARV: segue o esquema de preço do documento.
"!
"! Cálculo (N = líquido, C = CBS+IBS, t = alíquota ICMS, b = fator de base):
"!   BC ICMS = base standard + C ; ICMS = t x BC ICMS
"!   Líquido: o líquido é mantido e o ICMS sobre C entra no preço (V = N + ICMS)
"!   Bruto:   o preço com ICMS é mantido e o ICMS sobre C sai do líquido
"! Passos da CL_TAX_CALC_BR (J_1BTXCOND):
"!   CALCULATE_TAX       SD: ICMI, forma o preço (NETWR + ICMS), com gross-up
"!                       MM: BX01, passo único, com gross-up
"!   CALCULATE_INCL_2ND  SD: IBRX, base já inclui ICMS (sem gross-up)
"! SD: o esquema define o modo. Esquema de preço líquido (ICMI pela fórmula
"! 320) passa pelo CALCULATE_TAX e é tratado como líquido; esquema de preço
"! bruto (ICMI informado / outra fórmula) só passa pelo IBRX: bruto.
"! MM: modo da STVARV ZBR_ICMS_BC_CBS_IBS_MODO_MM (padrão bruto).
"! No CALCULATE_TAX em modo líquido o líquido recebe t x b x C antes do gross-up:
"! o valor com ICMS sai = N + ICMS final, sem C, e é a base de IPI e PIS/COFINS.
"! No fim do cálculo o ICMS recebe t x b x C e as bases do ICMS recebem C.
"!
"! Valor de CBS/IBS: KWERT da condição. Quando a condição ainda não tem valor
"! (ex. faturamento com tipo de preço G: impostos redeterminados e CBS/IBS
"! depois do ICMI no esquema, num cálculo único), usa alíquota x base, com a
"! base = líquido do item (NET_AMOUNT do passo CALCULATE_TAX).
"!
"! Fora do escopo (seguem o standard, sem CBS/IBS): FCP, ICMS-ST, partilha
"! (DIFAL), Convênio 100, CT-e.
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

    "! Regra ativa para o módulo? (switch geral e lista de condições)
    "! @parameter iv_kappl  | Aplicação do cálculo: V = SD, TX = MM
    CLASS-METHODS is_active
      IMPORTING iv_kappl         TYPE kappl
      RETURNING VALUE(rv_active) TYPE abap_bool.

    "! Soma CBS + IBS (UF + Mun.) do item
    "! @parameter iv_kappl   | Aplicação do cálculo: V = SD, TX = MM
    "! @parameter it_komv    | KOMV do item (MT_KOMV da CL_TAX_CALC_BR)
    "! @parameter iv_base    | Base para condição ainda sem valor (opcional)
    "! @parameter rv_amount  | CBS + IBS do item
    CLASS-METHODS get_cbs_ibs_amount
      IMPORTING iv_kappl         TYPE kappl
                it_komv          TYPE tax_xkomv_tab
                iv_base          TYPE ty_amount OPTIONAL
      RETURNING VALUE(rv_amount) TYPE ty_amount.

    "! Início do cálculo: NET_AMOUNT do passo ajustado conforme o modo e
    "! registro do CBS/IBS que o fim do cálculo soma na base do ICMS
    "! @parameter io_calc       | Instância da CL_TAX_CALC_BR (ME)
    "! @parameter iv_kappl      | Aplicação do cálculo (MS_KOMK-KAPPL)
    "! @parameter iv_cond_code  | Código do passo (GET_CONDITION_CODE)
    "! @parameter iv_kposn      | Item (MS_KOMP-KPOSN)
    "! @parameter iv_kschl      | Condição que chamou o cálculo (MS_KOMV_FRM-KSCHL)
    "! @parameter iv_icms_rate  | Alíquota ICMS x fator de base (fração, ex. 0,12)
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

    "! Fim do cálculo: CBS/IBS a somar na base do ICMS deste passo (0 = nada)
    "! @parameter io_calc    | Instância da CL_TAX_CALC_BR (ME)
    "! @parameter iv_kposn   | Item (MS_KOMP-KPOSN)
    "! @parameter iv_kschl   | Condição que chamou o cálculo (MS_KOMV_FRM-KSCHL)
    "! @parameter rv_amount  | CBS + IBS a somar na base do ICMS
    CLASS-METHODS get_icms_base_increment
      IMPORTING io_calc          TYPE REF TO object
                iv_kposn         TYPE kposn
                iv_kschl         TYPE kscha
      RETURNING VALUE(rv_amount) TYPE ty_amount.

  PRIVATE SECTION.
    CONSTANTS:
      c_tvarv_ativo    TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_ATIVO',
      c_tvarv_modo_mm  TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_MODO_MM',
      c_tvarv_kschl_sd TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_KSCHL_SD',
      c_tvarv_kschl_mm TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_KSCHL_MM',
      c_code_incl_2nd  TYPE j_1btxcode VALUE 'CALCULATE_INCL_2ND',
      c_krech_perc     TYPE krech      VALUE 'A',   "% (KBETR x 10)
      c_krech_perc6    TYPE krech      VALUE 'W'.   "% 6 dec. (KBETR x 10000)

    TYPES ty_r_kschl TYPE RANGE OF kscha.

    " Configuração por módulo
    TYPES: BEGIN OF ty_cfg,
             kappl   TYPE kappl,
             modo    TYPE char1,
             r_kschl TYPE ty_r_kschl,
           END OF ty_cfg.

    " Por instância / item / passo: último NET_AMOUNT devolvido e o CBS/IBS
    " que o fim do cálculo soma na base do ICMS (0 = não soma)
    TYPES: BEGIN OF ty_memo,
             calc     TYPE REF TO object,
             kposn    TYPE kposn,
             kschl    TYPE kscha,
             net      TYPE kawrt,
             icms_add TYPE ty_amount,
           END OF ty_memo.

    " Base de CBS/IBS (líquido) guardada no passo CALCULATE_TAX do item
    TYPES: BEGIN OF ty_base,
             calc  TYPE REF TO object,
             kposn TYPE kposn,
             base  TYPE ty_amount,
           END OF ty_base.

    CLASS-DATA:
      gv_loaded TYPE abap_bool,
      gv_ativo  TYPE abap_bool,
      gt_cfg    TYPE STANDARD TABLE OF ty_cfg WITH DEFAULT KEY,
      gt_memo   TYPE STANDARD TABLE OF ty_memo WITH DEFAULT KEY,
      gt_base   TYPE STANDARD TABLE OF ty_base WITH DEFAULT KEY.

    CLASS-METHODS load_config.

    CLASS-METHODS load_module
      IMPORTING iv_kappl      TYPE kappl
                iv_tvarv_modo TYPE rvari_vnam OPTIONAL
                iv_tvarv_list TYPE rvari_vnam.

    CLASS-METHODS get_cfg
      IMPORTING iv_kappl      TYPE kappl
      RETURNING VALUE(rs_cfg) TYPE ty_cfg.

    CLASS-METHODS get_cbs_ibs_base
      IMPORTING io_calc        TYPE REF TO object
                iv_kposn       TYPE kposn
                iv_cond_code   TYPE j_1btxcode
                iv_icms_rate   TYPE ty_amount
                iv_net_amount  TYPE kawrt
      RETURNING VALUE(rv_base) TYPE ty_amount.
ENDCLASS.



CLASS zcl_br_icms_base_cbs_ibs IMPLEMENTATION.

  METHOD is_active.
    load_config( ).
    rv_active = xsdbool( gv_ativo = abap_true
                     AND get_cfg( iv_kappl )-r_kschl IS NOT INITIAL ).
  ENDMETHOD.


  METHOD get_cbs_ibs_amount.
    DATA lv_rate TYPE ty_amount.

    load_config( ).
    DATA(ls_cfg) = get_cfg( iv_kappl ).

    " Range vazio no WHERE selecionaria a KOMV inteira: sem lista, não soma
    IF ls_cfg-r_kschl IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_komv ASSIGNING FIELD-SYMBOL(<ls_komv>)
         WHERE kschl IN ls_cfg-r_kschl
           AND kinak IS INITIAL.          "Ignora condição inativa

      IF <ls_komv>-kwert IS NOT INITIAL OR iv_base IS INITIAL.
        rv_amount = rv_amount + abs( <ls_komv>-kwert ).
        CONTINUE.
      ENDIF.

      " Condição ainda sem valor neste cálculo: alíquota x base
      CASE <ls_komv>-krech.
        WHEN c_krech_perc.
          lv_rate = <ls_komv>-kbetr / 1000.
        WHEN c_krech_perc6.
          lv_rate = <ls_komv>-kbetr / 1000000.
        WHEN OTHERS.
          lv_rate = 0.
      ENDCASE.

      rv_amount = rv_amount + abs( round( val = iv_base * lv_rate dec = 2 ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD adjust_net_amount.
    DATA:
      lv_add_net  TYPE ty_amount,
      lv_icms_add TYPE ty_amount.

    rv_net_amount = iv_net_amount.

    " CALCULATE_TAXES pode rodar 2x no mesmo passo sem o standard refazer o
    " NET_AMOUNT (ADJUST_ICMS_DUE_MINPRICE, nota 2141500): se o valor recebido
    " é o que este método devolveu da última vez, o ajuste já está dentro e
    " o registro para o fim do cálculo continua valendo.
    READ TABLE gt_memo ASSIGNING FIELD-SYMBOL(<ls_memo>)
         WITH KEY calc  = io_calc
                  kposn = iv_kposn
                  kschl = iv_kschl.
    IF sy-subrc = 0 AND <ls_memo>-net = iv_net_amount.
      RETURN.
    ENDIF.

    DATA(lv_base) = get_cbs_ibs_base( io_calc       = io_calc
                                      iv_kposn      = iv_kposn
                                      iv_cond_code  = iv_cond_code
                                      iv_icms_rate  = iv_icms_rate
                                      iv_net_amount = iv_net_amount ).

    DATA(lv_cbs_ibs) = get_cbs_ibs_amount( iv_kappl = iv_kappl
                                           it_komv  = it_komv
                                           iv_base  = lv_base ).

    IF iv_cond_code = c_code_incl_2nd.
      " IBRX: preço com ICMS já formado; CBS/IBS só na base do ICMS
      lv_icms_add = lv_cbs_ibs.

    ELSEIF iv_kappl = c_kappl_sd
        OR get_cfg( iv_kappl )-modo = c_modo_liquid.
      " Líquido (SD: esquema de preço líquido, ICMI pela fórmula 320): o
      " ICMS sobre o CBS/IBS entra no preço. Somar t x C ao líquido faz o
      " gross-up sair N + ICMS final, sem o CBS/IBS
      lv_add_net  = lv_cbs_ibs * iv_icms_rate.
      lv_icms_add = lv_cbs_ibs.

    ELSE.
      " Bruto MM: preço com ICMS mantido; CBS/IBS só na base do ICMS
      lv_icms_add = lv_cbs_ibs.
    ENDIF.

    rv_net_amount = iv_net_amount + lv_add_net.

    IF <ls_memo> IS ASSIGNED.
      <ls_memo>-net      = rv_net_amount.
      <ls_memo>-icms_add = lv_icms_add.
    ELSE.
      APPEND VALUE #( calc     = io_calc
                      kposn    = iv_kposn
                      kschl    = iv_kschl
                      net      = rv_net_amount
                      icms_add = lv_icms_add ) TO gt_memo.
    ENDIF.
  ENDMETHOD.


  METHOD get_icms_base_increment.
    READ TABLE gt_memo ASSIGNING FIELD-SYMBOL(<ls_memo>)
         WITH KEY calc  = io_calc
                  kposn = iv_kposn
                  kschl = iv_kschl.
    IF sy-subrc = 0.
      rv_amount = <ls_memo>-icms_add.
    ENDIF.
  ENDMETHOD.


  METHOD get_cbs_ibs_base.
    " Base de CBS/IBS = líquido do item, usada só se a condição ainda não
    " tem valor. No CALCULATE_TAX o NET_AMOUNT é o líquido: guarda para o
    " IBRX do mesmo item, cujo NET_AMOUNT já inclui o ICMS.
    READ TABLE gt_base ASSIGNING FIELD-SYMBOL(<ls_base>)
         WITH KEY calc  = io_calc
                  kposn = iv_kposn.

    IF iv_cond_code <> c_code_incl_2nd.
      rv_base = iv_net_amount.
      IF <ls_base> IS ASSIGNED.
        <ls_base>-base = rv_base.
      ELSE.
        APPEND VALUE #( calc  = io_calc
                        kposn = iv_kposn
                        base  = rv_base ) TO gt_base.
      ENDIF.
      RETURN.
    ENDIF.

    IF <ls_base> IS ASSIGNED.
      " Consome a base do passo de preço deste item
      rv_base = <ls_base>-base.
      DELETE gt_base WHERE calc = io_calc AND kposn = iv_kposn.
    ELSE.
      " Sem passo de preço (preço bruto): líquido = preço com ICMS x (1 - t)
      rv_base = iv_net_amount * ( 1 - iv_icms_rate ).
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

    " SD sem modo: o esquema de preço define bruto ou líquido
    load_module( iv_kappl      = c_kappl_sd
                 iv_tvarv_list = c_tvarv_kschl_sd ).

    load_module( iv_kappl      = c_kappl_mm
                 iv_tvarv_modo = c_tvarv_modo_mm
                 iv_tvarv_list = c_tvarv_kschl_mm ).
  ENDMETHOD.


  METHOD load_module.
    DATA ls_cfg TYPE ty_cfg.

    ls_cfg-kappl = iv_kappl.

    IF iv_tvarv_modo IS NOT INITIAL.
      SELECT SINGLE low FROM tvarvc
        WHERE name = @iv_tvarv_modo
          AND type = 'P'
          AND numb = '0000'
        INTO @ls_cfg-modo.
    ENDIF.

    " Modo diferente de líquido (inclusive vazio) = bruto
    IF ls_cfg-modo <> c_modo_liquid.
      ls_cfg-modo = c_modo_bruto.
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

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
"! Valor de CBS/IBS no SD: sempre alíquota (KBETR) x base, nunca o KWERT do
"! documento. O CBS/IBS fica depois do ICMS no esquema (a base dele exclui o
"! ICMS), então o KWERT visto no cálculo do ICMS é de um cálculo anterior.
"!   Líquido: base = líquido do item (NET_AMOUNT do passo CALCULATE_TAX)
"!   Bruto:   resolvido no fim do cálculo, com ICMS e PIS/COFINS do standard:
"!            base = (P - ICMS - PIS - COFINS) / (1 + R x t x b)
"!            P = valor com ICMS (sem IPI), R = soma das alíquotas CBS/IBS
"! MM: KWERT das condições (BX*); sem valor, alíquota x base.
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

    "! Fim do cálculo: CBS/IBS a somar na base do ICMS deste passo (0 = nada).
    "! No bruto do SD o CBS/IBS é calculado aqui, com os valores finais do
    "! standard (ICMS sem o CBS/IBS, PIS e COFINS).
    "! @parameter io_calc       | Instância da CL_TAX_CALC_BR (ME)
    "! @parameter iv_kappl      | Aplicação do cálculo (MS_KOMK-KAPPL)
    "! @parameter iv_kposn      | Item (MS_KOMP-KPOSN)
    "! @parameter iv_kschl      | Condição que chamou o cálculo (MS_KOMV_FRM-KSCHL)
    "! @parameter it_komv       | KOMV do item
    "! @parameter iv_value      | Valor com ICMS, sem IPI (LV_VAL_INCL_ICMS)
    "! @parameter iv_icms_amt   | ICMS do standard, sem o CBS/IBS
    "! @parameter iv_pis_cofins | PIS + COFINS do standard
    "! @parameter iv_icms_rate  | Alíquota ICMS x fator de base (fração)
    "! @parameter rv_amount     | CBS + IBS a somar na base do ICMS
    CLASS-METHODS get_icms_base_increment
      IMPORTING io_calc          TYPE REF TO object
                iv_kappl         TYPE kappl
                iv_kposn         TYPE kposn
                iv_kschl         TYPE kscha
                it_komv          TYPE tax_xkomv_tab
                iv_value         TYPE ty_amount
                iv_icms_amt      TYPE ty_amount
                iv_pis_cofins    TYPE ty_amount
                iv_icms_rate     TYPE ty_amount
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

    " Por instância / item / passo: último NET_AMOUNT devolvido, se ele foi
    " alterado, e o CBS/IBS que o fim do cálculo soma na base do ICMS
    " (gross = X: bruto do SD, calculado no fim)
    TYPES: BEGIN OF ty_memo,
             calc     TYPE REF TO object,
             kposn    TYPE kposn,
             kschl    TYPE kscha,
             net      TYPE kawrt,
             changed  TYPE abap_bool,
             icms_add TYPE ty_amount,
             gross    TYPE abap_bool,
           END OF ty_memo.

    " Alíquota (fração) de cada condição de CBS/IBS do item
    TYPES ty_t_rate TYPE STANDARD TABLE OF ty_amount WITH EMPTY KEY.

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

    CLASS-METHODS get_rates
      IMPORTING iv_kappl        TYPE kappl
                it_komv         TYPE tax_xkomv_tab
      RETURNING VALUE(rt_rate)  TYPE ty_t_rate.

    CLASS-METHODS get_gross_cbs_ibs
      IMPORTING iv_kappl         TYPE kappl
                it_komv          TYPE tax_xkomv_tab
                iv_value         TYPE ty_amount
                iv_icms_amt      TYPE ty_amount
                iv_pis_cofins    TYPE ty_amount
                iv_icms_rate     TYPE ty_amount
      RETURNING VALUE(rv_amount) TYPE ty_amount.
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

    " SD: sempre alíquota x base (o KWERT é de um cálculo anterior)
    IF iv_kappl = c_kappl_sd.
      LOOP AT get_rates( iv_kappl = iv_kappl it_komv = it_komv ) INTO lv_rate.
        rv_amount = rv_amount + round( val = iv_base * lv_rate dec = 2 ).
      ENDLOOP.
      RETURN.
    ENDIF.

    " MM: valor das condições; sem valor, alíquota x base
    LOOP AT it_komv ASSIGNING FIELD-SYMBOL(<ls_komv>)
         WHERE kschl IN ls_cfg-r_kschl
           AND kinak IS INITIAL.          "Ignora condição inativa

      IF <ls_komv>-kwert IS NOT INITIAL OR iv_base IS INITIAL.
        rv_amount = rv_amount + abs( <ls_komv>-kwert ).
        CONTINUE.
      ENDIF.

      LOOP AT get_rates( iv_kappl = iv_kappl
                         it_komv  = VALUE #( ( <ls_komv> ) ) ) INTO lv_rate.
        rv_amount = rv_amount + round( val = iv_base * lv_rate dec = 2 ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD adjust_net_amount.
    DATA:
      lv_base     TYPE ty_amount,
      lv_cbs_ibs  TYPE ty_amount,
      lv_add_net  TYPE ty_amount,
      lv_gross    TYPE abap_bool.

    rv_net_amount = iv_net_amount.

    " CALCULATE_TAXES pode rodar 2x no mesmo passo sem o standard refazer o
    " NET_AMOUNT (ADJUST_ICMS_DUE_MINPRICE, nota 2141500): se o valor recebido
    " é o que este método devolveu alterado da última vez, o ajuste já está
    " dentro e o registro para o fim do cálculo continua valendo.
    READ TABLE gt_memo ASSIGNING FIELD-SYMBOL(<ls_memo>)
         WITH KEY calc  = io_calc
                  kposn = iv_kposn
                  kschl = iv_kschl.
    IF sy-subrc = 0 AND <ls_memo>-changed = abap_true
                    AND <ls_memo>-net = iv_net_amount.
      RETURN.
    ENDIF.

    " Base de CBS/IBS = líquido do item. No CALCULATE_TAX o NET_AMOUNT é o
    " líquido: guarda para o IBRX do mesmo item, cujo NET_AMOUNT já tem ICMS
    READ TABLE gt_base ASSIGNING FIELD-SYMBOL(<ls_base>)
         WITH KEY calc  = io_calc
                  kposn = iv_kposn.

    IF iv_cond_code <> c_code_incl_2nd.
      lv_base = iv_net_amount.
      IF <ls_base> IS ASSIGNED.
        <ls_base>-base = lv_base.
      ELSE.
        APPEND VALUE #( calc  = io_calc
                        kposn = iv_kposn
                        base  = lv_base ) TO gt_base.
      ENDIF.
    ELSEIF <ls_base> IS ASSIGNED.
      " IBRX de esquema líquido: base do passo de preço deste item
      lv_base = <ls_base>-base.
      DELETE gt_base WHERE calc = io_calc AND kposn = iv_kposn.
    ELSEIF iv_kappl = c_kappl_sd.
      " IBRX sem passo de preço (SD bruto): a base depende do ICMS, PIS e
      " COFINS finais; o CBS/IBS é calculado no fim do cálculo
      lv_gross = abap_true.
    ELSE.
      lv_base = iv_net_amount * ( 1 - iv_icms_rate ).
    ENDIF.

    IF lv_gross = abap_false.
      lv_cbs_ibs = get_cbs_ibs_amount( iv_kappl = iv_kappl
                                       it_komv  = it_komv
                                       iv_base  = lv_base ).
    ENDIF.

    " Líquido (SD: esquema de preço líquido, ICMI pela fórmula 320; MM:
    " modo L): o ICMS sobre o CBS/IBS entra no preço. Somar t x C ao líquido
    " faz o gross-up sair N + ICMS final, sem o CBS/IBS. Bruto e IBRX: o
    " preço com ICMS é mantido, o CBS/IBS entra só na base do ICMS
    IF iv_cond_code <> c_code_incl_2nd
       AND ( iv_kappl = c_kappl_sd OR get_cfg( iv_kappl )-modo = c_modo_liquid ).
      lv_add_net = lv_cbs_ibs * iv_icms_rate.
    ENDIF.

    rv_net_amount = iv_net_amount + lv_add_net.

    IF <ls_memo> IS NOT ASSIGNED.
      APPEND VALUE #( calc  = io_calc
                      kposn = iv_kposn
                      kschl = iv_kschl ) TO gt_memo ASSIGNING <ls_memo>.
    ENDIF.
    <ls_memo>-net      = rv_net_amount.
    <ls_memo>-changed  = xsdbool( lv_add_net IS NOT INITIAL ).
    <ls_memo>-icms_add = lv_cbs_ibs.
    <ls_memo>-gross    = lv_gross.
  ENDMETHOD.


  METHOD get_icms_base_increment.
    READ TABLE gt_memo ASSIGNING FIELD-SYMBOL(<ls_memo>)
         WITH KEY calc  = io_calc
                  kposn = iv_kposn
                  kschl = iv_kschl.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF <ls_memo>-gross = abap_true.
      rv_amount = get_gross_cbs_ibs( iv_kappl      = iv_kappl
                                     it_komv       = it_komv
                                     iv_value      = iv_value
                                     iv_icms_amt   = iv_icms_amt
                                     iv_pis_cofins = iv_pis_cofins
                                     iv_icms_rate  = iv_icms_rate ).
    ELSE.
      rv_amount = <ls_memo>-icms_add.
    ENDIF.
  ENDMETHOD.


  METHOD get_gross_cbs_ibs.
    DATA:
      lv_rate_sum TYPE ty_amount,
      lv_base     TYPE ty_amount.

    " Base do CBS/IBS = P - ICMS final - PIS - COFINS, com ICMS final =
    " ICMS standard + t x C e C = R x base. Isolando a base:
    "   base = (P - ICMS standard - PIS - COFINS) / (1 + R x t)
    LOOP AT get_rates( iv_kappl = iv_kappl it_komv = it_komv ) INTO DATA(lv_rate).
      lv_rate_sum = lv_rate_sum + lv_rate.
    ENDLOOP.

    IF lv_rate_sum IS INITIAL.
      RETURN.
    ENDIF.

    lv_base = ( iv_value - iv_icms_amt - iv_pis_cofins )
            / ( 1 + lv_rate_sum * iv_icms_rate ).
    IF lv_base <= 0.
      RETURN.
    ENDIF.

    rv_amount = get_cbs_ibs_amount( iv_kappl = iv_kappl
                                    it_komv  = it_komv
                                    iv_base  = lv_base ).
  ENDMETHOD.


  METHOD get_rates.
    DATA lv_rate TYPE ty_amount.

    load_config( ).
    DATA(ls_cfg) = get_cfg( iv_kappl ).
    IF ls_cfg-r_kschl IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_komv ASSIGNING FIELD-SYMBOL(<ls_komv>)
         WHERE kschl IN ls_cfg-r_kschl
           AND kinak IS INITIAL.          "Ignora condição inativa
      CASE <ls_komv>-krech.
        WHEN c_krech_perc.
          lv_rate = abs( <ls_komv>-kbetr ) / 1000.
        WHEN c_krech_perc6.
          lv_rate = abs( <ls_komv>-kbetr ) / 1000000.
        WHEN OTHERS.
          CONTINUE.
      ENDCASE.
      APPEND lv_rate TO rt_rate.
    ENDLOOP.
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

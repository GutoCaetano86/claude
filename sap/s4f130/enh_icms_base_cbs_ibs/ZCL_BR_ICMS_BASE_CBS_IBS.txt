"! <p class="shorttext synchronized" lang="pt">Reforma Tributária: CBS/IBS na base do ICMS (SD/MM)</p>
"! Chamada pela enhancement ZENH_BR_ICMS_BC_CBS_IBS no início de
"! CL_TAX_CALC_BR->CALCULATE_TAXES. Soma o KWERT das condições que carregam o
"! valor de CBS/IBS do item ao valor líquido do passo de cálculo em curso.
"!
"! Configuração 100% na STVARV (nada fixo no código):
"!   ZBR_ICMS_BC_CBS_IBS_ATIVO  (Parâmetro) = 'X' liga a regra
"!   ZBR_ICMS_BC_CBS_IBS_KSCHL  (Seleção)   = condições cujo KWERT entra na BC
"!     Ex. S4F/130: MM (TAXBRA) BXCB/BXBS/BXBM - CBS1/IB1S/IB1M têm KBETR 100%
"!                  fixo, o valor do imposto fica nas BX* (passos 180-182);
"!                  SD (RVABRA/ZBRA01) CBS3/IB3S/IB3M - valor em KWERT.
"!   Regra só atua com as DUAS preenchidas: lista vazia = regra desligada.
"!
"! Preço líquido no SD (ICMI com fórmula 320): o 1º passo (ICMI) parte de
"! KOMP-NETWR e devolve NETWR + ICMS como preço; o 2º passo (IBRX) parte do
"! KAWRT. Por isso o ajuste é feito sobre o NET_AMOUNT que o standard já
"! preparou em cada passo, e não sobre o KAWRT da linha.
CLASS zcl_br_icms_base_cbs_ibs DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_amount TYPE p LENGTH 12 DECIMALS 6.

    "! Regra ativa? (switch = 'X' e lista de condições preenchida)
    CLASS-METHODS is_active
      RETURNING VALUE(rv_active) TYPE abap_bool.

    "! Soma CBS + IBS (UF + Mun.) do item
    "! @parameter it_komv    | KOMV do item (MT_KOMV da CL_TAX_CALC_BR)
    "! @parameter rv_amount  | Valor a somar na base do ICMS
    CLASS-METHODS get_cbs_ibs_amount
      IMPORTING it_komv          TYPE tax_xkomv_tab
      RETURNING VALUE(rv_amount) TYPE ty_amount.

    "! Valor líquido do passo + CBS/IBS, somado uma única vez por passo
    "! @parameter io_calc       | Instância da CL_TAX_CALC_BR (ME)
    "! @parameter iv_kposn      | Item (MS_KOMP-KPOSN)
    "! @parameter iv_kschl      | Condição que chamou o cálculo (MS_KOMV_FRM-KSCHL)
    "! @parameter iv_net_amount | NET_AMOUNT preparado pelo standard neste passo
    "! @parameter it_komv       | KOMV do item
    "! @parameter rv_net_amount | NET_AMOUNT com CBS/IBS
    CLASS-METHODS adjust_net_amount
      IMPORTING io_calc              TYPE REF TO object
                iv_kposn             TYPE kposn
                iv_kschl             TYPE kscha
                iv_net_amount        TYPE kawrt
                it_komv              TYPE tax_xkomv_tab
      RETURNING VALUE(rv_net_amount) TYPE kawrt.

  PRIVATE SECTION.
    CONSTANTS:
      c_tvarv_ativo TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_ATIVO',
      c_tvarv_kschl TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_KSCHL'.

    TYPES ty_r_kschl TYPE RANGE OF kscha.

    " Último valor ajustado por instância / item / passo
    TYPES: BEGIN OF ty_memo,
             calc  TYPE REF TO object,
             kposn TYPE kposn,
             kschl TYPE kscha,
             net   TYPE kawrt,
           END OF ty_memo.

    CLASS-DATA:
      gv_loaded TYPE abap_bool,
      gv_active TYPE abap_bool,
      gr_kschl  TYPE ty_r_kschl,
      gt_memo   TYPE STANDARD TABLE OF ty_memo WITH DEFAULT KEY.

    CLASS-METHODS load_config.
ENDCLASS.



CLASS zcl_br_icms_base_cbs_ibs IMPLEMENTATION.

  METHOD is_active.
    load_config( ).
    rv_active = gv_active.
  ENDMETHOD.


  METHOD get_cbs_ibs_amount.
    load_config( ).

    " Range vazio no WHERE selecionaria a KOMV inteira: sem lista, não soma
    IF gr_kschl IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_komv ASSIGNING FIELD-SYMBOL(<ls_komv>)
         WHERE kschl IN gr_kschl
           AND kinak IS INITIAL.          "Ignora condição inativa
      rv_amount = rv_amount + abs( <ls_komv>-kwert ).
    ENDLOOP.
  ENDMETHOD.


  METHOD adjust_net_amount.
    rv_net_amount = iv_net_amount.

    " CALCULATE_TAXES pode rodar 2x no mesmo passo sem o standard refazer o
    " NET_AMOUNT (ADJUST_ICMS_DUE_MINPRICE, nota 2141500): se o valor recebido
    " é o que este método devolveu da última vez, o CBS/IBS já está dentro.
    READ TABLE gt_memo ASSIGNING FIELD-SYMBOL(<ls_memo>)
         WITH KEY calc  = io_calc
                  kposn = iv_kposn
                  kschl = iv_kschl.
    IF sy-subrc = 0 AND <ls_memo>-net = iv_net_amount.
      RETURN.
    ENDIF.

    rv_net_amount = iv_net_amount + get_cbs_ibs_amount( it_komv ).

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

    " Chave liga/desliga
    SELECT SINGLE low FROM tvarvc
      WHERE name = @c_tvarv_ativo
        AND type = 'P'
        AND numb = '0000'
      INTO @DATA(lv_ativo).

    " Condições cujo KWERT é o valor de CBS/IBS
    SELECT sign, opti AS option, low, high FROM tvarvc
      WHERE name = @c_tvarv_kschl
        AND type = 'S'
        AND low <> @space
      INTO CORRESPONDING FIELDS OF TABLE @gr_kschl.

    gv_active = xsdbool( lv_ativo = abap_true AND gr_kschl IS NOT INITIAL ).
  ENDMETHOD.

ENDCLASS.

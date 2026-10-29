"! <p class="shorttext synchronized" lang="pt">Reforma Tributária: CBS/IBS na base do ICMS (SD/MM)</p>
"! Chamada pela enhancement ZENH_BR_ICMS_BC_CBS_IBS no início de
"! CL_TAX_CALC_BR->CALCULATE_TAXES. Calcula o valor de CBS + IBS do item
"! a partir das alíquotas já determinadas na KOMV (TAXBRA / RVABRA).
"!
"! Liga/desliga e lista de condições ficam na STVARV (sem transporte de código):
"!   ZBR_ICMS_BC_CBS_IBS_ATIVO  (P) = 'X' ativa a regra
"!   ZBR_ICMS_BC_CBS_IBS_KSCHL  (S) = tipos de condição CBS/IBS (opcional;
"!                                    vazio usa a lista padrão abaixo)
CLASS zcl_br_icms_base_cbs_ibs DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_amount TYPE p LENGTH 12 DECIMALS 6.

    "! Regra ativa na STVARV?
    CLASS-METHODS is_active
      RETURNING VALUE(rv_active) TYPE abap_bool.

    "! Soma CBS + IBS (UF + Mun.) do item
    "! @parameter it_komv    | KOMV do item (MT_KOMV da CL_TAX_CALC_BR)
    "! @parameter iv_base    | Base CBS/IBS = valor líquido do item (KAWRT)
    "! @parameter rv_amount  | Valor a somar na base do ICMS
    CLASS-METHODS get_cbs_ibs_amount
      IMPORTING it_komv          TYPE tax_xkomv_tab
                iv_base          TYPE kawrt
      RETURNING VALUE(rv_amount) TYPE ty_amount.

  PRIVATE SECTION.
    CONSTANTS:
      c_tvarv_ativo TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_ATIVO',
      c_tvarv_kschl TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_KSCHL',
      c_krech_perc  TYPE krech      VALUE 'A'.   "Cálculo percentual

    TYPES ty_r_kschl TYPE RANGE OF kscha.

    CLASS-DATA:
      gv_loaded TYPE abap_bool,
      gv_active TYPE abap_bool,
      gr_kschl  TYPE ty_r_kschl.

    CLASS-METHODS load_config.
ENDCLASS.



CLASS zcl_br_icms_base_cbs_ibs IMPLEMENTATION.

  METHOD is_active.
    load_config( ).
    rv_active = gv_active.
  ENDMETHOD.


  METHOD get_cbs_ibs_amount.
    DATA lv_value TYPE ty_amount.

    load_config( ).

    LOOP AT it_komv ASSIGNING FIELD-SYMBOL(<ls_komv>)
         WHERE kschl IN gr_kschl
           AND kinak IS INITIAL.          "Ignora condição inativa

      CLEAR lv_value.

      IF <ls_komv>-krech = c_krech_perc.
        " Alíquota já vem da tabela de condições (KBETR em ‰: 9 = 0,9%).
        " O valor (KWERT) ainda não existe nesta passada, porque CBS/IBS
        " ficam DEPOIS do cálculo do ICMS no esquema.
        lv_value = iv_base * <ls_komv>-kbetr / 1000.
      ELSE.
        " Outros tipos de cálculo: usa o valor já gravado na KOMV
        lv_value = <ls_komv>-kwert.
      ENDIF.

      rv_amount = rv_amount + abs( lv_value ).
    ENDLOOP.
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
    gv_active = xsdbool( lv_ativo = abap_true ).

    " Tipos de condição CBS/IBS
    SELECT sign, opti AS option, low, high FROM tvarvc
      WHERE name = @c_tvarv_kschl
        AND type = 'S'
        AND low <> @space
      INTO CORRESPONDING FIELDS OF TABLE @gr_kschl.

    IF gr_kschl IS INITIAL.
      " Padrão S4F/130: TAXBRA (MM) e RVABRA (SD)
      gr_kschl = VALUE #( sign = 'I' option = 'EQ'
                          ( low = 'CBS1' ) ( low = 'CBS2' )      "CBS - MM
                          ( low = 'IB1S' ) ( low = 'IB2S' )      "IBS UF - MM
                          ( low = 'IB1M' ) ( low = 'IB2M' )      "IBS Mun - MM
                          ( low = 'CBS3' )                       "CBS - SD
                          ( low = 'IB3S' ) ( low = 'IB3M' ) ).   "IBS - SD
    ENDIF.
  ENDMETHOD.

ENDCLASS.

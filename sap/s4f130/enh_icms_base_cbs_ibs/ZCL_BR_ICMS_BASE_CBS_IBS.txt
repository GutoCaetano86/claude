"! <p class="shorttext synchronized" lang="pt">Reforma Tributária: CBS/IBS na base do ICMS (SD/MM)</p>
"! Chamada pela enhancement ZENH_BR_ICMS_BC_CBS_IBS no início de
"! CL_TAX_CALC_BR->CALCULATE_TAXES. Soma o valor de CBS + IBS do item a partir
"! do KWERT das condições que carregam o valor do imposto em cada esquema:
"!   MM (TAXBRA): BXCB / BXBS / BXBM - CBS1, IB1S e IB1M têm KBETR = 100% fixo;
"!                a alíquota real fica nas BX*, cujo KWERT já é o valor do
"!                imposto (passos 180-182, calculados antes do ICMS).
"!   SD (RVABRA/ZBRA01): CBS3 / IB3S / IB3M - KRECH 'W', valor em KWERT.
"!
"! Liga/desliga e lista de condições ficam na STVARV (sem transporte de código):
"!   ZBR_ICMS_BC_CBS_IBS_ATIVO  (P) = 'X' ativa a regra
"!   ZBR_ICMS_BC_CBS_IBS_KSCHL  (S) = condições cujo KWERT é somado (opcional;
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
    "! @parameter rv_amount  | Valor a somar na base do ICMS
    CLASS-METHODS get_cbs_ibs_amount
      IMPORTING it_komv          TYPE tax_xkomv_tab
      RETURNING VALUE(rv_amount) TYPE ty_amount.

  PRIVATE SECTION.
    CONSTANTS:
      c_tvarv_ativo TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_ATIVO',
      c_tvarv_kschl TYPE rvari_vnam VALUE 'ZBR_ICMS_BC_CBS_IBS_KSCHL'.

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
    " Garante a lista carregada: range vazio no WHERE somaria a KOMV inteira
    load_config( ).

    LOOP AT it_komv ASSIGNING FIELD-SYMBOL(<ls_komv>)
         WHERE kschl IN gr_kschl
           AND kinak IS INITIAL.          "Ignora condição inativa
      rv_amount = rv_amount + abs( <ls_komv>-kwert ).
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

    " Condições cujo KWERT é o valor de CBS/IBS
    SELECT sign, opti AS option, low, high FROM tvarvc
      WHERE name = @c_tvarv_kschl
        AND type = 'S'
        AND low <> @space
      INTO CORRESPONDING FIELDS OF TABLE @gr_kschl.

    IF gr_kschl IS INITIAL.
      " Padrão S4F/130. Cada esquema só tem um dos grupos, então não há
      " soma em dobro: o TAXBRA não tem CBS3/IB3x e o SD não tem BX*.
      gr_kschl = VALUE #( sign = 'I' option = 'EQ'
                          ( low = 'BXCB' )                       "CBS     - MM
                          ( low = 'BXBS' )                       "IBS UF  - MM
                          ( low = 'BXBM' )                       "IBS Mun - MM
                          ( low = 'CBS3' )                       "CBS     - SD
                          ( low = 'IB3S' )                       "IBS UF  - SD
                          ( low = 'IB3M' ) ).                    "IBS Mun - SD
    ENDIF.
  ENDMETHOD.

ENDCLASS.

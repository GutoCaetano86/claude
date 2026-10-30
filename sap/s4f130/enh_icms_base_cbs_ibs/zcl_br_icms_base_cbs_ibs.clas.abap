"! <p class="shorttext synchronized" lang="pt">Reforma Tributária: CBS/IBS na base do ICMS (SD/MM)</p>
"! Chamada pela enhancement ZENH_BR_ICMS_BC_CBS_IBS no início de
"! CL_TAX_CALC_BR->CALCULATE_TAXES. Soma o KWERT das condições que carregam o
"! valor de CBS/IBS do item e devolve o total a somar na base do ICMS.
"!
"! Configuração 100% na STVARV (nada fixo no código):
"!   ZBR_ICMS_BC_CBS_IBS_ATIVO  (Parâmetro) = 'X' liga a regra
"!   ZBR_ICMS_BC_CBS_IBS_KSCHL  (Seleção)   = condições cujo KWERT entra na BC
"!     Ex. S4F/130: MM (TAXBRA) BXCB/BXBS/BXBM - CBS1/IB1S/IB1M têm KBETR 100%
"!                  fixo, o valor do imposto fica nas BX* (passos 180-182);
"!                  SD (RVABRA/ZBRA01) CBS3/IB3S/IB3M - valor em KWERT.
"!   Regra só atua com as DUAS preenchidas: lista vazia = regra desligada.
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

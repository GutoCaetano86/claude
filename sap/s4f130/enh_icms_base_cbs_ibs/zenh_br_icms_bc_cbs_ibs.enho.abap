ENHANCEMENT 1  .
*----------------------------------------------------------------------*
* ZENH_BR_ICMS_BC_CBS_IBS - Reforma Tributária
* Inclui CBS/IBS na base do ICMS (SD e MM, preço bruto ou líquido)
* Ponto: início de CL_TAX_CALC_BR->CALCULATE_TAXES
* Configuração (STVARV) e regra: ZCL_BR_ICMS_BASE_CBS_IBS
*----------------------------------------------------------------------*
  IF zcl_br_icms_base_cbs_ibs=>is_active( ms_komk-kappl ) = abap_true.

    " Passo do cálculo: CALCULATE_TAX (ICMI no SD / BX01 no MM) ou
    " CALCULATE_INCL_2ND (IBRX no SD)
    get_condition_code( EXPORTING iv_kschl = ms_komv_frm-kschl
                        IMPORTING ev_code  = DATA(lv_zcbs_code) ).

    " Ajusta o NET_AMOUNT que o standard preparou para este passo (no ICMI
    " o KAWRT da linha é a quantidade), uma única vez por passo
    ms_tax_data-net_amount = zcl_br_icms_base_cbs_ibs=>adjust_net_amount(
      io_calc       = me
      iv_kappl      = ms_komk-kappl
      iv_cond_code  = lv_zcbs_code
      iv_kposn      = ms_komp-kposn
      iv_kschl      = ms_komv_frm-kschl
      iv_icms_rate  = ms_tax_data-icmsrate * ms_tax_data-icmsbase
                    + mv_additional_rate
      iv_net_amount = ms_tax_data-net_amount
      it_komv       = mt_komv ).
  ENDIF.
ENDENHANCEMENT.

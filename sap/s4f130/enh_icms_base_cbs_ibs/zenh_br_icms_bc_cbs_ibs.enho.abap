ENHANCEMENT 1  .
*----------------------------------------------------------------------*
* ZENH_BR_ICMS_BC_CBS_IBS - Reforma Tributária
* Inclui CBS/IBS na base do ICMS (SD e MM)
* Ponto: início de CL_TAX_CALC_BR->CALCULATE_TAXES
* Configuração (STVARV) e regra: ZCL_BR_ICMS_BASE_CBS_IBS
*----------------------------------------------------------------------*
  IF zcl_br_icms_base_cbs_ibs=>is_active( ) = abap_true.
    " Soma CBS/IBS ao NET_AMOUNT que o standard preparou para este passo
    " (MM e 2º passo SD/IBRX: KAWRT; 1º passo SD/ICMI: KOMP-NETWR), uma
    " única vez por passo. Não usar o KAWRT da linha: no ICMI (KRECH C)
    " ele é a quantidade.
    ms_tax_data-net_amount = zcl_br_icms_base_cbs_ibs=>adjust_net_amount(
      io_calc       = me
      iv_kposn      = ms_komp-kposn
      iv_kschl      = ms_komv_frm-kschl
      iv_net_amount = ms_tax_data-net_amount
      it_komv       = mt_komv ).
  ENDIF.
ENDENHANCEMENT.

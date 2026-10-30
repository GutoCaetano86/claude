ENHANCEMENT 1  .
*----------------------------------------------------------------------*
* ZENH_BR_ICMS_BC_CBS_IBS - Reforma Tributária
* Inclui CBS/IBS na base do ICMS (SD = RVABRA/ZBRA01 / MM = TAXBRA)
* Ponto: início de CL_TAX_CALC_BR->CALCULATE_TAXES
* Liga/desliga: STVARV ZBR_ICMS_BC_CBS_IBS_ATIVO = 'X'
* Regra (quais condições somar, por esquema): ZCL_BR_ICMS_BASE_CBS_IBS
*----------------------------------------------------------------------*
  IF zcl_br_icms_base_cbs_ibs=>is_active( ) = abap_true.
    " Parte sempre do KAWRT original (MS_KOMV_FRM): CALCULATE_TAXES pode
    " rodar 2x por item (ADJUST_ICMS_DUE_MINPRICE, nota 2141500) e somar
    " sobre o NET_AMOUNT atual duplicaria CBS/IBS.
    ms_tax_data-net_amount = ms_komv_frm-kawrt
      + zcl_br_icms_base_cbs_ibs=>get_cbs_ibs_amount( mt_komv ).
  ENDIF.
ENDENHANCEMENT.

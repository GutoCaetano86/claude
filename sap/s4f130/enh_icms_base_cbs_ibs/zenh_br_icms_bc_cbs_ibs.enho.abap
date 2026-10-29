*----------------------------------------------------------------------*
* Enhancement Implementation: ZENH_BR_ICMS_BC_CBS_IBS
* Objeto   : CL_TAX_CALC_BR -> CALCULATE_TAXES
* Posição  : implícita, INÍCIO do método (antes de CALCULATE_ICMS)
* Objetivo : Reforma Tributária - incluir CBS/IBS na base do ICMS
*            (SD = RVABRA / MM = TAXBRA, inbound e outbound)
*----------------------------------------------------------------------*
ENHANCEMENT 1 zenh_br_icms_bc_cbs_ibs.
  IF zcl_br_icms_base_cbs_ibs=>is_active( ) = abap_true.
    " Recalcula a partir do KAWRT original (MS_KOMV_FRM) e não do valor
    " atual: CALCULATE_TAXES pode rodar 2x por item (ADJUST_ICMS_DUE_MINPRICE,
    " nota 2141500) e somar sobre NET_AMOUNT duplicaria CBS/IBS.
    ms_tax_data-net_amount = ms_komv_frm-kawrt
      + zcl_br_icms_base_cbs_ibs=>get_cbs_ibs_amount(
          it_komv = mt_komv
          iv_base = ms_komv_frm-kawrt ).
  ENDIF.
ENDENHANCEMENT.

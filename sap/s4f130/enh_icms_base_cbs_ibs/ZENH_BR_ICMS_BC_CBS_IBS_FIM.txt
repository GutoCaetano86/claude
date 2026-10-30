ENHANCEMENT 1  .
*----------------------------------------------------------------------*
* ZENH_BR_ICMS_BC_CBS_IBS_FIM - Reforma Tributária
* Fim de CL_TAX_CALC_BR->CALCULATE_TAXES: soma o CBS/IBS só na base e no
* valor do ICMS e recalcula PIS/COFINS com o ICMS final (IPI não muda).
* Configuração (STVARV) e regra: ZCL_BR_ICMS_BASE_CBS_IBS
*----------------------------------------------------------------------*
  DATA: lv_zcbs_bas_red TYPE zcl_br_icms_base_cbs_ibs=>ty_amount,
        lv_zcbs_pc_diff TYPE zcl_br_icms_base_cbs_ibs=>ty_amount.

  DATA(lv_zcbs_add) = zcl_br_icms_base_cbs_ibs=>get_icms_base_increment(
                        io_calc  = me
                        iv_kposn = ms_komp-kposn
                        iv_kschl = ms_komv_frm-kschl ).

  IF lv_zcbs_add IS NOT INITIAL
     AND zcl_br_icms_base_cbs_ibs=>is_active( ms_komk-kappl ) = abap_true
     AND check_icms_active( ) = 'X'
     AND check_cte_active( ) <> 'X'
     AND ms_tax_data-icmsconv100 IS INITIAL.

    DATA(lv_zcbs_icms_old) = ms_tax_result-icms_amt.
    lv_zcbs_bas_red = lv_zcbs_add * ms_tax_data-icmsbase.

    " ICMS e bases do ICMS (normal e excluída / outras)
    ms_tax_result-icms_amt  = ms_tax_result-icms_amt
                            + lv_zcbs_bas_red * ms_tax_data-icmsrate.
    ms_tax_result-icms_bas  = ms_tax_result-icms_bas  + lv_zcbs_bas_red.
    ms_tax_result-icms_cbas = ms_tax_result-icms_cbas + lv_zcbs_bas_red.
    IF ms_tax_data-icmsother IS INITIAL.
      ms_tax_result-icms_exc = ms_tax_result-icms_exc + lv_zcbs_add - lv_zcbs_bas_red.
    ELSE.
      ms_tax_result-icms_oth = ms_tax_result-icms_oth + lv_zcbs_add - lv_zcbs_bas_red.
    ENDIF.
    mv_icms_reduced_base = mv_icms_reduced_base + lv_zcbs_bas_red.

    " PIS/COFINS: mesma base do standard, refletindo o ICMS final na
    " exclusão do ICMS (sem CBS/IBS na base)
    IF ms_tax_control-piscof_base_is_config IS INITIAL.
      calculate_pis_cof_base( EXPORTING iv_val_incl_icms     = lv_val_incl_icms
                                        iv_val_incl_icms_ipi = lv_val_incl_icms_ipi
                                        iv_icms_amount       = lv_zcbs_icms_old
                              IMPORTING ev_base              = DATA(lv_zcbs_pc_old) ).
      calculate_pis_cof_base( EXPORTING iv_val_incl_icms     = lv_val_incl_icms
                                        iv_val_incl_icms_ipi = lv_val_incl_icms_ipi
                                        iv_icms_amount       = ms_tax_result-icms_amt
                              IMPORTING ev_base              = DATA(lv_zcbs_pc_new) ).
      lv_zcbs_pc_diff = lv_zcbs_pc_new - lv_zcbs_pc_old.

      IF lv_zcbs_pc_diff IS NOT INITIAL.
        lv_base_pis_cofins = lv_base_pis_cofins + lv_zcbs_pc_diff.
        calculate_cofins( iv_calcbase = lv_base_pis_cofins ).
        calculate_pis( iv_calcbase = lv_base_pis_cofins ).

        IF pis_cofins_base_resale <> lv_val_incl_icms.
          pis_cofins_base_resale = pis_cofins_base_resale + lv_zcbs_pc_diff.
        ENDIF.
        calculate_cofins_resale( iv_calcbase            = pis_cofins_base_resale
                                 iv_configured_calcbase = lv_base_pis_cofins_base2 ).
        calculate_pis_resale( iv_calcbase            = pis_cofins_base_resale
                              iv_configured_calcbase = lv_base_pis_cofins_base2 ).
      ENDIF.
    ENDIF.
  ENDIF.
ENDENHANCEMENT.

*&---------------------------------------------------------------------*
*& Report  Z_FI_EXCH_RATE_CHECK
*&---------------------------------------------------------------------*
*& Exchange rate check for one company code.
*& Read-only: the report changes nothing.
*&
*& View 1  Rates on key date  Which rate does a posting get on the key
*&                            date, since when is it valid, how old is
*&                            it, and what does the sample amount become
*&                            in local currency?
*& View 2  Rate history       TCURR entries per currency pair with the
*&                            days between consecutive entries (finds a
*&                            month that was skipped).
*& View 3  Posted documents   Foreign currency documents: BKPF-KURSF and
*&                            the posted local amount against the table
*&                            rate on the translation date.
*&
*& Traffic light   green  = as expected
*&                 yellow = rate is from an earlier month / old rate
*&                 red    = no rate, rate too old, or document differs
*&
*& Frame titles and selection texts are set at INITIALIZATION, so the
*& program runs without maintained text elements.
*&---------------------------------------------------------------------*
REPORT z_fi_exch_rate_check.

DATA: gv_waers TYPE waers,
      gv_blart TYPE blart,
      gv_budat TYPE budat.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE t_b01.
  PARAMETERS: p_bukrs TYPE bukrs       OBLIGATORY,
              p_kurst TYPE tcurr-kurst OBLIGATORY DEFAULT 'M',
              p_date  TYPE sy-datum    OBLIGATORY DEFAULT sy-datum.
  SELECT-OPTIONS: s_waers FOR gv_waers NO INTERVALS,
                  s_tcur  FOR gv_waers NO INTERVALS.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE t_b02.
  PARAMETERS: r_curr RADIOBUTTON GROUP vw DEFAULT 'X',
              r_hist RADIOBUTTON GROUP vw,
              r_docs RADIOBUTTON GROUP vw.
SELECTION-SCREEN END OF BLOCK b02.

SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE t_b03.
  PARAMETERS: p_maxage TYPE i DEFAULT 31,
              p_amt    TYPE bseg-wrbtr DEFAULT '1000.00',
              p_histm  TYPE i DEFAULT 13.
  SELECT-OPTIONS: s_budat FOR gv_budat,
                  s_blart FOR gv_blart.
  PARAMETERS: p_tol TYPE p LENGTH 5 DECIMALS 3 DEFAULT '0.010'.
SELECTION-SCREEN END OF BLOCK b03.

*----------------------------------------------------------------------*
CLASS lcl_report DEFINITION FINAL.
*----------------------------------------------------------------------*
  PUBLIC SECTION.
    CLASS-METHODS:
      set_defaults,
      check_selection,
      run.

  PRIVATE SECTION.
    CONSTANTS: BEGIN OF gc_light,
                 red    TYPE c LENGTH 1 VALUE '1',
                 yellow TYPE c LENGTH 1 VALUE '2',
                 green  TYPE c LENGTH 1 VALUE '3',
               END OF gc_light.

    TYPES: BEGIN OF ty_curr,
             waers TYPE waers,
           END OF ty_curr,
           ty_curr_tab TYPE STANDARD TABLE OF ty_curr WITH EMPTY KEY.

    " Result of one rate lookup. RATE carries the sign of BKPF-KURSF:
    " a negative value is an indirect quotation.
    TYPES: BEGIN OF ty_rate,
             kurst      TYPE tcurr-kurst,
             fcurr      TYPE tcurr-fcurr,
             tcurr      TYPE tcurr-tcurr,
             date       TYPE d,
             found      TYPE abap_bool,
             rate       TYPE tcurr-ukurs,
             ffact      TYPE tcurr-ffact,
             tfact      TYPE tcurr-tfact,
             valid_from TYPE d,
             message    TYPE bapiret1-message,
           END OF ty_rate,
           ty_rate_cache TYPE HASHED TABLE OF ty_rate
                         WITH UNIQUE KEY kurst fcurr tcurr date.

    TYPES: BEGIN OF ty_current,
             light      TYPE c LENGTH 1,
             fcurr      TYPE tcurr-fcurr,
             tcurr      TYPE tcurr-tcurr,
             kurst      TYPE tcurr-kurst,
             ukurs      TYPE tcurr-ukurs,
             quotation  TYPE c LENGTH 8,
             ffact      TYPE tcurr-ffact,
             tfact      TYPE tcurr-tfact,
             valid_from TYPE d,
             age_days   TYPE i,
             amount_fc  TYPE bseg-wrbtr,
             amount_lc  TYPE bseg-dmbtr,
             remark     TYPE c LENGTH 140,
           END OF ty_current.

    TYPES: BEGIN OF ty_history,
             light      TYPE c LENGTH 1,
             fcurr      TYPE tcurr-fcurr,
             tcurr      TYPE tcurr-tcurr,
             kurst      TYPE tcurr-kurst,
             valid_from TYPE d,
             ukurs      TYPE tcurr-ukurs,
             quotation  TYPE c LENGTH 8,
             ffact      TYPE tcurr-ffact,
             tfact      TYPE tcurr-tfact,
             gap_days   TYPE i,
             remark     TYPE c LENGTH 140,
           END OF ty_history.

    TYPES: BEGIN OF ty_document,
             light      TYPE c LENGTH 1,
             belnr      TYPE bkpf-belnr,
             gjahr      TYPE bkpf-gjahr,
             blart      TYPE bkpf-blart,
             monat      TYPE bkpf-monat,
             bldat      TYPE bkpf-bldat,
             budat      TYPE bkpf-budat,
             wwert      TYPE bkpf-wwert,
             waers      TYPE bkpf-waers,
             wrbtr      TYPE bseg-wrbtr,
             kurst      TYPE tcurr-kurst,
             kursf      TYPE bkpf-kursf,
             tab_rate   TYPE tcurr-ukurs,
             valid_from TYPE d,
             dev_pct    TYPE p LENGTH 8 DECIMALS 3,
             hwaer      TYPE bkpf-hwaer,
             dmbtr      TYPE bseg-dmbtr,
             dmbtr_exp  TYPE bseg-dmbtr,
             dmbtr_diff TYPE bseg-dmbtr,
             xblnr      TYPE bkpf-xblnr,
             usnam      TYPE bkpf-usnam,
             remark     TYPE c LENGTH 140,
           END OF ty_document.

    TYPES: BEGIN OF ty_col,
             name   TYPE lvc_fname,
             text   TYPE scrtext_l,
             cfield TYPE lvc_fname,
           END OF ty_col,
           ty_cols TYPE STANDARD TABLE OF ty_col WITH EMPTY KEY.

    CLASS-DATA: gt_cache TYPE ty_rate_cache,
                " Reference currency of rate type P_KURST (TCURV-BWAER). When it
                " is set, every rate is maintained against it (EUR/USD, CAD/USD)
                " and EUR/CAD is a cross rate calculated from the two legs.
                gv_bwaer TYPE tcurv-bwaer.

    CLASS-METHODS:
      get_target_currencies
        IMPORTING iv_hwaer        TYPE waers
        RETURNING VALUE(rt_waers) TYPE ty_curr_tab,
      get_rate
        IMPORTING iv_kurst       TYPE tcurr-kurst
                  iv_fcurr       TYPE tcurr-fcurr
                  iv_tcurr       TYPE tcurr-tcurr
                  iv_date        TYPE d
        RETURNING VALUE(rs_rate) TYPE ty_rate,
      to_local
        IMPORTING iv_kurst         TYPE tcurr-kurst
                  iv_fcurr         TYPE tcurr-fcurr
                  iv_tcurr         TYPE tcurr-tcurr
                  iv_date          TYPE d
                  iv_amount        TYPE bseg-wrbtr
        RETURNING VALUE(rv_amount) TYPE bseg-dmbtr,
      leg_dates
        IMPORTING iv_kurst  TYPE tcurr-kurst
                  iv_fcurr  TYPE tcurr-fcurr
                  iv_tcurr  TYPE tcurr-tcurr
                  iv_date   TYPE d
        EXPORTING ev_oldest TYPE d
                  ev_text   TYPE string,
      no_rate_text
        IMPORTING iv_kurst       TYPE tcurr-kurst
                  iv_fcurr       TYPE tcurr-fcurr
                  iv_tcurr       TYPE tcurr-tcurr
                  iv_date        TYPE d
        RETURNING VALUE(rv_text) TYPE string,
      date_to_gdatu
        IMPORTING iv_date         TYPE d
        RETURNING VALUE(rv_gdatu) TYPE tcurr-gdatu,
      gdatu_to_date
        IMPORTING iv_gdatu       TYPE tcurr-gdatu
        RETURNING VALUE(rv_date) TYPE d,
      show_current
        IMPORTING iv_hwaer TYPE waers,
      show_history
        IMPORTING iv_hwaer TYPE waers,
      show_documents,
      display
        IMPORTING iv_title TYPE csequence
                  it_cols  TYPE ty_cols
        CHANGING  ct_data  TYPE ANY TABLE.
ENDCLASS.

*----------------------------------------------------------------------*
CLASS lcl_report IMPLEMENTATION.
*----------------------------------------------------------------------*
  METHOD set_defaults.
    DATA lv_first TYPE d.

    s_waers[] = VALUE #( sign = 'I' option = 'EQ'
                         ( low = 'EUR' ) ( low = 'USD' ) ).

    lv_first = sy-datum.
    lv_first+6(2) = '01'.
    s_budat[] = VALUE #( ( sign = 'I' option = 'BT' low = lv_first high = sy-datum ) ).
  ENDMETHOD.

  METHOD check_selection.
    SELECT SINGLE @abap_true FROM t001 WHERE bukrs = @p_bukrs INTO @DATA(lv_exists).
    IF lv_exists = abap_false.
      MESSAGE |Company code { p_bukrs } does not exist| TYPE 'E'.
    ENDIF.

    AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
      ID 'BUKRS' FIELD p_bukrs
      ID 'ACTVT' FIELD '03'.
    IF sy-subrc <> 0.
      MESSAGE |No display authorization for company code { p_bukrs }| TYPE 'E'.
    ENDIF.

    IF s_waers[] IS INITIAL.
      MESSAGE 'Enter at least one transaction currency' TYPE 'E'.
    ENDIF.

    IF r_docs = abap_true AND s_budat[] IS INITIAL.
      MESSAGE 'Enter a posting date range for the document view' TYPE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD run.
    SELECT SINGLE waers FROM t001 WHERE bukrs = @p_bukrs INTO @DATA(lv_hwaer).
    SELECT SINGLE bwaer FROM tcurv WHERE kurst = @p_kurst INTO @gv_bwaer.

    CASE abap_true.
      WHEN r_curr.
        show_current( lv_hwaer ).
      WHEN r_hist.
        show_history( lv_hwaer ).
      WHEN r_docs.
        show_documents( ).
    ENDCASE.
  ENDMETHOD.

  METHOD get_target_currencies.
    " Company code currency first, then whatever the user added
    " (for example the group currency).
    rt_waers = VALUE #( ( waers = iv_hwaer ) ).
    IF s_tcur[] IS NOT INITIAL.
      SELECT waers FROM tcurc
        WHERE waers IN @s_tcur[]
          AND waers <> @iv_hwaer
        ORDER BY waers
        APPENDING TABLE @rt_waers.
    ENDIF.
  ENDMETHOD.

  METHOD get_rate.
    DATA: ls_bapi   TYPE bapi1093_0,
          ls_return TYPE bapiret1.

    READ TABLE gt_cache INTO rs_rate
         WITH TABLE KEY kurst = iv_kurst fcurr = iv_fcurr tcurr = iv_tcurr date = iv_date.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    rs_rate = VALUE #( kurst = iv_kurst fcurr = iv_fcurr tcurr = iv_tcurr date = iv_date ).

    " Same logic as a posting: latest rate with valid-from <= date,
    " including inverted rates and rates through a reference currency.
    CALL FUNCTION 'BAPI_EXCHANGERATE_GETDETAIL'
      EXPORTING
        rate_type  = iv_kurst
        from_curr  = iv_fcurr
        to_currncy = iv_tcurr
        date       = iv_date
      IMPORTING
        exch_rate  = ls_bapi
        return     = ls_return.

    IF ls_return-type CA 'EAX'.
      rs_rate-message = ls_return-message.
    ELSEIF ls_bapi-exch_rate_v IS NOT INITIAL.       " indirect quotation
      rs_rate-found      = abap_true.
      rs_rate-rate       = - ls_bapi-exch_rate_v.
      rs_rate-ffact      = ls_bapi-from_factor_v.
      rs_rate-tfact      = ls_bapi-to_factor_v.
      rs_rate-valid_from = ls_bapi-valid_from.
    ELSEIF ls_bapi-exch_rate IS NOT INITIAL.         " direct quotation
      rs_rate-found      = abap_true.
      rs_rate-rate       = ls_bapi-exch_rate.
      rs_rate-ffact      = ls_bapi-from_factor.
      rs_rate-tfact      = ls_bapi-to_factor.
      rs_rate-valid_from = ls_bapi-valid_from.
    ELSE.
      rs_rate-message = 'No exchange rate found'.
    ENDIF.

    INSERT rs_rate INTO TABLE gt_cache.
  ENDMETHOD.

  METHOD to_local.
    CALL FUNCTION 'CONVERT_TO_LOCAL_CURRENCY'
      EXPORTING
        date             = iv_date
        foreign_amount   = iv_amount
        foreign_currency = iv_fcurr
        local_currency   = iv_tcurr
        type_of_rate     = iv_kurst
      IMPORTING
        local_amount     = rv_amount
      EXCEPTIONS
        no_rate_found    = 1
        overflow         = 2
        no_factors_found = 3
        no_spread_found  = 4
        derived_2_times  = 5
        OTHERS           = 6.
    IF sy-subrc <> 0.
      CLEAR rv_amount.
    ENDIF.
  ENDMETHOD.

  METHOD leg_dates.
    " Cross rate through the reference currency: valid-from date of each leg.
    " The oldest leg decides how stale the cross rate is.
    DATA lt_cur TYPE ty_curr_tab.

    CLEAR: ev_oldest, ev_text.
    lt_cur = VALUE #( ( waers = iv_fcurr ) ( waers = iv_tcurr ) ).

    LOOP AT lt_cur INTO DATA(ls_cur) WHERE waers <> gv_bwaer.
      DATA(ls_leg) = get_rate( iv_kurst = iv_kurst
                               iv_fcurr = ls_cur-waers
                               iv_tcurr = gv_bwaer
                               iv_date  = iv_date ).
      IF ls_leg-found = abap_false.
        CONTINUE.
      ENDIF.
      IF ev_oldest IS INITIAL OR ls_leg-valid_from < ev_oldest.
        ev_oldest = ls_leg-valid_from.
      ENDIF.
      ev_text = |{ ev_text } { ls_cur-waers }/{ gv_bwaer } { ls_leg-valid_from DATE = USER }|.
    ENDLOOP.
  ENDMETHOD.

  METHOD no_rate_text.
    " GDATU is inverted, so 'on or before' is GDATU >= inverted date.
    DATA(lv_gdatu) = date_to_gdatu( iv_date ).

    " Rate type with a reference currency: name the leg that is missing.
    IF gv_bwaer IS NOT INITIAL.
      DATA: lt_cur TYPE ty_curr_tab,
            lv_leg TYPE abap_bool.
      lt_cur = VALUE #( ( waers = iv_fcurr ) ( waers = iv_tcurr ) ).
      LOOP AT lt_cur INTO DATA(ls_cur) WHERE waers <> gv_bwaer.
        CLEAR lv_leg.
        SELECT SINGLE @abap_true FROM tcurr
          WHERE kurst = @iv_kurst
            AND fcurr = @ls_cur-waers
            AND tcurr = @gv_bwaer
            AND gdatu >= @lv_gdatu
          INTO @lv_leg.
        IF lv_leg = abap_false.
          rv_text = |{ rv_text } { ls_cur-waers }/{ gv_bwaer }|.
        ENDIF.
      ENDLOOP.
      IF rv_text IS NOT INITIAL.
        rv_text = |Rate type { iv_kurst } works through reference currency { gv_bwaer }. Missing on or before key date:{ rv_text }|.
        RETURN.
      ENDIF.
    ENDIF.

    SELECT SINGLE @abap_true FROM tcurr
      WHERE kurst = @iv_kurst
        AND fcurr = @iv_tcurr
        AND tcurr = @iv_fcurr
        AND gdatu >= @lv_gdatu
      INTO @DATA(lv_inverse).

    IF lv_inverse = abap_true.
      rv_text = |Only inverse pair { iv_tcurr }/{ iv_fcurr } is maintained; rate type { iv_kurst } does not invert it|.
    ELSE.
      rv_text = |No rate { iv_fcurr }/{ iv_tcurr } or { iv_tcurr }/{ iv_fcurr } with type { iv_kurst } on or before the key date|.
    ENDIF.
  ENDMETHOD.

  METHOD date_to_gdatu.
    " TCURR-GDATU is the inverted date: 99999999 - YYYYMMDD.
    DATA: lv_c8 TYPE c LENGTH 8,
          lv_n8 TYPE n LENGTH 8.

    lv_c8 = iv_date.
    lv_n8 = 99999999 - CONV i( lv_c8 ).
    rv_gdatu = lv_n8.
  ENDMETHOD.

  METHOD gdatu_to_date.
    DATA: lv_c8 TYPE c LENGTH 8,
          lv_n8 TYPE n LENGTH 8.

    lv_n8 = 99999999 - CONV i( iv_gdatu ).
    lv_c8 = lv_n8.
    rv_date = lv_c8.
  ENDMETHOD.

  METHOD show_current.
    DATA: lt_out    TYPE STANDARD TABLE OF ty_current,
          ls_out    TYPE ty_current,
          lv_oldest TYPE d,
          lv_legs   TYPE string.

    SELECT waers FROM tcurc
      WHERE waers IN @s_waers[]
      ORDER BY waers
      INTO TABLE @DATA(lt_source).

    DATA(lt_target) = get_target_currencies( iv_hwaer ).

    LOOP AT lt_source INTO DATA(ls_source).
      LOOP AT lt_target INTO DATA(ls_target).
        ls_out = VALUE #( fcurr     = ls_source-waers
                          tcurr     = ls_target-waers
                          kurst     = p_kurst
                          amount_fc = p_amt ).

        IF ls_source-waers = ls_target-waers.
          ls_out-light     = gc_light-green.
          ls_out-ukurs     = 1.
          ls_out-ffact     = 1.
          ls_out-tfact     = 1.
          ls_out-amount_lc = p_amt.
          ls_out-remark    = 'Same currency - no exchange rate needed'.
          APPEND ls_out TO lt_out.
          CONTINUE.
        ENDIF.

        DATA(ls_rate) = get_rate( iv_kurst = p_kurst
                                  iv_fcurr = ls_source-waers
                                  iv_tcurr = ls_target-waers
                                  iv_date  = p_date ).
        IF ls_rate-found = abap_false.
          ls_out-light  = gc_light-red.
          ls_out-remark = no_rate_text( iv_kurst = p_kurst
                                        iv_fcurr = ls_source-waers
                                        iv_tcurr = ls_target-waers
                                        iv_date  = p_date ).
          APPEND ls_out TO lt_out.
          CONTINUE.
        ENDIF.

        ls_out-ukurs      = abs( ls_rate-rate ).
        ls_out-quotation  = COND #( WHEN ls_rate-rate < 0 THEN 'Indirect' ELSE 'Direct' ).
        ls_out-ffact      = ls_rate-ffact.
        ls_out-tfact      = ls_rate-tfact.
        ls_out-valid_from = ls_rate-valid_from.
        IF gv_bwaer IS NOT INITIAL.
          leg_dates( EXPORTING iv_kurst  = p_kurst
                               iv_fcurr  = ls_source-waers
                               iv_tcurr  = ls_target-waers
                               iv_date   = p_date
                     IMPORTING ev_oldest = lv_oldest
                               ev_text   = lv_legs ).
          IF lv_oldest IS NOT INITIAL.
            ls_out-valid_from = lv_oldest.
          ENDIF.
        ENDIF.
        ls_out-age_days   = p_date - ls_out-valid_from.
        ls_out-amount_lc  = to_local( iv_kurst  = p_kurst
                                      iv_fcurr  = ls_source-waers
                                      iv_tcurr  = ls_target-waers
                                      iv_date   = p_date
                                      iv_amount = p_amt ).

        IF ls_out-valid_from(6) = p_date(6).
          ls_out-light  = gc_light-green.
          ls_out-remark = 'Rate maintained for the key-date month'.
        ELSEIF ls_out-age_days <= p_maxage.
          ls_out-light  = gc_light-yellow.
          ls_out-remark = 'Rate is from an earlier month'.
        ELSE.
          ls_out-light  = gc_light-red.
          ls_out-remark = |Rate is older than { p_maxage } days|.
        ENDIF.
        IF lv_legs IS NOT INITIAL.
          ls_out-remark = |{ ls_out-remark }. Via { gv_bwaer }:{ lv_legs }|.
        ENDIF.
        APPEND ls_out TO lt_out.
      ENDLOOP.
    ENDLOOP.

    IF lt_out IS INITIAL.
      MESSAGE 'No valid currency keys selected' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    display(
      EXPORTING
        iv_title = |Exchange rates for company code { p_bukrs } on { p_date DATE = USER }, rate type { p_kurst }|
        it_cols  = VALUE #( ( name = 'FCURR'      text = 'From currency' )
                            ( name = 'TCURR'      text = 'To currency' )
                            ( name = 'QUOTATION'  text = 'Quotation' )
                            ( name = 'VALID_FROM' text = 'Valid from (oldest)' )
                            ( name = 'AGE_DAYS'   text = 'Age (days)' )
                            ( name = 'AMOUNT_FC'  text = 'Sample amount'     cfield = 'FCURR' )
                            ( name = 'AMOUNT_LC'  text = 'Converted amount'  cfield = 'TCURR' )
                            ( name = 'REMARK'     text = 'Remark' ) )
      CHANGING
        ct_data  = lt_out ).
  ENDMETHOD.

  METHOD show_history.
    DATA: lt_out        TYPE STANDARD TABLE OF ty_history,
          lt_tcur_range TYPE RANGE OF waers,
          lt_from_1     TYPE RANGE OF waers,
          lt_to_1       TYPE RANGE OF waers,
          lt_from_2     TYPE RANGE OF waers,
          lt_to_2       TYPE RANGE OF waers,
          lv_from       TYPE d,
          lv_fcurr      TYPE tcurr-fcurr,
          lv_tcurr      TYPE tcurr-tcurr,
          lv_older      TYPE i,
          lv_prev_from  TYPE d,
          lv_in_force   TYPE abap_bool,
          lv_age        TYPE i.

    " History months 0 = everything. LV_FROM stays initial then.
    IF p_histm > 0.
      lv_from = p_date - p_histm * 31.
    ENDIF.

    DATA(lt_target) = get_target_currencies( iv_hwaer ).
    lt_tcur_range = VALUE #( FOR ls_target IN lt_target
                             ( sign = 'I' option = 'EQ' low = ls_target-waers ) ).

    " A pair can be stored in either direction, so read both.
    " With a reference currency the entries are currency -> reference currency
    " for every currency involved, not transaction currency -> local currency.
    IF gv_bwaer IS INITIAL.
      lt_from_1 = s_waers[].
      lt_to_1   = lt_tcur_range.
    ELSE.
      lt_from_1 = s_waers[].
      APPEND LINES OF lt_tcur_range TO lt_from_1.
      lt_to_1   = VALUE #( ( sign = 'I' option = 'EQ' low = gv_bwaer ) ).
    ENDIF.
    lt_from_2 = lt_to_1.
    lt_to_2   = lt_from_1.

    " All dates are read: the rate in force can be much older than the period.
    SELECT kurst, fcurr, tcurr, gdatu, ukurs, ffact, tfact
      FROM tcurr
      WHERE kurst = @p_kurst
        AND ( ( fcurr IN @lt_from_1 AND tcurr IN @lt_to_1 )
           OR ( fcurr IN @lt_from_2 AND tcurr IN @lt_to_2 ) )
      INTO TABLE @DATA(lt_tcurr).

    LOOP AT lt_tcurr INTO DATA(ls_tcurr).
      APPEND VALUE #( light      = gc_light-green
                      fcurr      = ls_tcurr-fcurr
                      tcurr      = ls_tcurr-tcurr
                      kurst      = ls_tcurr-kurst
                      valid_from = gdatu_to_date( ls_tcurr-gdatu )
                      ukurs      = abs( ls_tcurr-ukurs )
                      quotation  = COND #( WHEN ls_tcurr-ukurs < 0 THEN 'Indirect' ELSE 'Direct' )
                      ffact      = ls_tcurr-ffact
                      tfact      = ls_tcurr-tfact ) TO lt_out.
    ENDLOOP.

    IF lt_out IS INITIAL.
      MESSAGE |No TCURR entry at all for rate type { p_kurst } and these currencies, in either direction|
              TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " Keep the selected period plus, per pair, the last entry before it:
    " that entry is the rate in force when the period starts.
    SORT lt_out BY fcurr ASCENDING tcurr ASCENDING valid_from DESCENDING.
    LOOP AT lt_out REFERENCE INTO DATA(lr_out).
      IF lr_out->fcurr <> lv_fcurr OR lr_out->tcurr <> lv_tcurr.
        lv_fcurr = lr_out->fcurr.
        lv_tcurr = lr_out->tcurr.
        lv_older = 0.
      ENDIF.
      IF lr_out->valid_from < lv_from.
        lv_older = lv_older + 1.
        IF lv_older > 1.
          lr_out->light = 'D'.
        ENDIF.
      ENDIF.
    ENDLOOP.
    DELETE lt_out WHERE light = 'D'.

    SORT lt_out BY fcurr ASCENDING tcurr ASCENDING valid_from ASCENDING.
    CLEAR: lv_fcurr, lv_tcurr.

    LOOP AT lt_out REFERENCE INTO lr_out.
      DATA(lv_next) = sy-tabix + 1.

      " TCURR itself carries no ratios (they are in TCURF), so take them
      " from the standard lookup on the valid-from date of the entry.
      DATA(ls_rate) = get_rate( iv_kurst = lr_out->kurst
                                iv_fcurr = lr_out->fcurr
                                iv_tcurr = lr_out->tcurr
                                iv_date  = lr_out->valid_from ).
      IF ls_rate-found = abap_true.
        lr_out->ffact = ls_rate-ffact.
        lr_out->tfact = ls_rate-tfact.
      ENDIF.

      " Days since the previous entry of the same pair
      IF lr_out->fcurr = lv_fcurr AND lr_out->tcurr = lv_tcurr.
        lr_out->gap_days = lr_out->valid_from - lv_prev_from.
        IF lr_out->gap_days > p_maxage.
          lr_out->light  = gc_light-red.
          lr_out->remark = |{ lr_out->gap_days } days since the previous rate - was a month skipped?|.
        ENDIF.
      ENDIF.
      lv_fcurr     = lr_out->fcurr.
      lv_tcurr     = lr_out->tcurr.
      lv_prev_from = lr_out->valid_from.

      IF lr_out->valid_from > p_date.
        lr_out->light  = gc_light-yellow.
        lr_out->remark = 'Valid-from date is after the key date'.
        CONTINUE.
      ENDIF.

      IF gv_bwaer IS NOT INITIAL AND lr_out->tcurr <> gv_bwaer.
        lr_out->light  = gc_light-yellow.
        lr_out->remark = |Not read: rates of type { p_kurst } must point to reference currency { gv_bwaer }|.
        CONTINUE.
      ENDIF.

      " In force on the key date = no later entry of the pair on or before it
      lv_in_force = abap_true.
      IF lv_next <= lines( lt_out ).
        READ TABLE lt_out INDEX lv_next REFERENCE INTO DATA(lr_next).
        IF lr_next->fcurr = lr_out->fcurr
           AND lr_next->tcurr = lr_out->tcurr
           AND lr_next->valid_from <= p_date.
          lv_in_force = abap_false.
        ENDIF.
      ENDIF.
      IF lv_in_force = abap_true.
        lv_age = p_date - lr_out->valid_from.
        lr_out->remark = |In force on the key date, { lv_age } days old|.
        IF lv_age > p_maxage.
          lr_out->light = gc_light-red.
        ENDIF.
      ENDIF.
    ENDLOOP.

    display(
      EXPORTING
        iv_title = |Exchange rate history (TCURR), rate type { p_kurst }, key date { p_date DATE = USER }|
        it_cols  = VALUE #( ( name = 'FCURR'      text = 'From currency' )
                            ( name = 'TCURR'      text = 'To currency' )
                            ( name = 'VALID_FROM' text = 'Valid from' )
                            ( name = 'QUOTATION'  text = 'Quotation' )
                            ( name = 'GAP_DAYS'   text = 'Days since previous' )
                            ( name = 'REMARK'     text = 'Remark' ) )
      CHANGING
        ct_data  = lt_out ).
  ENDMETHOD.

  METHOD show_documents.
    DATA: lt_out   TYPE STANDARD TABLE OF ty_document,
          ls_out   TYPE ty_document,
          lv_kurst TYPE tcurr-kurst,
          lv_wwert TYPE d,
          lv_age   TYPE i.

    " Debit side of every document = document total, in both currencies.
    " BSEG can be joined because this is S/4HANA (transparent table).
    SELECT h~belnr, h~gjahr, h~blart, h~monat, h~bldat, h~budat, h~wwert,
           h~waers, h~hwaer, h~kursf, h~xblnr, h~usnam,
           SUM( i~wrbtr ) AS wrbtr,
           SUM( i~dmbtr ) AS dmbtr
      FROM bkpf AS h
      INNER JOIN bseg AS i
        ON  i~bukrs = h~bukrs
        AND i~belnr = h~belnr
        AND i~gjahr = h~gjahr
      WHERE h~bukrs = @p_bukrs
        AND h~budat IN @s_budat[]
        AND h~blart IN @s_blart[]
        AND h~waers IN @s_waers[]
        AND h~bstat = @space
        AND i~shkzg = 'S'
      GROUP BY h~belnr, h~gjahr, h~blart, h~monat, h~bldat, h~budat, h~wwert,
               h~waers, h~hwaer, h~kursf, h~xblnr, h~usnam
      ORDER BY h~gjahr, h~belnr
      INTO TABLE @DATA(lt_docs).

    " A document type can carry its own exchange rate type (OBA7).
    SELECT blart, kurst FROM t003 INTO TABLE @DATA(lt_t003).

    LOOP AT lt_docs INTO DATA(ls_doc).
      IF ls_doc-waers = ls_doc-hwaer.
        CONTINUE.                       " local currency document: nothing to check
      ENDIF.

      lv_kurst = VALUE #( lt_t003[ blart = ls_doc-blart ]-kurst OPTIONAL ).
      IF lv_kurst IS INITIAL.
        lv_kurst = p_kurst.
      ENDIF.
      lv_wwert = COND #( WHEN ls_doc-wwert IS INITIAL THEN ls_doc-budat ELSE ls_doc-wwert ).

      ls_out = CORRESPONDING #( ls_doc ).
      ls_out-kurst = lv_kurst.

      DATA(ls_rate) = get_rate( iv_kurst = lv_kurst
                                iv_fcurr = ls_doc-waers
                                iv_tcurr = ls_doc-hwaer
                                iv_date  = lv_wwert ).
      IF ls_rate-found = abap_false.
        ls_out-light  = gc_light-red.
        ls_out-remark = ls_rate-message.
        APPEND ls_out TO lt_out.
        CONTINUE.
      ENDIF.

      ls_out-tab_rate   = ls_rate-rate.
      ls_out-valid_from = ls_rate-valid_from.
      ls_out-dmbtr_exp  = to_local( iv_kurst  = lv_kurst
                                    iv_fcurr  = ls_doc-waers
                                    iv_tcurr  = ls_doc-hwaer
                                    iv_date   = lv_wwert
                                    iv_amount = ls_out-wrbtr ).
      ls_out-dmbtr_diff = ls_out-dmbtr - ls_out-dmbtr_exp.

      TRY.
          ls_out-dev_pct = ( CONV decfloat34( ls_doc-kursf ) - ls_rate-rate ) / ls_rate-rate * 100.
        CATCH cx_sy_arithmetic_error.
          ls_out-dev_pct = 0.
          ls_out-remark  = 'Rate deviation could not be calculated'.
      ENDTRY.

      lv_age = lv_wwert - ls_rate-valid_from.
      IF abs( ls_out-dev_pct ) > p_tol OR ls_out-dmbtr_diff <> 0.
        ls_out-light  = gc_light-red.
        ls_out-remark = 'Document differs from the table rate on the translation date'.
      ELSEIF lv_age > p_maxage.
        ls_out-light  = gc_light-yellow.
        ls_out-remark = |Table rate was { lv_age } days old on the translation date|.
      ELSEIF ls_out-remark IS NOT INITIAL.
        ls_out-light  = gc_light-yellow.
      ELSE.
        ls_out-light  = gc_light-green.
      ENDIF.
      APPEND ls_out TO lt_out.
    ENDLOOP.

    IF lt_out IS INITIAL.
      MESSAGE 'No foreign currency documents found for this selection' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    display(
      EXPORTING
        iv_title = |Foreign currency documents in company code { p_bukrs } against the table rate|
        it_cols  = VALUE #( ( name = 'WRBTR'      text = 'Amount doc. curr.'   cfield = 'WAERS' )
                            ( name = 'KURST'      text = 'Rate type used' )
                            ( name = 'KURSF'      text = 'Document rate' )
                            ( name = 'TAB_RATE'   text = 'Table rate' )
                            ( name = 'VALID_FROM' text = 'Table rate from' )
                            ( name = 'DEV_PCT'    text = 'Rate deviation %' )
                            ( name = 'DMBTR'      text = 'Posted local amt'    cfield = 'HWAER' )
                            ( name = 'DMBTR_EXP'  text = 'Expected local amt'  cfield = 'HWAER' )
                            ( name = 'DMBTR_DIFF' text = 'Difference'          cfield = 'HWAER' )
                            ( name = 'REMARK'     text = 'Remark' ) )
      CHANGING
        ct_data  = lt_out ).
  ENDMETHOD.

  METHOD display.
    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = DATA(lo_alv)
          CHANGING  t_table      = ct_data ).

        lo_alv->get_functions( )->set_all( abap_true ).
        lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).
        lo_alv->get_display_settings( )->set_list_header( CONV #( iv_title ) ).
        lo_alv->get_layout( )->set_key( VALUE #( report = sy-repid ) ).
        lo_alv->get_layout( )->set_save_restriction( if_salv_c_layout=>restrict_none ).

        DATA(lo_cols) = lo_alv->get_columns( ).
        lo_cols->set_optimize( abap_true ).
        lo_cols->set_exception_column( 'LIGHT' ).

        LOOP AT it_cols INTO DATA(ls_col).
          DATA(lo_col) = lo_cols->get_column( ls_col-name ).
          " Texts that do not fit are left empty, so the ALV takes the long one.
          lo_col->set_short_text( COND #( WHEN strlen( ls_col-text ) <= 10 THEN ls_col-text ) ).
          lo_col->set_medium_text( COND #( WHEN strlen( ls_col-text ) <= 20 THEN ls_col-text ) ).
          lo_col->set_long_text( ls_col-text ).
          IF ls_col-cfield IS NOT INITIAL.
            lo_col->set_currency_column( CONV #( ls_col-cfield ) ).
          ENDIF.
        ENDLOOP.

        lo_alv->display( ).
      CATCH cx_salv_error INTO DATA(lx_salv).
        DATA(lv_text) = lx_salv->get_text( ).
        MESSAGE lv_text TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
INITIALIZATION.
  t_b01 = 'Company code and currencies'.
  t_b02 = 'View'.
  t_b03 = 'Options'.
  " Selection texts (maximum 30 characters). They replace maintained texts.
  %_p_bukrs_%_app_%-text  = 'Company code'.
  %_p_kurst_%_app_%-text  = 'Exchange rate type'.
  %_p_date_%_app_%-text   = 'Key date (posting date)'.
  %_s_waers_%_app_%-text  = 'Transaction currencies'.
  %_s_tcur_%_app_%-text   = 'Additional target currencies'.
  %_r_curr_%_app_%-text   = 'Rates on key date'.
  %_r_hist_%_app_%-text   = 'Rate history (TCURR)'.
  %_r_docs_%_app_%-text   = 'Posted documents vs table rate'.
  %_p_maxage_%_app_%-text = 'Max. age of a rate in days'.
  %_p_amt_%_app_%-text    = 'Sample amount (view 1)'.
  %_p_histm_%_app_%-text  = 'History months (view 2, 0=all)'.
  %_s_budat_%_app_%-text  = 'Posting date (view 3)'.
  %_s_blart_%_app_%-text  = 'Document type (view 3)'.
  %_p_tol_%_app_%-text    = 'Rate tolerance in % (view 3)'.
  lcl_report=>set_defaults( ).

AT SELECTION-SCREEN.
  lcl_report=>check_selection( ).

START-OF-SELECTION.
  lcl_report=>run( ).

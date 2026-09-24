*&---------------------------------------------------------------------*
*& Report  Z_ADAM_POSTING_KEY_COMPARE
*&---------------------------------------------------------------------*
*& Posting keys (OB41, table TBSL) of this client against the client
*& behind an RFC destination, with the field status of two chosen
*& fields - meant for Profit Center and Business Area - decoded side
*& by side. Read-only: the report changes nothing, here or there.
*&
*& Without an RFC destination it lists this client's posting keys with
*& the two decoded statuses and the raw field status strings.
*&
*& The field status of a posting key is two character strings,
*& TBSL-FAUS1 and TBSL-FAUS2, one character per field:
*&   '+' required entry    '.' optional entry    '-' suppressed
*& Which position belongs to which field is NOT hard-coded here. Find
*& it once: in a sandbox client, set Profit Center to required on one
*& posting key in OB41, run this report from that client against an
*& untouched client, and the "Differing positions" column of that key
*& names the position. Enter it on the selection screen from then on.
*& The positions are the same for every posting key.
*&
*& Traffic light   green  = identical on both sides
*&                 yellow = differs, but not in the two chosen fields
*&                 red    = a chosen field differs, or the key exists
*&                          on one side only
*&
*& Frame titles and selection texts are set at INITIALIZATION, so the
*& program runs without maintained text elements.
*&---------------------------------------------------------------------*
REPORT z_adam_posting_key_compare.

DATA gv_bschl TYPE bschl.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE t_b01.
  PARAMETERS p_dest TYPE rfcdest.
  SELECT-OPTIONS s_bschl FOR gv_bschl.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE t_b02.
  PARAMETERS: p_pos_a TYPE i,
              p_nam_a TYPE c LENGTH 15 DEFAULT 'Profit Center',
              p_pos_b TYPE i,
              p_nam_b TYPE c LENGTH 15 DEFAULT 'Business Area'.
SELECTION-SCREEN END OF BLOCK b02.

SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE t_b03.
  PARAMETERS: p_onlydf AS CHECKBOX DEFAULT 'X',
              p_raw    AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b03.

*----------------------------------------------------------------------*
CLASS lcl_report DEFINITION FINAL.
*----------------------------------------------------------------------*
  PUBLIC SECTION.
    CLASS-METHODS:
      check_selection,
      run.

  PRIVATE SECTION.
    CONSTANTS: BEGIN OF gc_light,
                 red    TYPE c LENGTH 1 VALUE '1',
                 yellow TYPE c LENGTH 1 VALUE '2',
                 green  TYPE c LENGTH 1 VALUE '3',
               END OF gc_light.

    " One posting key - the same shape whichever side it was read from.
    TYPES: BEGIN OF ty_key,
             bschl TYPE tbsl-bschl,
             shkzg TYPE tbsl-shkzg,
             koart TYPE tbsl-koart,
             stbsl TYPE tbsl-stbsl,
             xsonu TYPE tbsl-xsonu,
             xumsw TYPE tbsl-xumsw,
             xzahl TYPE tbsl-xzahl,
             faus1 TYPE tbsl-faus1,
             faus2 TYPE tbsl-faus2,
           END OF ty_key,
           ty_key_tab TYPE SORTED TABLE OF ty_key WITH UNIQUE KEY bschl.

    TYPES: BEGIN OF ty_text,
             bschl TYPE tbslt-bschl,
             ltext TYPE tbslt-ltext,
           END OF ty_text,
           ty_text_tab TYPE HASHED TABLE OF ty_text WITH UNIQUE KEY bschl.

    TYPES: ty_bschl_tab TYPE SORTED TABLE OF tbsl-bschl WITH UNIQUE KEY table_line,
           ty_char1     TYPE c LENGTH 1.

    " One output line. *_L = this client, *_R = the client behind P_DEST.
    TYPES: BEGIN OF ty_out,
             light   TYPE c LENGTH 1,
             bschl   TYPE tbsl-bschl,
             ltext   TYPE tbslt-ltext,
             found   TYPE c LENGTH 12,
             a_loc   TYPE c LENGTH 10,
             a_rem   TYPE c LENGTH 10,
             b_loc   TYPE c LENGTH 10,
             b_rem   TYPE c LENGTH 10,
             ndiff   TYPE i,
             diffpos TYPE c LENGTH 128,
             koart_l TYPE tbsl-koart,
             koart_r TYPE tbsl-koart,
             shkzg_l TYPE tbsl-shkzg,
             shkzg_r TYPE tbsl-shkzg,
             stbsl_l TYPE tbsl-stbsl,
             stbsl_r TYPE tbsl-stbsl,
             xsonu_l TYPE tbsl-xsonu,
             xsonu_r TYPE tbsl-xsonu,
             xumsw_l TYPE tbsl-xumsw,
             xumsw_r TYPE tbsl-xumsw,
             xzahl_l TYPE tbsl-xzahl,
             xzahl_r TYPE tbsl-xzahl,
             faus_l  TYPE c LENGTH 128,
             faus_r  TYPE c LENGTH 128,
           END OF ty_out,
           ty_out_tab TYPE STANDARD TABLE OF ty_out WITH EMPTY KEY.

    TYPES: BEGIN OF ty_col,
             name TYPE lvc_fname,
             text TYPE string,
             hide TYPE abap_bool,
           END OF ty_col,
           ty_col_tab TYPE STANDARD TABLE OF ty_col WITH EMPTY KEY.

    CLASS-METHODS:
      read_local
        RETURNING VALUE(rt_keys) TYPE ty_key_tab,
      read_remote
        IMPORTING iv_dest  TYPE rfcdest
        EXPORTING et_keys  TYPE ty_key_tab
                  ev_error TYPE string,
      read_texts
        RETURNING VALUE(rt_texts) TYPE ty_text_tab,
      total_length
        RETURNING VALUE(rv_len) TYPE i,
      char_at
        IMPORTING is_key         TYPE ty_key
                  iv_pos         TYPE i
        RETURNING VALUE(rv_char) TYPE ty_char1,
      status_at
        IMPORTING is_key         TYPE ty_key
                  iv_pos         TYPE i
        RETURNING VALUE(rv_text) TYPE string,
      differing_positions
        IMPORTING is_loc   TYPE ty_key
                  is_rem   TYPE ty_key
        EXPORTING ev_list  TYPE string
                  ev_count TYPE i,
      raw_string
        IMPORTING is_key        TYPE ty_key
        RETURNING VALUE(rv_raw) TYPE string,
      display
        IMPORTING iv_title TYPE string
                  it_cols  TYPE ty_col_tab
        CHANGING  ct_data  TYPE ty_out_tab.
ENDCLASS.

*----------------------------------------------------------------------*
CLASS lcl_report IMPLEMENTATION.
*----------------------------------------------------------------------*
  METHOD check_selection.
    IF p_pos_a < 0 OR p_pos_b < 0.
      MESSAGE 'A position is 1 or greater, or blank' TYPE 'E'.
    ENDIF.
    IF p_pos_a > 0 AND p_pos_a = p_pos_b.
      MESSAGE 'Field A and field B have the same position' TYPE 'E'.
    ENDIF.
    IF p_pos_a > total_length( ) OR p_pos_b > total_length( ).
      MESSAGE |A position cannot exceed { total_length( ) } (FAUS1 + FAUS2)| TYPE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD run.
    DATA: lt_out   TYPE ty_out_tab,
          ls_out   TYPE ty_out,
          lt_rem   TYPE ty_key_tab,
          lt_keys  TYPE ty_bschl_tab,
          ls_loc   TYPE ty_key,
          ls_rem   TYPE ty_key,
          lv_error TYPE string,
          lv_list  TYPE string,
          lv_count TYPE i,
          lv_title TYPE string.

    DATA(lt_loc)   = read_local( ).
    DATA(lt_texts) = read_texts( ).

    IF p_dest IS NOT INITIAL.
      read_remote( EXPORTING iv_dest  = p_dest
                   IMPORTING et_keys  = lt_rem
                             ev_error = lv_error ).
      IF lv_error IS NOT INITIAL.
        MESSAGE lv_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    ENDIF.

    " Union of the posting keys on both sides, in key order.
    LOOP AT lt_loc INTO ls_loc.
      INSERT ls_loc-bschl INTO TABLE lt_keys.
    ENDLOOP.
    LOOP AT lt_rem INTO ls_rem.
      INSERT ls_rem-bschl INTO TABLE lt_keys.
    ENDLOOP.

    IF lt_keys IS INITIAL.
      MESSAGE 'No posting keys found for this selection' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    LOOP AT lt_keys INTO DATA(lv_bschl).
      CLEAR ls_out.
      ls_out-bschl = lv_bschl.

      READ TABLE lt_texts INTO DATA(ls_text) WITH TABLE KEY bschl = lv_bschl.
      IF sy-subrc = 0.
        ls_out-ltext = ls_text-ltext.
      ENDIF.

      READ TABLE lt_loc INTO ls_loc WITH TABLE KEY bschl = lv_bschl.
      DATA(lv_has_loc) = xsdbool( sy-subrc = 0 ).
      READ TABLE lt_rem INTO ls_rem WITH TABLE KEY bschl = lv_bschl.
      DATA(lv_has_rem) = xsdbool( sy-subrc = 0 ).

      IF lv_has_loc = abap_true.
        ls_out-a_loc   = status_at( is_key = ls_loc iv_pos = p_pos_a ).
        ls_out-b_loc   = status_at( is_key = ls_loc iv_pos = p_pos_b ).
        ls_out-koart_l = ls_loc-koart.
        ls_out-shkzg_l = ls_loc-shkzg.
        ls_out-stbsl_l = ls_loc-stbsl.
        ls_out-xsonu_l = ls_loc-xsonu.
        ls_out-xumsw_l = ls_loc-xumsw.
        ls_out-xzahl_l = ls_loc-xzahl.
        ls_out-faus_l  = raw_string( ls_loc ).
      ENDIF.
      IF lv_has_rem = abap_true.
        ls_out-a_rem   = status_at( is_key = ls_rem iv_pos = p_pos_a ).
        ls_out-b_rem   = status_at( is_key = ls_rem iv_pos = p_pos_b ).
        ls_out-koart_r = ls_rem-koart.
        ls_out-shkzg_r = ls_rem-shkzg.
        ls_out-stbsl_r = ls_rem-stbsl.
        ls_out-xsonu_r = ls_rem-xsonu.
        ls_out-xumsw_r = ls_rem-xumsw.
        ls_out-xzahl_r = ls_rem-xzahl.
        ls_out-faus_r  = raw_string( ls_rem ).
      ENDIF.

      IF p_dest IS INITIAL.
        ls_out-found = 'this client'.
      ELSEIF lv_has_loc = abap_true AND lv_has_rem = abap_true.
        ls_out-found = 'both'.
        differing_positions( EXPORTING is_loc   = ls_loc
                                       is_rem   = ls_rem
                             IMPORTING ev_list  = lv_list
                                       ev_count = lv_count ).
        ls_out-diffpos = lv_list.
        ls_out-ndiff   = lv_count.
        DATA(lv_attr_differs) = xsdbool( ls_loc-koart <> ls_rem-koart
                                      OR ls_loc-shkzg <> ls_rem-shkzg
                                      OR ls_loc-stbsl <> ls_rem-stbsl
                                      OR ls_loc-xsonu <> ls_rem-xsonu
                                      OR ls_loc-xumsw <> ls_rem-xumsw
                                      OR ls_loc-xzahl <> ls_rem-xzahl ).
        IF ( p_pos_a > 0 AND ls_out-a_loc <> ls_out-a_rem )
        OR ( p_pos_b > 0 AND ls_out-b_loc <> ls_out-b_rem ).
          ls_out-light = gc_light-red.
        ELSEIF lv_attr_differs = abap_true OR lv_count > 0.
          ls_out-light = gc_light-yellow.
        ELSE.
          ls_out-light = gc_light-green.
        ENDIF.
      ELSEIF lv_has_loc = abap_true.
        ls_out-found = 'this only'.
        ls_out-light = gc_light-red.
      ELSE.
        ls_out-found = 'other only'.
        ls_out-light = gc_light-red.
      ENDIF.

      IF p_dest IS NOT INITIAL AND p_onlydf = abap_true AND ls_out-light = gc_light-green.
        CONTINUE.
      ENDIF.
      APPEND ls_out TO lt_out.
    ENDLOOP.

    IF lt_out IS INITIAL.
      MESSAGE |All { lines( lt_keys ) } posting keys are identical in { sy-sysid } { sy-mandt } and { p_dest }| TYPE 'S'.
      RETURN.
    ENDIF.

    IF p_dest IS INITIAL.
      lv_title = |TBSL in { sy-sysid } { sy-mandt }: { p_nam_a } = pos. { p_pos_a }, { p_nam_b } = pos. { p_pos_b }|.
    ELSE.
      lv_title = |TBSL { sy-sysid } { sy-mandt } vs { p_dest }: { p_nam_a } = { p_pos_a }, { p_nam_b } = { p_pos_b }|.
    ENDIF.

    DATA(lv_remote) = xsdbool( p_dest IS INITIAL ).   " hide the *_R columns in list mode
    DATA(lv_noraw)  = xsdbool( p_raw IS INITIAL ).

    display(
      EXPORTING
        iv_title = lv_title
        it_cols  = VALUE #( ( name = 'BSCHL'   text = 'Posting key' )
                            ( name = 'LTEXT'   text = 'Name (this client)' )
                            ( name = 'FOUND'   text = 'Found in' )
                            ( name = 'A_LOC'   text = |{ p_nam_a } here| )
                            ( name = 'A_REM'   text = |{ p_nam_a } there|  hide = lv_remote )
                            ( name = 'B_LOC'   text = |{ p_nam_b } here| )
                            ( name = 'B_REM'   text = |{ p_nam_b } there|  hide = lv_remote )
                            ( name = 'NDIFF'   text = 'Differing positions (count)'  hide = lv_remote )
                            ( name = 'DIFFPOS' text = 'Differing positions'  hide = lv_remote )
                            ( name = 'KOART_L' text = 'Account type here' )
                            ( name = 'KOART_R' text = 'Account type there'  hide = lv_remote )
                            ( name = 'SHKZG_L' text = 'D/C here' )
                            ( name = 'SHKZG_R' text = 'D/C there'  hide = lv_remote )
                            ( name = 'STBSL_L' text = 'Reversal key here' )
                            ( name = 'STBSL_R' text = 'Reversal key there'  hide = lv_remote )
                            ( name = 'XSONU_L' text = 'Special G/L here' )
                            ( name = 'XSONU_R' text = 'Special G/L there'  hide = lv_remote )
                            ( name = 'XUMSW_L' text = 'Sales-related here' )
                            ( name = 'XUMSW_R' text = 'Sales-related there'  hide = lv_remote )
                            ( name = 'XZAHL_L' text = 'Payment transaction here' )
                            ( name = 'XZAHL_R' text = 'Payment transaction there'  hide = lv_remote )
                            ( name = 'FAUS_L'  text = 'FAUS1|FAUS2 here'  hide = lv_noraw )
                            ( name = 'FAUS_R'  text = 'FAUS1|FAUS2 there'
                                               hide = xsdbool( lv_remote = abap_true OR lv_noraw = abap_true ) ) )
      CHANGING
        ct_data  = lt_out ).
  ENDMETHOD.

  METHOD read_local.
    SELECT bschl, shkzg, koart, stbsl, xsonu, xumsw, xzahl, faus1, faus2
      FROM tbsl
      WHERE bschl IN @s_bschl
      INTO TABLE @rt_keys.
  ENDMETHOD.

  METHOD read_remote.
    " RFC_READ_TABLE returns each row as one 512-character line and tells
    " us, in FIELDS, at which offset and length every requested field sits.
    " Slicing by those offsets keeps the trailing blanks of FAUS1/FAUS2,
    " which a delimiter would not.
    DATA: lt_fields  TYPE STANDARD TABLE OF rfc_db_fld WITH EMPTY KEY,
          lt_options TYPE STANDARD TABLE OF rfc_db_opt WITH EMPTY KEY,
          lt_data    TYPE STANDARD TABLE OF tab512 WITH EMPTY KEY,
          ls_key     TYPE ty_key,
          lv_off     TYPE i,
          lv_len     TYPE i,
          lv_msg     TYPE c LENGTH 255.
    FIELD-SYMBOLS <lv_comp> TYPE any.

    CLEAR: et_keys, ev_error.

    lt_fields = VALUE #( ( fieldname = 'BSCHL' )
                         ( fieldname = 'SHKZG' )
                         ( fieldname = 'KOART' )
                         ( fieldname = 'STBSL' )
                         ( fieldname = 'XSONU' )
                         ( fieldname = 'XUMSW' )
                         ( fieldname = 'XZAHL' )
                         ( fieldname = 'FAUS1' )
                         ( fieldname = 'FAUS2' ) ).

    CALL FUNCTION 'RFC_READ_TABLE' DESTINATION iv_dest
      EXPORTING
        query_table           = 'TBSL'
      TABLES
        options               = lt_options
        fields                = lt_fields
        data                  = lt_data
      EXCEPTIONS
        table_not_available   = 1
        table_without_data    = 2
        option_not_valid      = 3
        field_not_valid       = 4
        not_authorized        = 5
        data_buffer_exceeded  = 6
        system_failure        = 7 MESSAGE lv_msg
        communication_failure = 8 MESSAGE lv_msg
        OTHERS                = 9.
    IF sy-subrc <> 0.
      ev_error = |RFC_READ_TABLE on { iv_dest } failed with return code { sy-subrc } { lv_msg }|.
      RETURN.
    ENDIF.

    LOOP AT lt_data INTO DATA(ls_data).
      CLEAR ls_key.
      LOOP AT lt_fields INTO DATA(ls_fld).
        lv_off = ls_fld-offset.
        lv_len = ls_fld-length.
        ASSIGN COMPONENT ls_fld-fieldname OF STRUCTURE ls_key TO <lv_comp>.
        IF sy-subrc = 0 AND lv_len > 0.
          <lv_comp> = ls_data-wa+lv_off(lv_len).
        ENDIF.
      ENDLOOP.
      IF ls_key-bschl IN s_bschl.
        INSERT ls_key INTO TABLE et_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD read_texts.
    " TBSLT has a third key field after language and posting key: the
    " special G/L posting keys (09, 19, 29, 39 ...) carry one text per
    " special G/L indicator. A block insert into a unique table dumps on
    " the second one (ITAB_DUPLICATE_KEY, first run). So: read in primary
    " key order, which puts the blank indicator first, and insert row by
    " row - a single-row INSERT on an existing key sets sy-subrc 4 and
    " keeps the first text.
    DATA lt_tbslt TYPE STANDARD TABLE OF tbslt WITH EMPTY KEY.

    SELECT *
      FROM tbslt
      WHERE spras = @sy-langu
      ORDER BY PRIMARY KEY
      INTO TABLE @lt_tbslt.

    LOOP AT lt_tbslt INTO DATA(ls_tbslt).
      INSERT VALUE #( bschl = ls_tbslt-bschl
                      ltext = ls_tbslt-ltext ) INTO TABLE rt_texts.
    ENDLOOP.
  ENDMETHOD.

  METHOD total_length.
    DATA: ls_key  TYPE ty_key,
          lv_len1 TYPE i,
          lv_len2 TYPE i.
    DESCRIBE FIELD ls_key-faus1 LENGTH lv_len1 IN CHARACTER MODE.
    DESCRIBE FIELD ls_key-faus2 LENGTH lv_len2 IN CHARACTER MODE.
    rv_len = lv_len1 + lv_len2.
  ENDMETHOD.

  METHOD char_at.
    " Position 1 is the first character of FAUS1; FAUS2 continues the
    " numbering. Lengths are taken from the dictionary, not assumed.
    DATA: lv_len1 TYPE i,
          lv_len2 TYPE i,
          lv_off  TYPE i.

    CLEAR rv_char.
    DESCRIBE FIELD is_key-faus1 LENGTH lv_len1 IN CHARACTER MODE.
    DESCRIBE FIELD is_key-faus2 LENGTH lv_len2 IN CHARACTER MODE.
    IF iv_pos < 1.
      RETURN.
    ELSEIF iv_pos <= lv_len1.
      lv_off  = iv_pos - 1.
      rv_char = is_key-faus1+lv_off(1).
    ELSEIF iv_pos <= lv_len1 + lv_len2.
      lv_off  = iv_pos - lv_len1 - 1.
      rv_char = is_key-faus2+lv_off(1).
    ENDIF.
  ENDMETHOD.

  METHOD status_at.
    IF iv_pos < 1.
      rv_text = ''.
      RETURN.
    ENDIF.
    DATA(lv_char) = char_at( is_key = is_key iv_pos = iv_pos ).
    rv_text = SWITCH #( lv_char
                        WHEN '+' THEN 'required'
                        WHEN '.' THEN 'optional'
                        WHEN '-' THEN 'suppressed'
                        WHEN ' ' THEN '(blank)'
                        ELSE |'{ lv_char }'| ).
  ENDMETHOD.

  METHOD differing_positions.
    DATA lv_pos TYPE i.

    CLEAR: ev_list, ev_count.
    DATA(lv_total) = total_length( ).
    lv_pos = 1.
    WHILE lv_pos <= lv_total.
      IF char_at( is_key = is_loc iv_pos = lv_pos ) <> char_at( is_key = is_rem iv_pos = lv_pos ).
        ev_count = ev_count + 1.
        ev_list  = COND #( WHEN ev_list IS INITIAL THEN |{ lv_pos }|
                           ELSE |{ ev_list } { lv_pos }| ).
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD raw_string.
    " Trailing blanks of each string are dropped by &&, which is fine for
    " reading; the position arithmetic above never uses this string.
    rv_raw = is_key-faus1 && '|' && is_key-faus2.
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
          lo_col->set_long_text( CONV #( ls_col-text ) ).
          IF ls_col-hide = abap_true.
            lo_col->set_technical( abap_true ).
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
  t_b01 = 'Posting keys and other client'.
  t_b02 = 'Fields to decode'.
  t_b03 = 'Output'.
  " Selection texts (maximum 30 characters). They replace maintained texts.
  %_p_dest_%_app_%-text   = 'RFC destination (other client)'.
  %_s_bschl_%_app_%-text  = 'Posting key'.
  %_p_pos_a_%_app_%-text  = 'Field A: position in FAUS1/2'.
  %_p_nam_a_%_app_%-text  = 'Field A: name for the list'.
  %_p_pos_b_%_app_%-text  = 'Field B: position in FAUS1/2'.
  %_p_nam_b_%_app_%-text  = 'Field B: name for the list'.
  %_p_onlydf_%_app_%-text = 'Only keys that differ'.
  %_p_raw_%_app_%-text    = 'Show raw status strings'.

AT SELECTION-SCREEN.
  lcl_report=>check_selection( ).

START-OF-SELECTION.
  lcl_report=>run( ).

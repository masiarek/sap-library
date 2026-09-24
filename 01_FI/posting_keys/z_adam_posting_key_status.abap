*&---------------------------------------------------------------------*
*& Report  Z_ADAM_POSTING_KEY_STATUS
*&---------------------------------------------------------------------*
*& Field status of two chosen fields - Profit Center and Business Area
*& by default - for every posting key (OB41, table TBSL) of the client
*& you are logged on to: suppressed, required or optional, one line per
*& posting key. Read-only: the report changes nothing.
*&
*& The field status of a posting key is two character strings,
*& TBSL-FAUS1 and TBSL-FAUS2, one character per screen field:
*&   '+' required entry    '.' optional entry    '-' suppressed
*& Which position belongs to which field is looked up at runtime in the
*& field selection definition tables (TMODU and its siblings). They are
*& read dynamically, so the program activates whatever their layout:
*& every row mentioning the field name (PRCTR, GSBER) is collected, and
*& if all of them agree on one number, that number is the position. If
*& they do not, the rows are displayed first and the position can be
*& entered on the selection screen instead.
*&
*& To compare clients, run it in each client and export the lists, or
*& use SCMP on TBSL for the raw rows.
*&
*& Frame titles and selection texts are set at INITIALIZATION, so the
*& program runs without maintained text elements.
*&---------------------------------------------------------------------*
REPORT z_adam_posting_key_status.

DATA gv_bschl TYPE bschl.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE t_b01.
  SELECT-OPTIONS s_bschl FOR gv_bschl.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE t_b02.
  PARAMETERS: p_nam_a TYPE c LENGTH 15 DEFAULT 'Profit Center',
              p_pat_a TYPE c LENGTH 10 DEFAULT 'PRCTR',
              p_pos_a TYPE i,
              p_nam_b TYPE c LENGTH 15 DEFAULT 'Business Area',
              p_pat_b TYPE c LENGTH 10 DEFAULT 'GSBER',
              p_pos_b TYPE i.
SELECTION-SCREEN END OF BLOCK b02.

SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE t_b03.
  PARAMETERS: p_raw    AS CHECKBOX DEFAULT 'X',
              p_showdf AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b03.

*----------------------------------------------------------------------*
CLASS lcl_report DEFINITION FINAL.
*----------------------------------------------------------------------*
  PUBLIC SECTION.
    CLASS-METHODS:
      check_selection,
      run.

  PRIVATE SECTION.
    TYPES: ty_char1 TYPE c LENGTH 1.

    " One posting key, as read from TBSL.
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

    " One output line.
    TYPES: BEGIN OF ty_out,
             bschl  TYPE tbsl-bschl,
             ltext  TYPE tbslt-ltext,
             a_stat TYPE c LENGTH 10,
             b_stat TYPE c LENGTH 10,
             koart  TYPE tbsl-koart,
             shkzg  TYPE tbsl-shkzg,
             stbsl  TYPE tbsl-stbsl,
             xsonu  TYPE tbsl-xsonu,
             xumsw  TYPE tbsl-xumsw,
             xzahl  TYPE tbsl-xzahl,
             faus   TYPE c LENGTH 128,
           END OF ty_out,
           ty_out_tab TYPE STANDARD TABLE OF ty_out WITH EMPTY KEY.

    TYPES: BEGIN OF ty_col,
             name TYPE lvc_fname,
             text TYPE string,
             hide TYPE abap_bool,
           END OF ty_col,
           ty_col_tab TYPE STANDARD TABLE OF ty_col WITH EMPTY KEY.

    " One row of a field selection definition table that mentions one of
    " the two field names, flattened to text, with the numbers it carries.
    TYPES: BEGIN OF ty_def,
             tabname TYPE c LENGTH 30,
             field   TYPE c LENGTH 1,
             pattern TYPE c LENGTH 10,
             number  TYPE i,
             numbers TYPE c LENGTH 40,
             content TYPE c LENGTH 128,
           END OF ty_def,
           ty_def_tab TYPE STANDARD TABLE OF ty_def WITH EMPTY KEY.

    CLASS-METHODS:
      read_keys
        RETURNING VALUE(rt_keys) TYPE ty_key_tab,
      read_texts
        RETURNING VALUE(rt_texts) TYPE ty_text_tab,
      find_positions
        IMPORTING iv_pat_a TYPE csequence
                  iv_pat_b TYPE csequence
        EXPORTING ev_pos_a TYPE i
                  ev_pos_b TYPE i
                  et_def   TYPE ty_def_tab,
      collect_definition_rows
        IMPORTING iv_tabname TYPE string
                  iv_pat_a   TYPE csequence
                  iv_pat_b   TYPE csequence
        CHANGING  ct_def     TYPE ty_def_tab,
      unique_number
        IMPORTING it_def           TYPE ty_def_tab
                  iv_field         TYPE ty_char1
        RETURNING VALUE(rv_number) TYPE i,
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
      raw_string
        IMPORTING is_key        TYPE ty_key
        RETURNING VALUE(rv_raw) TYPE string,
      display
        IMPORTING iv_title TYPE string
                  it_cols  TYPE ty_col_tab
        CHANGING  ct_data  TYPE STANDARD TABLE.
ENDCLASS.

*----------------------------------------------------------------------*
CLASS lcl_report IMPLEMENTATION.
*----------------------------------------------------------------------*
  METHOD check_selection.
    IF p_pos_a < 0 OR p_pos_b < 0.
      MESSAGE 'A position is 1 or greater, or 0 to look it up' TYPE 'E'.
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
          lv_pos_a TYPE i,
          lv_pos_b TYPE i,
          lt_def   TYPE ty_def_tab.

    DATA(lt_keys)  = read_keys( ).
    DATA(lt_texts) = read_texts( ).

    IF lt_keys IS INITIAL.
      MESSAGE 'No posting keys found for this selection' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " Positions: entered, or looked up in the field selection definition.
    lv_pos_a = p_pos_a.
    lv_pos_b = p_pos_b.
    IF lv_pos_a = 0 OR lv_pos_b = 0 OR p_showdf = abap_true.
      find_positions( EXPORTING iv_pat_a = p_pat_a
                                iv_pat_b = p_pat_b
                      IMPORTING ev_pos_a = DATA(lv_found_a)
                                ev_pos_b = DATA(lv_found_b)
                                et_def   = lt_def ).
      IF lv_pos_a = 0.
        lv_pos_a = lv_found_a.
      ENDIF.
      IF lv_pos_b = 0.
        lv_pos_b = lv_found_b.
      ENDIF.
      IF p_showdf = abap_true OR lv_pos_a = 0 OR lv_pos_b = 0.
        IF lt_def IS INITIAL.
          MESSAGE |No field selection definition row mentions { p_pat_a } or { p_pat_b }; enter the positions| TYPE 'S' DISPLAY LIKE 'W'.
        ELSE.
          display(
            EXPORTING
              iv_title = |Definition rows for { p_pat_a } (A) and { p_pat_b } (B); found A = { lv_found_a }, B = { lv_found_b }|
              it_cols  = VALUE #( ( name = 'TABNAME' text = 'Table' )
                                  ( name = 'FIELD'   text = 'A/B' )
                                  ( name = 'PATTERN' text = 'Matched' )
                                  ( name = 'NUMBER'  text = 'Position candidate' )
                                  ( name = 'NUMBERS' text = 'All numbers in the row' )
                                  ( name = 'CONTENT' text = 'Row content' ) )
            CHANGING
              ct_data  = lt_def ).
        ENDIF.
      ENDIF.
    ENDIF.

    LOOP AT lt_keys INTO DATA(ls_key).
      CLEAR ls_out.
      ls_out-bschl = ls_key-bschl.
      READ TABLE lt_texts INTO DATA(ls_text) WITH TABLE KEY bschl = ls_key-bschl.
      IF sy-subrc = 0.
        ls_out-ltext = ls_text-ltext.
      ENDIF.
      ls_out-a_stat = status_at( is_key = ls_key iv_pos = lv_pos_a ).
      ls_out-b_stat = status_at( is_key = ls_key iv_pos = lv_pos_b ).
      ls_out-koart  = ls_key-koart.
      ls_out-shkzg  = ls_key-shkzg.
      ls_out-stbsl  = ls_key-stbsl.
      ls_out-xsonu  = ls_key-xsonu.
      ls_out-xumsw  = ls_key-xumsw.
      ls_out-xzahl  = ls_key-xzahl.
      ls_out-faus   = raw_string( ls_key ).
      APPEND ls_out TO lt_out.
    ENDLOOP.

    DATA(lv_noraw) = xsdbool( p_raw IS INITIAL ).

    display(
      EXPORTING
        iv_title = |Posting keys in { sy-sysid } { sy-mandt }: { p_nam_a } = pos. { lv_pos_a }, { p_nam_b } = pos. { lv_pos_b }|
        it_cols  = VALUE #( ( name = 'BSCHL'  text = 'Posting key' )
                            ( name = 'LTEXT'  text = 'Name' )
                            ( name = 'A_STAT' text = CONV #( p_nam_a ) )
                            ( name = 'B_STAT' text = CONV #( p_nam_b ) )
                            ( name = 'KOART'  text = 'Account type' )
                            ( name = 'SHKZG'  text = 'D/C' )
                            ( name = 'STBSL'  text = 'Reversal key' )
                            ( name = 'XSONU'  text = 'Special G/L' )
                            ( name = 'XUMSW'  text = 'Sales-related' )
                            ( name = 'XZAHL'  text = 'Payment transaction' )
                            ( name = 'FAUS'   text = 'FAUS1|FAUS2'  hide = lv_noraw ) )
      CHANGING
        ct_data  = lt_out ).
  ENDMETHOD.

  METHOD read_keys.
    SELECT bschl, shkzg, koart, stbsl, xsonu, xumsw, xzahl, faus1, faus2
      FROM tbsl
      WHERE bschl IN @s_bschl
      INTO TABLE @rt_keys.
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

  METHOD find_positions.
    " The field selection definition lives in a family of tables named
    " TMOD*. Their exact layout is not assumed: each is read dynamically,
    " every row is flattened to text, and a row counts when it mentions
    " the field name. The numbers such a row carries are the candidates.
    CLEAR: ev_pos_a, ev_pos_b, et_def.
    LOOP AT VALUE string_table( ( `TMODU` ) ( `TMODO` ) ( `TMODP` ) ( `TMODF` ) ( `TMODG` ) )
         INTO DATA(lv_tabname).
      collect_definition_rows( EXPORTING iv_tabname = lv_tabname
                                         iv_pat_a   = iv_pat_a
                                         iv_pat_b   = iv_pat_b
                               CHANGING  ct_def     = et_def ).
    ENDLOOP.
    ev_pos_a = unique_number( it_def = et_def iv_field = 'A' ).
    ev_pos_b = unique_number( it_def = et_def iv_field = 'B' ).
  ENDMETHOD.

  METHOD collect_definition_rows.
    DATA: lr_tab  TYPE REF TO data,
          ls_def  TYPE ty_def,
          lv_text TYPE string,
          lv_val  TYPE string,
          lv_upa  TYPE string,
          lv_upb  TYPE string.
    FIELD-SYMBOLS: <lt_tab>  TYPE STANDARD TABLE,
                   <ls_row>  TYPE any,
                   <lv_comp> TYPE any.

    TRY.
        CREATE DATA lr_tab TYPE STANDARD TABLE OF (iv_tabname).
      CATCH cx_sy_create_data_error.
        RETURN.   " no such table in this release - nothing to read
    ENDTRY.
    ASSIGN lr_tab->* TO <lt_tab>.
    TRY.
        SELECT * FROM (iv_tabname) INTO TABLE @<lt_tab>.
      CATCH cx_sy_dynamic_osql_error.
        RETURN.
    ENDTRY.

    DATA(lo_table) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data_ref( lr_tab ) ).
    DATA(lo_line)  = lo_table->get_table_line_type( ).
    IF lo_line->kind <> cl_abap_typedescr=>kind_struct.
      RETURN.
    ENDIF.
    DATA(lt_comp) = CAST cl_abap_structdescr( lo_line )->components.

    lv_upa = to_upper( condense( CONV string( iv_pat_a ) ) ).
    lv_upb = to_upper( condense( CONV string( iv_pat_b ) ) ).

    LOOP AT <lt_tab> ASSIGNING <ls_row>.
      CLEAR ls_def.
      ls_def-tabname = iv_tabname.
      lv_text = ``.
      LOOP AT lt_comp INTO DATA(ls_comp).
        ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_row> TO <lv_comp>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        lv_val = condense( |{ <lv_comp> }| ).
        lv_text = COND #( WHEN lv_text IS INITIAL THEN lv_val ELSE |{ lv_text }\|{ lv_val }| ).
        " A position number: a numeric component, or a short all-digit
        " text - but never the client.
        IF ls_comp-name <> 'MANDT' AND lv_val IS NOT INITIAL AND strlen( lv_val ) <= 3
           AND lv_val CO '0123456789'.
          IF ls_def-number = 0.
            ls_def-number = lv_val.
          ENDIF.
          ls_def-numbers = COND #( WHEN ls_def-numbers IS INITIAL THEN lv_val
                                   ELSE |{ ls_def-numbers } { lv_val }| ).
        ENDIF.
      ENDLOOP.
      DATA(lv_upper) = to_upper( lv_text ).
      IF lv_upa IS NOT INITIAL AND lv_upper CS lv_upa.
        ls_def-field   = 'A'.
        ls_def-pattern = iv_pat_a.
        ls_def-content = lv_text.
        APPEND ls_def TO ct_def.
      ENDIF.
      IF lv_upb IS NOT INITIAL AND lv_upper CS lv_upb.
        ls_def-field   = 'B'.
        ls_def-pattern = iv_pat_b.
        ls_def-content = lv_text.
        APPEND ls_def TO ct_def.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD unique_number.
    " The position is trusted only when every matching row agrees on it.
    DATA lt_numbers TYPE SORTED TABLE OF i WITH UNIQUE KEY table_line.
    LOOP AT it_def INTO DATA(ls_def) WHERE field = iv_field AND number > 0.
      INSERT ls_def-number INTO TABLE lt_numbers.
    ENDLOOP.
    IF lines( lt_numbers ) = 1.
      rv_number = lt_numbers[ 1 ].
    ELSE.
      rv_number = 0.
    ENDIF.
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
      rv_text = '?'.   " position unknown - see the definition rows
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
  t_b01 = 'Posting keys'.
  t_b02 = 'Fields to decode'.
  t_b03 = 'Output'.
  " Selection texts (maximum 30 characters). They replace maintained texts.
  %_s_bschl_%_app_%-text  = 'Posting key'.
  %_p_nam_a_%_app_%-text  = 'Field A: name for the list'.
  %_p_pat_a_%_app_%-text  = 'Field A: field name to look up'.
  %_p_pos_a_%_app_%-text  = 'Field A: position (0 = look up)'.
  %_p_nam_b_%_app_%-text  = 'Field B: name for the list'.
  %_p_pat_b_%_app_%-text  = 'Field B: field name to look up'.
  %_p_pos_b_%_app_%-text  = 'Field B: position (0 = look up)'.
  %_p_raw_%_app_%-text    = 'Show raw status strings'.
  %_p_showdf_%_app_%-text = 'Show the definition rows'.

AT SELECTION-SCREEN.
  lcl_report=>check_selection( ).

START-OF-SELECTION.
  lcl_report=>run( ).

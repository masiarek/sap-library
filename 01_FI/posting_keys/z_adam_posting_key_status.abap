*&---------------------------------------------------------------------*
*& Report  Z_ADAM_POSTING_KEY_STATUS
*&---------------------------------------------------------------------*
*& One line per posting key (OB41, table TBSL) of the client you are
*& logged on to:
*&   client | posting key | Business Area | Profit Center | Segment
*& where the last three are the field status of that field on that key:
*& suppressed, required or optional. Read-only: changes nothing.
*&
*& The field status of a posting key is two character strings,
*& TBSL-FAUS1 and TBSL-FAUS2, one character per screen field:
*&   '+' required entry    '.' optional entry    '-' suppressed
*& A blank is not a status: the key was last saved in OB41 before that
*& field existed in the definition (Segment sits in FAUS2, at 101 on
*& the system this ran on), so nobody ever chose one. The list says
*& "not maintained" for it.
*& Which position belongs to which field is looked up at runtime in
*& the field selection definition table TMODU (read dynamically, so the
*& program activates whatever its layout): the rows of the FI document's
*& field selection SKB1-FAUS1 that name GSBER, PRCTR or SEGMENT as a
*& whole column value (not as part of PSEGMENT or PPRCTR). If all rows
*& of a field agree on one number, that is the position. If they do
*& not, the rows are displayed first and the position can be entered on
*& the selection screen. A run on S/4HANA showed 33 for GSBER and 42 for
*& PRCTR; the lookup is kept so that nothing here depends on that.
*&
*& To compare clients, run it in each client and export the list.
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
  PARAMETERS: p_fauna TYPE c LENGTH 20 DEFAULT 'SKB1-FAUS1',
              p_posba TYPE i,
              p_pospc TYPE i,
              p_posse TYPE i.
SELECTION-SCREEN END OF BLOCK b02.

SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE t_b03.
  PARAMETERS: p_more   AS CHECKBOX,
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
    CONSTANTS: gc_field_ba  TYPE c LENGTH 10 VALUE 'GSBER',
               gc_field_pc  TYPE c LENGTH 10 VALUE 'PRCTR',
               gc_field_seg TYPE c LENGTH 10 VALUE 'SEGMENT'.

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

    " One output line. The first five columns are the list; the rest
    " appear only with "More columns".
    TYPES: BEGIN OF ty_out,
             mandt    TYPE sy-mandt,
             bschl    TYPE tbsl-bschl,
             ba_stat  TYPE c LENGTH 14,
             pc_stat  TYPE c LENGTH 14,
             seg_stat TYPE c LENGTH 14,
             ltext    TYPE tbslt-ltext,
             koart   TYPE tbsl-koart,
             shkzg   TYPE tbsl-shkzg,
             stbsl   TYPE tbsl-stbsl,
             xsonu   TYPE tbsl-xsonu,
             xumsw   TYPE tbsl-xumsw,
             xzahl   TYPE tbsl-xzahl,
             faus    TYPE c LENGTH 128,
           END OF ty_out,
           ty_out_tab TYPE STANDARD TABLE OF ty_out WITH EMPTY KEY.

    TYPES: BEGIN OF ty_col,
             name TYPE lvc_fname,
             text TYPE string,
             hide TYPE abap_bool,
           END OF ty_col,
           ty_col_tab TYPE STANDARD TABLE OF ty_col WITH EMPTY KEY.

    " One row of the field selection definition that mentions one of the
    " two field names, flattened to text, with the numbers it carries.
    TYPES: BEGIN OF ty_def,
             tabname TYPE c LENGTH 30,
             field   TYPE c LENGTH 10,
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
        IMPORTING iv_fauna  TYPE csequence
        EXPORTING ev_posba  TYPE i
                  ev_pospc  TYPE i
                  ev_posseg TYPE i
                  et_def    TYPE ty_def_tab,
      collect_definition_rows
        IMPORTING iv_tabname TYPE string
                  iv_fauna   TYPE csequence
        CHANGING  ct_def     TYPE ty_def_tab,
      unique_number
        IMPORTING it_def           TYPE ty_def_tab
                  iv_field         TYPE csequence
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
    IF p_posba < 0 OR p_pospc < 0 OR p_posse < 0.
      MESSAGE 'A position is 1 or greater, or 0 to look it up' TYPE 'E'.
    ENDIF.
    IF ( p_posba > 0 AND p_posba = p_pospc )
    OR ( p_posba > 0 AND p_posba = p_posse )
    OR ( p_pospc > 0 AND p_pospc = p_posse ).
      MESSAGE 'Two fields have the same position' TYPE 'E'.
    ENDIF.
    IF p_posba > total_length( ) OR p_pospc > total_length( ) OR p_posse > total_length( ).
      MESSAGE |A position cannot exceed { total_length( ) } (FAUS1 + FAUS2)| TYPE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD run.
    DATA: lt_out    TYPE ty_out_tab,
          ls_out    TYPE ty_out,
          lv_posba  TYPE i,
          lv_pospc  TYPE i,
          lv_posseg TYPE i,
          lt_def    TYPE ty_def_tab.

    DATA(lt_keys)  = read_keys( ).
    DATA(lt_texts) = read_texts( ).

    IF lt_keys IS INITIAL.
      MESSAGE 'No posting keys found for this selection' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " Positions: entered, or looked up in the field selection definition.
    lv_posba  = p_posba.
    lv_pospc  = p_pospc.
    lv_posseg = p_posse.
    IF lv_posba = 0 OR lv_pospc = 0 OR lv_posseg = 0 OR p_showdf = abap_true.
      find_positions( EXPORTING iv_fauna  = p_fauna
                      IMPORTING ev_posba  = DATA(lv_found_ba)
                                ev_pospc  = DATA(lv_found_pc)
                                ev_posseg = DATA(lv_found_seg)
                                et_def    = lt_def ).
      IF lv_posba = 0.
        lv_posba = lv_found_ba.
      ENDIF.
      IF lv_pospc = 0.
        lv_pospc = lv_found_pc.
      ENDIF.
      IF lv_posseg = 0.
        lv_posseg = lv_found_seg.
      ENDIF.
      IF p_showdf = abap_true OR lv_posba = 0 OR lv_pospc = 0 OR lv_posseg = 0.
        IF lt_def IS INITIAL.
          MESSAGE |No definition row of { p_fauna } names { gc_field_ba }, { gc_field_pc } or { gc_field_seg }; enter the positions| TYPE 'S' DISPLAY LIKE 'W'.
        ELSE.
          display(
            EXPORTING
              iv_title = |{ p_fauna }: Business Area = { lv_found_ba }, Profit Center = { lv_found_pc }, Segment = { lv_found_seg } (0 = not unique)|
              it_cols  = VALUE #( ( name = 'TABNAME' text = 'Table' )
                                  ( name = 'FIELD'   text = 'Field' )
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
      ls_out-mandt   = sy-mandt.
      ls_out-bschl   = ls_key-bschl.
      ls_out-ba_stat  = status_at( is_key = ls_key iv_pos = lv_posba ).
      ls_out-pc_stat  = status_at( is_key = ls_key iv_pos = lv_pospc ).
      ls_out-seg_stat = status_at( is_key = ls_key iv_pos = lv_posseg ).
      READ TABLE lt_texts INTO DATA(ls_text) WITH TABLE KEY bschl = ls_key-bschl.
      IF sy-subrc = 0.
        ls_out-ltext = ls_text-ltext.
      ENDIF.
      ls_out-koart = ls_key-koart.
      ls_out-shkzg = ls_key-shkzg.
      ls_out-stbsl = ls_key-stbsl.
      ls_out-xsonu = ls_key-xsonu.
      ls_out-xumsw = ls_key-xumsw.
      ls_out-xzahl = ls_key-xzahl.
      ls_out-faus  = raw_string( ls_key ).
      APPEND ls_out TO lt_out.
    ENDLOOP.

    DATA(lv_less) = xsdbool( p_more = abap_false ).

    display(
      EXPORTING
        iv_title = |Posting keys in { sy-sysid } { sy-mandt }: positions BA { lv_posba }, PC { lv_pospc }, Segment { lv_posseg }|
        it_cols  = VALUE #( ( name = 'MANDT'    text = 'Client' )
                            ( name = 'BSCHL'    text = 'Posting key' )
                            ( name = 'BA_STAT'  text = 'Business Area' )
                            ( name = 'PC_STAT'  text = 'Profit Center' )
                            ( name = 'SEG_STAT' text = 'Segment' )
                            ( name = 'LTEXT'   text = 'Name'                 hide = lv_less )
                            ( name = 'KOART'   text = 'Account type'         hide = lv_less )
                            ( name = 'SHKZG'   text = 'D/C'                  hide = lv_less )
                            ( name = 'STBSL'   text = 'Reversal key'         hide = lv_less )
                            ( name = 'XSONU'   text = 'Special G/L'          hide = lv_less )
                            ( name = 'XUMSW'   text = 'Sales-related'        hide = lv_less )
                            ( name = 'XZAHL'   text = 'Payment transaction'  hide = lv_less )
                            ( name = 'FAUS'    text = 'FAUS1|FAUS2'          hide = lv_less ) )
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
    " The field selection definition lives in TMODU (and siblings). The
    " layout is not assumed: the table is read dynamically, every row is
    " flattened to text, and a row counts when it belongs to the field
    " selection asked for and mentions the field name. The numbers such
    " a row carries are the candidates; a run showed rows like
    "   SKB1-FAUS1|033|BSEG|GSBER|D||X   and   SKB1-FAUS1|042|BSEG|PRCTR|S||X
    CLEAR: ev_posba, ev_pospc, ev_posseg, et_def.
    LOOP AT VALUE string_table( ( `TMODU` ) ( `TMODO` ) ( `TMODP` ) ( `TMODF` ) ( `TMODG` ) )
         INTO DATA(lv_tabname).
      collect_definition_rows( EXPORTING iv_tabname = lv_tabname
                                         iv_fauna   = iv_fauna
                               CHANGING  ct_def     = et_def ).
    ENDLOOP.
    ev_posba  = unique_number( it_def = et_def iv_field = gc_field_ba ).
    ev_pospc  = unique_number( it_def = et_def iv_field = gc_field_pc ).
    ev_posseg = unique_number( it_def = et_def iv_field = gc_field_seg ).
  ENDMETHOD.

  METHOD collect_definition_rows.
    DATA: lr_tab  TYPE REF TO data,
          ls_def  TYPE ty_def,
          lv_text TYPE string,
          lv_val  TYPE string,
          lv_upf  TYPE string,
          lt_tok  TYPE string_table.
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

    lv_upf = to_upper( condense( CONV string( iv_fauna ) ) ).

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
      " Whole column values, not substrings: BSEG also has PSEGMENT and
      " PPRCTR (partner segment, partner profit center), which would
      " otherwise match SEGMENT and PRCTR and make the number ambiguous.
      SPLIT to_upper( lv_text ) AT '|' INTO TABLE lt_tok.
      " Only the field selection asked for: the same table carries other
      " applications' numbering (Real Estate had PRCTR at 29 beside FI's 42).
      IF lv_upf IS NOT INITIAL AND NOT line_exists( lt_tok[ table_line = lv_upf ] ).
        CONTINUE.
      ENDIF.
      IF line_exists( lt_tok[ table_line = gc_field_ba ] ).
        ls_def-field   = gc_field_ba.
        ls_def-content = lv_text.
        APPEND ls_def TO ct_def.
      ENDIF.
      IF line_exists( lt_tok[ table_line = gc_field_pc ] ).
        ls_def-field   = gc_field_pc.
        ls_def-content = lv_text.
        APPEND ls_def TO ct_def.
      ENDIF.
      IF line_exists( lt_tok[ table_line = gc_field_seg ] ).
        ls_def-field   = gc_field_seg.
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
                        WHEN ' ' THEN 'not maintained'
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
  t_b02 = 'Positions (0 = look up)'.
  t_b03 = 'Output'.
  " Selection texts (maximum 30 characters). They replace maintained texts.
  %_s_bschl_%_app_%-text  = 'Posting key'.
  %_p_fauna_%_app_%-text  = 'Field selection (FI document)'.
  %_p_posba_%_app_%-text  = 'Business Area position'.
  %_p_pospc_%_app_%-text  = 'Profit Center position'.
  %_p_posse_%_app_%-text  = 'Segment position'.
  %_p_more_%_app_%-text   = 'More columns'.
  %_p_showdf_%_app_%-text = 'Show the definition rows'.

AT SELECTION-SCREEN.
  lcl_report=>check_selection( ).

START-OF-SELECTION.
  lcl_report=>run( ).

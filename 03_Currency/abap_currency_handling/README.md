# Currencies in ABAP: CURR, CUKY, CDS amount fields and conversion

**Level:** 201 · for ABAP developers

**One line:** An ABAP amount is never a number on its own: the Dictionary ties every CURR field to a CUKY field, CDS ties it with an annotation, and every output, conversion and comparison has to go through that link or the decimals of JPY and KWD will be wrong by a factor of 100 or 10.

## The Dictionary types

| Type | What it is | Rules |
|---|---|---|
| **CURR** | Currency amount. Handled as DEC, stored in BCD; ABAP type `p`. Up to 31 digits; the number of decimals is defined on the data element (at least one, two by default) and should be an odd number of digits overall as for any packed number. | Every structure component of type CURR must name a **reference field** of type CUKY, in the same structure or in another table or view. |
| **CUKY** | Currency key. Technically CHAR 5. | Its content is a currency key from TCURC. |

The reference field is what makes a CURR field a *currency field* ([ABAP keyword documentation: DDIC currency fields ↗](https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/abenddic_currency_field.htm)). The documentation's own words for what the amount is: "a currency amount is an integer in the smallest unit of the currency. The integer is constructed from all figures in a currency field while ignoring the position of the decimal separator." That sentence is the internal representation of [Currency keys](../currency_keys_and_decimals/README.md) stated from the other side. A DECFLOAT16 or DECFLOAT34 field with a reference field is a currency field too; without one it is a number.

When a dynpro displays a CURR field it looks for the reference field's content in the program's global data and reads TCURX for it; if it finds neither, it shows two decimals. So a screen field that shows 10.00 for a JPY amount is a program that has not made the currency key available where the dynpro looks.

The glossary entries the ABAP documentation uses: [currency key ↗](https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/ABENCURRENCY_KEY_GLOSRY.html), [DDIC currency field ↗](https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/ABENDDIC_CURRENCY_FIELD_GLOSRY.html), [ABAP CDS amount field ↗](https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/ABENCDS_AMOUNT_FIELD_GLOSRY.html).

## CDS

In a CDS view entity every element of type `abap.curr` must carry `@Semantics.amount.currencyCode: 'field'` pointing at an element of the same view that holds the key ([annotation documentation ↗](https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/ABENCDS_689127610-_ANNO.html)); the key element can be marked `@Semantics.currencyCode: true`. In the obsolete DDIC-based views a currency key field was assigned implicitly to every amount without one. The framework (Fiori elements, the OData layer, ALV) applies TCURX on output when the annotation is there and shows two decimals when it is not.

Conversion inside a view:

```abap
currency_conversion( amount             => amount,
                     source_currency    => currency,
                     target_currency    => :to_currency,
                     exchange_rate_date => :exc_date,
                     exchange_rate_type => 'M',
                     round              => 'X',
                     error_handling     => 'SET_TO_NULL' ) as amount_in_target
```

with `decimal_shift` and `decimal_shift_back` parameters that say whether the input is in the two-decimal internal form and whether the output should be ([CDS conversion functions ↗](https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/abencds_conv_func_unit_curr_v2.htm)). `DECIMAL_SHIFT( amount => …, currency => … )` does the shift alone in DDIC-based views. For unit tests, `CL_CDS_TEST_DATA_FOR_CURR_CONV=>for_parameters( … )` stubs the conversion. The same function exists in ABAP SQL since 7.55 with `=` instead of `=>` and an `on_error` parameter from the released class `sql_currency_conversion` (`fail`, `set_to_null`) ([ABAP SQL conversion functions ↗](https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/abensql_curr_unit_conv_func.htm)); the `client` parameter is not available in ABAP for Cloud Development. The documentation's warning is worth quoting: the conversion "is performed on the database, which means that part of the calculation takes place using different rounding rules from ABAP. The same results cannot be expected as when using standard function modules."

The SAP community cheat sheet *Amounts and Quantities in ABAP CDS* collects the annotations and their effect on Fiori.

## Output

| Statement | Effect |
|---|---|
| `WRITE amount CURRENCY key.` | Places the decimal separator according to the key's decimals in TCURX: two unless the key is in the table. For type `p` the decimals of the data type are ignored, so this is a re-interpretation of the digits, not a rescaling ([WRITE options ↗](https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/abapwrite_int_options.htm)). |
| `WRITE amount TO text CURRENCY key DECIMALS n ROUND r NO-GROUPING.` | The same for a character target, with rounding and grouping control ([WRITE TO ↗](https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-us/abapwrite_to_options.htm)). |
| A string template with the `CURRENCY` format option | The same placement for a string result; the example below gives `123.456,78` under a German country setting ([string template format options ↗](https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-us/abapcompute_string_format_options.htm)). |
| `SET COUNTRY code.` | Switches the decimal and thousands separators and the date format for the session to the country's (T005X); an unknown code gives a decimal point and a comma for thousands. |

```abap
DATA(text) = |{ 12345678 CURRENCY = 'EUR' }|.   " 123.456,78 with SET COUNTRY 'DE'
```

One of the introductory ABAP textbooks introduces the CURRENCY addition with the line "due to SAP's international presence, the need to display currency in the appropriate formats brings the CURRENCY command into play", and adds that the formats are defined for all countries but "some smaller or newer countries might need to be added", which is TCURX again.

## Function modules and classes

| Name | Use |
|---|---|
| `CONVERT_TO_LOCAL_CURRENCY`, `CONVERT_TO_FOREIGN_CURRENCY` | Convert an amount between two currencies for a date and rate type (default M), returning the rate and factors used. Inputs and outputs are in the internal two-decimal form: feed them an external JPY amount and the result is off by 100. KBA 3473266 is a precision case. |
| `READ_EXCHANGE_RATE` | The rate lookup alone, with the full search order of [Exchange rates](../exchange_rates/README.md). |
| `BAPI_EXCHANGERATE_GETDETAIL`, `BAPI_EXCHRATE_GETCURRENTRATES`, `BAPI_EXCHANGERATE_CREATE`, `BAPI_EXCHRATE_CREATEMULTIPLE`, `BAPI_EXCHANGERATE_GETFACTORS` | Function group BUS1093, RFC-enabled: read and write TCURR from outside. |
| `BAPI_CURRENCY_CONV_TO_INTERNAL`, `BAPI_CURRENCY_CONV_TO_EXTERNAL`, `BAPI_CURRENCY_GETDECIMALS` | The TCURX shift for BAPI amounts (type BAPICURR_D). Unreleased, and used everywhere anyway (KBA 2659445). |
| `CURRENCY_AMOUNT_SAP_TO_IDOC`, `CURRENCY_AMOUNT_IDOC_TO_SAP`, `CURRENCY_AMOUNT_SAP_TO_DISPLAY`, `CURRENCY_AMOUNT_DISPLAY_TO_SAP`, `CURRENCY_CONVERTING_FACTOR` | The same shift for IDocs and screens, and the factor itself. |
| `ROUND` (function module), `round( )` (built-in, `mode = cl_abap_math=>round_half_up` by default) | Commercial rounding to n decimals; see [Rounding](../rounding_and_amount_fields/README.md). |
| `CL_EXCHANGE_RATES` | The released class for ABAP Cloud: `convert_to_local_currency`, `convert_to_foreign_currency` and `put` to write rates (SAP's sample that loads ECB rates uses it). There is no read method; rates are read through the CDS views below. |

Released CDS views for reading the configuration in ABAP Cloud and RAP: `I_Currency` (TCURC joined with TCURX, with `Decimals`), `I_CurrencyText`, `I_CurrencyStdVH`, `I_ExchangeRateType`, `I_ExchangeRateTypeText`, `I_ExchangeRateRawData` (TCURR with a readable date), `I_ExchangeRateFactorsRawData` (TCURF) and, in S/4HANA, `I_ExchangeRate`. Direct `SELECT`s on TCURR still work on premise and are not allowed in ABAP Cloud.

## The classic bugs

1. **Forgetting TCURX.** Reading BSEG-WRBTR for a JPY line and printing it, adding it, or sending it to an interface as it is. Symptom: amounts 100 times too small; or, after someone "fixes" it by multiplying, 100 times too large (SAP Note 1240163).
2. **Converting an external amount.** Calling `CONVERT_TO_LOCAL_CURRENCY` with 1,000 for 1,000 JPY. The module expects 10.00.
3. **Using `f` or an unrounded `decfloat34`.** A `TYPE f` intermediate loses cents; a `decfloat34` result assigned to a CURR field without `round( )` is truncated by the assignment's rounding rules, not commercially.
4. **Comparing amounts in different keys.** Nothing in the language prevents `IF wrbtr > dmbtr`; only the annotation in a CDS view entity insists on a key per amount. Convert first, or compare in one currency field.
5. **Hard-coding the length.** `TYPE p LENGTH 7 DECIMALS 2` and a 13-digit assumption overflow after the amount field length extension; declare with reference to the Dictionary type and let AFLE change it.
6. **Assuming the field is the type.** Reading ACDOCA-OSL as "the hard currency" without reading FINSC_LEDGER; see [Currencies in the Universal Journal](../universal_journal_currencies/README.md).

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| The reference field | `SE11` on a table with CURR fields, tab *Currency/Quantity Fields* |
| Output applies TCURX | `SE38` test: `WRITE` a JPY amount with and without `CURRENCY` |
| The annotation is mandatory in a view entity | ADT: activate a view entity with an `abap.curr` element and no `@Semantics.amount.currencyCode`; read the error |
| Database and ABAP rounding can differ | A CDS `currency_conversion` against `CONVERT_TO_LOCAL_CURRENCY` for an amount that ends on a half |
| The function modules expect the internal form | `SE37` test of `CONVERT_TO_LOCAL_CURRENCY` with 10.00 and with 1000 for the same JPY amount |
| Released objects for ABAP Cloud | ADT: the release contract of `I_Currency`, `I_ExchangeRateType`, `CL_EXCHANGE_RATES` in your release |
| The amount field length extension | `FLETS`; ATC with the `S4HANA_READINESS` variant on custom code |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory. The ABAP keyword documentation pages linked on the page were the source for the statement semantics; the quoted sentences are from those pages.

## Related pages

- [Currency keys, codes and decimal places](../currency_keys_and_decimals/README.md) — the tables and the shift
- [Rounding and the amount field](../rounding_and_amount_fields/README.md) — commercial rounding and AFLE
- [Exchange rates](../exchange_rates/README.md) — what `READ_EXCHANGE_RATE` does
- [Reporting and troubleshooting](../reporting_and_troubleshooting/README.md) — where the bugs surface

Back to the chapter map: [Currencies in SAP](../README.md).

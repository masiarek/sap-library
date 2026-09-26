# Exchange rates: TCURR, rate types, quotation and translation dates

**Level:** 201 · for FI consultants and anyone who has been asked why a posting used the wrong rate

**One line:** An exchange rate in SAP is a row keyed by rate type, from-currency, to-currency and valid-from date, read backwards through inverse rates, ratios and a reference currency — so the rate a posting used is a derivation, not a lookup.

Three pages elsewhere in this library go deeper on the lookup itself and were confirmed on a system: [How a posting picks its exchange rate](../../01_FI/exchange_rates/how_a_posting_picks_its_rate.md), [A report that shows which rate a posting would get](../../01_FI/exchange_rates/exchange_rate_check_report.md) and [Test scenarios for foreign currency postings from an interface](../../01_FI/exchange_rates/testing_foreign_currency_postings.md). This page is the map they sit in.

## The tables

| Table | Transaction | Key | What it holds |
|---|---|---|---|
| `TCURV` | OB07 | rate type | The exchange rate types: description, reference currency (BWAER), whether the inverse rate may be used (XINVR), an alternative rate type to fall back on (ABWCT), a fixed-rate flag for EMU currencies |
| `TCURW` | OB07 | rate type, language | Texts |
| `TCURF` | OBBS | rate type, from, to, valid from | The ratio (FFACT : TFACT) a rate is quoted in, e.g. 100 : 1 |
| `TCURR` | OB08 | rate type, from, to, valid from | The rate itself (UKURS), with a copy of the ratio in force; the valid-from date is stored inverted (GDATU = 99999999 − date) so that the newest row sorts first |
| `TCURN` | ONOT | from, to, valid from | The standard quotation for the pair: direct or indirect |
| `TCURC`, `TCURX` | OY03, OY04 | currency | The keys and their decimals; see [Currency keys](../currency_keys_and_decimals/README.md) |

SAP's own overview of these tables, written for BW but valid everywhere, is *Overview of Important Tables used for Currency Translation* on the help portal (support content 3361385803).

## Rate types

An exchange rate type names *which* rate: the average rate the bank quoted, its buying rate, its selling rate, the rate the group fixed for planning, the closing rate the auditors want. FI posting uses **M** unless something says otherwise, and the check that a rate of type M exists for the day is the one that fails with the message asking you to *enter rate USD / EUR, rate type M, for the date in the system settings* (SG105 on the system where [How a posting picks its exchange rate](../../01_FI/exchange_rates/how_a_posting_picks_its_rate.md) read it).

| Type | Delivered as | Used for |
|---|---|---|
| M | Standard translation at average rate | FI document posting; the default everywhere a rate type is not specified |
| G | Bank buying rate | Incoming payments, where configured |
| B | Bank selling rate | Outgoing payments, where configured |
| P | Standard translation for cost planning | CO planning (assigned to the plan version in OKEQ) |
| EURO, EURX | Euro fixed rates and EMU reference | Triangulation through the euro for the legacy EMU currencies; EURX is the usual *alternative* rate type of M |
| customer types | e.g. closing rate, historical rate, budget rate, central-bank rate | Foreign currency valuation (per valuation method, OB59), group reporting, statutory rates |

Where a different rate type is used is a configuration decision in the module: the valuation method in OB59, the currency conversion settings per parallel currency in FINSC_LEDGER (or OB22), the document type (OBA7, rate type per document type, which goods receipts ignore: KBA 2592703), the plan version in CO, the pricing procedure in SD. In S/4HANA Cloud the rate for document currency to company code currency is fixed to M (KBA 3512760).

## Quotation, ratios and the sign of a rate

A rate can be quoted in two directions. **Direct** quotation gives the price of one unit of the foreign currency in local currency (1 USD = 0.92 EUR, seen from Frankfurt); **indirect** gives the price of one unit of local currency in foreign currency (1 EUR = 1.087 USD). SAP stores both in the same column: an indirect rate is stored as a **negative** number, and OB08 shows two columns, *direct* and *indirect*, of which one is filled. ONOT (TCURN) sets which quotation is the standard for a currency pair, and OB08 displays the other with a prefix (by default `/`) so that a rate typed in the wrong column is visible. In S/4HANA Cloud the same setting is the SSCUI *Define Standard Quotation for Exchange Rates* (KBA 3323804).

The **ratio** exists for currencies where a rate per unit would have too few significant digits in five decimals: JPY against EUR was quoted per 100 JPY, and rates of 1 : 100 or 100 : 1 still exist in most systems. The ratio is maintained in OBBS with a validity, copied into the TCURR row when the rate is entered, and the arithmetic is

> amount in *to* currency = amount in *from* currency × rate × (to factor ÷ from factor)

A rate read without its ratio is wrong by a factor of 100. OB08 showing `0 : 0` for a pair whose OBBS ratio is `1 : 1` is a display artefact with its own KBAs (3366043, 3314213).

## The search order

When a posting needs a rate of type M from USD to EUR on a date, the system tries, in order:

1. **The direct row.** The TCURR row for (M, USD, EUR) with the latest valid-from date not after the translation date.
2. **The inverse row**, if TCURV allows inverse rates for the type: the row for (M, EUR, USD), inverted.
3. **The reference currency**, if the type has one: rates are maintained only against the reference (say EUR), and the cross rate is (USD → EUR) ÷ (CHF → EUR). Rate type EURX works this way, and so does a type set up for a group that wants one rate table against its group currency.
4. **The alternative rate type**, if TCURV names one: the same search again under that type. M falling back to EURX is the delivered example.

If all four fail, the message above. If a user types a rate on the document instead, it is checked against the table: a deviation beyond the *maximum exchange rate deviation* percentage per company code (IMG *Define Maximum Exchange Rate Difference per Company Code*, the field OBY6 shows), or beyond the per-currency-pair limit (TCURD, *Define Maximum Exchange Rate Difference per Foreign Currency*), gives a warning that the rate deviates from the table rate by that percentage, and the posting goes through with the typed rate. The translation date itself can be derived differently through BAdI FI_TRANS_DATE_DERIVE (KBA 1848683). The function module that does all of this is `READ_EXCHANGE_RATE`, wrapped by `CONVERT_TO_LOCAL_CURRENCY` and `CONVERT_TO_FOREIGN_CURRENCY`; see [Currencies in ABAP](../abap_currency_handling/README.md).

## Which date

The rate is read for the **translation date**, BKPF-WWERT. In FI document entry it defaults to the posting date and can be overridden on the header. For the parallel currencies the translation date type in FINSC_LEDGER (or OB22) chooses between document date, posting date and translation date per currency. Other modules read the rate on their own dates: the purchase order at header rate (with a *fixed exchange rate* flag that makes the goods receipt reuse it), SD pricing at the pricing date (KBA 2549273), the accrual engine by its own derivation (KBA 3062527), asset transactions at posting date.

Once read, the rate is **frozen on the document**: BKPF-KURSF (and KURS2, KURS3 for the parallel currencies), five decimals. Changing OB08 afterwards changes nothing that is posted; a wrong rate on a posted document is corrected by reversing and reposting, or by an exchange rate difference on clearing. KBA 2646229 is the ticket in which the header rate and the OB08 row disagree because the translation date was not the one assumed.

## What the program prints

<!-- output:exchange_rate_conversion -->
*Verified output of [`exchange_rate_conversion.py`](examples/exchange_rate_conversion.py) — regenerated by `tools/run_examples.py`, never hand-typed.*

```text
1. A RATE IS PICKED BY VALID-FROM DATE: THE LATEST ROW NOT AFTER THE TRANSLATION DATE
   1,000.00 USD on 2017-04-05:    930.00 EUR   rate 0.93000   <- row 2017-04-01 rate 0.93000 (1:1)
   1,000.00 USD on 2017-04-20:    920.00 EUR   rate 0.92000   <- row 2017-04-20 rate 0.92000 (1:1)
   1,000.00 USD on 2017-04-30:    920.00 EUR   rate 0.92000   <- row 2017-04-20 rate 0.92000 (1:1)
   The translation date is BKPF-WWERT; it defaults to the posting date and can be entered.

2. THE RATIO FROM TCURF IS PART OF THE RATE
   TCURR says JPY->EUR = 0.83000, TCURF says the ratio is 100 : 1, so 100 JPY = 0.83 EUR.
   100,000 JPY = 830.00 EUR   (per-unit rate 0.00830)   <- row 2017-04-01 rate 0.83000 (100:1)
   Read 0.83000 without the ratio and 100,000 JPY becomes 83,000 EUR. OB08 shows the
   ratio next to the rate for exactly this reason.

3. NO ROW FOR THE PAIR: THE INVERSE OF THE OPPOSITE ROW, IF THE RATE TYPE ALLOWS IT
   1,000.00 EUR -> 1086.96 USD   rate 1.08696
   <- inverse of USD->EUR: row 2017-04-20 rate 0.92000 (1:1)
   Rate type M has 'inverse' allowed in OB07 (TCURV). Without it this lookup fails with
   'exchange rate not maintained' even though the opposite direction exists.

4. AN INDIRECT QUOTATION IS STORED AS A NEGATIVE RATE
   TCURR holds GBP->EUR = -0.85000, meaning 1 EUR = 0.85 GBP (quoted the other way round).
   1,000.00 GBP = 1176.47 EUR   per-unit rate 1.17647   <- row 2017-04-01 indirect 0.85000 (1:1)
   OB08 shows the same row as 'indirect' 0.85000; the sign is only in the table.

5. A REFERENCE CURRENCY: TWO ROWS COMBINED INTO A CROSS RATE
   Rate type EURX keeps every rate against EUR, so USD->CHF is (USD->EUR) / (CHF->EUR):
   1,000.00 USD = 983.96 CHF   rate 0.98396
   <- via EUR: (row 2017-04-01 rate 0.92000 (1:1)) / (row 2017-04-01 rate 0.93500 (1:1))
   Maintain n rates against the reference and every one of the n*(n-1) pairs is derived.

6. THE RATE ON THE DOCUMENT IS FROZEN THERE: BKPF-KURSF
   Posting 100 USD to a JPY company code on 2017-04-25: rate 110.00000, 11000 JPY.
   BKPF-KURSF stores 110.00000; changing OB08 tomorrow changes nothing on this document.
   A user may also type a rate. If it deviates from the table by more than the maximum
   exchange rate deviation per company code (OB64) the system warns, but posts.
   typed rate 120.00000 vs table 110.00000: deviation 9.1%

7. THE SAME 100 USD, SEEN FROM THE CLEARING PAGE OF THIS CHAPTER
   posted at 1 : 100  ->   10000 JPY
   cleared at 1 : 110 ->   11000 JPY
   difference 1000 JPY, which is the whole subject of the SKB1-XSALH page.
```
<!-- /output -->

Run it yourself from the folder that holds it:

```bash
cd 03_Currency/exchange_rates/examples
python3 exchange_rate_conversion.py
```

## Getting rates into the table

OB08 is a Customizing transaction, and in a production system TCURR is usually set to *current settings* so that rates can be entered without a transport (KBA 2455178 is the prompt that appears when it is not). Nobody types daily rates by hand for long. The alternatives:

- **File import.** Program RFTBFF00 reads a datafeed file in SAP's own format; the Fiori app *Import Foreign Exchange Rates* takes a spreadsheet, with its own KBAs about indirect quotation (3155262, 3280826).
- **BAPIs.** `BAPI_EXCHANGERATE_CREATE` and `BAPI_EXCHRATE_CREATEMULTIPLE` for an interface program; `BAPI_EXCHANGERATE_GETDETAIL` and `BAPI_EXCHRATE_GETCURRENTRATES` to read.
- **Market data.** The datafeed (TBDM, TBD4) and, in S/4HANA, SAP Market Rates Management, a cloud service that delivers rates from a market data provider or from central banks straight into TCURR on a schedule.
- **Central bank rates.** The European Central Bank publishes free daily reference rates; many national banks (NBP, CNB, NBU, CBR, RBI and others) publish theirs. Where the law requires the central bank's rate for tax or statutory postings, a dedicated rate type is loaded from that source and used by the processes that must use it. See [Payments and currency management](../payments_and_currency_management/README.md).

A rate that is wrong in the table is the second commonest root cause on the [troubleshooting page](../reporting_and_troubleshooting/README.md); KBA 3107891 walks through the cases, and the help portal page *Exchange Rate Types & Exchange Rates & Translation* (support content 3361878126) is SAP's own summary.

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Rate types, reference currency, inversion, alternative type | `OB07`; `SE16N` on `TCURV`, fields `BWAER`, `XINVR`, `ABWCT` |
| Ratios | `OBBS`; `SE16N` on `TCURF` |
| Rates and their valid-from dates | `OB08`; `SE16N` on `TCURR` (mind the inverted `GDATU`) |
| Standard quotation per pair | `ONOT`; `SE16N` on `TCURN` |
| The rate a posting would get, and the search order | `SE37` test of `READ_EXCHANGE_RATE` or `CONVERT_TO_LOCAL_CURRENCY`; the report on [A report that shows which rate a posting would get](../../01_FI/exchange_rates/exchange_rate_check_report.md) |
| The rate is frozen on the document | `FB03` header, exchange rate and translation date; `SE16N` on `BKPF`, fields `KURSF`, `WWERT`; change `OB08` afterwards and re-read |
| The deviation warning and its tolerance | The IMG activities *Define Maximum Exchange Rate Difference per Company Code* and *per Foreign Currency* (`TCURD`); then type a deviating rate in `FB01` and read the warning |
| Rates on a document type | `OBA7`; `T003-KURST` |

## Provenance

Written from working FI knowledge and from the cited SAP Notes, KBAs and help-portal pages, whose titles were verified in September 2026. The message asking for a missing rate is named on this page because it was read from an S/4HANA development system on 17 September 2026 for [How a posting picks its exchange rate](../../01_FI/exchange_rates/how_a_posting_picks_its_rate.md), which also confirmed that the lookup never checks a rate's age and that a rate type with a reference currency ignores a direct pair. Nothing else on this page was confirmed against a named system.

## Related pages

- [Currency keys, codes and decimal places](../currency_keys_and_decimals/README.md) — why ratios of 100 : 1 exist
- [Local currency and the parallel currencies](../local_and_parallel_currencies/README.md) — rate type and translation date per parallel currency
- [Foreign currency valuation](../foreign_currency_valuation/README.md) — the closing rate and the rate type per valuation method
- [Exchange rate differences on clearing](../exchange_rate_differences_on_clearing/README.md) — what two rates on two dates produce
- [Payments and currency management](../payments_and_currency_management/README.md) — bank rates, fees and mandated central-bank rates

Back to the chapter map: [Currencies in SAP](../README.md).

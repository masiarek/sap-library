# Reporting and troubleshooting currency questions

**Level:** 201 · for support consultants

**One line:** Almost every "the currency is wrong" ticket is one of five known shapes — a balance that does not match its line items, a document currency that is not the currency shown, a rate that was not the rate in OB08, a difference that should not have been posted, or one that should — and each has a first table to look in.

## Where to look

| Question | Transaction / app | Reads |
|---|---|---|
| The document, entry view | FB03 | BKPF, BSEG: WAERS, KURSF, WWERT on the header; WRBTR, DMBTR, DMBE2/3, PSWSL, PSWBT per line |
| The document, ledger view with all currencies | FB03L, or FB03 → *General ledger view* | ACDOCA: WSL, TSL, HSL, KSL, OSL … with their key fields |
| Line items of a G/L account | FBL3N (BSEG/BSIS, classic) · FAGLL03 (ledger view) · FAGLL03H (ledger view, HANA-optimised) · Fiori *Display G/L Account Line Items* | BSEG sees the three BSEG currencies; the others see every ACDOCA field |
| Balances of a G/L account | FS10N (classic, GLT0 / FAGLFLEXT) · FAGLB03 (ledger) · Fiori *Display G/L Account Balances*, *Trial Balance* | Transaction figures per **update currency** |
| Customer and vendor items | FBL5N, FBL1N · Fiori *Manage Customer / Supplier Line Items* | BSID/BSIK/BSAD/BSAK: document currency and local currency |
| All currencies of a journal entry, analytically | Fiori *Journal Entry Analyzer*, *Audit Journal*, *Display Financial Statement*, *Trial Balance* | CDS views on ACDOCA |
| The rate table | OB08, Fiori *Currency Exchange Rates* | TCURR, TCURF |
| The configuration | FINSC_LEDGER, OBY6, OB22 (ECC), FS03 → *Control data* | FINSC_LD_CMP_CT, T001, T001A, SKB1 |

## Shape 1: the balance does not match the line items

FS10N (or FAGLB03) shows 0.00 for an account in EUR; FBL3N filtered on EUR shows open lines. Or the other way round: a balance in USD on an account nobody thinks posts in USD. This is the [update currency](../update_currency_pswsl/README.md): balances are keyed by PSWSL, line item lists by the document currency WAERS, and on an account without *only balances in local currency* they differ whenever a clearing crossed currencies. Checklist:

1. FS03 → *Control data*: is *Only balances in local currency* set? If not, the account has a bucket per currency.
2. FB03 on a suspicious line → *General ledger currency* field: that is PSWSL. If it differs from the document currency, the line was posted in the course of a clearing (KBA 2219419).
3. FBL3N with the update currency and amount columns added (BSEG-PSWSL and PSWBT, available as special fields through OBVU when the layout does not offer them) reconciles to FS10N; the document currency column does not.
4. KBA 1904331 is the case where the local balance is zero and the items still cannot be cleared: the per-currency buckets are not.

## Shape 2: the document currency is not the currency shown

A clearing document shows lines in EUR although the payment was in USD; a report for currency USD lists a document whose header says EUR. Same cause as shape 1, seen from the document. The lines in the clearing document that nobody entered are the additional update-currency lines that bring each bucket to zero (SAP Note 391532). A document that cannot be cleared at all with F1806 has no PSWSL, usually from an interface (KBA 1906780); F.13 clearing a single line is the same field (KBA 3511670).

## Shape 3: the rate was not the rate in OB08

The local amount is not what the user computed from the rate table. In order of likelihood:

1. **Translation date.** BKPF-WWERT is the date the rate was read for, and it is the posting date unless entered; a document dated the 3rd and posted on the 5th used the 5th's rate (KBA 1848683, and BAdI FI_TRANS_DATE_DERIVE if the derivation was changed).
2. **Rate type.** The document type (OBA7) or the parallel currency's conversion settings (FINSC_LEDGER) may name a rate type other than M; MM goods receipts ignore OBA7 (KBA 2592703); FCV uses the valuation method's type (KBAs 2443070, 3359366, 3618871).
3. **Ratio, inverse or reference currency.** The rate was derived: see the search order in [Exchange rates](../exchange_rates/README.md). OB08 showing `0 : 0` is a display artefact (KBAs 3366043, 3314213).
4. **Manual rate.** The header field BKPF-KURSF was typed; the deviation warning was accepted (KBA 2646229).
5. **Parallel currency source.** The second local currency was translated from the first, not from the document currency, so the rate is a product of two rates (KBA 2542937).
6. **PO rate.** A goods receipt used the purchase order's fixed rate.

## Shape 4: a difference was posted that should not have been

An exchange rate difference appeared on clearing two items in the same local amount. The clearing revalued a foreign-currency item at the clearing rate because the account keeps balances per currency and the company code does not have *No forex rate diff. when clearing in LC* (see [SKB1-XSALH](../only_balances_in_local_currency/README.md) and [Exchange rate differences on clearing](../exchange_rate_differences_on_clearing/README.md)). The guided answer in KBA 2560929 and the flowchart in KBA 2220851 (for F5263) cover the decision; KBA 2547111 is "unexplained difference", usually shape 3 in disguise. A difference in the *second* local currency with none in the first is not an error (see [Local currency and the parallel currencies](../local_and_parallel_currencies/README.md)).

## Shape 5: a difference was not posted that should have been

Foreign currency valuation did nothing for an account: the account has *only balances in local currency* (KBA 3138607), or is not open-item managed and has no exchange rate difference key for KDB, or the valuation area's ledger group is not the one being looked at, or the delta logic found no change (KBA 3641501). The group currency not valuated is KBA 3320183. The support-content page *Most common errors in FAGL_FC_VAL and FAGL_FCV* is the checklist.

## Messages

| Message | Meaning | Page |
|---|---|---|
| The message asking to *enter rate X / Y, rate type M, for a date* (SG105 on the system where [How a posting picks its exchange rate](../../01_FI/exchange_rates/how_a_posting_picks_its_rate.md) read it) | No rate found by the search order | [Exchange rates](../exchange_rates/README.md) |
| The warning that the entered rate *deviates from the table rate by n %* | Manual rate outside the tolerance per company code or per currency pair | [Exchange rates](../exchange_rates/README.md) |
| F5263 *Difference too large for clearing* | The revalued items do not net within tolerance | [Exchange rate differences on clearing](../exchange_rate_differences_on_clearing/README.md) |
| F5063 (KBAs 1697833, 1701011), F5263 from FBB1 (KBA 1699746) | Clearing in local currency with amounts entered manually | same |
| F1806 | Line without update currency | [Update currency](../update_currency_pswsl/README.md) |
| FH085 *Account still has balance* | Changing SKB1-XSALH on an account with a balance | [SKB1-XSALH](../only_balances_in_local_currency/README.md) |
| *Currency & not permitted in account &* (KBA 2888262) | Account currency ≠ posting currency | [Currency keys](../currency_keys_and_decimals/README.md) |
| FINS_ACDOC_CUST242, CUST298, CUST516 | FINSC_LEDGER configuration rules | [Ledgers and their currencies](../ledgers_and_currencies/README.md) |
| C+339, KM133, MLCCS003, C+039 | Material Ledger currency configuration | [Material Ledger currencies](../material_ledger_currencies/README.md) |
| AFLE007 *Amount too long* | Amount exceeds 13 digits where AFLE is off | [Rounding and the amount field](../rounding_and_amount_fields/README.md) |
| 00011 *Decimal places are not permitted* (KBA 2743937), *Enter a number with no decimal places* (KBA 2920613) | Decimals typed for a zero-decimal currency | [Currency keys](../currency_keys_and_decimals/README.md) |

## Reading the non-BSEG currencies

A freely defined currency is not in FBL3N or FS10N at all, and asking why "the GBP column is empty" in a classic report is a common ticket after a currency was added. FB03L, FAGLB03, FAGLL03H, the Fiori apps and the CDS analytics show it; the trial balance per freely defined currency type is KBA 2593455. A custom report needs FINSC_LEDGER to know which ACDOCA field the type occupies; see [Currencies in the Universal Journal](../universal_journal_currencies/README.md).

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Balance versus line items | `FS10N` / `FAGLB03` against `FBL3N` with the `PSWSL` / `PSWBT` columns |
| The rate a document used | `SE16N` on `BKPF`: `KURSF`, `WWERT`; the `OB08` row for that date |
| A difference that should not have been posted | `FS03` (the indicator), `OBY6` (`XSLTA`), `OBA1` (the account it went to) |
| A difference that was not posted | `FS03`, `OB59`, the valuation area and its ledger group, the run's log |
| A currency that is not in a classic report | `FB03L` and `FAGLB03` against `FBL3N`; `FINSC_LEDGER` for the field the type occupies |

## Provenance

Written from support experience and from the cited KBAs, whose titles were verified in September 2026. Message numbers in the table are quoted from KBA titles or from a message read on a system for another page of this library (linked where so); the one message whose number could not be sourced is described by its text instead.

## Related pages

- [Update currency](../update_currency_pswsl/README.md) — shapes 1 and 2
- ["Only manage balances in local currency"](../only_balances_in_local_currency/README.md) — shape 4
- [Exchange rate differences on clearing](../exchange_rate_differences_on_clearing/README.md) — shapes 4 and 5
- [Currencies in the Universal Journal](../universal_journal_currencies/README.md) — the fields the newer apps show
- [Exchange rates](../exchange_rates/README.md) — shape 3

Back to the chapter map: [Currencies in SAP](../README.md).

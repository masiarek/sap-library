# Currencies in the Universal Journal (ACDOCA)

**Level:** 301 · for anyone who has to read ACDOCA or plan an S/4HANA conversion

**One line:** ACDOCA carries up to thirteen amount fields per line — WSL, TSL, HSL, KSL, OSL … GSL and CO_OSL — each a currency *type* configured per ledger and company code, and only three of them survive into BSEG.

## From three currencies to ten

In ECC the currencies were scattered. FI had a local currency and two parallel ones (T001A, OB22). Controlling had a controlling area currency and an object currency (TKA01, OKKP), one of which had to be the local currency and the other of which did not have to exist in FI at all. The new G/L's non-leading ledgers (T882G) could carry a subset of the leading ledger's currencies. Each module converted on its own, and reconciling them was a job.

The Universal Journal put FI and CO line items in one table, ACDOCA, and so needed one currency configuration for both: the view cluster FINSC_LEDGER (*Define Settings for Ledgers and Currency Types*). Per ledger and company code it lists up to ten currency types, each with its own conversion settings, and every posting from any source is converted into every one of them in the accounting interface, in real time, with balance zero guaranteed per journal entry. SAP Note 2344012 (*Currencies in Universal Journal*) is the reference for all of this, and the numbers in this page are its numbers.

## The amount fields

| ACDOCA field | Currency key field | Description | Role | Where else it lives |
|---|---|---|---|---|
| WSL | RWCUR | Amount in transaction currency | The document currency, type 00. Not contained in balances, because amounts in different currencies cannot be aggregated. | BSEG-WRBTR |
| TSL | RTCUR | Amount in balance transaction currency | The currency the G/L account's balance is kept in; the [update currency](../update_currency_pswsl/README.md). Derived per line, not configured. | BSEG-PSWBT / PSWSL |
| HSL | RHCUR | Amount in company code currency | Type 10, the local currency. Mandatory, the same in every ledger. | BSEG-DMBTR; CO object currency unless the CO area currency type is 10 |
| KSL | RKCUR | Amount in global currency | The currency type of the controlling area (TKA01-CTYP). Filled when the company code is in a controlling area; SAP recommends it be type 30, the group currency. Mandatory, the same in every ledger. | BSEG-DMBE2 or DMBE3 when marked BSEG-relevant; CO area currency |
| OSL | ROCUR | Freely defined currency 1 | Any standard or customer type, per ledger and company code | BSEG-DMBE2/3 if chosen |
| VSL | RVCUR | Freely defined currency 2 | " | " |
| BSL | RBCUR | Freely defined currency 3 | " | ACDOCA only |
| CSL | RCCUR | Freely defined currency 4 | " | " |
| DSL | RDCUR | Freely defined currency 5 | " | " |
| ESL | RECUR | Freely defined currency 6 | " | " |
| FSL | RFCUR | Freely defined currency 7 | " | " |
| GSL | RGCUR | Freely defined currency 8 | " | " |
| CO_OSL | RCO_OCUR | Amount in object currency of CO | Type 70, stored only when the object currency is really a different currency | COEP object currency |

WSL, TSL, HSL and KSL are mandatory in every ledger. The "freely defined" fields are freely *assigned*, not necessarily customer types: OSL may well hold the hard currency (40) and VSL a Z type. Which field a type lands in is a consequence of the order in FINSC_LEDGER, and a program reading ACDOCA must read the configuration (or the CDS views over it) rather than assume that OSL "is" anything in particular.

## BSEG-relevant currencies

BSEG was not extended and holds three parallel currencies. On the overview screen of the company code assignment in FINSC_LEDGER, the columns *1st / 2nd / 3rd FI currency* choose which of the ledger's currency types also go to BSEG-DMBTR, DMBE2 and DMBE3. The rules from SAP Note 2344012:

- the 1st FI currency is always type 10;
- customer types (Y*, Z*) cannot be BSEG-relevant (KBA 2543240);
- a type marked BSEG-relevant in the leading ledger that is also configured in a non-leading ledger must be BSEG-relevant there as well.

Everything that is BSEG-relevant is visible to the classic transactions (FBL3N, FS10N, F-03 and the whole open-item machinery) and to fixed asset accounting and the Material Ledger before UPA. Everything else is visible only in the ledger view: FB03L, FAGLB03, FAGLL03, FAGLL03H, the Fiori *Display G/L Account Line Items*, *Journal Entry Analyzer*, *Audit Journal* and *Display Financial Statement* apps, and the CDS-based analytics.

## Conversion settings per currency type

For every type of a ledger and company code, FINSC_LEDGER holds:

| Setting | Values | Meaning |
|---|---|---|
| Source currency type | 00 (document currency) or 10 (company code currency), or another configured type | The amount this one is converted *from*. |
| Exchange rate type | M or any TCURV type | Which rate. In S/4HANA Cloud, M is fixed for the document-to-company-code conversion and cannot differ per ledger (KBA 3512760). |
| Translation date type | 1 document date · 2 posting date · 3 translation date | Which date the rate is read for. |
| Real-time conversion | on / off | Whether the accounting interface fills the field on every posting (the normal case) or a process delivers it. |

KBA 2542937 (*Understanding the currency conversion settings in FINSC_LEDGER*) explains the three; KBAs 2895413 and 3253173 are the cases where they cannot be saved; KBA 1700266 is about changing the rate type afterwards, which does not touch the history. In a migrated system the settings are whatever OB22 held, and in a converted system no new currency is introduced along with the conversion.

## What the program prints

One document in JPY converted into four configured currency types, rounded line by line, with the rounding difference moved onto one line so that every field balances, TSL derived per line, and the BSEG mapping:

<!-- output:universal_journal_amounts -->
*Verified output of [`universal_journal_amounts.py`](examples/universal_journal_amounts.py) — regenerated by `tools/run_examples.py`, never hand-typed.*

```text
1. THE CONFIGURATION: WHICH CURRENCY TYPE OWNS WHICH FIELD (tx FINSC_LEDGER, ledger 0L, CoCd 1010)
   type  field  key  converted from  in BSEG as
   00    WSL    JPY  (document currency itself)  WRBTR
   10    HSL    EUR  type 00              DMBTR
   30    KSL    USD  type 10              DMBE2
   40    OSL    CHF  type 10              DMBE3
   Z1    VSL    GBP  type 10              -- (ACDOCA only)
   TSL is not configured: it is derived per line (the update currency, see PSWSL).

2. CONVERT EVERY LINE INTO EVERY FIELD, ROUNDING EACH LINE
   account     WSL JPY            TSL    HSL EUR    KSL USD    OSL CHF    VSL GBP
   400000      1234567    1234567 JPY   10333.33   11235.43   10164.90    8838.10
   154000       123457    1033.34 EUR    1033.34    1123.55    1016.50     883.82
   160000     -1358024   -1358024 JPY  -11366.66  -12358.97  -11181.38   -9721.90
   sum               0                      0.01       0.01       0.02       0.02
   balanced in WSL; not balanced in HSL, KSL, OSL, VSL: rounding each line leaves a cent or two.

3. BALANCE ZERO PER JOURNAL ENTRY: THE DIFFERENCE IS ADJUSTED ON ONE LINE
   The accounting interface moves each field's rounding difference onto one line item
   (this program takes the last one) so that every field nets to zero. No extra line,
   no extra account: a line's HSL may differ by a cent from its own converted amount.
     HSL: line 160000 -11366.66 -> -11366.67   (adjusted by -0.01)
     KSL: line 160000 -12358.97 -> -12358.98   (adjusted by -0.01)
     OSL: line 160000 -11181.38 -> -11181.40   (adjusted by -0.02)
     VSL: line 160000 -9721.90 -> -9721.92   (adjusted by -0.02)
   sums now: WSL 0  HSL 0.00  KSL 0.00  OSL 0.00  VSL 0.00

4. TSL DOES NOT HAVE TO BALANCE PER ENTRY, ONLY PER ACCOUNT AND CURRENCY OVER TIME
   TSL by currency in this entry: JPY -123457, EUR 1033.34
   The tax account has XSALH set, so its balance is kept in EUR while the other two
   lines keep JPY; TSL mixes currencies within one entry by design.

5. WHAT REACHES BSEG, AND WHAT DOES NOT
   field  currency key field  BSEG
   WSL    RWCUR               WRBTR / WAERS (header)
   TSL    RTCUR               PSWBT / PSWSL
   HSL    RHCUR               DMBTR
   KSL    RKCUR               DMBE2
   OSL    ROCUR               DMBE3
   VSL    RVCUR               -- not in BSEG
   BSEG has room for three parallel currencies and will not be extended; the Z1 amount
   in GBP is visible in FB03L, FAGLB03, FAGLL03H and the Fiori apps, not in FBL3N.

6. WHICH PROCESSES CONVERT WITH HISTORICAL RATES (X) AND WHICH FALL BACK (1..4), note 2344012, UPA off
   process                                  10 30 40 Z1
   Realtime currency conversion             X  X  X  X
   Balance zero per journal entry           X  X  X  X
   Open item management (AP, AR, GL)        X  X  X  X
   Foreign currency valuation               X  X  X  X
   GL allocations                           X  X  X  X
   Regrouping                               X  X  X  1
   Fixed asset accounting                   X  X  X  1
   Material ledger                          X  X  X  1
   CO allocations                           X  X  4  4
   CO settlement                            X  X  2  2
   CO reposting                             X  X  1  1
   1 = converted at the current rate as a fallback; 2 = all currencies since 2020 if set in
   the settlement profile; 4 = accurate if the field is in the cycle. With Universal
   Parallel Accounting (2022+) every cell is X.
```
<!-- /output -->

Run it yourself from the folder that holds it:

```bash
cd 03_Currency/universal_journal_currencies/examples
python3 universal_journal_amounts.py
```

## Process coverage: what converts with history and what falls back

Converting every line at posting time with the current rate is the easy part. Some processes must carry *historical* amounts: an open item cleared in the group currency has to be cleared at the group-currency amount it was posted with, not at today's rate; an asset's depreciation in the hard currency has to be computed from its hard-currency acquisition value. SAP Note 2344012 keeps the matrix, and with UPA switched off it looks like this for a ledger whose currencies are 10, 30, 40, 50, 60 and Z1–Z5:

| Process | 10 | 30 | 40 | 50 | 60 | Z1–Z5 |
|---|---|---|---|---|---|---|
| Real-time currency conversion | X | X | X | X | X | X |
| Balance zero per journal entry | X | X | X | X | X | X |
| Open item management (FI-AP, FI-AR, FI-GL) | X | X | X | X | X | X |
| Foreign currency valuation | X | X | X | X | X | X |
| G/L allocations (assessment and distribution) | X | X | X | X | X | X |
| Regrouping | X | X | X | 1 | 1 | 1 |
| Fixed asset accounting | X | X | X | 1 | 1 | 1 |
| Material Ledger | X | X | X | 1 | 1 | 1 |
| CO allocations | X | X | 4 | 4 | 4 | 4 |
| CO-PA allocations | X | X | 3 | 3 | 3 | 3 |
| CO settlement | X | X | 2 | 2 | 2 | 2 |
| CO reposting | X | X | 1 | 1 | 1 | 1 |

Where, in the note's own terms: **1** the amounts are converted with the current exchange rate as a fallback, and a difference from rounding or from different rates can remain; **2** since S/4HANA 2020 CO settlement supports all ACDOCA currencies if activated in the settlement profile; **3** since 2021 CO-PA allocations are part of Universal Allocation, which supports all currencies, while classic CO-PA allocations still support 10 and 30 only; **4** CO allocations treat all amounts accurately if the amount field is included in the cycle definition, otherwise convert with current rates. Final settlements of assets under construction count as fixed asset accounting. With Universal Parallel Accounting switched on, every cell is X since S/4HANA 2022; see [Universal Parallel Accounting](../universal_parallel_accounting/README.md).

The practical reading of the matrix: before configuring a fourth currency, decide which processes must carry it with history. If asset depreciation or actual costing must be exact in it, it has to be one of the three BSEG-relevant currencies, or the system has to be on UPA.

## Reporting on the non-BSEG currencies

Since S/4HANA 1610 the currencies that are not in BSEG can be displayed in FB03 (with the ledger view), FB03L, FAGLB03, FAGLL03, FAGLL03H, and in the Fiori apps *Display G/L Account Line Items*, *Journal Entry Analyzer*, *Audit Journal* and *Display Financial Statement*. The trial balance for a freely defined currency type is KBA 2593455. The CDS-based analytics (SAP Note 2579584 by the note's own reference, via the *Trial Balance* and *Journal Entry Analyzer* apps) support all currencies of the Universal Journal.

## Release history

| Release | Currency fields |
|---|---|
| Simple Finance 1503 | WSL, TSL, HSL, KSL, OSL, VSL: enough to hold the ECC FI and CO amounts |
| S/4HANA 1511 | two freely defined currencies (OSL, VSL, plus FSL); no real-time conversion for customer types, so foreign currency valuation served as a substitute |
| S/4HANA 1610 and S/4HANA Finance 1605 | eight freely defined currencies with real-time conversion; the table above |
| S/4HANA 1809 | freely defined (non-BSEG) currencies can be introduced into a live system with the *Manage Currencies* tools |
| S/4HANA 2020 / 2021 | CO settlement and Universal Allocation cover all currencies |
| S/4HANA 2022 / 2023 | Universal Parallel Accounting: all currencies in all processes |

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Which type occupies which field | `FINSC_LEDGER`, *Company Code Settings for the Ledger*: the order of the currency types |
| The field contents | `SE16N` on `ACDOCA`: `WSL`, `TSL`, `HSL`, `KSL`, `OSL` … with `RWCUR`, `RTCUR`, `RHCUR`, `RKCUR`, `ROCUR` … |
| BSEG relevance | `FINSC_LEDGER` 1st / 2nd / 3rd FI currency; compare `BSEG-DMBE2` / `DMBE3` with the matching `ACDOCA` fields on one document |
| Balance zero per field | `SE16N` on `ACDOCA` for one document; sum each amount field; find the line that carries the rounding cent |
| Conversion settings per type | `FINSC_LEDGER`, *Currency Conversion Settings* |
| Non-BSEG currencies in reports | `FB03L`, `FAGLB03`, `FAGLL03H` against `FBL3N` on the same document |
| Process coverage | SAP Note 2344012 in SAP for Me; then a test settlement or depreciation run in a non-BSEG currency, comparing with a conversion at the current rate |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory. The field list and the process matrix are transcribed from SAP Note 2344012; the currency key fields beyond RVCUR follow the note's naming pattern and were not read from a system.

## Related pages

- [Currency types](../currency_types/README.md) — what the types are
- [Ledgers and their currencies](../ledgers_and_currencies/README.md) — FINSC_LEDGER in full
- [Universal Parallel Accounting](../universal_parallel_accounting/README.md) — the matrix with every cell X
- [Local currency and the parallel currencies](../local_and_parallel_currencies/README.md) — the BSEG side
- [Update currency](../update_currency_pswsl/README.md) — TSL
- [Rounding and the amount field](../rounding_and_amount_fields/README.md) — balance zero per field

Back to the chapter map: [Currencies in SAP](../README.md).

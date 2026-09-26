# Introducing, changing and retiring currencies

**Level:** 301 · for architects and anyone who has been asked to "just add a currency"

**One line:** Adding a currency *key* is a table entry; adding a currency *type* to a live company code is a data conversion project, because every historical line would have to be re-valued — the one setting SAP itself says cannot be introduced by migration.

## Adding a currency key

A new key is Customizing: OY03 for TCURC (key, ISO code, validity), OY04 for TCURX if the decimals are not two, texts in TCURT, and rates in OB08 (with ratios in OBBS and quotation in ONOT if the pair needs them). It is done for a new country, for a redenomination, or when ISO 4217 changes. Recent changes a system may need:

| Year | Change | Old key | New key | Decimals |
|---|---|---|---|---|
| 2018 | Mauritania redenominated the ouguiya | MRO | MRU | 2 |
| 2018 | São Tomé and Príncipe redenominated the dobra | STD | STN | 2 |
| 2018 | Venezuela: bolívar soberano (SAP Notes 2623984, 2626145 on hyperinflation) | VEF | VES | 2 |
| 2021 | Venezuela: bolívar digital | VES | VED | 2 |
| 2022 | Sierra Leone redenominated the leone | SLL | SLE | 2 |
| 2023 | Croatia adopted the euro (SAP Notes 3093354, 3251724) | HRK | EUR | 2 |
| 2024 | Zimbabwe: Zimbabwe Gold (SAP Note 3484778, ISO 4217 amendment 177) | ZWL | ZWG | 2 |
| 2025 | Sint Maarten and Curaçao: Caribbean guilder | ANG | XCG | 2 |

An expired key keeps its row, with a valid-to date, because history refers to it; open items in it are settled or converted, and a company code whose *local* currency was the old key is the subject of the changeover section below.

## Adding a currency type to a live company code

This is where "just add a currency" stops being a table entry. A currency type is an amount field on every line item, and the lines already posted do not have it. Three levels:

**A freely defined (non-BSEG) type, S/4HANA 1809 and later.** Supported through the IMG tools under *Financial Accounting → Financial Accounting Global Settings → Tools → Manage Currencies*: check and simulate, activate the type in FINSC_LEDGER, then enrich the existing ACDOCA data (the program FINS_ACDOC_UTIL_SET_CURR_KEYS sets the keys; the enrichment converts the amounts at the rates of the original translation dates). Only legal-valuation types can be introduced this way (no 11/12/31/32), archived data is not enriched, and the new type is ACDOCA-only: it is available to the processes in the [coverage matrix](../universal_journal_currencies/README.md) but not to BSEG, fixed assets or the Material Ledger before UPA. SAP Note 2334583 (*Introduction of new currencies and currency types in SAP S/4HANA*) is the reference; KBA 2856805 is the Cloud version.

**A BSEG-relevant type (a new second or third local currency), or a change of an existing one's key.** Not supported by configuration, and not by migration: SAP Note 2344012 states that a system conversion migrates the currency configuration as it is and cannot introduce new currencies, because the existing data does not contain them and open processes would not work if the configuration changed underneath. This is a *currency conversion* project with SAP's Data Management and Landscape Transformation services (or a partner's equivalent), which convert every table that holds the amount, open items included, with a cut-over.

**A Material Ledger currency.** Cannot be added or modified once the ML is active for the valuation area (KBA 2555648); it is part of the same conversion project.

## Changing the local currency: the changeover

A company code whose country changes currency (the euro adoptions, most recently Croatia in 2023; redenominations elsewhere) needs its local currency changed, which means every local-currency amount in every table — open items, balances, assets, cost estimates, ML prices, planning, archived data references — converted at the fixed conversion rate on a key date, with the rounding differences of the conversion posted. SAP delivers this as the *SAP S/4HANA currency changeover add-on* (help-portal document set of that name, with the *General Ledger-Specific Conversion Logic*), the descendant of the euro changeover workbench (EWU) of 1999–2002. The blog *Currency Changeover needs on productive SAP S/4HANA On-Prem and Private Cloud Environment* is SAP's current guidance; KBA 3642962 is one of the post-changeover synchronisation steps (ACDOCA and ACDOCU against the ICADOCM table). Before the key date: close open items where possible, complete valuations, freeze rates. After: the old key expires in TCURC, and rate type EURX with its fixed rate handles the triangulation for anything that still refers to it.

## Retiring a currency

A currency the company stops using is not deleted: the key stays, the open items in it are cleared, the bank accounts in it are closed (their G/L accounts blocked for posting after the balance is zero), the rate rows stop being loaded, and the valuation runs stop finding items. A freely defined currency *type* can, in principle, be removed from a ledger's configuration only when no data in it exists, which is never true in a productive system; it stays configured and stops being reported.

## Migration to S/4HANA

For completeness, what the conversion does with currencies, from SAP Note 2344012 and the *SAP S/4HANA Currency Setup* blog:

- ECC's local currency, OB22 parallel currencies with their conversion settings, the controlling area currency (into KSL) and the new G/L non-leading ledger currencies are migrated as they are;
- no new currency is introduced along with the conversion;
- installations that used transfer prices arrive with their currency/valuation combinations in the same ledger, which is the one way to start S/4HANA with more than three currencies without a project;
- after the conversion, the 1809 tools above are the way to add a freely defined type.

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Existing keys and their expiry | `OY03`; `SE16N` on `TCURC` |
| Adding a key | `OY03`, `OY04`, `OB08` in a sandbox client |
| The 1809 tools | IMG *Financial Accounting Global Settings → Tools → Manage Currencies* |
| The BSEG-relevance limit | `FINSC_LEDGER`: try a Z type as 2nd FI currency and read the message |
| The Material Ledger restriction | `OMX2` on an active valuation area |
| The migration rule | SAP Notes 2344012 and 2334583 in SAP for Me; `FINSC_LEDGER` in a converted system shows the former `OB22` settings |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory. The table of recent ISO 4217 changes is from public ISO amendment lists and the cited SAP Notes; the year given is the year of the change, not of the SAP Note.

## Related pages

- [Currency keys, codes and decimal places](../currency_keys_and_decimals/README.md) — what a key is
- [Local currency and the parallel currencies](../local_and_parallel_currencies/README.md) — what a BSEG-relevant type is
- [Currencies in the Universal Journal](../universal_journal_currencies/README.md) — what an ACDOCA-only type can do
- [Ledgers and their currencies](../ledgers_and_currencies/README.md) — where the type is activated

Back to the chapter map: [Currencies in SAP](../README.md).

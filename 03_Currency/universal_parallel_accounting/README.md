# Universal Parallel Accounting and currencies

**Level:** 301 · for architects planning S/4HANA 2022 and later

**One line:** Universal Parallel Accounting makes every configured currency a first-class citizen of every process — asset depreciation, settlement, overhead, actual costing — instead of the pre-2022 world where only the three BSEG currencies were converted with historical rates and the rest fell back to the current rate.

## The problem it solves

The Universal Journal could hold ten currencies from 1610 on, but the processes around it could not all use them. The [coverage matrix](../universal_journal_currencies/README.md) in SAP Note 2344012 has a row per process and a column per currency, and the columns beyond the three BSEG currencies are full of fallbacks: fixed asset accounting, the Material Ledger, regrouping and CO reposting converted the extra currencies at the *current* rate, so a depreciation charge in the hard currency was not the historical hard-currency acquisition value spread over the useful life but a translation of the local-currency charge at whatever the rate was that month. For a group that needs an exact second set of books in a second currency, that is not parallel accounting; it is a translation.

Asset accounting had a second limit of its own: a depreciation area could carry at most three currencies, and parallel currencies needed parallel *areas*, one per currency and principle, with the rules about which area posts to which ledger that every asset accountant knows. The Material Ledger had the same three-currency ceiling. Controlling was not integrated in all currencies for allocations, settlement and production accounting.

## What UPA is

Universal Parallel Accounting is a business function (FINS_PARALLEL_ACCOUNTING_BF), available for new implementations from S/4HANA 2022 and, from 2023, with a migration path for systems with existing data. Once activated it cannot be deactivated (SAP Note 3191636, *Universal Parallel Accounting: Scope Information*; 3265275 is the FAQ, 3327778 the migration scope for 2023, KBA 3577390 the activation procedure). It makes the *ledger* the single carrier of parallel valuation everywhere:

- **Asset accounting:** one depreciation area per ledger, carrying all the ledger's currencies, so no separate parallel-currency areas; ledger-specific fiscal year variants; depreciation computed in each currency from that currency's historical acquisition value.
- **Material Ledger:** the ML currency types are the ledger's currency types, up to ten; ledger-dependent inventory valuation and actual costing.
- **Controlling:** overhead, settlement, allocations, event-based WIP and production accounting in all currencies, ledger by ledger, and event-based revenue recognition. Some classic functions are not supported and have event-based successors: classic assessment and distribution, classic WIP and variance calculation, results analysis, costing-based CO-PA, classic period-end production accounting.
- **Currency conversion settings become ledger-specific**: a ledger can use its own exchange rate type and translation date for a currency type.

In SAP's own summary: "with Universal Parallel Accounting, up to ten currencies are calculated and posted in parallel," and the former limitations "to three parallel currencies in asset accounting and material ledger" are removed.

## What it changes for currencies, concretely

| Before UPA | With UPA |
|---|---|
| Three BSEG currencies carried with history through AA, ML, CO; the rest converted at the current rate as a fallback | All ledger currencies carried with history through every process |
| Depreciation areas per currency and principle | One area per ledger, all currencies |
| ML currency and valuation profile with at most three combinations (OMX2, OMX3) | ML currencies = ledger currencies |
| Conversion settings per currency type, shared across ledgers | Conversion settings per ledger |
| A fourth currency was "for reporting" | A fourth currency is a set of books |
| The 2344012 matrix with 1, 2, 3, 4 | Every cell X |

A functional currency per company code is part of the same wave (S/4HANA 2023), and the localisation scope grows release by release (in 2022 it was a short list of countries; check SAP Note 3191636 for the current one).

## Restrictions and decisions

- **New implementation versus conversion.** 2022 was pilot and greenfield only; 2023 added migration for systems with existing data (SAP Note 3327778). A brownfield system that uses classic parallel accounting needs the migration project, not a switch.
- **Irreversible.** The business function cannot be switched off; the UPA guide and the readiness blog series exist because of this.
- **Not everything is supported.** Costing-based CO-PA, classic results analysis and classic period-end production accounting are replaced by event-based functions; a company that depends on them has a functional gap to close first.
- **Profit center valuation** had restrictions in the first releases (SAP Note 3419623).
- **Public Cloud** does not expose ledger-specific rate types (KBA 3512760); the on-premise and private-cloud editions do.

## Where to read

- The UPA guide for S/4HANA 2023 on the help portal (a PDF, *Universal Parallel Accounting (UPA)*), and the on-premise product-assistance page *Universal Parallel Accounting*.
- The SAP blog *Universal Parallel Accounting in SAP S/4HANA* and the follow-ups on production accounting, financial planning and readiness.
- The SAP PRESS titles on UPA and on S/4HANA finance listed under [Resources](../resources/README.md).

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Activation state | `SFW5`, business function `FINS_PARALLEL_ACCOUNTING_BF` |
| Depreciation areas per ledger | Asset accounting configuration (`OADB`) after activation: one area per ledger, all currencies |
| ML currencies equal ledger currencies | `OMX2` and `OMX3` against `FINSC_LEDGER` after activation |
| Scope, restrictions and migration | SAP Notes 3191636, 3265275 and 3327778 in SAP for Me |
| Ledger-specific conversion settings | `FINSC_LEDGER`, *Currency Conversion Settings* per ledger |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory. The description of what UPA changes follows SAP's UPA guide and blogs; no UPA system was used for this page.

## Related pages

- [Currencies in the Universal Journal](../universal_journal_currencies/README.md) — the matrix UPA completes
- [Ledgers and their currencies](../ledgers_and_currencies/README.md) — ledger-specific settings
- [Material Ledger currencies](../material_ledger_currencies/README.md) — the three-currency limit it removes
- [Currencies in Controlling](../controlling_currencies/README.md) — allocations and settlement in all currencies

Back to the chapter map: [Currencies in SAP](../README.md).

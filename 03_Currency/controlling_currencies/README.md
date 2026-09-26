# Currencies in Controlling and margin analysis

**Level:** 201 · for CO consultants

**One line:** Controlling keeps two currencies of its own — the controlling area currency and the object currency — and in S/4HANA both are just currency types of the same journal, which is why a cross-company controlling area forces a choice that FI never had to make.

## Three currencies on a CO line item

Every Controlling line item (COEP in ECC, ACDOCA in S/4HANA) carries three amounts:

| Currency | Where it comes from | ACDOCA field |
|---|---|---|
| **Transaction currency** | The currency of the business transaction, the same as the FI document currency for an integrated posting | WSL |
| **Controlling area currency** | The currency of the controlling area, OKKP, TKA01-WAERS, with a currency type in TKA01-CTYP | KSL (the *global currency*) |
| **Object currency** | The currency of the cost object: cost center, internal order, WBS element, each with a currency field in its master record; defaults to the company code currency | HSL when it equals the company code currency, otherwise CO_OSL |

The controlling area's currency **type** is chosen in OKKP from 10, 20, 30, 40, 50 and 60. Type 10 is only possible when every company code in the area shares its currency (or the assignment is one to one). Type 20, a free controlling area currency that is none of the FI types, is allowed but discouraged in S/4HANA because it then occupies KSL without being a group currency anybody reports in. Type 30 is what SAP recommends for new installations: then KSL is the group currency in FI and the controlling area currency in CO at once, and the two never need reconciling. Types 40, 50 and 60 require all company codes to share the same hard, index-based or global company currency (via the country or the company).

The object currency can be chosen freely on a cost object only when the controlling area currency equals the company code currency; otherwise it is fixed to the company code currency. KBA 3363959 is the message that enforces it on an internal order.

## Cross-company code controlling

A controlling area that spans company codes in different currencies (cross-company code cost accounting, set in OKKP's assignment control) is the case that forces the choice. The controlling area currency cannot be 10; it becomes 30 (or 20), every CO posting is translated into it, and every allocation between cost centers in different company codes crosses a rate. Three consequences:

- **The rate.** CO postings from FI are translated at the FI document's rate into the controlling area currency (via the ledger's conversion settings in S/4HANA). Internal CO postings (allocations, settlements) use the rate at their own posting date, and the *value date* and exchange rate type of the CO version (OKEQ; type P by default for plan, M for actual) decide which.
- **Balance zero.** A CO allocation that balances in the controlling area currency can be out of balance in the object currency or transaction currency after rounding (KBA 3300701).
- **Reporting.** Cost center reports default to the controlling area currency; company code currency is a display switch (KBA 2356348). A manager in a EUR company code sees USD unless told otherwise.

## Which currencies CO processes carry

From the coverage matrix in SAP Note 2344012, with UPA off:

| Process | 10 | 30 | others |
|---|---|---|---|
| CO allocations (assessment, distribution) | X | X | accurate if the amount field is included in the cycle definition, otherwise converted at the current rate |
| CO settlement | X | X | all ACDOCA currencies since S/4HANA 2020, if activated in the settlement profile |
| CO reposting | X | X | converted at the current rate |
| CO-PA allocations | X | X | Universal Allocation (2021 and later) supports all currencies; classic CO-PA allocations only 10 and 30 |

Cross-company allocations and the cost-of-goods-manufactured scenario convert with current rates whatever the setting. With Universal Parallel Accounting every CO process carries every ledger currency; see [Universal Parallel Accounting](../universal_parallel_accounting/README.md).

## Planning currencies

CO plan versions (OKEQ) carry an exchange rate type, P by default, and a value date, so that plan data entered in the object currency is translated once at a planning rate rather than at whatever the rate is on the day of entry. Activity prices in KP26 can be planned in a currency other than the controlling area currency (KBA 2547586), and cost rates in the Fiori apps have their own rate handling (KBA 3013212). Base planning objects take a default currency setting (KBA 3529726).

## CO-PA: costing-based and margin analysis

Costing-based profitability analysis (the CE1/CE2/CE3/CE4 tables) stores value fields in the **operating concern currency** (type `B0`) and, if the operating concern is set up that way, also in the **company code currency** (type `10`), plus the profit-center valuation variants. The second storage exists precisely to avoid exchange-rate differences between CO-PA and FI when the two currencies differ. The operating concern currency can be changed only while no data has been posted. Exchange rates in CO-PA are derived by their own rules (help-portal page *Calculation Of Exchange Rate in Profitability Analysis*), and group currency in CO-PA record type F has its own reconciliation (KBA 2276469). The CO-PA FAQ notes (553626 and its continuations 2182929, 2221237, 2322447, 2559609, 2718989) collect the rest.

**Margin analysis** (account-based CO-PA) is the Universal Journal itself with profitability characteristics, so it inherits every currency of the ledger and has no currency configuration of its own. That is one of the reasons UPA does not support costing-based CO-PA: the parallel currencies are already in the journal.

## Product costing

Cost estimates are calculated in the controlling area currency and the company code currency, and in the Material Ledger's currencies when the ML is active. The costing variant's valuation variant chooses the exchange rate type for translating prices in other currencies (KBA 2161317), and the cost estimate's currencies must match the ML's (KBA 3513568 is what an inconsistency between company code and controlling area currency in a cost estimate looks like). See [Material Ledger currencies](../material_ledger_currencies/README.md).

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Controlling area currency and type | `OKKP`; `TKA01`, fields `WAERS`, `CTYP`; the assignment control for cross-company code cost accounting |
| Object currency | `KS03`, `KO03`, `CJ03`: the currency field of the object |
| Three amounts on a CO line | `SE16N` on `COEP`: the amounts in controlling area, object and transaction currency; on `ACDOCA`: `KSL`, `HSL` or `CO_OSL`, `WSL` |
| Plan version rate type and value date | `OKEQ`, settings per fiscal year |
| CO-PA currencies | `KEA0`, operating concern attributes: currency and the company code currency flag; `SE16N` on `CE1xxxx` |
| Settlement in all currencies | The settlement profile's currency setting (S/4HANA 2020 and later); a test settlement read in `FB03L` |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory.

## Related pages

- [Currency types](../currency_types/README.md) — 20, 70 and the valuation views
- [Currencies in the Universal Journal](../universal_journal_currencies/README.md) — KSL and CO_OSL
- [Material Ledger currencies](../material_ledger_currencies/README.md) — inventory's currencies and valuations
- [Universal Parallel Accounting](../universal_parallel_accounting/README.md) — CO in all currencies

Back to the chapter map: [Currencies in SAP](../README.md).

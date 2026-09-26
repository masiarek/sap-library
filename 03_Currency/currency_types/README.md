# Currency types: 00, 10, 30, 40, 50, 60 and the Z types

**Level:** 201 · for consultants and developers who have to read ACDOCA or configure a ledger

**One line:** A currency *key* says which money; a currency *type* says which *role* an amount plays — document, company code, group, hard, index-based, global company or freely defined — and every amount field in the journal is one role, not one key.

## Key versus type

Two documents in the same company code can both be in EUR and still mean different things by it. In a German company code, EUR is the company code currency (type 10). In a Swiss company code of the same group, whose group currency is EUR, the same key is the group currency (type 30). A report that asks for "the EUR amount" has not asked a well-formed question; it has to ask for the amount of type 10 or of type 30. The currency type is the answer to "which role", and the currency key attached to that role, per company code and ledger, is the answer to "which money".

This is not pedantry. The Universal Journal has one amount field per configured type, and the key can differ from one company code to the next while the field stays the same: ACDOCA-HSL is *the company code currency amount* for every line in the table, in EUR for one company code and in CHF for the next. See [Currencies in the Universal Journal](../universal_journal_currencies/README.md).

## The standard types

| Type | Name | Where the key is set | Amount field | Notes |
|---|---|---|---|---|
| 00 | Document (transaction) currency | Entered on the document, BKPF-WAERS | ACDOCA-WSL, BSEG-WRBTR | The currency the business event happened in. Never aggregated across documents. |
| 10 | Company code currency (local currency) | Company code, OBY6, T001-WAERS | ACDOCA-HSL, BSEG-DMBTR | Mandatory. The currency the legal entity keeps its books in. |
| 20 | Controlling area currency | Controlling area, OKKP, TKA01-WAERS | (CO) | Used when the controlling area has a currency of its own that is none of the FI types. |
| 30 | Group currency | Client, SCC4 (standard currency), T000 | ACDOCA-KSL when configured, BSEG-DMBE2/3 | One per client; the consolidation currency. |
| 40 | Hard currency | Country of the company code, OY01, T005 | any parallel field | A stable currency chosen per country, historically for high-inflation economies. |
| 50 | Index-based currency | Country of the company code, OY01, T005 | any parallel field | A fictitious inflation-indexed currency, for the same economies. |
| 60 | Global company currency | Company (OX15), T880 | any parallel field | The currency of the *company* (the consolidation unit), which need not be the group currency. |
| 70 | Object currency (CO) | The CO object's master record | ACDOCA-CO_OSL | Cost center, order or WBS currency; only stored separately when it really is different. |

The table is the ECC vocabulary carried forward. In ECC, a company code could have its local currency plus two of {30, 40, 50, 60} as parallel currencies (OB22), and Controlling could have a currency of its own (OKKP). In S/4HANA the same types are configured per ledger and company code in FINSC_LEDGER, and up to eight more can be added.

## Valuation views: the second digit

A currency type is two characters, and for the parallel currencies the second one is a valuation view:

| Type | Currency | Valuation |
|---|---|---|
| 10 | company code currency | 0 · legal valuation |
| 11 | company code currency | 1 · group valuation |
| 12 | company code currency | 2 · profit center valuation |
| 30 | group currency | 0 · legal valuation |
| 31 | group currency | 1 · group valuation |
| 32 | group currency | 2 · profit center valuation |

Group and profit center valuation exist for transfer prices: the same goods movement between two company codes has a legal price (what was invoiced), a group price (cost, since the group sold nothing to itself) and a profit-center price (the internal transfer price). The Material Ledger is where these views are carried for inventory, and the Universal Journal carries them as further currency types. See [Material Ledger currencies](../material_ledger_currencies/README.md) and [Group currency and translation](../group_currency_and_translation/README.md).

## Freely defined currency types

S/4HANA 1511 allowed two customer-defined currency types; 1610 and later allow eight, keys `Y*` or `Z*`, defined in FINSC_LEDGER (*Define Currency Types*). Each is a currency key plus a description, and it is assigned to a ledger and company code like any other type, with its own conversion settings (source type, rate type, translation date). Typical uses:

- a second group currency, for a sub-group that reports in another currency;
- a statutory reporting currency where the law requires books in a currency other than the company code currency;
- a functional currency in the IAS 21 sense when it differs from the company code currency;
- a stable "management" currency for a group that operates in volatile currencies.

Two constraints matter. A freely defined type cannot be one of the three BSEG currencies (message FINS_ACDOC_CUST242, KBA 2543240): it lives in ACDOCA only, which means it is visible in FB03L, FAGLB03, FAGLL03H and the Fiori apps but not in FBL3N or classic reports that read BSEG. And a freely defined type can be added to a *live* company code (since 1809, through the *Manage Currencies* tools in the IMG), while a standard BSEG-relevant type cannot. See [Introducing, changing and retiring currencies](../introducing_and_changing_currencies/README.md).

S/4HANA 2023 with Universal Parallel Accounting adds a *functional currency* setting for a company code (KBA 3622052 is about it not appearing in FINSC_LEDGER when UPA is off).

## Controlling and CO-PA have vocabularies of their own

Controlling area currency type is chosen in OKKP from 10, 20, 30, 40, 50, 60: if the controlling area spans company codes with different local currencies, it cannot be 10, and the usual choice is 30. Cost objects carry an object currency (type 70) which defaults to the company code currency. Costing-based CO-PA has currency types `B0` (operating concern currency) and `10` (company code currency), and stores both when the operating concern is set up that way. See [Currencies in Controlling](../controlling_currencies/README.md).

## Seeing the type on a document

- **FB03**, *General ledger view*, and the currency drop-down on the line item display, switch between the types of the ledger.
- **FB03L** shows the ledger view with all currency types of the ledger, including the freely defined ones.
- **ACDOCA** has one column per type and a matching currency key column: `HSL` with `RHCUR`, `KSL` with `RKCUR`, `OSL` with `ROCUR` and so on; the type-to-field mapping for the ledger and company code is in FINSC_LEDGER (tables `FINSC_LD_CMP` and `FINSC_CURTYPE` hold the assignment and the type definitions).
- **BSEG** has three amount fields, DMBTR, DMBE2 and DMBE3, and the currency keys for the last two are in the company code configuration, not on the line.

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Company code currency | `OBY6`; `T001-WAERS` |
| Group currency | `SCC4`, standard currency; `T000` |
| Hard and index-based currency | `OY01`, the country's hard currency and index-based currency fields; `T005` |
| Global company currency | `OX15`; `T880` |
| Controlling area currency and its type | `OKKP`; `TKA01`, fields `WAERS`, `CTYP` |
| Which types a ledger and company code carry | `FINSC_LEDGER`, *Company Code Settings for the Ledger*: the list of currency types and the three FI currency columns |
| A customer type cannot be a BSEG currency | `FINSC_LEDGER`: enter a Z type as 2nd FI currency and read the message (KBA 2543240) |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory.

## Related pages

- [Local currency and the parallel currencies](../local_and_parallel_currencies/README.md) — the types a company code carries on every line
- [Currencies in the Universal Journal](../universal_journal_currencies/README.md) — one amount field per type
- [Ledgers and their currencies](../ledgers_and_currencies/README.md) — types are configured per ledger and company code
- [Currencies in Controlling](../controlling_currencies/README.md) — controlling area currency and object currency
- [Material Ledger currencies](../material_ledger_currencies/README.md) — the valuation views for inventory

Back to the chapter map: [Currencies in SAP](../README.md).

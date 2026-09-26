# Group currency, consolidation and currency translation

**Level:** 201 · for group accountants

**One line:** The group currency is set once per client, carried on every line as currency type 30, and is the currency a consolidation translates *into* — with different rates for balance sheet, P&L and equity, and a translation difference that has nowhere to go but equity.

## The group currency in the journal

The group currency is the client's standard currency (SCC4, table T000) and appears in every company code's ledgers as currency type 30. In S/4HANA it usually also is the controlling area's currency type, so ACDOCA-KSL, the *global currency*, holds it for every line of FI and CO alike; SAP recommends exactly that for new installations, and KBAs 2446407 and 3009909 are what happens when the controlling area was set up otherwise and type 30 then cannot be assigned. Because it is converted in real time on every posting, a subsidiary's books in EUR exist in USD line by line, at the rate of each transaction's date.

That is *not* what a consolidation wants.

## Real-time translation versus period-end translation

A consolidation translates a subsidiary's financial statements into the group currency by the rules of IAS 21 or ASC 830: assets and liabilities at the closing rate, income and expenses at the average rate of the period (or the transaction-date rates, which the average approximates), equity at historical rates. The sum of a year's transactions each translated at its own date's rate is close to the average-rate P&L but not equal to it, and is nowhere near the closing-rate balance sheet. So the group currency in the journal (type 30, translated line by line) and the group currency of the consolidated statements are different numbers by design, and both are right.

Two ways to produce the second from the first:

- **In the ledger:** FAGL_FC_TRANS, *currency translation of balances*, translates the balances of the local currency into a target currency type at period end, per account with a rate per account type, and posts translation differences. See [Foreign currency valuation](../foreign_currency_valuation/README.md).
- **In the consolidation:** S/4HANA Finance for group reporting (or a legacy EC-CS, BPC or SEM-BCS) reads the reported data in local currency and translates it with its own methods. The delivered translation methods differ in whether they retranslate everything (Y0901: standard, year-to-date values), keep the group-currency values from the Universal Journal and retranslate only the balance sheet at the closing rate (Y0902), or work periodically (S0901, S0902, S0903).

## Translation methods and rate indicators

Group reporting ties a *currency translation attribute* on each financial statement item (or a selection) to an *exchange rate indicator* (average, closing, historical), and the indicator to an exchange rate type per version, year and period. A method is a list of such assignments plus rules for the difference:

| Account type | Rate | Difference |
|---|---|---|
| Balance sheet: assets and liabilities | closing (spot) rate at the key date | posted to the translation difference item |
| Income statement | average rate of the period, or transaction-date rates | the difference between the P&L translated at average and the net income carried into equity at closing goes to equity |
| Equity, investments, historical items | historical rate at the date of the transaction | the opening balance retranslated at the new closing rate produces the period's translation difference |

The **currency translation adjustment** (CTA) is that difference, and it is not a gain or loss of anyone: it is the arithmetic gap between rates, accumulated in other comprehensive income until the subsidiary is sold. The SAP blog *Understanding Currency Translation process in SAP S/4HANA Finance for group reporting* and the help-portal page *Currency Translation - Group Reporting* have the mechanics; the KBAs in the group reporting space (3258768 for translation errors, 3137945 for a translation key that posts with the wrong indicator, 3501827 for cross rates through a reference currency) are the tickets.

## Group valuation

Group *currency* is about which money; group *valuation* is about which price. When two company codes trade, the legal view records the invoice; the group view records the sender's cost, so that consolidated inventory and cost of sales carry no intercompany margin. In SAP the group valuation is a valuation view on a currency type (11 for the company code currency, 31 for the group currency), carried through the Material Ledger and the Universal Journal from the goods movement onwards, so that the consolidation's intercompany profit elimination is already done in the ledger for inventory. See [Material Ledger currencies](../material_ledger_currencies/README.md).

## Functional currency

IAS 21 defines an entity's functional currency as the currency of its primary economic environment, and ASC 830 does the same. It is a matter of fact, not of choice, and it is not necessarily the currency the local law requires the statutory books in. Three cases:

- **Functional = local (the normal case).** The company code currency is the functional currency; foreign currency transactions are remeasured into it (that is what [foreign currency valuation](../foreign_currency_valuation/README.md) does) and the whole entity is translated into the group currency by the rules above.
- **Functional ≠ local.** A Swiss trading subsidiary whose economics are in USD keeps CHF statutory books but has a USD functional currency. Remeasurement into USD (monetary items at closing rate, non-monetary at historical, differences in P&L) is not the same operation as translation into a presentation currency. In SAP this is modelled with a parallel currency of type 40, or a freely defined type, whose conversion settings give the functional-currency amounts, and with S/4HANA 2023's functional currency setting under UPA.
- **Hyperinflation.** IAS 29 requires restatement before translation, and SAP's index-based currency (type 50) exists for this; the Venezuelan notes (2623984, 2626145) are the recent example.

The working notes this chapter grew from have a separate document on the functional currency; see [Resources](../resources/README.md).

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| The group currency | `SCC4`; `T000` |
| Type 30 in the ledger | `FINSC_LEDGER`; `SE16N` on `ACDOCA`, `KSL` and `RKCUR` |
| Translation in the ledger | `FAGL_FC_TRANS`; `OBA1` translation accounts |
| Translation in group reporting | The group reporting configuration for exchange rate indicators and translation methods; the currency translation task's log in the data monitor |
| Group valuation in inventory | `OMX2` for type 31 or 11; a goods receipt from an affiliated company read in `FB03L` with the valuation view |
| Functional currency | `FINSC_LEDGER`, company code settings, on S/4HANA 2023 with UPA (KBA 3622052 when it is not shown) |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory. The IAS 21 and ASC 830 statements are accounting, not SAP, and were not checked against the standards' current text for this page.

## Related pages

- [Currency types](../currency_types/README.md) — type 30 and the valuation views
- [Foreign currency valuation](../foreign_currency_valuation/README.md) — FAGL_FC_TRANS and remeasurement
- [Material Ledger currencies](../material_ledger_currencies/README.md) — group valuation in inventory
- [Ledgers and their currencies](../ledgers_and_currencies/README.md) — where the group currency is configured per ledger

Back to the chapter map: [Currencies in SAP](../README.md).

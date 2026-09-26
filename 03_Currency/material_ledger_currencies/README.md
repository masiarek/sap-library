# Material Ledger: parallel currencies and valuations for inventory

**Level:** 301 · for CO-PC and ML consultants

**One line:** The Material Ledger is where inventory gets its parallel currencies and valuations: up to three currency/valuation combinations per valuation area, so the same stock can carry a legal value in the company code currency, a group value in the group currency, and a profit-center value at transfer prices.

## Why inventory needs its own ledger for a second currency

A G/L balance in a parallel currency is easy: every line item is converted at posting, and the balance is the sum. Inventory is not a sum of postings; it is a quantity times a price, and the price in a second currency is not the translation of the price in the first. A material bought in USD by a EUR company code has a EUR moving average price built from purchase after purchase at different rates, and a USD price built from the same purchases at the USD amounts. Translate the EUR price at today's rate and you get a third number that is neither. To carry inventory values in more than one currency the *material valuation* has to keep a price and a stock value per currency, and that is the Material Ledger.

In S/4HANA the Material Ledger is mandatory for material valuation (SAP Note 2396864); actual costing remains optional. So every S/4HANA system has ML currencies, whether or not anyone configured them consciously.

## Configuration

| Step | Transaction | What it does |
|---|---|---|
| Define the ML type | OMX2 | An ML type names the currency types the Material Ledger carries. It can take them from FI (the company code's currency types), from CO (the controlling area's), or be maintained manually. Type 10 is mandatory; 30 is the usual second; 31 or 32 for group or profit-center valuation. |
| Assign the ML type to the valuation area | OMX3 | Every valuation area (plant, or company code) gets an ML type. Message C+339 when more than three currency/valuation combinations are assigned (KBA 2429640); KM133 when a combination does not exist (KBA 3335505); MLCCS003 when an ML currency type is not an FI type (KBA 2426246). |
| Activate | OMX1 | Per valuation area. Once active, the currency types can no longer be added or modified (KBA 2555648): the ML records (CKMLCR, CKMLPP, MLCD …) hold prices per currency and cannot be back-filled. |
| Currency and valuation profile | 8KEM, 8KEQ, 8KEP | Brings parallel currencies and parallel *valuations* together for transfer pricing: up to three combinations, assigned to the controlling area and activated. Required for group and profit-center valuation. |

Before UPA the ceiling is three combinations, and they must be a subset of the ledger's currency types with the same valuation views; typical settings with profit-center valuation are FI 10 and 32, CO 30, and ML 10 and 32. The ML currencies of a system converted from ECC are what they were (KBA 3246781 is CKMLCT holding different types for different valuation areas after a conversion).

## Valuation views and transfer prices

The second digit of a currency type is the valuation view, and inventory is where it does its work:

| View | Meaning for a goods movement between two company codes of the group |
|---|---|
| **0 legal** | The invoice price. What each legal entity books. |
| **1 group** | The group's cost. The intercompany margin is eliminated at the moment of transfer, so consolidated inventory carries no unrealised profit. |
| **2 profit center** | An internal transfer price agreed between the profit centers, so that each profit center's margin is measured on its own terms. |

Goods receipts from affiliated companies in group valuation are posted at the sender's group cost rather than the invoice price (KBAs 2156037, 3367502, 2420690), which is how the elimination happens in the ledger itself rather than in consolidation. Currency types 11 and 31, or 12 and 32, cannot be processed completely in parallel along the value chain in every scenario; the SAP blog *Transfer prices in Material Ledger: currencies, ledgers and multiple valuations* has the implementation hints.

## Product costing in parallel currencies

A cost estimate is calculated in the company code currency and the controlling area currency, and in the ML currencies. Each currency of the cost estimate is built from the prices in that currency, not translated: a raw material price maintained in USD and a EUR standard price give a EUR cost estimate at the valuation variant's rate and a USD estimate directly. The exchange rate type is the valuation variant's (KBA 2161317). Standard price release (CK24) updates the material's price in every ML currency; a price change in MR21/MR22 must be complete in all currencies (KBA 1754054); sales order cost estimates for the group currency have their own KBA (2506193).

## Actual costing

With actual costing, the period-end run (the *actual costing cockpit*, CKMLCP; *Run Material Ledger Actual Costing* in Fiori) computes a periodic unit price per material per currency and valuation, from the actual purchase prices and the actual costs of the period. Each currency's price comes from that currency's amounts: the USD periodic unit price is the USD sum of the period's receipts divided by the quantity. The revaluation of consumption at the end of the period is posted in every ML currency, and the differences between currencies (KBA 3062950, price unit rounding between company code and group currency) are normal. Actual price calculation in parallel currencies (CKM3) is KBA 1920994.

## Under Universal Parallel Accounting

The three-combination ceiling goes: the ML currency types are the ledger's currency types, up to ten, and inventory valuation and actual costing are ledger-dependent, so an IFRS ledger and a local-GAAP ledger can carry different inventory values in the same currency as well as the same value in different currencies. See [Universal Parallel Accounting](../universal_parallel_accounting/README.md). KBA 3305451 is SAP's central KBA for the Material Ledger and collects the rest.

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| The ML type and its currency types | `OMX2`; `OMX3` for the assignment; `SE16N` on `CKMLCT` per valuation area |
| Prices per currency and valuation | `CKM3N` for a material: switch currency and valuation view |
| Currency and valuation profile | `8KEM`, `8KEQ`, `8KEP` |
| Cost estimate in each currency | `CK13N`, switch the currency; the valuation variant's exchange rate type |
| Actual costing per currency | `CKMLCP` run log; `CKM3N` period view |
| No change after activation | `OMX2` on an active valuation area: change a type and read the message (KBA 2555648) |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory.

## Related pages

- [Currency types](../currency_types/README.md) — the valuation views
- [Currencies in Controlling](../controlling_currencies/README.md) — controlling area currency and product costing
- [Currencies in the Universal Journal](../universal_journal_currencies/README.md) — where the ML currencies must be a subset
- [Group currency and translation](../group_currency_and_translation/README.md) — group valuation seen from the consolidation
- [Universal Parallel Accounting](../universal_parallel_accounting/README.md) — the ceiling removed

Back to the chapter map: [Currencies in SAP](../README.md).

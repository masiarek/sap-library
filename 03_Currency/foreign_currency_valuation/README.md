# Foreign currency valuation and translation (unrealized differences)

**Level:** 201 · for FI consultants closing a period

**One line:** At period end, open items and balances in foreign currency are restated at the closing rate; the unrealized gain or loss is posted and, depending on the valuation method, either reversed on day one or carried as a delta — realized differences are somebody else's job.

## What is valuated

Two kinds of things carry a foreign-currency value that the balance sheet has to show at the closing rate:

- **Open items** in a foreign currency on customer, vendor and open-item-managed G/L accounts. Each item is valuated individually at its own document currency amount (WRBTR) against the closing rate, and the difference to its current local amount (DMBTR, plus any earlier valuation difference) is the unrealized gain or loss. Transaction key KDF.
- **Balances** of G/L accounts in a foreign currency that are not open-item managed (a USD bank account, a USD loan): the balance per currency (from the transaction figures, i.e. the update currency buckets) is valuated as one amount. Transaction key KDB, with the exchange rate difference key on the account master.

An account with *only balances in local currency* has neither, and is skipped (KBA 3138607). Everything is posted in the local currency and in the parallel currencies, each against its own closing rate: the group currency is valuated too, and KBA 3320183 is the case where it unexpectedly is not.

## The programs and the apps

| Generation | Program / app | Notes |
|---|---|---|
| Classic G/L | SAPF100 (F.05) | Valuation by company code, reset by reversal |
| New G/L | FAGL_FC_VAL | Valuation *areas* tied to accounting principles, so each ledger group can be valuated by its own method |
| S/4HANA | FAGL_FCV, Fiori *Perform Foreign Currency Valuation* | Same configuration as FAGL_FC_VAL; the delta logic; posts to ACDOCA for all currency fields |
| S/4HANA Cloud | *Advanced Foreign Currency Valuation* | A different implementation with its own currency concept (KBA 3503527) and posting logic after clearing (KBA 3526213) |
| Translation | FAGL_FC_TRANS | Translates *balances* from the local currency into another currency; not valuation. Below. |

## Valuation methods (OB59) and valuation areas

A valuation method says *how* to valuate; a valuation area says *for which accounting principle* and therefore for which ledger group. The method's settings:

| Setting | Meaning |
|---|---|
| **Lowest value principle** | Post a difference only if it is a loss: a receivable may be written down, not up; a liability written up, not down. Prudence. |
| **Strict lowest value principle** | As above, and never write back above the last valuation in later runs either. |
| **Always valuate** | Post gains and losses alike. IFRS and US GAAP expect this. |
| **Revalue only** | Post only gains (rare; the mirror image of the lowest value principle). |
| **Reset / reverse postings** | Post the valuation on the key date and reverse it on the next day, so the next run starts again from the original amount. The classic behaviour. |
| **Delta logic** (S/4HANA and new G/L with the switch) | Do not reverse; each run posts the change since the last, and the item remembers its cumulative valuation difference (BSEG-BDIFF in classic terms). Support-content page *FAGL_FC_VAL: Delta Logic Foreign Currency Valuation*; KBAs 2312235, 3502546, 3641501. |
| **Exchange rate type** | Which rate the valuation uses: typically a dedicated closing-rate type, or M. KBAs 2443070, 3359366 and 3618871 are all "it did not use the rate I expected". |
| **Document type, posting key, exchange hedging** | Housekeeping, and the hedged-rate option (KBAs 1714718, 2561409). |

The delta logic is the S/4HANA default and the one the newer processes assume: KBA 3715580 says year-end or mid-year valuation of vendor and customer items is *not permitted* without it in some configurations, because the posting period logic of the delta valuation needs it (KBA 3310524).

## Account determination

OBA1, transaction KDF per reconciliation account (and per currency and currency type if wanted):

| Account | Role |
|---|---|
| Valuation loss / valuation gain | P&L: unrealized loss and gain |
| Balance sheet adjustment account | The other side of the valuation posting, so that the customer or vendor reconciliation account itself is never posted to directly (a reconciliation account cannot be posted manually, and the valuation is not an open item) |
| Translation loss / gain and the translation adjustment accounts | For FAGL_FC_TRANS |

For KDB, the loss and gain accounts per exchange rate difference key, and the valuated G/L account is adjusted directly or through an adjustment account depending on the configuration. KBA 1910482 is the run in which loss and gain are posted per account instead of netted, and KBA 3121140 the general account-determination question. The support-content page *Most common errors in FAGL_FC_VAL and FAGL_FCV* is the list to read before opening a ticket.

## What the program prints

One vendor item, three month-ends, reset versus delta, the lowest value principle, the realized difference on payment, and translation as distinct from valuation:

<!-- output:foreign_currency_valuation -->
*Verified output of [`foreign_currency_valuation.py`](examples/foreign_currency_valuation.py) — regenerated by `tools/run_examples.py`, never hand-typed.*

```text
1. THE OPEN ITEM AND THE RATES
   vendor invoice 10,000 USD at 0.90 = 9000.00 EUR (BSEG-DMBTR), open until April
   closing rates: 31.01 0.92, 28.02 0.88, 31.03 0.91;  paid 10.04 at 0.89
   For a liability, a higher EUR value is a loss and a lower one is a gain.

2. VALUATION WITH RESET (POST ON THE KEY DATE, REVERSE ON THE NEXT DAY)
   Each run compares the closing value with the ORIGINAL amount, because the previous
   valuation was reversed on the first day of the period.
   key date   closing value   vs original   posting on key date            reversed on
   31.01        9200.00 EUR     +200.00     unrealized loss   200.00 EUR   next day
   28.02        8800.00 EUR     -200.00     unrealized gain   200.00 EUR   next day
   31.03        9100.00 EUR     +100.00     unrealized loss   100.00 EUR   next day
   Accounts (OBA1, transaction KDF for the reconciliation account): the P&L side goes to
   the unrealized loss / gain account, the balance-sheet side to the adjustment account,
   so the vendor account itself is never touched.

3. VALUATION WITH DELTA LOGIC (NO REVERSAL; POST ONLY THE CHANGE)
   Each run compares the closing value with the LAST VALUATED amount; the item keeps a
   running valuation difference (BSEG-BDIFF in classic terms).
   key date   closing value   last valued   delta posted   cumulative BDIFF
   31.01        9200.00 EUR     9000.00       +200.00        +200.00
   28.02        8800.00 EUR     9200.00       -400.00        -200.00
   31.03        9100.00 EUR     8800.00       +300.00        +100.00
   Same balance-sheet value at every key date as in section 2; fewer postings, and the
   difference stays on the item until it is cleared.

4. THE LOWEST VALUE PRINCIPLE: ONLY VALUATE IN THE DIRECTION OF PRUDENCE
   For a liability, 'lowest value' means: post the loss, never the gain (the liability
   may go up in the books, not down). 'Always valuate' posts both directions.
   key date   diff vs original   always valuate   lowest value principle
   31.01        +200.00            +200.00           +200.00
   28.02        -200.00            -200.00                +0
   31.03        +100.00            +100.00           +100.00
   'Strict lowest value' adds: once written up, do not write back down below the
   original in later runs either. 'Revalue only' is the mirror for assets.

5. PAYMENT ON 10.04 AT 0.89: THE REALIZED DIFFERENCE, AND THE LIFETIME P&L
   paid 8900.00 EUR for an item booked at 9000.00 EUR: realized gain 100.00 EUR
   Under reset, the March valuation was already reversed on 01.04, so the realized line
   is the whole story: -100.00 EUR gain to the realized gain account (KDF).
   Under delta logic, the item still carries BDIFF +100.00 from March; clearing reverses
   that (+100.00 back out of unrealized) and posts the realized -100.00.
   lifetime P&L, any method:  payment - original = 8900.00 - 9000.00 = -100.00 EUR

6. TRANSLATION IS NOT VALUATION
   Valuation restates ITEMS in a foreign currency into the local currency (FAGL_FC_VAL).
   Translation restates whole BALANCES from the local currency into another currency
   (FAGL_FC_TRANS, or the group's consolidation), with different rates per account type:
     liability 9100.00 EUR at closing rate 1.12 = 10192.00 USD group currency
     expense   9000.00 EUR at average rate 1.08 = 9720.00 USD group currency
   The two rates leave a gap that is not anyone's gain or loss: the translation difference,
   which goes to equity (the currency translation adjustment).
```
<!-- /output -->

Run it yourself from the folder that holds it:

```bash
cd 03_Currency/foreign_currency_valuation/examples
python3 foreign_currency_valuation.py
```

## Translation: FAGL_FC_TRANS

Valuation restates *items* from their document currency into the local currency. Translation restates *balances* from the local currency into another currency, typically the group currency, for a subsidiary whose books are in a currency other than the group's. FAGL_FC_TRANS does it per account with a rate per account type, the way IAS 21 prescribes: closing rate for balance sheet accounts, average rate for P&L, historical rates for equity, and the difference between them goes to a translation adjustment account in equity. It reads the *source currency type* configured for the target currency (KBA 3154025), uses KDF-style accounts from OBA1 (KBA 3582037 is the message when they are missing), and can be reset (KBA 2059254 explains why a reset does not always post). In a group that consolidates in S/4HANA group reporting, the consolidation's own currency translation does the same job on the group side; see [Group currency and translation](../group_currency_and_translation/README.md).

There is also an older tool, EWCT, for translating balances into another currency for reporting (support-content page *About foreign currency translation tool (EWCT)*), with its own rate handling (KBAs 2441607, 2720369).

## Ledger-specific valuation

With parallel ledgers, IFRS and local GAAP can valuate differently: *always valuate* for the IFRS ledger group and *lowest value* for the local one. Each valuation area is tied to an accounting principle, the accounting principle to a ledger group, and FAGL_FC_VAL posts each area to its ledger group only. The GR/IR account is the awkward case, because it is open-item managed and usually has *only balances in local currency*; the support-content page *Foreign Currency Valuation for WRX GRIR Clearing Account* and KBAs 3018485 and 3691303 cover what can and cannot be valuated there.

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Valuation methods and their settings | `OB59`; `SE16N` on `T044A` |
| Valuation areas and accounting principles | IMG *Define Valuation Areas* and *Assign Valuation Areas and Accounting Principles*; `FINSC_LEDGER` for the ledger group behind the principle |
| Account determination | `OBA1`, KDF (valuation loss and gain, balance sheet adjustment) and KDB |
| The rate the run used | The method's rate type in `OB59`, the `OB08` row for the key date, and the run's log |
| Reset versus delta | The reversal document on key date + 1 after a run with reset, or its absence with delta logic; the item's cumulative difference (`BSEG-BDIFF`) |
| Translation is a different program | `FAGL_FC_TRANS`; `OBA1` translation accounts |
| Skipped accounts | `FS03`, *Only balances in local currency*, then a test run of `FAGL_FC_VAL` or `FAGL_FCV` on that account |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory. The Fiori app names are given as they appear in the help portal; the app IDs are not quoted because they were not verified.

## Related pages

- [Exchange rates](../exchange_rates/README.md) — closing rate types and the translation date
- [Exchange rate differences on clearing](../exchange_rate_differences_on_clearing/README.md) — the realized side
- [Ledgers and their currencies](../ledgers_and_currencies/README.md) — valuation areas, accounting principles and ledger groups
- [Group currency and translation](../group_currency_and_translation/README.md) — translation into the group currency

Back to the chapter map: [Currencies in SAP](../README.md).

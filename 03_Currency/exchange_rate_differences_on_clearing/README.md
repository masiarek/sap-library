# Exchange rate differences on clearing (realized gains and losses)

**Level:** 201 · for FI consultants and accountants

**One line:** When an open item posted at one rate is cleared at another, the local-currency amounts no longer net to zero, and the system posts the gap automatically to the accounts in OBA1 — realized, because the cash has moved.

## Realized versus unrealized

An item in a foreign currency has a local-currency value that is only ever provisional until it is settled. Two processes deal with that:

| | Realized difference | Unrealized difference |
|---|---|---|
| When | At clearing: payment, offsetting, write-off | At period end, on items still open |
| Trigger | F-28, F-53, F-03, F110, F.13, bank statement processing, the Fiori clearing apps | FAGL_FC_VAL / FAGL_FCV, *Perform Foreign Currency Valuation* |
| What is compared | The local amount of the item when posted vs. the local amount of what cleared it | The local amount of the item when posted vs. its value at the closing rate |
| Accounts | OBA1, KDF (open items) or KDB (G/L balances): *realized* gain and loss accounts | OBA1, KDF or KDB: *unrealized* gain and loss accounts plus the balance sheet adjustment account |
| Reversed? | Never | Depending on the method: reversed the next day, or kept as a delta |

This page is the left column. [Foreign currency valuation](../foreign_currency_valuation/README.md) is the right one.

## Where the difference comes from

A vendor invoice for 1,000 USD posted at 0.90 is a liability of 900 EUR. The payment of 1,000 USD leaves the bank at 0.92, which is 920 EUR. The vendor account is cleared: 1,000 USD against 1,000 USD, zero in document currency. In local currency the vendor line says −900 and the payment says +920, and a document has to balance in every currency, so the system adds a third line: 20 EUR to the realized exchange rate loss account, with zero USD. That line is the *exchange rate difference*, and it is created without anyone entering it.

Everything else on the page is variation on that: which account, which currency the difference line is in, what happens when the amounts differ in document currency too, and the two configuration switches that stop it.

## Account determination: OBA1

OBA1 (*Automatic postings: exchange rate differences*) holds, per chart of accounts:

| Transaction key | Used for | What is configured |
|---|---|---|
| **KDF** | Open items on customer, vendor and open-item-managed G/L accounts | Per reconciliation account (or per G/L account) and optionally per currency and currency type: realized loss, realized gain, valuation loss, valuation gain, balance sheet adjustment account, and the translation accounts |
| **KDB** | G/L accounts without open item management, valuated by balance | Per exchange rate difference key (SKB1-KDFSL, an entry on the account master): loss and gain accounts |
| **KDW** | Loss from valuation with the (old) *write-down* method | rarely used |
| **KDZ** | Exchange rate differences from transfer postings (regrouping) | |
| **RDF** | Rounding differences | not an exchange rate difference, but often confused with one |

KBA 1523296 explains the sequence in which FAGL_FC_VAL and SAPF100 read KDB versus KDF, and the help-portal page *Account determination in SAPF100, FAGL_FC_VAL and FAGL_FCV* has the decision tree. The difference from a clearing always uses KDF, keyed by the reconciliation account of the item (for customers and vendors) or the G/L account itself, with the *currency* and *currency type* columns allowing a different account for, say, differences in the group currency.

## The update currency of the difference line

The difference line's own currency pair (PSWSL / PSWBT) is decided by the *only balances in local currency* indicator of the **difference account**, and the currency it takes when the indicator is off is the document currency of the item being cleared, not of the clearing document:

```abap
IF skb1-xsalh = space.
  bseg-pswsl = kdbtab-waers.   " currency of the open item
ELSE.
  bseg-pswsl = t001-waers.
ENDIF.
```

This is FORM KDFTAB_ABARBEITEN in SAPMF05A; see [Update currency](../update_currency_pswsl/README.md). In practice the realized gain and loss accounts are set up with the indicator, so the difference line updates the local-currency bucket and the P&L account never grows a USD balance.

## Partial payments, residual items and cash discount

The clearing screen offers three ways to settle an item for less than its full amount, and each treats the rate difference differently:

- **Partial payment** leaves the original item open and posts the payment as a new open item referencing it. No clearing happens, so no realized difference is posted yet; the whole difference comes when the two are cleared together later.
- **Residual item** clears the original and creates a new open item for the remainder. The cleared part realizes its difference now; the residual item is posted at the current rate and carries the rest.
- **Charge off difference** clears the original and writes the remainder to an account chosen on the screen (a reason code in OBXL, or a manual account). The exchange rate difference on the *cleared* amount is still computed and posted separately; the charged-off amount is a different posting.
- **Cash discount** taken on a foreign-currency item is computed in document currency and translated at the clearing rate; the rate difference on the net amount is posted as usual, which is why a discount can produce a difference line even when the payment rate equals the invoice rate.

The [SKB1-XSALH page](../only_balances_in_local_currency/README.md) has the worked JPY example in which a residual item of 1,000 JPY appears on the *Res. items* tab.

## The two switches that prevent a difference

- **SKB1-XSALH on the G/L account.** The item was only ever remembered in local currency, so there is nothing to revalue. For open-item accounts it means clearing succeeds whenever the local amounts match.
- **T001-XSLTA on the company code** (*No forex rate diff. when clearing in LC*, OBY6). A clearing *entered in local currency* takes the foreign items at their original local amounts. The account keeps its per-currency balance; only the recalculation at clearing is switched off. KBA 2249505 defines the scope precisely, and KBA 3619218 describes the same switch in S/4HANA Cloud.

Message F5263 is what a clearing says when the difference exceeds the tolerance and none of these applies; KBA 2220851 has the flowchart, and the guided answer in KBA 2560929 walks a support consultant through the causes. KBA 2547111 is the ticket "unexplained exchange rate difference": usually a translation date or an OB08 row that was not the one assumed.

## Parallel currencies

A document balances in every currency field, so the same clearing can produce a difference in the second local currency and none in the first (a EUR invoice paid in EUR in a EUR company code with a USD group currency: zero difference in DMBTR, a difference in DMBE2 if the group rate moved), or differences of opposite sign in the two. The KDF account determination has the *currency type* column for exactly this, and in the Universal Journal the accounting interface produces the difference for every configured currency, including the freely defined ones (the *open item management* row is fully supported in SAP Note 2344012's matrix). See [Currencies in the Universal Journal](../universal_journal_currencies/README.md).

## Resetting a clearing

A realized difference is a real posting, so undoing the clearing (FBRA) must undo it: *only resetting* is refused when a difference was posted (KBA 1796941, and 3677911 for the Fiori *Reset Cleared Items* app), and *reset and reverse* reverses the clearing document, difference line included. This is the same rule that keeps the update currency consistent; see [Update currency](../update_currency_pswsl/README.md).

## Bank statement processing

Automatic clearing from the electronic bank statement (FEBAN, the *Reprocess Bank Statement Items* app) posts differences with the same account determination, and the rate on the bank statement item is the rate the bank actually applied, which is the one the realized difference should reflect. KBA 1920513 covers the assignment case. What the bank charged in fees and spread is a separate matter: see [Payments and currency management](../payments_and_currency_management/README.md).

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Account determination | `OBA1`, transaction keys KDF and KDB; `SE16N` on `T030H` (KDF) and `T030` (KDB) |
| The exchange rate difference key of a G/L account | `FS03`, *Control data*, exchange rate difference key; `SKB1-KDFSL` |
| The difference line | `FB03` on a clearing document: the line with a zero document-currency amount and a non-zero local amount |
| Clearing tolerances | `OBA4` (employee tolerance groups) and `OBA3` (customer/vendor tolerance groups); exceed them and read the message |
| The company code switch and its scope | `OBY6`, `T001-XSLTA`; clear the same items once in local and once in document currency |
| A reset must reverse the difference | `FBRA` on a clearing that posted a difference; read the message (KBA 1796941) |
| Differences in the parallel currencies | `FB03L` on the clearing document, switching the currency display |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory.

## Related pages

- [Update currency](../update_currency_pswsl/README.md) — why the difference line's PSWSL follows the open item
- ["Only manage balances in local currency"](../only_balances_in_local_currency/README.md) — the worked 1,000 JPY example
- [Foreign currency valuation](../foreign_currency_valuation/README.md) — the unrealized side
- [Exchange rates](../exchange_rates/README.md) — the two rates on two dates

Back to the chapter map: [Currencies in SAP](../README.md).

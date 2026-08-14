# Payments and clearing

The automatic payment program (F110), automatic clearing (F.13), and the master data and configuration that govern which direction cash is allowed to move — plus the intercompany case, where those rules stop being academic.

Read in order; each page assumes the one before it.

| # | Page | What it answers |
| :-- | :-- | :-- |
| 1 | [How F110 knows a payment is debit or credit](f110_debit_vs_credit.md) | Where the debit/credit sign lives, why a payment line is always the mirror of the item it clears, the four-way matrix of balance × payment-method direction, and why a net debit vendor group is never paid. |
| 2 | [Intercompany settlement, worked end to end](intercompany_settlement_worked_example.md) | Two company codes, four subledger accounts, one month of trade. Three settlement models, how each side clears, and what to do when the balance lands where no payment run can reach it. |
| 3 | [Why intercompany reconciliation is hard](intercompany_reconciliation_why_hard.md) | The structural reasons the two sides drift — no common key, no single owner, currency, cash in transit — and the controls that actually reduce the pile. |

## The through-line

The three pages are one argument:

- **The sign is data.** `BSEG-SHKZG` is stamped by the posting key at posting time. Programs read it; they never derive it.
- **Direction is data *and* configuration.** The net balance says what is owed; the payment method says what the program is permitted to do about it. Both gates must open.
- **Intercompany is the same rules, doubled.** Every transaction posts twice, in mirror. Settlement keeps the mirrors moving together; reconciliation proves they still match.
- **The hard part is upstream.** By the time an item reaches a reconciliation, most of what decides whether it will match has already been determined at posting.

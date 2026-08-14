# 01_FI — Financial Accounting

Pages on FI proper: the subledgers, what posts into them, and the programs that clear them out again.

## Payments

| Page | What it answers |
| :-- | :-- |
| [How F110 knows a payment is debit or credit](payments/f110_debit_vs_credit.md) | Where the debit/credit sign actually lives, how the payment program groups and nets open items, why a net debit vendor group is never paid, and why an intercompany run can't collect from the other company code when vendor/customer clearing is off. |

## Recurring themes across these pages

- **The subledger sign is data, not logic.** `BSEG-SHKZG` is set by the posting key when the document is posted. Programs read it; they don't derive it.
- **Direction is half data, half configuration.** What the balance is, and what the payment method is *allowed* to do, are separate gates — and the configuration gate is usually the stronger argument in an audit conversation.
- **"Clearing job" is ambiguous.** F110 moves cash; F.13 only matches. Half the confusing questions in this area come from the two being called the same thing.

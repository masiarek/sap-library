# Glossary

Field names, abbreviations, and terms that carry a specific meaning in SAP FI. Entries are deliberately short — each links to the page that works it through properly, so no definition here dead-ends.

## Fields and tables

| Term | Meaning | Worked through in |
| :-- | :-- | :-- |
| `BSEG-SHKZG` | Debit/credit indicator on a line item. `S` (Soll) = debit, `H` (Haben) = credit. Amounts are stored unsigned; this field carries the sign. | [F110 debit vs credit](01_FI/payments/f110_debit_vs_credit.md) |
| `BSEG-BSCHL` | Posting key. Determines the account type and, with it, the debit/credit indicator at the moment of posting. | [F110 debit vs credit](01_FI/payments/f110_debit_vs_credit.md) |
| `BSEG-REBZG` | Invoice reference on a credit memo. A referenced credit memo is always netted with the invoice it points at. | [F110 debit vs credit](01_FI/payments/f110_debit_vs_credit.md) |
| `BSIK` / `BSID` | Open items — vendors and customers respectively. F110's selection reads these. | [F110 debit vs credit](01_FI/payments/f110_debit_vs_credit.md) |
| `LFB1-XVERR` / `KNB1-XVERR` | *Clearing with customer* / *Clearing with vendor*, in the **company-code** segment. Both, plus the master links, are required before AP and AR can be netted. | [F110 debit vs credit §5](01_FI/payments/f110_debit_vs_credit.md) |
| `LFA1-KUNNR` / `KNA1-LIFNR` | The cross-links pairing a vendor with a customer. Necessary but not sufficient for netting — the `XVERR` flags are the other half. | [F110 debit vs credit §5](01_FI/payments/f110_debit_vs_credit.md) |
| `LFB1-GRUPP` | Payment grouping key. Shapes how open items are gathered into one payment. | [F110 debit vs credit §2](01_FI/payments/f110_debit_vs_credit.md) |
| `LFB1-XPORE` | *Individual payment* — forces one payment per item instead of a netted group. | [F110 debit vs credit §2](01_FI/payments/f110_debit_vs_credit.md) |

## Transactions

| Code | What it is | Worked through in |
| :-- | :-- | :-- |
| `F110` | Automatic payment program. Groups open items, nets them, and pays groups whose net sign matches the payment method's direction. | [F110 debit vs credit](01_FI/payments/f110_debit_vs_credit.md) |
| `F.13` | Automatic clearing. Matches debits against credits on an account; posts **no** cash. Frequently confused with F110. | [F110 debit vs credit §7](01_FI/payments/f110_debit_vs_credit.md) |
| `FBZP` | Payment program configuration — paying company codes, payment methods (including the outgoing/incoming direction), bank determination. | [F110 debit vs credit §4](01_FI/payments/f110_debit_vs_credit.md) |
| `OBYA` | Cross-company-code clearing accounts — the due-to/due-from pair used when one company code pays on behalf of another. | [F110 debit vs credit §8](01_FI/payments/f110_debit_vs_credit.md) |
| `F-44` / `F-32` | Manual clearing, vendor and customer. Their *other account* selection honours the same `XVERR` flags F110 does. | [F110 debit vs credit §5](01_FI/payments/f110_debit_vs_credit.md) |

## Terms

| Term | Meaning | Worked through in |
| :-- | :-- | :-- |
| **Unusual balance** | A subledger account sitting on the side it normally isn't: a vendor in debit, a customer in credit. Usually a signal, not an error. | [F110 debit vs credit §1](01_FI/payments/f110_debit_vs_credit.md) |
| **Open item** | A posted line not yet cleared. Everything on this page's subject operates on these. | [F110 debit vs credit](01_FI/payments/f110_debit_vs_credit.md) |
| **IC vendor / IC customer** | The mirrored subledger accounts two company codes carry to represent each other. | [F110 debit vs credit §6](01_FI/payments/f110_debit_vs_credit.md) |
| **Payment proposal** | F110's dry run — the groups it intends to pay, plus an exception line per group it won't. The exception log is the primary evidence for "the job could not have done that". | [F110 debit vs credit §3](01_FI/payments/f110_debit_vs_credit.md) |

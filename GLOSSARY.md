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

## Intercompany

| Term | Meaning | Worked through in |
| :-- | :-- | :-- |
| `BSEG-VBUND` | **Trading partner** — the company ID of the counterparty, defaulted from the customer/vendor master. What group consolidation uses to eliminate intercompany balances. Can be wrong while FI still reconciles. | [Why IC recon is hard §9](01_FI/payments/intercompany_reconciliation_why_hard.md) |
| `BKPF-BVORG` | Cross-company-code transaction number — links the two document numbers a cross-company posting creates. | [IC settlement, Model C](01_FI/payments/intercompany_settlement_worked_example.md) |
| `BKPF-XBLNR` | Reference field. In intercompany, the practical place to carry the counterpart's document number — the key document-level matching depends on. | [Why IC recon is hard §3](01_FI/payments/intercompany_reconciliation_why_hard.md) |
| `BSEG-ZUONR` | Assignment. Populated by the sort key; the other candidate common key for automatic matching. | [Why IC recon is hard §3](01_FI/payments/intercompany_reconciliation_why_hard.md) |
| **IC vendor / IC customer** | The mirrored pair of subledger accounts each company code carries for a partner — payable and receivable sides kept separate. | [IC settlement, worked](01_FI/payments/intercompany_settlement_worked_example.md) |
| **Gross / netted / central settlement** | The three models by which two company codes settle: each pays its own IC vendor; one nets AP against AR and pays the difference; or one pays on behalf of the other with no cash crossing at all. | [IC settlement, worked](01_FI/payments/intercompany_settlement_worked_example.md) |
| **Cash in transit** | Payer has cleared, receiver has not — a structural, permanent reconciling category, not an exception. | [Why IC recon is hard §5](01_FI/payments/intercompany_reconciliation_why_hard.md) |
| **ICR / ICMR** | Intercompany reconciliation tooling — the ECC components (`FBICS3` → `FBICA3` → `FBICR3`) and S/4HANA's Intercompany Matching and Reconciliation. Verify what is activated in your own landscape. | [Why IC recon is hard](01_FI/payments/intercompany_reconciliation_why_hard.md) |
| **Residual item vs partial payment** | Clearing with a residual creates a *new* document, breaking the link to the counterpart; a partial payment leaves the original open. Prefer the latter on IC accounts. | [Why IC recon is hard §7](01_FI/payments/intercompany_reconciliation_why_hard.md) |

## Document types and numbering

| Term | Meaning | Worked through in |
| :-- | :-- | :-- |
| `BKPF-BLART` | Document type — two characters, client-level, configured in `OBA7` and stored in `T003`. Controls permitted account types, required fields, reversal type, authorization, and *which number range key* is used. | [Document types and number ranges](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) |
| `T003-NUMKR` | The number range **key** carried by a document type — a pointer, not an interval. | [Part 1](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) |
| `RF_BELEG` | Number range object for FI documents. Intervals are maintained in `FBN1` **per company code and per fiscal year**. Conventionally unbuffered, because several jurisdictions expect gapless numbering. | [Part 1](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) |
| `RV_BELEG` | Number range object for SD billing documents. Has **no year dimension** — the difference from `RF_BELEG` is the source of the SD/FI numbering conflict. | [Part 2](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) |
| `NRIV` | Table holding number range intervals, including the current number. | [Part 1](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) |
| **Year `9999`** | On an FI interval, means year-independent — one continuous sequence across all years. A real year means the numbering restarts annually. | [Part 1](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) |
| **External assignment** | The interval's *Ext* flag: the calling application supplies the number and SAP only validates the range. What makes SD=FI number identity possible — and what rules out a year-dependent restart. | [Part 2](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) |
| `RV` | The FI document type created from an SD billing document. | [Part 2](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) |
| `BKPF-AWTYP` / `AWKEY` | Reference transaction and key — the audit link from an FI document back to its originating document (`VBRK` for SD billing). The alternative to number identity. | [Part 2](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) |
| **FEC** | France's *Fichier des Écritures Comptables* — the audit file that puts **accounting entry** numbering in scope, unlike most European rules which address the invoice number. | [Part 3](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) |

## Interface numbering

| Term | Meaning | Worked through in |
| :-- | :-- | :-- |
| **Idempotency (posting)** | The property that re-sending the same source document cannot create a second accounting document. Under external assignment the database key enforces it; under internal assignment it must be built. | [Inbound interface numbering](01_FI/document_types_and_number_ranges/inbound_interface_numbering.md) |
| **Document type authorization group** | The field on `T003` that makes a document type impossible to post manually. The only control for "nothing stops users doing this later" that doesn't rely on convention. | [Inbound interface numbering](01_FI/document_types_and_number_ranges/inbound_interface_numbering.md) |
| **Number range register** | A landscape-wide record of range keys, their owning process, assignment mode and intervals. Since intervals live in each system's own `NRIV`, this — not configuration — is what reserves a key across systems. | [Inbound interface numbering](01_FI/document_types_and_number_ranges/inbound_interface_numbering.md) |

## AR patterns

| Term | Meaning | Worked through in |
| :-- | :-- | :-- |
| **AR Full** | A system running receivables **with** SD — typically several of them across a landscape. Invoices are billing documents, the FI document type is `RV`, and SD = FI number identity is available. | [Document types and number ranges, Part 2](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) |
| **AR Lite** | One central system running receivables **without** SD. Invoices originate upstream and arrive by interface; there is no billing document, no `RV`, and no document flow — so the source key must be carried deliberately. | [Worked decision: inbound AR interface](01_FI/document_types_and_number_ranges/case_inbound_ar_interface.md) |

## Exchange rates

| Term | Meaning | Worked through in |
| :-- | :-- | :-- |
| `TCURR` | Exchange rates, keyed by rate type, from-currency, to-currency and valid-from date. No valid-to: an entry is in force until a later one exists, however long that takes. | [How a posting picks its rate §2](01_FI/exchange_rates/how_a_posting_picks_its_rate.md) |
| `TCURR-GDATU` | Valid-from date stored **inverted** (`99999999` − `YYYYMMDD`), so that "latest entry on or before a date" is one ascending index read. | [How a posting picks its rate §2](01_FI/exchange_rates/how_a_posting_picks_its_rate.md) |
| `TCURR-UKURS` | The rate. **Negative = indirect quotation**, not a negative price. `BKPF-KURSF` uses the same convention. | [How a posting picks its rate §2](01_FI/exchange_rates/how_a_posting_picks_its_rate.md) |
| `TCURF` | Translation ratios (1 : 1, 100 : 1). The ratio fields in `TCURR` itself can be empty; read ratios here or from the standard lookup. | [How a posting picks its rate §2](01_FI/exchange_rates/how_a_posting_picks_its_rate.md) |
| `TCURV-BWAER` | Reference currency of a rate type. When set, rates exist only against it and every other pair is a calculated cross rate. | [How a posting picks its rate §4](01_FI/exchange_rates/how_a_posting_picks_its_rate.md) |
| `T003-KURST` | Exchange rate type of a document type. Empty means `M`. | [How a posting picks its rate §1](01_FI/exchange_rates/how_a_posting_picks_its_rate.md) |
| `BKPF-WWERT` | Translation date — the date the rate is read for. Defaults to the posting date, not the document date. | [How a posting picks its rate §1](01_FI/exchange_rates/how_a_posting_picks_its_rate.md) |
| `BKPF-KURSF` | The rate the document was translated with. Compare it with the table rate for `WWERT` to find documents posted before a late rate load. | [Rate check report, view 3](01_FI/exchange_rates/exchange_rate_check_report.md) |
| Cross rate | A rate between two currencies calculated from each one's rate against a reference currency. As stale as its older leg. | [Rate check report](01_FI/exchange_rates/exchange_rate_check_report.md) |
| `OB08` / `OBBS` / `OB07` | Maintain rates · translation ratios · rate types (reference currency, inversion). | [How a posting picks its rate](01_FI/exchange_rates/how_a_posting_picks_its_rate.md) |

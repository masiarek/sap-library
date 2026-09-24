# 01_FI — Financial Accounting

Pages on FI proper: the subledgers, what posts into them, the numbering that identifies what posted, and the programs that clear it all out again.

## [Payments and clearing](payments/README.md)

| Page | What it answers |
| :-- | :-- |
| [How F110 knows a payment is debit or credit](payments/f110_debit_vs_credit.md) | Where the debit/credit sign actually lives, how the payment program groups and nets open items, and why a net debit vendor group is never paid. |
| [Intercompany settlement, worked end to end](payments/intercompany_settlement_worked_example.md) | Two company codes and four accounts, followed from the first invoice to a reconciled balance. |
| [Why intercompany reconciliation is hard](payments/intercompany_reconciliation_why_hard.md) | Why the two sides drift, and what actually reduces the pile. |

## [Document types and number ranges](document_types_and_number_ranges/README.md)

| Page | What it answers |
| :-- | :-- |
| [Document types and number ranges](document_types_and_number_ranges/document_types_and_number_ranges.md) | What a document type governs, how intervals resolve per company code and year, the SD-FI `RV` document, and the collision between year-dependent FI ranges and SD number identity. |
| [Numbering design for an inbound interface](document_types_and_number_ranges/inbound_interface_numbering.md) | Dedicated document type or reuse; one type or two; internal or external assignment — and why a range register, not configuration, is what prevents cross-system collisions. |
| [Worked decision: numbering for an inbound AR interface](document_types_and_number_ranges/case_inbound_ar_interface.md) | The same framework argued to a recommendation on a real design question, anonymized. |

## [Exchange rates](exchange_rates/README.md)

| Page | What it answers |
| :-- | :-- |
| [How a posting picks its exchange rate](exchange_rates/how_a_posting_picks_its_rate.md) | Pair, rate type, translation date and table; the inverted date in `TCURR`; why no rate is ever too old; and why a rate type with a reference currency ignores the pair you maintained. |
| [A report that shows which rate a posting would get](exchange_rates/exchange_rate_check_report.md) | A read-only ABAP report: rates on a key date with their age, history with gaps, posted documents against the table rate. |
| [Test scenarios for foreign currency postings from an interface](exchange_rates/testing_foreign_currency_postings.md) | Same amount in two months, month boundary, rounding, missing rate, month not loaded — with reference rates that make the expected cent unambiguous. |

## [Posting keys](posting_keys/README.md)

| Page | What it answers |
| :-- | :-- |
| [Comparing posting keys between clients](posting_keys/comparing_posting_keys_between_clients.md) | Where `OB41` stores a posting key and why its field status is two character strings; `SCMP` and a download against a read-only report that lists Profit Center and Business Area as required / optional / suppressed per posting key, looking the positions up itself; and what else decides whether the field is required. |

## Recurring themes across these pages

- **The subledger sign is data, not logic.** `BSEG-SHKZG` is set by the posting key when the document is posted. Programs read it; they don't derive it.
- **Direction is half data, half configuration.** What the balance is, and what the payment method is *allowed* to do, are separate gates — and the configuration gate is usually the stronger argument in an audit conversation.
- **Global object, local behaviour.** A document type is defined once for the client; its number range intervals are per company code and per fiscal year. Most multi-country numbering problems are solved at the interval, not by minting new document types.
- **"Clearing job" is ambiguous.** F110 moves cash; F.13 only matches. Half the confusing questions in this area come from the two being called the same thing.
- **Existence is checked, currency is not.** The rate lookup takes the latest entry on or before the translation date and never asks how old it is. A late monthly load, or a test system with one ancient rate, produces documents — just not the ones you expected.
- **A posting key is a row per client, and its field status is a string.** `TBSL` carries the client in its key, and the suppressed/required/optional choices live as one character per field in `FAUS1`/`FAUS2`. A table comparison sees the string as one field; only decoding a position says whether the profit center is what changed.
- **Intercompany doubles everything.** Two books, two documents, one economic fact. Most intercompany pain is the cost of keeping those two views equal.

# SAP Library

<!-- --8<-- [start:hero] -->
Working notes on SAP, written as pages rather than as chat history.

The rule this library is built on: **an answer that only exists in a Teams thread gets asked again next quarter.** So when a question is worth answering properly — the mechanism, not just the verdict — it gets a page here, with the fields, tables and transactions that let the next person verify it themselves instead of taking anyone's word for it.

Published as a searchable site: **<https://masiarek.github.io/sap-library/>**
<!-- --8<-- [end:hero] -->

<!-- --8<-- [start:below-hero] -->

## Start here

| Area | What's in it |
| :-- | :-- |
| [01_FI — Financial Accounting](01_FI/README.md) | Payments and clearing · document types and number ranges · exchange rates · posting keys |
| [02_Master_Data — Master data](02_Master_Data/README.md) | Addresses: the postal code check per country |

### Payments, clearing and intercompany

A three-page sequence, in reading order:

1. [How F110 knows a payment is debit or credit](01_FI/payments/f110_debit_vs_credit.md) — the sign is stamped on the line item, not derived by the program; a payment line is always the mirror of the item it clears; and a net debit vendor group is never paid, whatever payment methods exist.
2. [Intercompany settlement, worked end to end](01_FI/payments/intercompany_settlement_worked_example.md) — two company codes, four subledger accounts, one month of trade; gross vs netted vs central settlement; and the stranded balance that neither payment run can act on.
3. [Why intercompany reconciliation is hard](01_FI/payments/intercompany_reconciliation_why_hard.md) — no common key, no single owner, currency, cash in transit, and the ten controls that actually reduce the pile.

### Document types and number ranges

- [Numbering design for an inbound interface](01_FI/document_types_and_number_ranges/inbound_interface_numbering.md) — when an external system posts accounting documents into SAP: dedicated document type or reuse, one type or two, internal or external assignment. Includes the two reframings that usually settle the argument — the sending system transmits its number under *either* mode, and database-rejected duplicates are the feature, not the drawback.
- [Worked decision: numbering for an inbound AR interface](01_FI/document_types_and_number_ranges/case_inbound_ar_interface.md) — the framework argued through to a recommendation on a real question: a legacy system posting customer documents into S/4, in a landscape already burnt once by an uncoordinated range reuse. Anonymized.
- [Document types and number ranges](01_FI/document_types_and_number_ranges/document_types_and_number_ranges.md) — what a document type governs versus what its number range does; how intervals resolve **per company code and per fiscal year**; the SD-FI interface and the `RV` document; and why a year-dependent FI range and an SD=FI number identity cannot both exist. Includes the distinction that saves the most wasted effort: European numbering statutes almost always name the *invoice* number, which is SD's, not the FI accounting document number.

### Exchange rates

- [How a posting picks its exchange rate](01_FI/exchange_rates/how_a_posting_picks_its_rate.md) — the latest `TCURR` entry on or before the translation date, however old; the inverted date; and the rate type with a reference currency, which reads `EUR → USD` and `CAD → USD` and ignores the `EUR → CAD` you maintained.
- [A report that shows which rate a posting would get](01_FI/exchange_rates/exchange_rate_check_report.md) — read-only ABAP, built on the standard lookup: rates on a key date with their age, history with gaps, posted documents against the table rate. Includes the five assumptions its first runs proved wrong.
- [Test scenarios for foreign currency postings from an interface](01_FI/exchange_rates/testing_foreign_currency_postings.md) — the same amount in two months, the month boundary, rounding both ways, the missing rate, and the month that is not loaded yet. Anonymized.

### Posting keys

- [Comparing posting keys between clients](01_FI/posting_keys/comparing_posting_keys_between_clients.md) — `OB41` is one row of `TBSL` per client, and the field status is two strings with one character per field; `SCMP` says *that* the string differs, and only decoding a position says whether it is the profit center. Three routes compared, a read-only report that lists two chosen fields as required / optional / suppressed per posting key and looks their positions up in the field-selection definition itself, and the other three inputs that decide whether Profit Center and Business Area are required.

### Addresses

- [Postal code checks per country](02_Master_Data/addresses/postal_code_checks.md) — two fields in `T005` and nine rules; why *"4 digits or `A9999AAA`"* has no exact setting; a five-country request worked through, with what each setting also lets through; the SAP Notes on the subject; and why a stricter rule surfaces months later, on somebody else's save.

## How these pages are written

Four conventions, in priority order — the reasoning is in [CONTRIBUTING.md](CONTRIBUTING.md):

1. **Mechanism over verdict.** "It won't do that" is worth little; "it can't, because the selection set never contains those items" is worth keeping.
2. **Every claim gets a verification path** — the table, field, or transaction where the reader confirms it in their own system.
3. **Provenance is stated.** A page written from experience says so; a page confirmed against a named system names the system and the date. The two are not the same evidence and are never presented as if they were.
4. **No message numbers from memory.** Release-dependent text is read from the system, not quoted from a page.

## Glossary

Field names, abbreviations and the terms that mean something specific in FI: [GLOSSARY.md](GLOSSARY.md).
<!-- --8<-- [end:below-hero] -->

# Document types and number ranges

What a document type governs, how a number range interval is actually resolved, and the two places that design gets contested: the SD billing interface, and European statutory numbering.

| Page | What it answers |
| :-- | :-- |
| [Document types and number ranges](document_types_and_number_ranges.md) | The generic mechanics (`T003`, `OBA7`, `FBN1`, `RF_BELEG`), the SD-FI interface and the `RV` document, and why a year-dependent FI range and an SD=FI number identity cannot both exist. |
| [Numbering design for an inbound interface](inbound_interface_numbering.md) | Applying it: reuse a standard document type or create a dedicated one, one type or two, internal or external assignment — and which part of a cross-system range collision configuration can actually prevent. |

## The one distinction to carry away

**A document type is client-level. Its number range intervals are per company code and per fiscal year.**

Almost every hard question here dissolves once those are separated:

- The same document type can number continuously in one company code and restart annually in another — no second document type required. That is the multi-country escape hatch.
- The document key is `BUKRS` + `BELNR` + `GJAHR`, so a repeated number in a new year is correct, not a collision.
- SD number ranges (`RV_BELEG`) have **no** year dimension; FI ranges (`RF_BELEG`) always have one. That asymmetry is the source of the SD/FI numbering conflict, and it cannot be configured away.

## And one thing to check before designing anything

European numbering statutes almost always address the **invoice number** — in SAP, the SD billing document number — not the internal FI accounting document number. France's FEC is the notable exception, where the accounting entry numbering itself is in scope. Establishing which number the requirement names is the first task, not the last.

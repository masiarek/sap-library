# Numbering design for an inbound interface

**Level: 301 · for FI consultants and integration architects** — choosing document types and number ranges when an external system posts accounting documents into SAP.

**One line:** Two decisions get argued as one — *which document type* and *who assigns the number* — and they are independent. Separating them resolves most of the disagreement before anyone has to compromise.

Builds directly on [Document types and number ranges](document_types_and_number_ranges.md); read Part 1 of that page first if the type/key/interval chain isn't familiar.

---

## The two decisions

An inbound interface posting customer or vendor documents raises them together, which is why discussions go in circles:

| | Decision | What it is really about |
| :-- | :-- | :-- |
| **A** | Reuse a standard document type, or create a dedicated one | **Separation** — reporting, authorization, and blast radius |
| **B** | Internal or external number assignment | **Idempotency versus numbering guarantees** |

They are orthogonal. A dedicated document type with an internal range is a perfectly coherent design, and so is the opposite. Deciding A does not decide B.

---

## Decision A — reuse a standard type, or create a dedicated one

The instinct to reuse `DR` / `DG` (or `KR` / `KG`) is reasonable: they exist, everyone knows them, no new config. The instinct to separate is usually right anyway, and the decisive argument is not the one people reach for first.

### The argument that actually settles it: authorization

A document type carries an **authorization group** (`T003`, checked through the document-type authorization object). A dedicated type can be made **impossible to post manually** — not discouraged, not by convention, but denied.

That converts *"nothing prevents users from posting these manually in future"* from a standing risk into a closed one. It is worth more than every reporting argument combined, because it is the only option on the list that doesn't depend on people remembering something.

### The rest of the case for a dedicated type

| Benefit | Why it matters |
| :-- | :-- |
| **Selection by `BLART`** | "Everything from the interface" becomes a one-field filter in `FBL5N`, `FAGLL03` and every standard report — permanently, without depending on number range boundaries holding. |
| **Field control** | The type can make the reference field (`XBLNR`) mandatory, so the source system's key is always present. Forcing that on standard `DR` would affect every other process that uses it. |
| **Reversal type** | Set independently of the standard types. |
| **Blast radius** | Config changes for the interface cannot affect unrelated postings. |
| **Range separation comes free** | The type gets its own number range key, rather than carving a sub-interval out of a shared range and trusting nobody drifts into it. |

### The honest cost

Two more config objects to create, document and maintain in every system of the landscape; and users whose saved report variants filter on `DR` will not see the interface's documents until told. Both are one-time and small. **The separation case wins on the merits, not on preference.**

## One type or two?

If the interface sends both invoices and credit memos, the question mirrors `DR` versus `DG`.

Worth noting first: **you do not need a document type to tell an invoice from a credit memo.** The debit/credit indicator is on the line item already, as [the payment pages](../payments/f110_debit_vs_credit.md) cover — the sign is never ambiguous. A second type is about convenience and control, not information.

That said, two types is usually the better call: it matches the mental model users already have, credit memos are the items that draw scrutiny and create unusual balances, and each can carry its own reversal type.

> **The move that gets missed: two document types can share one number range key.** `T003-NUMKR` is per type, but nothing requires the keys to differ. Two types pointing at one key gives semantic separation for reporting and authorization while leaving **one interval** to create, protect, and administer each year.
>
> The exception that forces two ranges: **external assignment where the source system numbers invoices and credit memos on independent sequences.** Then the two could collide inside a shared interval, and they need separate ranges. If the source has a single document sequence, one range is strictly better.

---

## Decision B — internal or external assignment

This is the genuine trade, and it is not primarily about effort.

### Clear away the objection that isn't real

The usual objection to external is *"the sending system now has to send us its number."*

**It has to send it either way.** Under internal assignment you still need the source key in `XBLNR` — for reconciliation, for support, and for the duplicate check discussed below. The field travels in the message regardless. The only question is whether SAP uses it **as the key** or **as a reference**.

What genuinely changes is *error handling*, not payload.

### What external assignment buys

| | |
| :-- | :-- |
| **Idempotency, enforced by the database** | The document key is company code + document number + fiscal year. A resend of the same document **cannot** double-post — it fails on the primary key. This is the strongest argument on either side: double-posting AR is serious and hard to detect after the fact. |
| **1:1 traceability** | The FI document number *is* the source number. No lookup, no join, no mapping table. |
| **Trivial reconciliation** | Compare the two number sets directly. |
| **Collisions fail loudly** | An uncoordinated second source posting into the same interval errors immediately rather than silently interleaving into one sequence. |

### What external assignment costs

| | |
| :-- | :-- |
| **Sequence and gaps become the sender's problem** | SAP no longer guarantees sequential, gapless numbering. Where a statutory expectation applies, that obligation has moved to a system that may not be built to evidence it — see [Part 3 on European requirements](document_types_and_number_ranges.md). |
| **Format coupling — a hard gate** | The source number must be numeric and fit a 10-character `BELNR` inside the defined interval. An alphanumeric or longer key rules external assignment out, or forces a derivation that destroys the traceability benefit. Check this **first**; it is binary. |
| **Year-dependency coupling** | If source numbering runs continuously across the year boundary, the FI interval must be year-independent (`9999`). This is the same collision the SD interface has, for the same reason. |
| **Duplicate protection is scoped to the year** | The key includes the fiscal year, so on a **year-dependent** interval the same source number can post again in a new year with no error. If idempotency is the reason for choosing external, the interval must be `9999` or the guarantee has a hole in it. |
| **Harsher failure mode** | Duplicates and out-of-range numbers are hard posting failures needing a defined reprocessing path. |
| **Interval planning becomes joint** | The interval must cover the source's numbering space for the life of the interface; extending it later is a coordinated change. |
| **Renumbering in the source becomes an SAP change** | A source-system migration that renumbers documents now requires config here. |

### What internal assignment buys and costs

Internal is the mirror image: SAP keeps its numbering guarantees, year-dependent ranges stay available, there is no format constraint and no coupling to the source's numbering — but **duplicate protection is something you build.**

Typically that means storing the source key in `XBLNR` and checking it before posting. That check must be designed properly: it needs to be atomic with the posting, and it must behave correctly when a previous attempt failed partway. A duplicate check that races is worse than none, because it produces confidence rather than protection.

### Choosing

External is the better answer **only if all three gates pass**:

1. **Format** — source numbers are numeric and fit a 10-digit `BELNR` within one interval.
2. **Stability** — source numbering will not be renumbered or restructured.
3. **Statutory** — no gapless or annual-restart expectation applies to these documents in these company codes, or the source can evidence its own sequence.

If any gate fails, **internal plus a properly-built reference-key idempotency check** is the right design. Gate 1 is binary and cheap to test — establish it before the discussion goes any further.

---

## What configuration can and cannot prevent

A landscape that has been burned by an uncoordinated document type reused across systems tends to reach for a technical control. It is worth being precise about which part of that risk configuration actually addresses:

| Risk | Prevented by |
| :-- | :-- |
| Users posting the interface's type by hand | **Yes** — authorization group on a dedicated document type |
| Two sources interleaving in one interval **silently** | **Partly** — external assignment turns it into an immediate hard error instead |
| Another team adopting the same range key in another system | **No.** Number range intervals live in each system's own `NRIV`. Nothing in SAP knows what a different system is doing. |

That last row is the important one. **A number range key is only reserved because a register says so and a change process checks it.** No assignment mode, document type, or interval definition prevents an uncoordinated team elsewhere from adopting the same key.

So the durable control is organizational: a landscape-wide register of number range keys, their owning process, their assignment mode and their intervals — consulted before any new interface or document type is created. External assignment makes a breach *visible immediately* rather than months later in a reconciliation, which is a real benefit, but it is a detector, not a lock.

## Decision checklist

1. Are the source numbers numeric and within 10 digits? *(Fails → internal.)*
2. Does the source have one document sequence, or separate ones per document class? *(Separate → two ranges.)*
3. Does a gapless or annual-restart expectation apply in these company codes?
4. If external: is the interval `9999`, and does it cover the source's full numbering space?
5. Is the interval defined in **every** company code the interface posts to?
6. What is the reversal document type, and does it have an **internal** range? *(A reversal of an externally-numbered document otherwise needs a number supplied by hand.)*
7. Is the document type authorization-protected against manual posting?
8. Is `XBLNR` mandatory and carrying the source key — under **either** assignment mode?
9. Is the range key registered as owned by this interface, landscape-wide?
10. What happens to a rejected document — corrected in the source, or resent?

## Related

- [Document types and number ranges](document_types_and_number_ranges.md) — the type/key/interval chain, external assignment, and the European year-dependency collision this page inherits.
- [How F110 knows a payment is debit or credit](../payments/f110_debit_vs_credit.md) — why the invoice/credit-memo distinction never depends on the document type.

## Provenance and caveats

Written from working SAP FI and integration knowledge, not from a transcript of a named system. The authorization behaviour, the `BELNR` format constraint and the year-scoping of the duplicate key are the load-bearing technical claims — verify each in your own system before designing to them, since a design that assumes idempotency it does not actually have is worse than one that never claimed it.

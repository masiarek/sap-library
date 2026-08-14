# Worked decision: numbering for an inbound AR interface

**Level: 301 · for FI consultants and integration architects** — a real design question, argued through to a recommendation. Names and system IDs removed; the reasoning is unchanged.

**One line:** Reusing `DR` / `DG` for an interface is the cheap option that quietly costs you the ability to ever separate interface documents from manual ones — and the fix is authorization, not numbering.

Framework behind this: [Numbering design for an inbound interface](inbound_interface_numbering.md). Mechanics: [Document types and number ranges](document_types_and_number_ranges.md).

---

## The situation

A **legacy system** will post **customer accounting documents** into S/4 through an interface. Its numbering already exists and is not ours to change — which is what makes the assignment-mode question load-bearing rather than academic. Two options are on the table:

- **Reuse standard `DR` (customer invoice) and `DG` (customer credit memo).**
- **Create one or two dedicated document types**, with a number range reserved for the interface and used nowhere else in the landscape.

Two concerns drive the discussion, and they are different in kind — which is why they need different remedies.

### Concern 1 — manual postings, later

Today there are **no manual customer postings** anywhere in the landscape. Nothing prevents another division from starting to post manual `DR` / `DG` in future. If they do, interface documents and manual documents share one document type and one number range, and **no single field distinguishes them** — retrospectively, or ever.

Note the shape of this concern: it is not that something is wrong now. It is that the current cleanliness is **unenforced**, and relies on nobody exercising a capability they already have.

### Concern 2 — uncoordinated range reuse across systems

This landscape has already been bitten. `RV` documents were adopted in a second system without coordination, and the legacy shows in the current state: **one system on range `18` (internal), another on `1P` (external)**. The resulting sensitivity to managed control over number ranges is well founded.

A third option was therefore proposed: a dedicated range **`1C`, external** — the sending system supplies the numbers and SAP rejects duplicates, rather than SAP assigning numbers internally.

---

## Decision A — dedicated document types

**Recommendation: create dedicated types. Do not reuse `DR` / `DG`.**

The decisive argument is not the reporting one people reach for first. It is **authorization**.

A dedicated document type carries an authorization group, so it can be made **impossible to post manually** — denied, not discouraged. That converts Concern 1 from a standing risk into a closed one, and it is the only remedy available that does not depend on people remembering a convention indefinitely.

Everything else is supporting benefit:

| Benefit | Effect |
| :-- | :-- |
| Selection by `BLART` | "Everything from the interface" is a one-field filter in `FBL5N` / `FAGLL03` — permanently, and independent of whether range boundaries hold |
| `XBLNR` mandatory | The source key is guaranteed present on every document, needed for reconciliation under either assignment mode |
| Independent reversal type | Set without touching the standard types |
| Blast radius | Interface config changes cannot affect unrelated postings |
| Range separation | Comes free — the type gets its own key, rather than carving a sub-interval out of `DR`'s range and trusting nobody drifts into it |

**Cost:** two config objects to create and maintain per system, and users with saved variants filtering on `DR` will not see interface documents until told. Both one-time and minor. The separation case wins on merits.

## Decision B — one type or two, and how many ranges

**Recommendation: two document types, one shared number range key.**

Two types mirror the `DR` / `DG` split users already understand, keep credit memos — the items that draw scrutiny and create unusual balances — selectable on their own, and allow separate reversal types.

The point that resolves the "one or two ranges?" question directly: **`T003-NUMKR` is per document type, but nothing requires the keys to differ.** Two types pointing at one key give semantic separation with **one interval** to create, protect and administer each year.

> **The one condition.** Under external assignment, a shared range requires the legacy system to guarantee uniqueness **across both** invoices and credit memos. One sequence in the source → one range is strictly better. Independent sequences → they can collide inside a shared interval, and **two ranges are required.** This is a question about the *legacy* system, and it has to be answered before the range is defined.

## Decision C — external assignment

**Recommendation: external, subject to one gate.**

### The objection that isn't real

The stated drawback was that the legacy system would have to transmit its numbers. **It has to transmit them either way.** Under internal assignment the source key is still needed in `XBLNR` — for reconciliation, for support, and for duplicate detection. The field is in the message regardless; the only question is whether SAP uses it *as the key* or *as a reference*. What actually changes is error handling, not payload.

### The reframe that matters

*"SAP will be rejecting duplicates"* was raised as a cost. **It is the strongest argument in favour.**

The document key is company code + document number + fiscal year, so a resend of the same source document **cannot** double-post — it fails on the primary key, enforced by the database.

Under internal assignment that protection has to be **built**: store the source key, check it before posting, make the check atomic with the posting and correct when a prior attempt failed partway. Buildable — but a duplicate check with a race produces *confidence* rather than protection, and double-posted AR is both serious and hard to detect after the fact.

So the trade is: **external gives idempotency for free and hands you the numbering obligations; internal keeps SAP's numbering guarantees and hands you the idempotency build.**

| | External | Internal |
| :-- | :-- | :-- |
| Duplicate resend | **Impossible** — database-enforced | Possible unless the check is built correctly |
| Traceability | FI number **is** the source number | Two numbers; join on `XBLNR` |
| Cross-source collision | Fails **loudly**, immediately | Interleaves silently |
| Sequence / gaps | **Source's responsibility** | SAP manages |
| Number format | **Hard constraint** — numeric, ≤10 digits | No constraint |
| Year-dependent ranges | Effectively unavailable | Available |
| Source renumbering later | Becomes an SAP config change | No impact |

### Three traps that quietly break the guarantee

1. **The interval must be year-independent (`9999`).** The duplicate key includes fiscal year, so on a year-dependent interval **the same source number can post again in a new year with no error.** If idempotency is why external was chosen — and it is — a year-dependent range puts a hole straight through it.
2. **The interval must exist in every posting company code.** Intervals are per company code. A missing one fails at the first real posting, not in testing, unless testing covers every company code.
3. **The reversal type needs an internal range.** Otherwise reversing an externally-numbered document requires somebody to key a number by hand.

---

## What this fixes, and what it does not

Being precise here matters, because the proposed control is being asked to carry more weight than it can:

| Risk | Fixed? |
| :-- | :-- |
| Users posting interface documents manually | **Yes** — authorization group on a dedicated type |
| A second source interleaving silently into the range | **Converted to an immediate hard error** by external assignment |
| Another team adopting the same key **in another system** | **No.** Intervals live in each system's own `NRIV`. Nothing in SAP knows what another system is doing. |

That third row is Concern 2 — the original incident — and **no configuration choice prevents a recurrence.** A range key is reserved only because a register says so and a change process checks it.

**So the proposal is incomplete without a governance item:** a landscape-wide register of number range keys — key, owning process, assignment mode, intervals, systems in use — consulted before any new document type or interface is created.

External assignment makes a breach *visible immediately* rather than months later in a reconciliation. That is a real improvement, and it is a **detector, not a lock.** The register is the lock.

## Proposed configuration

| Item | Proposal |
| :-- | :-- |
| Document types | Two, dedicated to the interface — invoice and credit memo |
| Account types permitted | Customer (`D`) and G/L (`S`) only |
| Authorization group | Set, and **not** granted to any dialog role — interface user only |
| Reference `XBLNR` | **Mandatory**, carrying the source document key |
| Number range key | One, shared by both types — pending Q2 below |
| Assignment | **External** — pending Q1 below |
| Interval year | **`9999`**, year-independent |
| Interval | Covering the source's full numbering space, defined in **every** posting company code |
| Reversal type | Separate, with an **internal** range |
| Governance | The key registered landscape-wide as owned by this interface |

## Open questions, before build

| # | Question | Why it matters |
| :-- | :-- | :-- |
| **Q1** | Are source document numbers **numeric and ≤10 digits**? | **The gate.** Binary, cheap to test, and it can overturn the assignment mode. If no, external is off the table and the design falls back to internal plus a properly-built idempotency check. Answer this first. |
| **Q2** | Does the source number invoices and credit memos on **one sequence** or two? | One → one range. Independent → two, or they collide in a shared interval. |
| **Q3** | What is the source's **full numbering space** over the life of the interface? | The interval must cover it; extending later is a coordinated change. |
| **Q4** | Which **company codes**, and could the list grow? | An interval is needed in each. |
| **Q5** | Does any **gapless or annual-restart** expectation apply in those company codes? | External moves that obligation to the source system. See [Part 3 on European requirements](document_types_and_number_ranges.md). |
| **Q6** | On rejection, does the source **correct and resend**, or is it a manual fix? | External has a harder failure mode; the path must be designed, not discovered in production. |

## The recommendation in one paragraph

Create **two dedicated document types** sharing one number range key, authorization-protected so they cannot be posted by hand, with `XBLNR` mandatory and carrying the source key. Use **external** assignment on a **year-independent** interval defined in every posting company code, with an internally-numbered reversal type. This closes the manual-posting concern by configuration rather than convention, and buys database-enforced protection against double-posting, which is the more serious exposure of the two. Confirm **Q1** first, since it is binary and can overturn the assignment mode — and add the key to a landscape-wide range register, because that register, not the configuration, is what actually prevents the next uncoordinated reuse.

## Provenance and caveats

An anonymized real design question — systems, people and organization removed; the reasoning, the concerns and the range keys are as discussed. Nothing here has been verified against a system. The authorization behaviour, the `BELNR` format constraint and the **year-scoping of the duplicate key** are the load-bearing technical claims and should be confirmed before build, because a design that assumes idempotency it does not actually have is worse than one that never claimed it.

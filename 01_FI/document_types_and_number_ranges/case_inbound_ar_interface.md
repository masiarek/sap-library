# Worked decision: numbering for an inbound AR interface

**Level: 301 · for FI consultants and integration architects** — a real design question for an **AR Lite** system, argued through to a recommendation. Names and system IDs removed; the reasoning is unchanged.

**One line:** Reusing `DR` / `DG` for an interface is the cheap option that quietly costs you the ability to ever separate interface documents from manual ones — and the fix is authorization, not numbering.

Framework behind this: [Numbering design for an inbound interface](inbound_interface_numbering.md). Mechanics: [Document types and number ranges](document_types_and_number_ranges.md). Downstream: [how the payment program treats these open items](../payments/f110_debit_vs_credit.md), since payments and clearing all happen in S/4.

---

## The situation

A **legacy system** will post **customer accounting documents** into S/4 through an interface. Its numbering already exists and is not ours to change — which is what makes the assignment-mode question load-bearing rather than academic. Two options are on the table:

- **Reuse standard `DR` (customer invoice) and `DG` (customer credit memo).**
- **Create one or two dedicated document types**, with a number range reserved for the interface and used nowhere else in the landscape.

Two concerns drive the discussion, and they are different in kind — which is why they need different remedies.

### The architecture: an AR Lite system

Worth naming, because two of the arguments below turn on it, and because a landscape usually runs **both** patterns:

| Pattern | What it is | Where invoices come from | Numbering consequence |
| :-- | :-- | :-- | :-- |
| **AR Full** — *several systems* | AR **with** SD | Billing documents in SD | FI document type `RV`, and the option of [SD = FI number identity](document_types_and_number_ranges.md) |
| **AR Lite** — *one, central* | AR **without** SD | An upstream legacy system, by interface | No `RV`, no billing document — the subject of this page |

This design is the **AR Lite** system: one central S/4 receivables subledger, fed by interface, with no SD functionality in scope.

> **Why the range is chosen deliberately.** Several AR Full systems each number their `RV` documents from their own ranges, held in their own `NRIV`. The AR Lite system is one central book that has to coexist with all of them, so its range must be distinct from every one of theirs — and nothing in SAP checks that, because no system can read another's intervals.


```
Legacy system                    S/4
  invoices raised    ──────▶   AR open items          (this interface)
  invoice issued                     │
  to the customer                    ▼
                                incoming payments,
                                clearing, dunning     (all in S/4)
```

Three consequences follow, and each one changes a decision:

1. **There is no SD document flow to fall back on.** In an AR Full flow the accounting document is tied to a billing document, so even with independent numbering you can always navigate between them. Here there is no `VBRK`, no *Accounting* button, no document flow. **The only link back to the source is the one you deliberately put there** — which makes the mandatory reference field a requirement rather than good practice. The posting API also exposes a reference key (`AWTYP` / `AWKEY`), so the source key can be carried in both places; do that.
2. **The legal invoice number is the legacy system's number.** The invoice the customer receives is raised and issued by the legacy system. That number is what appears on the paper, in the customer's own system, on their remittance advice, and in every query they raise. See §Decision C — it is the strongest *business* argument for external assignment, and it is specific to AR Lite.
3. **S/4 owns the whole downstream lifecycle.** Payments, clearing, residuals, reversals and dunning all happen here. The interface's document types cover **incoming invoices and credit memos only**; clearing and reversal documents draw from their own types and ranges, which must be planned alongside — see the configuration table.

Given point 3, the interface documents must arrive as **complete AR items** — payment terms, baseline date, dunning data — because S/4, not the legacy system, runs collection from that point on. That is outside numbering, but it fails in the same go-live week.

### Concern 1 — manual postings, later

Today there are **no manual customer postings** anywhere in the landscape. Nothing prevents another division from starting to post manual `DR` / `DG` in future. If they do, interface documents and manual documents share one document type and one number range, and **no single field distinguishes them** — retrospectively, or ever.

Note the shape of this concern: it is not that something is wrong now. It is that the current cleanliness is **unenforced**, and relies on nobody exercising a capability they already have.

### Concern 2 — uncoordinated range reuse across systems

This landscape has already been bitten. `RV` documents were adopted in a second system without coordination, and the inconsistency persists in the AR Full estate today: **one system on range `18` (internal), another on `1P` (external)**.

**That history is accepted, not in scope to remediate.** Rewriting numbering in live AR Full systems would cost more than the inconsistency does. Its relevance here is forward-looking: it is the reason the *new central* system's range is being chosen deliberately, distinct from anything the AR Full systems use, rather than picked from whatever looked free.

Hence the proposal of a dedicated range **`1C`, external** — the legacy system supplies the numbers and SAP rejects duplicates, rather than SAP assigning them internally.

---

## The three questions

The design reduces to three, and they are **independent** — answering one does not answer the others:

1. **Standard `DR` / `DG`, or custom document types?**
2. **One document type, or two?**
3. **Internal or external number assignment?**

## The options, side by side

Seven combinations are worth stating. `Z1` / `Z2` stand for custom types; the range key is illustrative.

| | Document types | Range(s) | Assignment | Viable? |
| :-- | :-- | :-- | :-- | :-- |
| **A** | Standard `DR` + `DG` | Existing | Internal | Yes — the do-nothing option |
| **B** | Standard `DR` + `DG` | Existing | External | **No** — see below |
| **C** | One custom `Z1` | One | Internal | Yes |
| **D** | One custom `Z1` | One | External | Yes |
| **E** | Two custom `Z1` + `Z2` | One shared | Internal | Yes |
| **F** | Two custom `Z1` + `Z2` | One shared | External | Yes — **recommended** |
| **G** | Two custom `Z1` + `Z2` | Two | External | Yes — required if the legacy sequences are independent |

### How they compare

| Criterion | A | B | C | D | E | F | G |
| :-- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| Manual posting can be blocked | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Interface docs identifiable by `BLART` | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Invoice vs credit memo separable by type | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ |
| Duplicate resend impossible | ✗ | ✓ | ✗ | ✓ | ✗ | ✓ | ✓ |
| FI number = legacy invoice number | ✗ | ✓ | ✗ | ✓ | ✗ | ✓ | ✓ |
| Intervals to maintain per year | 0 | — | 1 | 1 | 1 | 1 | 2 |
| New config objects | 0 | — | 1 | 1 | 2 | 2 | 2 |

### Option by option

**A — Standard `DR` / `DG`, internal.** *The do-nothing option.*
**Pros:** no config, no new objects, familiar to everyone, existing report variants work unchanged.
**Cons:** interface and manual documents become indistinguishable the day someone posts a manual `DR` — permanently and retrospectively. Manual posting cannot be blocked without also blocking it for everyone. No duplicate protection unless built. Legacy invoice number lives only in `XBLNR`.
**Verdict:** cheapest today, and the only option that gets *worse* over time rather than staying flat.

**B — Standard `DR` / `DG`, external.** *Listed to be eliminated.*
**Why not:** switching `DR`'s range to external forces **every** manual `DR` posting to have its number keyed by hand, across the whole client. It solves nothing the interface needs and imposes a cost on unrelated processes. Not a real candidate.

**C — One custom type, internal.**
**Pros:** manual posting blockable; interface documents filterable by `BLART`; one interval; SAP keeps sequence and gap guarantees; no coupling to legacy number format.
**Cons:** invoices and credit memos share one type, so separating them in reporting means reading the sign rather than filtering a field. Duplicate protection must be built, race-free. Two numbering worlds, joined through `XBLNR`.

**D — One custom type, external.**
**Pros:** all of C's separation benefits, plus database-enforced idempotency and the FI number matching the legacy invoice number.
**Cons:** invoices and credit memos share a type *and* a range, so the legacy system must guarantee uniqueness across both. Inherits every external constraint — numeric ≤10 digits, `9999` interval, sequence obligation moves to the source.

**E — Two custom types, one shared range, internal.**
**Pros:** full separation — manual posting blocked, `BLART` filter, invoice vs credit memo distinguishable by type — with only one interval to administer. SAP keeps the numbering guarantees. No format coupling.
**Cons:** duplicate protection is a build. Two numbering worlds. The strongest option if the external gate fails.

**F — Two custom types, one shared range, external.** ← **recommended**
**Pros:** everything in E, plus idempotency enforced by the primary key and the FI document number equal to the number the customer sees on the invoice. One interval despite two types, because `T003-NUMKR` need not differ between them.
**Cons:** requires legacy numbers to be numeric and fit `BELNR`; requires a single legacy sequence across invoices and credit memos; sequence and gap obligations move to the legacy system; harder failure mode on rejection.

**G — Two custom types, two ranges, external.**
**Pros:** as F, but tolerates a legacy system that numbers invoices and credit memos on **independent** sequences.
**Cons:** two intervals to create, protect and administer in every company code — double the year-end task and double the register entries. Choose only if forced by the answer to Q2.

> **F and G are the same design.** The only thing that decides between them is whether the legacy system has one document sequence or two — a question about the *source*, not about SAP. Answer Q2 before defining any interval.

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

### The argument specific to AR Lite

Because the legacy system issues the invoice, **its number is the one the customer knows.** With external assignment the S/4 AR document carries that same number, and the payoff is operational rather than architectural:

- A **dunning notice** quotes a number the customer recognizes.
- A **customer query** — "what is this charge?" — is answered by looking up the number they quoted, directly, with no mapping step.
- **Cash application** matches a remittance advice that cites the legacy invoice number against a document carrying it.
- **Support** stops needing to know that two numbering worlds exist.

With internal assignment all of these still work, but each one goes through `XBLNR` — a lookup that every report, every integration and every new joiner has to know about. That is a small tax charged continuously rather than a one-time cost, and in an AR Lite system it is charged on the busiest process in the subledger.

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

That third row is Concern 2 — and **no configuration choice prevents a recurrence.** A range key is reserved only because a register says so and a change process checks it.

The goal is not to repair the AR Full estate. It is to ensure the central system's key is recorded as taken, so the next interface or document type created anywhere in the landscape cannot quietly claim it.

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
| **Q7** | When the legacy system **cancels** an invoice, does it send a credit memo through the interface, or expect a reversal in S/4? | A credit memo arrives with an external number; a reversal draws from the reversal type's internal range. Different designs, and the two must not both be in play. |
| **Q8** | Does the legacy number appear on the **customer-facing invoice**? | If yes, external assignment makes the S/4 document number match what the customer quotes — the business argument in Decision C. If no, that argument falls away and the decision rests on idempotency alone. |

## The recommendation in one paragraph

**Option F.** Create **two dedicated document types** sharing one number range key, authorization-protected so they cannot be posted by hand, with `XBLNR` mandatory and carrying the source key. Use **external** assignment on a **year-independent** interval defined in every posting company code, with an internally-numbered reversal type. This closes the manual-posting concern by configuration rather than convention, and buys database-enforced protection against double-posting, which is the more serious exposure of the two. Confirm **Q1** first, since it is binary and can overturn the assignment mode — and add the key to a landscape-wide range register, because that register, not the configuration, is what actually prevents the next uncoordinated reuse.

## Provenance and caveats

An anonymized real design question — systems, people and organization removed; the reasoning, the concerns and the range keys are as discussed. Nothing here has been verified against a system. The authorization behaviour, the `BELNR` format constraint and the **year-scoping of the duplicate key** are the load-bearing technical claims and should be confirmed before build, because a design that assumes idempotency it does not actually have is worse than one that never claimed it.

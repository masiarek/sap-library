# Document types and number ranges

**Level: 201 → 301 · for FI consultants, support and rollout teams** — the generic mechanics first, then the SD billing interface, then why European statutory requirements make the two collide.

**One line:** A document type is a *behaviour* setting that happens to carry a number range key; the number range is a *per-company-code, per-fiscal-year* interval. Almost every painful question in this area comes from those two being treated as one thing.

---

# Part 1 — The generic picture

## What a document type actually controls

The document type (`BKPF-BLART`, two characters, configured in **OBA7**, stored in **`T003`**) is a client-level object. It governs rather more than most people expect:

| It controls | Why it matters |
| :-- | :-- |
| **Number range key** (`T003-NUMKR`) | The two-character key — *not* the interval itself. See below; this distinction is the whole point. |
| **Account types permitted** | `S` G/L · `D` customer · `K` vendor · `A` asset · `M` material. A type that forbids customers cannot post to one, which is a control, not an obstacle. |
| **Reversal document type** | The type used when this document is reversed — often a different range. |
| **Required header fields** | Reference (`XBLNR`) mandatory, header text mandatory. The lever for enforcing the reference discipline that [intercompany reconciliation](../payments/intercompany_reconciliation_why_hard.md) lives or dies on. |
| **Negative postings allowed** | Whether a reversal reduces the original side rather than posting a new gross line. |
| **Net document type** | Vendor invoices posted net of cash discount. |
| **Authorization group** | Who may post this type at all. |
| **Exchange rate type** | Which rate table foreign-currency translation reads. |

### The types you will actually meet

| Type | What creates it |
| :-- | :-- |
| `SA` | G/L account document — the general-purpose journal |
| `KR` / `KG` / `KZ` | Vendor invoice / credit memo / payment |
| `DR` / `DG` / `DZ` | Customer invoice / credit memo / payment |
| `AB` | Accounting document — permits all account types |
| `ZP` / `ZV` | **Payment program postings** — what [F110](../payments/f110_debit_vs_credit.md) writes, and payment clearing |
| `RV` | **Billing document transfer** — the FI document created from an SD invoice. Part 2 is about this one. |
| `RE` / `RN` | MM invoice receipt, gross / net |
| `WA` / `WE` | Goods issue / goods receipt |
| `AF` / `AA` | Depreciation / asset posting |
| `X1` / `X2` | Recurring entry / sample document |

## The chain: type → key → interval

This is the part worth being precise about, because it is where the multi-country answer in Part 3 comes from.

```
Document type   RV        ← client-level (T003), one definition for everybody
      ↓  carries a number range KEY
Number range    19        ← still just a key, no numbers in it
      ↓  resolved per COMPANY CODE and per FISCAL YEAR (FBN1, object RF_BELEG)
Interval        CC 1000 / 2026 / 0900000000–0999999999   internal
                CC 2000 / 9999 / 1800000000–1899999999   external
```

Three consequences, none of them obvious from the config screens:

1. **The document type is global; the intervals are local.** Company code 1000 and company code 2000 can both use `RV`, with completely different intervals — and one of them can be year-dependent while the other is not.
2. **The document key is `BUKRS` + `BELNR` + `GJAHR`.** The document number alone is not unique. The same number legitimately recurs in a different year, which is precisely what makes annual restart possible.
3. **The "year" is the *fiscal* year**, derived from the posting date through the fiscal year variant. Company codes on different variants cross the boundary on different dates.

Maintained in **FBN1** (number range object `RF_BELEG`); the intervals live in table **`NRIV`**.

## Internal vs external assignment

Each interval carries an *external* flag:

| | Who assigns the number | Used for |
| :-- | :-- | :-- |
| **Internal** | SAP, sequentially from the interval | Almost everything |
| **External** | The calling application or the user supplies it | Data migration, interfaces, and **the SD same-number setup** in Part 2 |

An external range does **not** guarantee sequence and does not track a current number — it only validates that the supplied number falls inside the interval. That trade is the entire subject of Part 3.

## Year-dependent vs year-independent

The Year field on the interval decides:

- **A real fiscal year** (`2026`) — the interval applies to that year only. Numbering **restarts** each year, because next year gets its own interval with its own current number.
- **`9999`** — one interval spanning every year. Numbering runs **continuously** across year ends.

> **Year-end task.** With year-dependent ranges, the next year's intervals must exist **before the first posting into that year**. If they don't, the posting fails outright with a "number not in the defined range" error. This belongs on the year-end checklist; it is a common and entirely avoidable production incident. Read the exact message in your own system rather than trusting a number quoted on a page.

## Buffering, and why FI documents are not buffered

Number range buffering (**SNRO**) pre-fetches blocks of numbers per application server. It is a genuine performance feature, and it produces **gaps and non-chronological assignment** as a matter of design — a server that is restarted discards the rest of its block.

`RF_BELEG` is conventionally left **unbuffered** for exactly this reason: several jurisdictions expect accounting documents to be numbered without gaps. Turning buffering on to fix a throughput problem is a decision with a statutory dimension, not just a technical one.

Note the honest caveat: unbuffered does **not** mean provably gapless. A number is drawn as the document is created, and an update termination can consume one without producing a document. Gaps of that kind are explainable, and auditors generally accept a documented explanation — but "we can explain each gap" is a different claim from "there are none."

## Transport: the trap

Number range intervals are **not** carried by ordinary configuration transports. The document type is; the intervals are not.

FBN1 does offer an interval transport function, and it behaves in a way that has caused real damage: it **deletes all existing intervals in the target client** and replaces them with those from the source. Run against a productive client with live current-number states, that is destructive.

Standard practice is to maintain intervals **manually in each system**, and to treat their creation as a cutover and year-end task rather than a transportable object.

---

# Part 2 — SD integration and the `RV` document

## How an SD billing document becomes an FI document

Billing (VF01 / VF04) creates the SD billing document, then hands it to accounting through the SD-FI interface. Two number ranges are in play, and they belong to different objects:

| | SD billing document | FI accounting document |
| :-- | :-- | :-- |
| Number range object | `RV_BELEG` | `RF_BELEG` |
| Assigned via | The **billing type** configuration (`TVFK`) | The **document type** on the billing type — `RV` unless overridden |
| Year dimension | **None** — SD ranges have no year field | **Always** — every interval carries a year |

That last row is the fact the rest of this page turns on. **SD number ranges have no concept of a fiscal year. FI number ranges cannot avoid one.**

## The two configurations, and what each costs

### Option 1 — Same number in SD and FI

Set the FI number range used by `RV` to **external assignment**, with an interval covering the SD billing range. SD then passes its billing document number to FI, and the accounting document is created with the **same number**.

- **Gain:** a 1:1 number match. Anyone can quote one number across both modules; reconciling billing to revenue is trivial.
- **Cost:** the FI range must be external, and it must cover whatever SD produces. Since the SD range never restarts, the FI interval effectively has to be year-independent (`9999`) — or be maintained identically for every single year, which achieves nothing except more work.

### Option 2 — Independent numbers, linked by reference

Leave the FI range **internal**. FI assigns its own number; the link back to the billing document is carried in the document header:

| Field | Contents |
| :-- | :-- |
| `BKPF-AWTYP` | The reference transaction — `VBRK` for an SD billing document |
| `BKPF-AWKEY` | The reference key — the originating document's number |

This is the same mechanism that links MM invoice receipts and material documents to their FI postings, and it is what the *Accounting* button in the billing document and the SD document flow both follow.

- **Gain:** FI numbering is free to be whatever local statute requires, including a year-dependent restart.
- **Cost:** two numbers for one business event. Anyone reconciling by eye needs the reference field; reports need to join on it.

> **Which one is live in your system?** Look at the interval behind the `RV` document type in FBN1. If the *Ext* flag is set, you are on Option 1. If the interval carries a real year rather than `9999`, you are on Option 2 whether or not anyone decided that deliberately.

---

# Part 3 — Year-dependent ranges and European requirements

## First, the distinction that prevents most of the wasted effort

European statutory numbering requirements overwhelmingly concern the **invoice number** — the number printed on the document the customer receives — and not the internal FI accounting document number.

In SAP that legal invoice number is normally the **SD billing document number**, not the `RV` accounting document number. Conflating the two produces expensive redesigns of the wrong object.

The genuine exception is **audit-file formats that describe the accounting entries themselves**. France's **FEC** (*Fichier des Écritures Comptables*) is the clearest case: it requires an entry-numbering scheme that is continuous and chronological within the ledger. There, the accounting document numbering really is in scope.

So the first question on any rollout is not *"how do we make FI year-dependent?"* but *"which number is the statute actually talking about?"*

## What the requirements commonly are

Presented as the requirements one commonly meets, not as tax advice — **confirm each against local statutory guidance for the country and period in question**, since these regimes change frequently:

| Country | Commonly cited requirement |
| :-- | :-- |
| **France** | FEC: accounting entries numbered continuously and chronologically; the file is the audit deliverable |
| **Italy** | Progressive invoice numbering per year; VAT register numbering per register per year; e-invoicing through SdI |
| **Spain** | Invoice series with sequential numbering within the series; near-real-time reporting under SII |
| **Portugal** | Certified invoicing software, sequential numbering per series, SAF-T PT, and document codes/QR on the printed invoice |
| **Poland** | Sequential invoice numbering; structured e-invoicing and SAF-T style reporting |
| **Germany** | GoBD: completeness, unalterability and traceability. Gapless numbering is not the literal requirement; being able to demonstrate completeness is |
| **Hungary / Romania** | Real-time or near-real-time invoice reporting, with the reported invoice number as the key |

The recurring themes: **sequence**, **an annual restart** (or a year embedded in the key), **series** where a single sequence is insufficient, and **an audit file** that must reconcile to the ledger.

## The collision

Now put Part 1 and Part 2 together.

A requirement for **annual restart of FI document numbering** means year-dependent intervals — a real year on each interval, not `9999`.

But the **same-number setup from Option 1 depends on a year-independent external range**, because the SD number that must fit inside it never restarts.

**You cannot have both.** Force a year-dependent FI interval while SD keeps counting through the year boundary, and the first January billing run fails: SD offers a number that no longer falls within any defined FI interval, and the accounting document cannot be created. The billing document exists and is not posted to accounting — a queue that grows silently until somebody looks.

## Four ways out

| Approach | What you get | What it costs |
| :-- | :-- | :-- |
| **A. FI year-independent (`9999`), external, SD = FI** | Number identity; nothing to maintain each year | No annual restart. Fine where the statute addresses the *invoice* number, which the SD range provides. |
| **B. FI year-dependent, internal, numbers differ** | Annual restart in FI; link via `AWTYP`/`AWKEY` | Two numbers per business event. **The usual answer in European company codes.** |
| **C. FI year-dependent, and switch the SD range annually** | Restart on both sides, numbers still aligned | A mandatory year-end config step. Fragile: miss it and billing stops. Rarely worth it. |
| **D. Split by company code — same document type, different intervals** | European company codes year-dependent; the rest year-independent | The escape hatch from Part 1: `T003` is global, intervals are per company code. One document type, two behaviours, no extra config objects. |

**D is the one people miss**, and it is usually the right answer on a multi-country template. You do not need a separate document type per country to get different numbering behaviour — you need different *intervals*, which are already per company code. A separate document type is warranted when the *behaviour* differs (permitted account types, required fields, authorization), not merely the numbering.

## The design questions, in order

1. **Which number does the statute name** — the invoice number, or the accounting entry number? Usually the former, which is SD's.
2. **Is an annual restart genuinely required**, or is a unique key that includes the year sufficient? The FI document key already contains `GJAHR`.
3. **Do you need SD = FI number identity**, or is `AWKEY` enough? Identity is a convenience, not a requirement, and it is the thing being traded away.
4. **Is buffering off** on `RF_BELEG` where gapless numbering is expected?
5. **Are next year's intervals created**, in every company code, before the first posting of the year?
6. **Are series required** (Portugal, Spain)? A single number range cannot express a series; that is a different design conversation.

## Year-end checklist

- Create next year's intervals for every year-dependent range, in every company code, **in production** — they do not transport.
- Verify the fiscal year variant per company code, so you know when each one actually crosses.
- Confirm buffering state has not been changed for a performance fix.
- Check that external ranges still cover what the sending application will produce next year.
- Post one test document per critical type into the new year before go-live day.

---

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| What a document type controls | `OBA7`, or `SE16N` on `T003` |
| Which interval a type actually uses | `FBN1` for the company code — check the Year and *Ext* flag |
| Whether numbering is year-dependent | The Year column: a real year, or `9999` |
| Buffering state | `SNRO`, object `RF_BELEG` |
| SD billing ranges | The billing type configuration and number range object `RV_BELEG` |
| Whether SD and FI numbers match | Any billing document and its accounting document — compare, then check `BKPF-AWTYP` / `AWKEY` |
| Current number and gaps | `NRIV`, and the document list for the type and year |

## Related

- [How F110 knows a payment is debit or credit](../payments/f110_debit_vs_credit.md) — the payment program writes `ZP` / `ZV` documents from its own ranges.
- [Intercompany settlement, worked end to end](../payments/intercompany_settlement_worked_example.md) — a cross-company posting draws a document number **per company code**, linked by `BKPF-BVORG`.
- [Why intercompany reconciliation is hard](../payments/intercompany_reconciliation_why_hard.md) — the reference field a document type can make mandatory is the same field document-level matching depends on.

## Provenance and caveats

Written from working SAP FI knowledge, not from a transcript of a named system, and **the country table is not tax advice.** Statutory e-invoicing and audit-file regimes across Europe change frequently and differ by entity size, transaction type and period; treat the table as the shape of the problem and confirm the specifics with local statutory guidance before designing to them.

No message numbers are quoted — the failure texts for a missing interval and an out-of-range external number are worth reading in your own system, since the wording moves between releases.

Field and table names (`T003`, `NRIV`, `BKPF-BLART`, `AWTYP`, `AWKEY`) are the stable core and travel across ECC and S/4HANA. In S/4 the underlying journal entry is stored in `ACDOCA` with `BKPF`/`BSEG` retained as compatibility views; document types, number ranges and this whole chain are unchanged.

If you confirm any of this against a specific system, add the system ID and the date beside the claim.

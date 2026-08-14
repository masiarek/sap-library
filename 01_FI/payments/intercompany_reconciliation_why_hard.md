# Why intercompany reconciliation is hard

**Level: 301 · for FI consultants, controllers and close teams** — the structural reasons IC recon resists automation, and the controls that actually reduce the pile.

**One line:** Intercompany reconciliation is hard not because the arithmetic is difficult but because it is the only close activity with **two owners, two systems of record for one fact, and no natural matching key** — so every weakness in reference-field discipline surfaces here first.

Companion pages: the mechanics are in [Intercompany settlement, worked end to end](intercompany_settlement_worked_example.md); the payment program's own logic is in [How F110 knows a payment is debit or credit](f110_debit_vs_credit.md).

---

## The structural problem

Everything else in the close has one owner and one version of the truth. IC has two of each. That single asymmetry generates most of what follows.

### 1. Nobody owns the pair

CC 1000's accountant owns CC 1000's books. CC 2000's owns theirs. **The pair belongs to neither.** A difference is therefore always someone else's problem first, and the natural equilibrium is both sides waiting.

The fix is organizational, not technical: name an owner per partner pair — conventionally the **seller's AR is authoritative**, so the selling side owns the explanation and the buying side owns the correction. Write the convention down. Half the ageing differences in a typical landscape exist because nobody agreed which side moves.

### 2. A balance difference tells you nothing useful

The comparison report says the pair is out by 12,438. That number is the *sum of* an unknown set of items — possibly one, possibly forty, possibly two large ones that nearly offset. You cannot act on a net.

Real reconciliation is **document-level matching**, and document-level matching needs a key both sides carry. Which is the crux:

### 3. There is no natural common key

The two documents are created independently, in different company codes, by different processes, with **different document numbers**. Nothing links them unless somebody deliberately put a link there.

The usual candidates and how they fail:

| Candidate key | Fails when |
| :-- | :-- |
| Amount + date | Partial payments; combined payments; two invoices for the same amount in one month; any FX difference |
| Document number | Only ever meaningful in its own company code |
| Reference (`BKPF-XBLNR`) | Works — **if** the receiving side is disciplined about populating it with the *sender's* document number |
| Assignment (`BSEG-ZUONR`) | Works — **if** the sort key is configured to produce a common value, and nobody overwrites it |

This is why reference-field discipline is the whole ballgame. An IC process that populates `XBLNR` and `ZUONR` consistently on both sides reconciles almost automatically; one that doesn't cannot be rescued by any tool, because the tool has nothing to match on either.

### 4. Timing differences are indistinguishable from errors

An item posted on one side and not the other looks *identical* in a balance comparison whether it is:

- a genuine cut-off timing difference that self-resolves next period, or
- a document that will never arrive because it was disputed, or
- a one-sided posting that is simply wrong.

Only document-level detail separates them, and the first category is by far the largest — so a team without matching spends its time re-examining items that were never problems.

### 5. Cash in transit is structural, not exceptional

The payer clears its payable the moment the payment run posts. The receiver clears its receivable when the bank statement is applied — a day later, three days later, or after a weekend. **At any month-end, some payments are mid-flight by definition.**

This one is permanent, predictable, and should be a standing reconciling category with an expected magnitude, not a fresh investigation every month.

### 6. Currency is where "equal" stops being simple

If the two company codes have different local currencies, the pair can only be reconciled in a **common currency** — group currency. And there:

- The two sides may translate at **different rates** (different rate types, different translation dates, one side using the posting-date rate and the other a month-end rate).
- **Realized and unrealized FX** on the open items moves each side independently.
- A pair that agrees exactly in transaction currency can be out by a real amount in group currency, and **that difference is correct** — it must be explained and reported, not eliminated.

Reconciling in local currency and hoping is the single most common methodological error in this area.

### 7. Partial payments and residual items destroy the link

Clear an item with a residual and SAP creates a **new document** for the remainder. The original document number — possibly the only thing tying the two sides together — is now cleared on one side while the other still shows the original. Repeat over a few months and the audit trail is a chain nobody can walk.

Prefer **partial payment** (leaves the original open) over **residual item** (creates a new one) on intercompany accounts, unless there is a specific reason otherwise.

### 8. Central payment and netting erase the cash trail

Under a payment factory or cross-company-code payment ([Model C](intercompany_settlement_worked_example.md#model-c-central-payment-cross-company-code-payment)), **no cash moves between the two company codes at all** — the obligation is restated as a due-to/due-from on the OBYA clearing accounts. Bank-statement matching, the most reliable clearing route, is simply unavailable.

Netting ([Model B](intercompany_settlement_worked_example.md#model-b-netted-settlement-vendorcustomer-netting-on)) has a milder version of the same effect: one payment clears items on two accounts, so a one-to-one document match no longer exists.

Both models are operationally *better* than gross settlement. Both make reconciliation harder. Know which trade you made.

### 9. The trading partner can be right in FI and wrong for consolidation

`BSEG-VBUND` defaults from the master record. If a master points at the wrong company — or the field is blank on a manual posting — the company code's books still balance and the pair may still reconcile, while **consolidation elimination fails** and the difference surfaces at group level, weeks later, far from anyone who could explain it.

Reconciling FI balances does not prove trading partner integrity. Check it separately.

### 10. Manual one-sided postings

The category that produces permanent, unexplainable differences. A journal into an intercompany account with no counterpart in the partner's books cannot be reconciled by any process, because there is nothing to reconcile it to.

This is the one worth a hard control: restrict who may post manually to IC accounts, and require the counterpart reference on every such posting.

### 11. Everything else that differs between two company codes

The long tail, each capable of producing a difference that looks like an error:

- **Different fiscal year variants** — "period 3" is not the same window on both sides.
- **Different charts of accounts** or account mapping in a non-uniform landscape.
- **Parallel ledgers** — reconciling the leading ledger while the difference lives in a local one.
- **Tax treatment** on cross-border IC invoices, where one side posts a tax line the other does not.
- **Rounding** on allocated or multi-line rebillings.
- **Goods in transit** — the physical IC supply-chain case, where the seller invoices on dispatch and the buyer receives days later, so an inventory leg and an accrual sit between the two.

### 12. Volume

None of the above is hard once. All of it is hard across thousands of items and dozens of pairs, every month, against a close deadline. **Manual matching does not scale, and the failure mode of manual matching under time pressure is a plug.**

---

## What actually reduces the pile

Roughly in order of return on effort:

| # | Control | Why it works |
| :-- | :-- | :-- |
| 1 | **Enforce a common reference at posting** — sender's document number into `XBLNR`, a stable value into `ZUONR` via sort key | Turns an unmatched pile into an automated match. Nothing else on this list matters as much. |
| 2 | **Name an owner per pair** and adopt "seller's AR is authoritative" | Removes the both-sides-waiting equilibrium |
| 3 | **Reconcile in group currency**, with a stated rate convention | Stops the team chasing differences that are correct |
| 4 | **Restrict manual postings to IC accounts** | Cuts off the permanent-difference generator |
| 5 | **Automate matching** — ECC ICR (`FBICS3` → `FBICA3` → `FBICR3`), or S/4HANA ICMR | Humans then work only exceptions, which is the only sustainable model at volume |
| 6 | **Standing categories with expected magnitudes** — cash in transit, cut-off, FX | Converts recurring noise into a checked expectation rather than an investigation |
| 7 | **Age the differences and force decisions** at a materiality threshold | Unexplained differences compound; a written write-off policy with approval stops the carry-forward |
| 8 | **Sequence the close calendar** so both sides post before the comparison runs | Removes self-inflicted timing differences |
| 9 | **Prefer partial payment over residual items** on IC accounts | Preserves the document link |
| 10 | **Check `VBUND` integrity separately** from balance reconciliation | Catches the class that FI reconciliation structurally cannot see |

## The uncomfortable truth about a clean IC reconciliation

A pair that reconciles to zero every month is usually evidence of **upstream process discipline** — consistent references, controlled postings, a sequenced calendar — and not of a good reconciliation process. By the time an item reaches the reconciliation, most of what determines whether it will match has already happened.

Which is why the highest-value work in this area is almost never in the reconciliation itself. It is in the posting.

---

## How to verify this in your own system

| Claim | Where to look |
| :-- | :-- |
| Whether a common key exists | `FBL1N` / `FBL5N` — is `XBLNR` populated with the counterpart's document on both sides? |
| Sort key behaviour on `ZUONR` | The reconciliation account's master, and what `F.13` is configured to match on |
| Currency convention | The pair's balances in local vs group currency; the rate type and translation date in use |
| Trading partner integrity | `BSEG-VBUND` against the master record — and against what consolidation received |
| Where the differences actually are | Document-level matching output, never the net balance |
| Which reconciliation tooling is active | ECC ICR components, or the S/4HANA ICMR apps, as activated in your landscape |

## Provenance and caveats

Written from working SAP FI knowledge and general close-process experience, not from a transcript of a named system. The structural causes and the controls are broadly applicable; the **tooling** is the part to verify locally — ECC ICR components and S/4HANA ICMR differ by release and by what has been activated, and organizations vary widely in whether they use standard tooling, a third-party matching product, or spreadsheets.

Nothing here is a substitute for your group's own intercompany policy, which is where the authoritative-side convention and the materiality threshold should already be written down. If they are not, that absence is itself the finding.

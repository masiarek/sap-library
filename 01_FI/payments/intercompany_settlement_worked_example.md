# Intercompany settlement, worked end to end

**Level: 201 · for FI consultants and support** — two company codes, four subledger accounts, one month of trade. Follows the money from the first invoice to a reconciled balance at close.

**One line:** Every intercompany transaction is posted twice, once in each company code, and the two postings are mirror images. Settlement and reconciliation are both just the discipline of keeping those mirrors equal.

This page is the worked companion to [How F110 knows a payment is debit or credit](f110_debit_vs_credit.md), which covers the payment program's group-and-net logic in the abstract. Here it is with numbers.

---

## The cast: four accounts, not two

The setup that confuses newcomers is that **each company code carries two accounts for the same partner** — one payable, one receivable:

| | Books of **CC 1000** | Books of **CC 2000** |
| :-- | :-- | :-- |
| **IC vendor** (AP — what we owe them) | `V2000` — "Company Code 2000" | `V1000` — "Company Code 1000" |
| **IC customer** (AR — what they owe us) | `C2000` — "Company Code 2000" | `C1000` — "Company Code 1000" |

Both exist because trade runs both ways: 2000 bills 1000 for services, and 1000 rebills 2000 for shared costs. Keeping them on separate accounts is not bureaucracy — payables and receivables age differently, report differently, and are confirmed with the partner differently.

Each of these masters carries a **trading partner** (`BSEG-VBUND`, defaulted from the master record), which is the field group consolidation uses to eliminate intercompany balances. A posting with the right amount and the wrong trading partner reconciles fine in FI and breaks consolidation — worth knowing before anyone "fixes" a difference by editing the wrong thing.

The mirror rule that governs everything below:

> **CC 1000's IC vendor balance for 2000 must equal CC 2000's IC customer balance for 1000** (opposite signs), and vice versa for the other pair. Any gap is a reconciling item with a name.

---

## One month of trade

Three transactions. Each one posts in both company codes.

### Jan 5 — CC 2000 bills CC 1000 for services, 100,000

| | Books of CC 1000 | Books of CC 2000 |
| :-- | :-- | :-- |
| | Dr Services expense 100,000 | Dr **IC customer `C1000`** 100,000 |
| | Cr **IC vendor `V2000`** 100,000 | Cr IC revenue 100,000 |
| Effect | payable created | receivable created |

### Jan 12 — CC 1000 rebills shared IT costs to CC 2000, 30,000

| | Books of CC 1000 | Books of CC 2000 |
| :-- | :-- | :-- |
| | Dr **IC customer `C2000`** 30,000 | Dr IT expense 30,000 |
| | Cr Cost recovery 30,000 | Cr **IC vendor `V1000`** 30,000 |
| Effect | receivable created | payable created |

### Jan 20 — CC 2000 over-billed January by 15,000; credit memo issued

| | Books of CC 1000 | Books of CC 2000 |
| :-- | :-- | :-- |
| | Dr **IC vendor `V2000`** 15,000 | Dr IC revenue 15,000 |
| | Cr Services expense 15,000 | Cr **IC customer `C1000`** 15,000 |
| Effect | payable reduced | receivable reduced |

Note the credit memo lands as a **debit** on the vendor and a **credit** on the customer — each the "unusual" side of its account. That is normal for a credit memo and is exactly the item that later nets against its invoice, provided it carries the invoice reference (`BSEG-REBZG`).

### Position before settlement

| Account | Books of | Open items | Net balance |
| :-- | :-- | :-- | --: |
| IC vendor `V2000` | CC 1000 | 100,000 Cr, 15,000 Dr | **85,000 Cr** |
| IC customer `C2000` | CC 1000 | 30,000 Dr | **30,000 Dr** |
| IC customer `C1000` | CC 2000 | 100,000 Dr, 15,000 Cr | **85,000 Dr** |
| IC vendor `V1000` | CC 2000 | 30,000 Cr | **30,000 Cr** |

Both mirrors hold: 85,000 against 85,000, 30,000 against 30,000. **Net economic position: CC 1000 owes CC 2000 55,000.**

---

## Three ways two company codes settle this

Which one you are running is a configuration decision, and it changes both the cash movement and the clearing work.

### Model A: Gross settlement (vendor/customer netting OFF)

Each company code pays its own IC vendor. Nothing offsets.

- **F110 in CC 1000** selects `V2000`, nets the invoice and credit memo to 85,000 Cr, pays it.
  `Dr IC vendor V2000 85,000 / Cr Bank 85,000`
- **F110 in CC 2000** selects `V1000`, pays 30,000.
  `Dr IC vendor V1000 30,000 / Cr Bank 30,000`

Two bank transfers, in opposite directions, to move a net 55,000. The receivable side of each is cleared when the cash lands (below).

This is the model in place whenever the four netting settings are not all set — see §5 of the [companion page](f110_debit_vs_credit.md#5-vendorcustomer-netting-four-settings-all-four-required). It is also the model where **an unusual balance gets stuck**, which is its own section further down.

### Model B: Netted settlement (vendor/customer netting ON)

With `LFA1-KUNNR`, `KNA1-LIFNR`, `LFB1-XVERR` and `KNB1-XVERR` all set, F110 in CC 1000 pulls the customer's items into the vendor's group and pays the difference:

```
Books of CC 1000 — one payment document
  Dr  IC vendor    V2000     85,000
  Cr  IC customer  C2000     30,000
  Cr  Bank                   55,000
```

One transfer instead of two. CC 2000 then clears both of its accounts against the single receipt:

```
Books of CC 2000 — one receipt document
  Dr  Bank                   55,000
  Dr  IC vendor    V1000     30,000
  Cr  IC customer  C1000     85,000
```

Same end state, half the cash movement, and the two sides can no longer drift apart between two separate payment runs.

### Model C: Central payment (cross-company-code payment)

Configured in **FBZP → Paying Company Codes**, where the paying company code differs from the sending one: CC 1000 pays on behalf of CC 2000 out of one bank account. The payment document posts into both company codes at once, with the due-to/due-from lines hitting the clearing accounts defined in **OBYA**, and the two document numbers linked by the cross-company transaction number (`BKPF-BVORG`).

No cash moves between 1000 and 2000 at all. The obligation is simply restated as an intercompany clearing balance, settled later on whatever cadence treasury runs.

> **Which model are you on?** Check `FBZP → Paying Company Codes` for a paying company code that isn't itself, and the four netting flags on the master records. Those two answers fully determine the cash pattern you should expect to see.

---

## Clearing the open items

Settlement creates the cash. **Clearing** is the separate act of marking the open items as satisfied, and it happens on both sides.

**Paying side (CC 1000).** The payment run clears as it pays. The invoice and credit memo on `V2000` move from open (`BSIK`) to cleared (`BSAK`), stamped with the payment document number and clearing date. No follow-up needed.

**Receiving side (CC 2000).** The receivable is *not* cleared by the payer's run — CC 2000's books know nothing about it until the cash arrives. It clears when the receipt is applied, by one of:

| Route | How it matches | Notes |
| :-- | :-- | :-- |
| Electronic bank statement (`FF.5` import, `FEBAN`/`FEB_BSPROC` post-processing) | On the payment reference carried in the payment medium | The clean path. Depends on the paying side populating a reference the receiving side can match on. |
| Manual incoming payment (`F-28`) | User selects the open items | The fallback when the statement can't match. |
| Automatic clearing (`F.13`) | Matching criteria on an IC clearing account — assignment, reference | Posts **no** cash. Only clears groups netting to zero. |

That third row is the one worth being precise about, because "the clearing job" usually means F.13 and people assume it moves money. It does not. F.13 is a matcher: it pairs debits against credits already on the account and clears them when they sum to zero. If an intercompany account has a residual balance, F.13 leaves it — correctly — and that residual is your reconciling item.

**Result after settlement and clearing**, all four accounts:

| Account | Balance | Open items remaining |
| :-- | --: | :-- |
| `V2000` in CC 1000 | 0 | none |
| `C2000` in CC 1000 | 0 | none |
| `C1000` in CC 2000 | 0 | none |
| `V1000` in CC 2000 | 0 | none |

---

## When the balance is on the wrong side

Now change one number: make the January credit memo **120,000** instead of 15,000 — an over-billing correction larger than the invoice it corrects.

| Account | Books of | Open items | Net balance |
| :-- | :-- | :-- | --: |
| IC vendor `V2000` | CC 1000 | 100,000 Cr, 120,000 Dr | **20,000 Dr** ← unusual |
| IC customer `C1000` | CC 2000 | 100,000 Dr, 120,000 Cr | **20,000 Cr** ← unusual |

CC 2000 now owes CC 1000 20,000. Both accounts sit on their unusual side, and here is the trap:

- **F110 in CC 1000 will not pay** — the group nets to debit, so it drops out of the proposal as an exception. Correct: 1000 does not owe.
- **F110 in CC 2000 will not pay it either** — not because of the sign, but because the balance is sitting on the *customer* `C1000`. F110's outgoing selection reads **vendor** open items. `V1000` has its own separate 30,000; the 20,000 owed to 1000 is on an account the outgoing run never looks at.

So with netting off, the obligation is real, both sides agree on it, and **neither payment run can act on it.** It will sit there indefinitely, ageing, until someone intervenes. Three ways out:

| Option | What you do | Trade-off |
| :-- | :-- | :-- |
| **Reclassify** | Journal entry in CC 2000 moving the 20,000 credit off `C1000` onto `V1000`, where the outgoing run can see it. Mirror it in CC 1000 (debit off `V2000` onto `C2000`). | Manual, per occurrence, and needs a documented convention so both sides move together. The usual answer in practice. |
| **Outgoing payment method on the customer** | Assign an outgoing method to `C1000` so F110 can disburse a customer credit balance — the same mechanism as a customer refund. | Configuration; widens what the payment program can do to customer accounts generally. |
| **Turn on netting** | Set the four flags (Model B). The 20,000 simply nets with everything else in the next run. | The structural fix, but it changes settlement behaviour for every transaction with that partner, not just this one. |

The wrong answer, and the one the original question was really probing: **letting a job collect it from the other company code.** With no incoming payment method on the intercompany customers, F110 has no vehicle to do that, and with netting off the other side's items are not even in its selection set. The obligation has to be settled by a posting somebody makes deliberately, not harvested by a run.

---

## Reconciling the balances

Reconciliation asks one question per partner pair, in both directions:

```
CC 1000: IC vendor V2000 balance      ==  CC 2000: IC customer C1000 balance
CC 1000: IC customer C2000 balance    ==  CC 2000: IC vendor V1000 balance
```

Equal amounts, opposite signs, in a common currency. When they don't match, the difference always has a name — and naming it is the whole job:

| Reconciling item | What it looks like | Where it comes from |
| :-- | :-- | :-- |
| **Timing / cut-off** | One side posted in period 1, the other in period 2 | Invoice raised on the 31st, received on the 2nd. Resolves itself; document it, don't chase it. |
| **Cash in transit** | Payer has cleared, receiver hasn't | Payment run executed, bank statement not yet applied. The most common single cause. |
| **Disputed rebilling** | Receiver refuses to post the charge | Not an FI problem. Escalate; do not paper it over with a one-sided entry. |
| **FX translation** | Amounts agree in local currency, differ in group currency | Different local currencies and different translation rates. Reconcile the pair in **group currency**, not local. |
| **Wrong trading partner** | Balances match in total but the partner analysis doesn't | `VBUND` defaulted from a master record that points at the wrong company. Breaks consolidation while looking fine in FI. |
| **One-sided posting** | No mirror exists at all | Manual journal into an IC account without the counterpart. The category worth having a control against. |

### Where to look

| Tool | What it gives you |
| :-- | :-- |
| `FBL1N` / `FBL5N` | Vendor and customer line items — filter by trading partner and by the intercompany reconciliation account |
| `FBL3N` / `FAGLL03` | The G/L side, including the OBYA clearing accounts under Model C |
| `F.13` | Clears what genuinely offsets, leaving the residual — which *is* your reconciling list |
| ECC **ICR** (`FBICS3` select → `FBICA3` assign → `FBICR3` reconcile) | The standard intercompany reconciliation process for customer/vendor open items |
| S/4HANA **ICMR** | Intercompany Matching and Reconciliation — the successor apps for matching and reconciling IC transactions |

### Cadence that works

- **Monthly, before close** — run the pair comparison, resolve timing items, escalate disputes with enough runway to fix them in period.
- **Quarterly, hard confirmation** — both sides sign the same number. Anything unexplained gets written off deliberately, with approval, rather than carried.
- **Continuously** — keep an eye on unusual balances. An IC vendor sitting in debit is not an error, but it is a signal that something needs a decision, and per the section above it will never clear itself.

---

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| The mirror pairs and their balances | `FBL1N` / `FBL5N` on both company codes, filtered by trading partner |
| Which settlement model is live | `FBZP` → *Paying Company Codes*; the four netting flags via `XK03` / `FD03` |
| Cross-company clearing accounts | `OBYA`; the linked documents via `BKPF-BVORG` |
| Why an item wasn't paid | `F110` → *Proposal* → display proposal log |
| What F.13 actually cleared | The clearing document, and the residual left on the account |
| Trading partner integrity | `BSEG-VBUND` against the master record's trading partner |

## Provenance and caveats

Written from working SAP FI knowledge, not from a transcript of a named system. The figures are illustrative; the postings, field names and transaction codes are the stable core and travel across ECC and S/4HANA.

Two things to check locally rather than take from this page: **transaction codes for the reconciliation tooling** (the ECC ICR components and the S/4 ICMR apps differ by release and by what is activated in your landscape), and **master-data maintenance paths**, since S/4 maintains the vendor/customer link and the trading partner through business partner roles rather than the classic master transactions. The underlying tables — `LFB1`, `KNB1`, `BSEG` — did not change.

If you confirm any of this against a specific system, add the system ID and the date beside the claim.

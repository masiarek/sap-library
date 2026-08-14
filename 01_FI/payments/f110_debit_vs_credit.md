# How F110 knows a payment is debit or credit

**Level: 201 · for FI consultants and support** — the question comes up most often on intercompany clearing jobs, so that case is worked through in full at the bottom.

**One line:** F110 does not decide. The debit/credit sign is already stamped on every open item; F110 groups items, nets them, and pays only a group whose net sign matches the direction its payment method is configured for.

That single sentence answers the usual question. The rest of this page is the mechanism behind it, because the follow-up is always *"then how do I prove the job can't pull money from the other company code?"*

---

## 1. The sign lives on the line item, not in the program

Every open item carries a debit/credit indicator in `BSEG-SHKZG`:

| `SHKZG` | Meaning | On a vendor (AP) | On a customer (AR) |
| :-- | :-- | :-- | :-- |
| `S` (Soll) | Debit | **unusual** — vendor owes us | normal — receivable |
| `H` (Haben) | Credit | normal — we owe the vendor | **unusual** — we owe the customer |

The indicator is set by the posting key (`BSEG-BSCHL`) at the moment the document is posted — 31 for a vendor invoice, 21 for a vendor credit memo, and so on. Amounts (`WRBTR`, `DMBTR`) are stored **unsigned**; `SHKZG` carries the sign.

So the premise of the question is slightly off. F110 never inspects a payment and works out its direction. It reads a flag that accounting set months earlier.

## 2. What F110 actually does: group, then net

The payment program's job is to turn many open items into few payments. It does that in three moves:

1. **Select** open items for the company codes, accounts and payment methods in the run parameters (`BSIK` for vendors, `BSID` for customers).
2. **Group** them. The grouping is by company code, account, payment method, house bank, currency and due date, and is further shaped by the payment grouping key (`LFB1-GRUPP`) and the *Individual payment* flag (`LFB1-XPORE`) in the vendor's company-code data.
3. **Net** each group and read the resulting sign.

Netting is where credit memos disappear into invoices. A credit memo carrying an invoice reference (`BSEG-REBZG`) is always pulled in with the invoice it references; an unreferenced one nets into the group on its own due date.

## 3. The net sign decides — and a debit net is simply not paid

| Net of the group | Account type | What F110 does |
| :-- | :-- | :-- |
| Credit | Vendor | Pays. Cash leaves the house bank. |
| **Debit** | **Vendor** | **Nothing.** The group falls out of the proposal as an exception. |
| Debit | Customer | Collects — **but only** with an incoming payment method (see §4). |
| Credit | Customer | Nothing, by the same rule mirrored. |

The exception line appears in the payment proposal log. The wording varies by release — along the lines of *"net amount is a debit balance"* or *"only credit memos exist"* — so read it in your own system rather than quoting a message number from a page like this one.

The important property: **this is structural, not a setting.** There is no run parameter, variant, or proposal edit that makes F110 pay out on a net debit vendor group. If you are being asked whether a job could have done it, the answer is no, and the proposal log is the evidence.

## 4. Direction is *also* a configuration property

The sign of the data is only half of it. The other half is the payment method, which is explicitly one-directional:

**FBZP → Payment Methods in Country** carries a radio button for **outgoing payments** vs **incoming payments**. A method flagged outgoing can only ever disburse; collecting from a customer (direct debit) requires a method flagged incoming, present in the run's payment-method list and assigned on the item or the customer master.

This is the control that matters when the worry is *"could the job have grabbed money from the other side?"* If your intercompany customers carry no incoming payment method, F110 has no vehicle to debit them — whatever balance sits on the account. That is a stronger argument than reasoning about signs, because it does not depend on what anyone posted.

## 5. Vendor/customer netting: four settings, all four required

Offsetting a trading partner's AP against their AR is **off unless four things are true at once**:

| Setting | Where | Field |
| :-- | :-- | :-- |
| Vendor points at the customer | Vendor general data | `LFA1-KUNNR` |
| Customer points at the vendor | Customer general data | `KNA1-LIFNR` |
| *Clearing with customer* ticked | Vendor **company-code** data | `LFB1-XVERR` |
| *Clearing with vendor* ticked | Customer **company-code** data | `KNB1-XVERR` |

All four, or nothing happens. Which means **finding any one of them blank settles the question** — you do not need to check the other three.

With netting off:

- F110's selection set contains the vendor's items only. The customer's open items are not netted, not offered, not visible to the run.
- The manual route is closed too: the *other account* selection in F-44 / F-32 that would let a user pull customer items into a vendor clearing honours the same flag.
- There is no FBZP switch that overrides this. Netting is driven purely by master data.

## 6. Worked example: the intercompany case

Two company codes, mirrored subledger accounts:

- CC 1000 carries an **IC vendor** representing CC 2000.
- CC 2000 carries an **IC customer** representing CC 1000.

**Normal flow.** 1000 owes 2000. The IC vendor in 1000 shows a **credit** balance. F110 **in CC 1000** pays it. Cash moves 1000 → 2000, and the IC customer in 2000 clears against the receipt.

**The unusual balance.** The IC vendor in CC 1000 shows a **debit** balance — IC credit memos, rebilled costs, or an overpayment. Read it plainly: *1000 does not owe anything; 2000 owes 1000.*

What F110 does with that:

- A run in CC 1000 nets the group to debit and **excludes it** (§3). No payment document, no bank line.
- It does **not** turn around and collect from the IC customer in CC 2000 — that account is not in its selection set (§5), and absent an incoming payment method it could not be collected from anyway (§4).

The settlement has to originate on the other side: a run **in CC 2000** against *its* IC vendor (the mirror leg), or a manual intercompany settlement. The debit balance in 1000 then clears against the incoming cash.

> **The one-liner for the person asking:** a debit balance on the IC vendor means we don't owe — the other company code does. F110 can't act on that by design: a net debit group is excluded from the proposal, and with vendor/customer clearing switched off, the IC customer's items aren't even in scope. Settlement originates in the other company code.

## 7. Don't confuse F110 with the clearing jobs

"Jobs that clear open items" is ambiguous, and the ambiguity is usually what produced the question in the first place:

| | **F110** — payment program | **F.13** — automatic clearing |
| :-- | :-- | :-- |
| Moves cash? | Yes — posts a payment document and a bank line | **No** |
| Direction logic | Net sign + payment method direction | None — it only matches |
| What it needs | A group netting to the payable direction | A group netting to **zero** |
| Can it "grab" money? | Only via an incoming payment method | Never — it has no bank leg |

If the intercompany jobs in question are F.13-style automatic clearing, the whole premise dissolves: debit versus credit there is matching arithmetic, and there is no cash movement available to it at all.

## 8. Cross-company-code payments (the case where F110 *does* touch both)

One genuine exception is worth naming so nobody is blindsided by it. F110 can pay **on behalf of** another company code — configured in **FBZP → Paying Company Codes**, where the paying company code differs from the sending one. The payment document then carries intercompany clearing lines against the due-to/due-from accounts defined in **OBYA**.

This is still not netting AP against AR, and it still cannot pay out a net debit group. But it is the one mechanism inside F110 that posts into two company codes from one run, so it is worth confirming whether it is active before telling anyone the payment program never crosses company-code boundaries.

---

## How to verify all of this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| The item's sign | `FBL1N` / `SE16N` on `BSIK`, field `SHKZG` |
| Why the group wasn't paid | `F110` → *Proposal* → display proposal log — the exception line, in SAP's own words |
| Payment method direction | `FBZP` → *Payment Methods in Country* → outgoing/incoming radio |
| Netting is off | `XK03` / `FD03`, or `SE16N` on `LFB1-XVERR` and `KNB1-XVERR` |
| Cross-company payments | `FBZP` → *Paying Company Codes*; clearing accounts in `OBYA` |

## Provenance and caveats

This page is written from working SAP FI knowledge, not from a recorded transcript of a named system. Two deliberate omissions follow from that:

- **No message numbers are quoted.** Proposal-log wording and message IDs shift between releases and support packs; citing one from memory is how a confident page becomes a wrong page. Read the log.
- **Field and table names are the stable core** (`SHKZG`, `BSCHL`, `REBZG`, `XVERR`, `KUNNR`, `LIFNR`, `GRUPP`, `XPORE`) and are safe to rely on across ECC and S/4 — but the *screen* labels and menu paths around them have moved, particularly for business-partner-based master data in S/4, where the vendor/customer link is maintained through the BP roles rather than the classic master transactions. The underlying `LFB1` / `KNB1` fields are still what F110 reads.

If you confirm any of this against a specific system, add the system ID and the date beside the claim.

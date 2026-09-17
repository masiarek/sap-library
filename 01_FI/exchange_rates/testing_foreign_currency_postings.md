# Test scenarios for foreign currency postings from an interface

**Level: 201 · for interface owners, testers and FI consultants** — a scenario set for an inbound interface that sends amount and currency and lets S/4 calculate the local amount. Anonymized; the structure and the arithmetic are what matter.

**One line:** The test that proves the most is the dullest one — the same foreign amount posted twice, in two months — and it proves nothing unless someone has first made sure the two months have *different* rates, maintained against the currency the rate type actually reads.

Mechanics: [How a posting picks its exchange rate](how_a_posting_picks_its_rate.md). Tool: [the rate check report](exchange_rate_check_report.md).

---

## The setting

- Company code currency **CAD**. The sending system delivers customer invoices and credit memos in CAD, USD and EUR, two lines per document (customer line and one offsetting G/L line). `Y1` is the invoice type, `Y2` the credit memo type — the illustrative custom types used [elsewhere in this library](../document_types_and_number_ranges/case_inbound_ar_interface.md).
- The sender supplies **amount and currency only**: no local amount, no rate, no translation date.
- Rates are loaded **once a month**, rate type `M`, and `M` has **reference currency USD**.
- The ledger also carries a **group currency, USD**, so every document gets a third amount.

## The rule under test

1. S/4 takes the latest rate of type `M` valid on or before the **posting date**.
2. `USD → CAD` is derived from the `CAD → USD` entry; `EUR → CAD` is a cross rate from `EUR → USD` and `CAD → USD`.
3. Local amount = amount × rate, rounded commercially to two decimals.
4. Both lines carry the same amount, so the document balances in both currencies without a rounding line.
5. Every document also gets a group currency amount: a USD document 1 : 1, an EUR document through `EUR → USD`, a CAD document through `CAD → USD`.
6. A missing rate is a business error: no document, and a message the sender can act on.

## Step 0 — look before you write expected results

Run view 1 of the report for the planned posting dates. On a development or test system the usual finding is one of:

| Finding | Meaning for the test |
| :-- | :-- |
| One ancient entry, nothing since | Every month gets the same rate. The two-month test passes trivially and proves nothing. |
| No rate for one currency | Every record in that currency fails — this *is* your missing-rate scenario, for free, but nothing else can run. |
| Rates exist, but copied from production at the last refresh | Usable, but the expected results must be taken from view 1, not from a rate sheet someone mailed round. |

The fix in a test client is to maintain reference rates yourself. That raises the question of *which* rates.

## Choosing reference rates

Pick values that make the arithmetic checkable by eye **and** make the result independent of how the cross rate is rounded internally. With an indirect `CAD → USD` leg, that means values whose reciprocal is exact in five decimals:

| Entry to maintain | Valid from | Rate | Quotation | Why this value |
| :-- | :-- | :-- | :-- | :-- |
| `CAD → USD` | 01.08.2026 | 1.25000 | indirect (1 USD = 1.25 CAD) | 1 / 1.25 = 0.80000 exactly |
| `CAD → USD` | 01.09.2026 | 1.28000 | indirect | 1 / 1.28 = 0.78125 exactly |
| `EUR → USD` | 01.08.2026 | 1.20000 | direct (1 EUR = 1.20 USD) | |
| `EUR → USD` | 01.09.2026 | 1.25000 | direct | |

Resulting rates to CAD:

| Pair | August | September | How |
| :-- | :-- | :-- | :-- |
| `USD → CAD` | 1.25000 | 1.28000 | from the `CAD → USD` entry |
| `EUR → CAD` | 1.50000 | 1.60000 | 1.20 × 1.25 and 1.25 × 1.28 |

Whether the system multiplies by 1.28 or divides by 0.78125, `EUR → CAD` for September is 1.60000. With a realistic leg such as 1.37000 the two methods can differ in the fifth decimal (1 / 1.37 rounds to 0.72993, and 1.20 / 0.72993 is 1.64399, not 1.64400), and the expected result of a large amount moves by a cent. Realistic rates belong in production; checkable ones belong in a test.

Two prerequisites that are easy to miss: a **translation ratio** for `EUR → USD` must exist before the rate can be entered, and the **offsetting G/L account** must have the company code currency as its account currency — an account kept in a foreign currency accepts only that currency.

## The scenarios

| # | Type | Document date | Posting date | Amount | Rate | Amount × rate | Expected CAD | Expected group USD | What it proves |
| :-- | :-- | :-- | :-- | --: | :-- | --: | --: | --: | :-- |
| FX-01 | `Y1` | 20.08. | 20.08. | 1,000.00 USD | 1.25000 | 1,250 | **1,250.00** | 1,000.00 | First half of the pair |
| FX-02 | `Y1` | 17.09. | 17.09. | 1,000.00 USD | 1.28000 | 1,280 | **1,280.00** | 1,000.00 | Same amount, next month: the CAD amount differs by 30.00, the group amount does not |
| FX-03 | `Y1` | 17.09. | 17.09. | 1,000.00 EUR | 1.60000 | 1,600 | **1,600.00** | 1,250.00 | Cross rate through the reference currency |
| FX-04 | `Y2` | 17.09. | 17.09. | 250.00 EUR | 1.60000 | 400 | **400.00** | 312.50 | Credit memo: posting keys reversed, same translation |
| FX-05 | `Y2` | 17.09. | 17.09. | 333.33 USD | 1.28000 | 426.6624 | **426.66** | 333.33 | Rounds down |
| FX-06 | `Y1` | 17.09. | 17.09. | 123.48 EUR | 1.60000 | 197.568 | **197.57** | 154.35 | Rounds up |
| FX-07 | `Y1` | 20.08. | 20.08. | 123.48 EUR | 1.50000 | 185.22 | **185.22** | 148.18 | Same EUR amount as FX-06, other month: CAD differs by 12.35, group by 6.17 |
| FX-08 | `Y1` | 31.08. | 31.08. | 2,500.00 USD | 1.25000 | 3,125 | **3,125.00** | 2,500.00 | Last day of the month: still August's rate |
| FX-09 | `Y1` | 01.09. | 01.09. | 2,500.00 USD | 1.28000 | 3,200 | **3,200.00** | 2,500.00 | First day: already September's rate |
| FX-10 | `Y1` | 25.08. | 05.09. | 1,234.56 USD | 1.28000 | 1,580.2368 | **1,580.24** | 1,234.56 | Document date in August, posting date in September: the posting date decides |
| FX-11 | `Y1` | 17.09. | 17.09. | 0.01 USD | 1.28000 | 0.0128 | **0.01** | 0.01 | Smallest amount does not become 0.00 |
| FX-12 | `Y1` | 17.09. | 17.09. | 1,000.00 CAD | — | — | **1,000.00** | 781.25 | Control record: no translation to CAD — but still one to the group currency (1,000 / 1.28) |

**The group currency column has a configuration question hidden in it.** A second local currency is translated either from the *document currency* or from the *first local currency amount*. With arbitrary rates the two routes can differ by a cent, because the second one starts from an amount that was already rounded. The amounts above were checked by script to give the same result by both routes, so the column holds whichever is configured. One amount was changed for a related reason: the obvious 123.46 EUR gives 123.46 × 1.25 = 154.325 USD, exactly on the half cent, and an expected result should not hang on the rounding rule — 123.48 avoids it.

Expected on every one of them: the document posts; the header shows the currency as sent, translation date = posting date, and the rate of that date; both lines show the same foreign amount and the same CAD amount; view 3 of the report shows a green light and a difference of 0.00.

FX-08 and FX-09 hold only if the monthly entry is valid from the **first calendar day**. If the load uses the last day of the previous month, FX-08 gets September's rate. Ask the owner of the load; do not assume.

### Error and edge scenarios

| # | Data | Expected |
| :-- | :-- | :-- |
| FX-20 | A currency that exists but has no rate against the reference currency | Business error, no document. The message names the pair *currency / reference currency* — not *currency / CAD*. Record the message ID and number from the interface response: the sender's error reporting will key on them. After the rate is maintained, the same record posts. |
| FX-21 | A currency key that does not exist | Business error, no document. |
| FX-22 | A posting date in a month whose rates are not loaded yet | **The document posts** with last month's rate. No error, no warning. View 1 for that date shows yellow. Once the month's rate is loaded with an earlier valid-from date, the document is *not* re-translated, and view 3 shows it red. |

FX-22 is not a pass/fail test. It is a question for the business with evidence attached: *is a document translated at last month's rate acceptable on the first days of a month, or must the rate load precede the first interface file?* Whichever they choose, it is better decided before go-live than discovered in the first month-end.

## What the scenarios deliberately leave out

- **Further ledger currencies.** The group currency is covered above on the assumption that it uses the same rate type and the same translation date as the local currency. Each additional currency can have its own of both; check before trusting the column.
- **A document type with its own rate type.** If `T003-KURST` is set for the interface's document types, every expected rate comes from that type, not from `M`. Check before computing anything.
- **What happens later.** Open foreign currency items are revalued at month-end, and a payment in a later month posts a realized exchange rate difference. Neither is the interface's doing, but both will be asked about the first time someone looks at the customer account.

## How to verify all of this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| The rates the test will use | [Report](exchange_rate_check_report.md) view 1, key date = each posting date; or `SE37` on `CONVERT_TO_LOCAL_CURRENCY` (not `BAPI_EXCHANGERATE_GETDETAIL`, which returns the literal table entry) |
| The entries exist against the reference currency | Report view 2; `OB08` |
| Rate and translation date on a posted document | `FB03` header; `BKPF-KURSF`, `BKPF-WWERT` |
| Foreign and local amount per line | `FB03`, switching the display currency; `BSEG-WRBTR`, `BSEG-DMBTR` |
| Group currency amount, and how it was derived | `BSEG-DMBE2`; on the header `BKPF-HWAE2` (currency), `BASW2` (source: 1 document currency, 2 first local currency), `UMRD2` (which date), `KURS2` (rate) |
| Open item in both currencies | `FBL5N` with the local currency amount in the layout |
| Posted against expected, for the whole test | Report view 3, restricted to the interface's document types and the test's posting dates |
| Account currency of the offsetting account | `FS00`, control data of the company code segment |

## Provenance and caveats

- **The scenario set has not been executed.** It was designed on 17 September 2026 after the first manual attempt — an `EUR` document entered in `FB01` on a development system — stopped for a missing `EUR / USD` rate. That attempt is the source of FX-20's expectation about which pair the message names.
- The **expected amounts are arithmetic** on the reference rates, computed with decimal arithmetic and commercial rounding, not read from a system. The script also asserts that every group currency amount is the same from either translation source. The binding expected result for any real run is the *Converted amount* in view 1 of the report, which comes from the standard conversion function.
- That the posting date, not the document date, is the default translation date (FX-10) is written from experience and is exactly what FX-10 is there to confirm.

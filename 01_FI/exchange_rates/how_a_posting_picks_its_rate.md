# How a posting picks its exchange rate

**Level: 201 · for FI consultants, interface owners and testers** — written after a foreign currency test for an inbound interface stopped before the first document, for a reason nobody in the room had predicted.

**One line:** A posting does not ask for *today's* rate. It asks for the latest `TCURR` entry of one rate type whose valid-from date is on or before the translation date — and it never asks how old that entry is, or whether the pair you maintained is the pair it reads.

Both halves of that sentence bite. The first is why a monthly rate load fails silently. The second is why maintaining `EUR → CAD` can change nothing at all.

Companion pages: [a report that shows which rate a posting would get](exchange_rate_check_report.md), and [test scenarios for foreign currency postings](testing_foreign_currency_postings.md).

---

## 1. The four inputs

| Input | Where it comes from | Default |
| :-- | :-- | :-- |
| Currency pair | Document currency `BKPF-WAERS` → company code currency `T001-WAERS` | — |
| Exchange rate type | Document type, `T003-KURST` | `M` when the document type names none |
| Translation date | `BKPF-WWERT` | the posting date — **not** the document date |
| The rate | `TCURR`, read through the rate type's rules in `TCURV` | — |

An interface that sends an amount and a currency key, and nothing else, leaves all four to the system. That is usually what you want: the rate then comes from the same table as every manual posting. It also means the interface inherits every property of that table, including the two below.

The translation date is the input most often guessed wrong. A document dated in August and posted in September is translated with September's rate. If the business expects August's, that is a requirement on the interface (send a translation date), not a defect in the posting.

## 2. What the table actually holds

`TCURR` is keyed by rate type, from-currency, to-currency and **valid-from date** (`KURST`, `FCURR`, `TCURR`, `GDATU`). There is no valid-to. An entry is in force until a later entry for the same key exists.

Three details make the table harder to read than it looks:

- **`GDATU` is stored inverted:** `99999999` minus `YYYYMMDD`. So 1 September 2026 is `79739098`. The reason is mechanical: with the date inverted, *"latest entry on or before date D"* is simply the first row at or after D's inverted value in ascending key order — one index read, no sorting. Depending on the display settings, `SE16N` shows you either the converted date or the raw inverted number; the raw one is not a corrupt date.
- **A negative rate is an indirect quotation.** `UKURS = -1.28` for `CAD → USD` means *1 USD = 1.28 CAD*, not a negative price. `BKPF-KURSF` on the document uses the same sign convention.
- **The ratio is not reliably in `TCURR`.** The translation ratios (1 : 1, 100 : 1 for some currencies) live in `TCURF`. `TCURR` has ratio fields too, but they can be zero while the rate works perfectly well. Read ratios from `TCURF`, or better, from the standard lookup (§5).

## 3. No entry is ever too old

The lookup takes the latest entry on or before the translation date. **Nothing in it checks the age of that entry.** A rate entered once, decades ago, and never followed by another is still the valid rate today.

Two consequences for a company that loads rates once a month:

1. **Every posting date in a month gets the same rate** — provided the monthly entry is valid from the first day. If the convention is "valid from the last day of the previous month", the boundary moves by one day, and a month-end posting gets next month's rate. Find out which convention the load uses before writing expected results.
2. **A missed or late load is silent.** On the 2nd of the month, before the new file is loaded, postings take last month's rate — no error, no warning. When the file arrives later with valid-from = the 1st, the documents already posted are **not** re-translated. They now disagree with the table for their own translation date, and nothing reports that unless you go looking.

Development and test systems are the extreme case. Rates are rarely loaded there, so the rate in force can be the one delivered with the system. A foreign currency test there either fails for a missing rate, or — worse — passes with a rate nobody chose.

## 4. The rate type may not read the pair you maintained

A rate type can carry a **reference currency** (`TCURV-BWAER`). When it does:

- Rates are maintained only *against that currency*: with reference currency `USD`, the entries are `CAD → USD`, `EUR → USD`, and so on.
- A conversion between two other currencies is a **cross rate** the system calculates from the two legs. `EUR → CAD` comes from `EUR → USD` and `CAD → USD`.
- A directly maintained `EUR → CAD` entry is not what the lookup reads.
- The error for a missing rate names **the leg**, not the pair you asked for. Posting `EUR` in a company code whose currency is `CAD` fails with a message about `EUR / USD`. Read literally, that message looks like a wrong company code currency. It is not — it is the rate type telling you how it works.

The practical damage is in test preparation: someone maintains `EUR → CAD` for the test dates, the entry saves without complaint, and the posting still fails — or still uses the old cross rate.

A second switch in the same table, **inversion** (`TCURV-XINVR`), decides whether a missing `A → B` may be answered from `B → A`. Where it is off, the two directions are independent entries.

How the cross rate is rounded — whether an indirect leg is first turned into a five-decimal direct rate, or the division is carried at full precision — is not something this page has verified. It matters for the last cent of an expected result; the [test page](testing_foreign_currency_postings.md) shows how to choose reference rates so that it cannot matter.

## 5. Ask the system, not the table

Because of §2 to §4, a `SELECT` on `TCURR` for "my pair, my date" is the wrong check: it misses inversion, misses the reference currency, and misreads ratios. The standard lookup applies all of them:

| Function | What it gives you |
| :-- | :-- |
| `BAPI_EXCHANGERATE_GETDETAIL` | Rate, ratios and the valid-from date for a rate type, a pair and a date; direct and indirect quotation in separate fields |
| `CONVERT_TO_LOCAL_CURRENCY` | The converted amount, rounded to the target currency's decimals |

The [report](exchange_rate_check_report.md) is built on exactly these two, so what it shows is what a posting with no explicit rate would get.

## 6. What ends up on the document

| Field | Content |
| :-- | :-- |
| `BKPF-WAERS` / `BKPF-HWAER` | Document currency and company code currency |
| `BKPF-KURSF` | The rate used; negative = indirect quotation |
| `BKPF-WWERT` | The translation date the rate was read for |
| `BSEG-WRBTR` / `BSEG-DMBTR` | Line amount in document currency and in company code currency |

These four are enough to re-check any document afterwards: read the rate for `WWERT` again and compare. A mismatch means one of three things — the rate was loaded after the posting (§3), the rate or the local amount was supplied by the sender, or someone changed a past entry.

## S/4 differences

The tables (`TCURR`, `TCURF`, `TCURV`), the inverted date and the lookup are unchanged. Rates can be maintained in a Fiori app as well as in `OB08`. One thing S/4 makes easier: `BSEG` is a transparent table and can be joined to `BKPF` in one statement, which the document view of the report relies on. On ECC that join is not possible, and the same check needs two reads.

## How to verify all of this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Rate type of a document type | `OBA7`, or `SE16N` on `T003`, field `KURST` |
| Reference currency and inversion of a rate type | `OB07`, or `SE16N` on `TCURV`, fields `BWAER`, `XINVR` |
| Entries and their valid-from dates | `OB08`; `SE16N` on `TCURR` (mind the inverted `GDATU`) |
| Ratios | `OBBS`; `SE16N` on `TCURF` |
| The rate a posting would get | `SE37` test of `BAPI_EXCHANGERATE_GETDETAIL`, or view 1 of the [report](exchange_rate_check_report.md) |
| No age check | The same call with a date decades after the only entry — it answers |
| The missing-leg message | Enter a foreign currency document (`FB01`) for a currency with no rate against the reference currency, and read the message |
| What a document used | `FB03` header: exchange rate and translation date; `SE16N` on `BKPF`, fields `KURSF`, `WWERT` |

## Provenance and caveats

Written from working FI knowledge, with four points confirmed on an S/4HANA development system on **17 September 2026** (system ID withheld — this is a public page):

- **§3, no age check:** for key date 17.09.2026 the standard lookup returned a rate valid from 01.01.2001 — 9,390 days old — with no message.
- **§2, ratios:** the `TCURR` rows read directly showed ratio 0 : 0, while the standard lookup returned 1 : 1 for the same pair and date.
- **§4, the missing-leg message:** with rate type `M` on reference currency `USD`, entering an `EUR` document in a company code with currency `CAD` stopped with message `SG105`, asking for the rate `EUR / USD` for the posting date. The ID is quoted because it was read from the system on that date, not recalled; it may differ on another release.
- **§4, reference currency:** that `M` uses a reference currency, and that cross-currency entries are not considered, was stated by the person who owns that configuration; the message above is consistent with it. One more observation supports it: the table held a `USD → EUR` entry (valid from 2011) and no `EUR → USD` entry — and the `EUR` posting still failed asking for `EUR / USD`. So an entry pointing *away from* the reference currency did not help. Whether that is the reference currency rule or inversion being switched off for `M`, the run cannot tell apart. That a direct `EUR → CAD` entry is ignored was **not** tested separately.

- **§2 and §4, the entry that is read:** in a second company code on the same system, with local currency `USD`, a document of 22.00 CAD carried 14.71 USD — 22.00 / 1.496, the indirect `CAD → USD` entry from 2001. The same entry, read from the other side, gave 17.95 CAD for 12.00 USD in the CAD company code.

Not confirmed on a system: the rounding of cross rates (§4), and the behaviour of `TCURV-XINVR` (§4), which is described from experience.

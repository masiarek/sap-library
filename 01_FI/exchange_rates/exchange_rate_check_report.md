# A report that shows which rate a posting would get

**Level: 201 · for FI consultants and ABAP developers** — a read-only ABAP report, `Z_FI_EXCH_RATE_CHECK`, with the three questions it answers and the four mistakes its first runs exposed.

**One line:** Do not read `TCURR` and reason about it — call the same lookup a posting uses, show since when the answer has been valid, and colour it by age, because age is the one thing the system itself never checks.

Mechanics behind it: [How a posting picks its exchange rate](how_a_posting_picks_its_rate.md). What it is used for: [test scenarios for foreign currency postings](testing_foreign_currency_postings.md).

Source: [`z_fi_exch_rate_check.abap`](z_fi_exch_rate_check.abap) — one executable program, one local class, no dependencies beyond standard FI tables and two standard function modules.

---

## The situation it was written for

A company code with one local currency receives postings in two foreign currencies from an interface that sends amount and currency only. Rates are loaded **once a month**. Three questions kept coming up, and each needed several transactions to answer:

1. *If a document posts today in EUR, which rate does it get, and is that this month's rate?*
2. *Was a month ever skipped?*
3. *Did the documents that already posted use the rate the table says they should have?*

## The three views

| View | Question | Green | Yellow | Red |
| :-- | :-- | :-- | :-- | :-- |
| **1 · Rates on key date** | Which rate does a posting get on this date, since when is it valid, and what does a sample amount become in local currency? | Rate's valid-from is in the month of the key date | Rate is from an earlier month, but younger than the maximum age | No rate, or older than the maximum age |
| **2 · Rate history** | Which `TCURR` entries exist, and how many days lie between consecutive entries? | — | Entry is dated after the key date, or is not read by this rate type | Gap to the previous entry, or age of the entry in force, exceeds the maximum age |
| **3 · Posted documents** | Does `BKPF-KURSF` equal the table rate for the translation date, does the posted local amount equal the expected one — and the same for the second local currency (group currency), where the document has one? | All match | Match, but the table rate was already old on the translation date | Rate or an amount differs |

The maximum age defaults to 31 days — one missed monthly load turns the light red.

View 1 doubles as the **expected-result calculator** for a test: key date = planned posting date, sample amount = test amount, and the *Converted amount* column is what the document must show.

View 3 is the **evidence** after the test, and the monitoring tool afterwards: a document posted on the 2nd with last month's rate turns red as soon as the new month's rate is loaded with valid-from the 1st.

## Design decisions

**The rate comes from the lookup the conversion itself uses, not from a `SELECT`.** View 1 and view 3 call `READ_EXCHANGE_RATE` for the rate and the ratios, and `CONVERT_TO_LOCAL_CURRENCY` for the amount. Inversion, reference currency and rounding are then the system's own, not a re-implementation that agrees with it on easy cases only. (The first versions used a different function here, and were wrong in an instructive way — mistake 4 below.)

```abap
CALL FUNCTION 'READ_EXCHANGE_RATE'
  EXPORTING
    date             = iv_date
    foreign_currency = iv_fcurr
    local_currency   = iv_tcurr
    type_of_rate     = iv_kurst
  IMPORTING
    exchange_rate    = lv_rate       " negative = indirect quotation
    foreign_factor   = lv_ffact
    local_factor     = lv_tfact
  EXCEPTIONS
    no_rate_found    = 1
    no_factors_found = 2
    OTHERS           = 7.
```

**The valid-from date is read separately, from the entries the rate type really uses.** A cross rate has no single valid-from date. With a reference currency the report reads the latest entry of each leg *currency → reference currency* and reports the **older** one; without one, the entry of the pair, or of the inverse pair.

**The rate type is the document's, not the screen's.** View 3 reads `T003-KURST` for each document type and falls back to the rate type on the selection screen only when the document type names none.

**The document total comes from the debit side.** View 3 joins `BKPF` to `BSEG` and sums `WRBTR` and `DMBTR` over debit lines (`SHKZG = 'S'`). That is the document total in both currencies for any document type, without knowing which line is the customer. For a two-line interface document the comparison is exact; for a many-line document, translating the total and translating each line can differ by a cent, so a difference of that size there is rounding, not a wrong rate.

**The second local currency is checked from the document's own settings.** The header records how the amount was derived: `BKPF-HWAE2` (the currency), `BASW2` (translated from the document currency or from the first local currency amount) and `UMRD2` (document, posting or translation date). View 3 reads those rather than the ledger configuration, so it follows what the document was posted with. It assumes the same rate type as the first local currency — the one thing the header does not record. A document in local currency is therefore listed too, as soon as it carries a group currency.

**The inverted date is converted in two places only.**

```abap
" TCURR-GDATU is the inverted date: 99999999 - YYYYMMDD.
lv_c8 = iv_date.
lv_n8 = 99999999 - CONV i( lv_c8 ).
rv_gdatu = lv_n8.
```

**Lookups are cached.** View 3 can list thousands of documents that share a handful of (rate type, pair, date) combinations; each combination is looked up once.

## What the first runs got wrong

The report was activated and run on a development system the same day it was written. Four of its assumptions did not survive, and each failure is the mechanism page in miniature.

**1. The history window hid the only entry.** View 2 first read the last 13 months. It reported *no entries* for a pair whose only entry was from 2001 — which was the rate in force. A window on valid-from dates answers "what was entered recently", never "what applies now". *Fix:* read all entries, show the selected period **plus the last entry before it**, and mark the entry in force on the key date with its age.

**2. The ratios came out as 0 : 0.** View 2 showed the ratio fields of `TCURR` itself; on that system they are empty, and the ratios live in `TCURF`. *Fix:* take the ratios from the standard lookup for each entry's own valid-from date.

**3. The pair on the screen was not the pair in the table.** Rate type `M` had a reference currency. The report looked for `EUR →` local currency in the history and found nothing — correctly, and uselessly: the entries that matter are `EUR →` reference currency and local currency `→` reference currency. *Fix:* read `TCURV-BWAER`. When it is set, view 2 lists every currency against the reference currency and flags entries that do not point to it; view 1 shows the valid-from date of the **oldest leg** and names both legs in the remark; and a missing rate names the missing leg.

```abap
IF gv_bwaer IS NOT INITIAL AND lr_out->tcurr <> gv_bwaer.
  lr_out->light  = gc_light-yellow.
  lr_out->remark = |Not read: rates of type { p_kurst } must point to reference currency { gv_bwaer }|.
  CONTINUE.
ENDIF.
```

**4. The function that "returns the exchange rate" returned the table entry.** The first three versions asked `BAPI_EXCHANGERATE_GETDETAIL` for the rate. After real rates had been maintained against the reference currency, view 1 showed, on one line, a rate of **1.49600** and a converted amount of **1,280.00** for 1,000.00 — two different rates for the same pair and date. The amount came from `CONVERT_TO_LOCAL_CURRENCY` and was right (1.28, the new `CAD → USD` entry, read through the reference currency). The rate came from the BAPI, which had returned the **literal `USD → CAD` entry from 2001** — an entry this rate type never reads. For `EUR → CAD`, which has no literal entry at all, the BAPI returned nothing, so the pair stayed red although both legs now existed. *Fix:* `READ_EXCHANGE_RATE`, the function the conversion itself calls.

The uncomfortable part: mistakes 1 to 3 made the report show *too little*. This one made it show a plausible, precise, wrong number — and it was only visible because a second column, fed by a different function, disagreed. A cross-check that costs one extra column is worth having.

The oldest leg is the right age for a cross rate because a cross rate is as stale as its stalest input: `EUR → USD` loaded this month and `CAD → USD` from years ago is an old rate, whatever date the newer leg carries.

## Installing it

1. `SE38`: create an executable program and paste the [source](z_fi_exch_rate_check.abap). Rename it to your own namespace and naming convention.
2. Activate. No text elements need maintaining: frame titles and selection texts are set at `INITIALIZATION`.
3. The report checks `F_BKPF_BUK` with activity 03 for the company code. Add an authorization group or a transaction code as your standards require.

Setting selection texts in code uses the generated `%_<name>_%_app_%-text` fields. It is a widely used technique, but it is not part of the documented language. If your code review does not accept it, delete those lines and maintain the selection texts in the text elements instead; nothing else depends on them.

## How to verify all of this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| View 1 equals what a posting gets | Enter a foreign currency document in `FB01` for the same date and compare the proposed rate and local amount |
| The entry in force can be older than any window | View 2 with *History months* = 1 on a test system: the old entry is still listed |
| `TCURR` ratios are empty on your system, or not | `SE16N` on `TCURR`, fields `FFACT`, `TFACT`, against `TCURF` |
| Reference currency of the rate type | `OB07`, or `SE16N` on `TCURV-BWAER` |
| View 3 catches a late load | Post a document, then enter a newer rate valid on or before its translation date, and run view 3 again |

## Provenance and caveats

- Activated and run on an S/4HANA development system on **17 September 2026**, in three rounds the same day: the first version, the fixes for mistakes 1 and 2, and then the reference currency handling. **Views 1 and 2 ran in every round**; the last run showed ratios of 1 : 1, the missing leg named as `EUR/USD`, the 2001 leg named as the age of the `USD → CAD` rate, and two entries flagged as not pointing to the reference currency. System ID withheld — this is a public page.
- Each version was checked with the `abaplint` parser before it was pasted into the system. That checks statement syntax, not types; all three activated without a correction, which is luck as much as method.
- **The switch to `READ_EXCHANGE_RATE` (mistake 4) has not been activated yet.** It passes the `abaplint` parser. The three parameters it imports are typed after the `TCURR` fields they return; the valid-from date is deliberately *not* taken from the function but read from `TCURR`, to avoid depending on a parameter type recalled from memory.
- **View 3 ran later the same day, on one document** — a credit memo of 12.00 USD in a company code with local currency CAD and group currency USD. Document rate and table rate were both 1.49600, posted and expected local amount both 17.95 (12.00 × 1.496 = 17.952), posted and expected group currency amount both 12.00, and the light was yellow because the table rate was 9,390 days old on the translation date. An independent extract of the same document showed the same three amounts. One matching document proves the join, the header fields and the arithmetic; it does not prove the red branches, which need a document that disagrees with the table. View 3 needs S/4HANA, because it joins `BSEG`.
- View 3 checks the company code currency and the **second** local currency only, and the second one under the assumption of the same rate type. A third currency, or a group currency with its own rate type, is not covered; view 1 can at least display such a pair through *Additional target currencies*.

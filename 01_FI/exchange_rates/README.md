# Exchange rates

How a foreign currency posting finds its rate, a report that shows the answer before you post, and a scenario set for testing an interface that posts in foreign currency.

| Page | What it answers |
| :-- | :-- |
| [How a posting picks its exchange rate](how_a_posting_picks_its_rate.md) | The four inputs (pair, rate type, translation date, table); the inverted date in `TCURR`; why no entry is ever too old; and why a rate type with a reference currency does not read the pair you maintained. |
| [A report that shows which rate a posting would get](exchange_rate_check_report.md) | `Z_FI_EXCH_RATE_CHECK`: rates on a key date with their age, the rate history with gaps, and posted documents against the table rate — plus the four wrong assumptions its first runs exposed. |
| [Test scenarios for foreign currency postings from an interface](testing_foreign_currency_postings.md) | The same amount in two months, the month boundary, document date against posting date, rounding both ways, the missing rate and the month that is not loaded yet — with reference rates chosen so the expected cent cannot depend on internal rounding. |
| [`z_fi_exch_rate_check.abap`](z_fi_exch_rate_check.abap) | The report's source. Read-only, one program, standard function modules only. |

## The one distinction to carry away

**The system checks that a rate exists. It never checks that the rate is current.**

Everything else on these pages follows from that:

- A monthly load that arrives late is not an error anywhere — postings quietly take last month's rate, and are not re-translated when the new one arrives.
- A test system with one rate from the year it was installed will translate every foreign currency document you send it, in every month, identically.
- So *"is the rate right?"* is a question you have to ask on purpose — before posting, by looking at the valid-from date of what the lookup returns; and after posting, by comparing the document's rate with the table's for the same translation date.

## And one thing to check before maintaining any rate

Look at the **rate type**, not just the rate table. If the rate type has a reference currency, the entries that count are *currency → reference currency*. A carefully maintained direct pair is not read, saves without complaint, and changes nothing.

# Local currency and the parallel currencies of a company code

**Level:** 201 · for FI consultants

**One line:** Every company code has exactly one local currency, and up to two more that are carried on every line item in BSEG — in ECC via OB22, in S/4HANA via FINSC_LEDGER — which is why the choice is nearly impossible to change after go-live.

## The local currency

The local currency is the currency of the legal entity's books: the one its balance sheet is drawn up in and its tax return is filed in. In SAP it is the *company code currency*, currency type 10, set once in the company code global parameters (OBY6) and stored in T001-WAERS. Every line item of every document of the company code carries an amount in it — BSEG-DMBTR, ACDOCA-HSL — translated from the document currency at the rate on the document header, or entered by hand.

Three things follow that are easy to miss:

- **It is a per-company-code choice, not a per-country one.** A US subsidiary can keep its books in EUR if that is what its statutory reporting requires; the country of the company code decides the hard and index-based currencies (types 40 and 50), not the local currency.
- **It is not the account currency.** A G/L account can have its own currency (SKB1-WAERS); if it is not the local currency the account accepts postings in that currency only. Bank accounts in a foreign currency are the usual case.
- **It is not the IFRS functional currency by construction.** IAS 21 defines the functional currency by the economics of the entity; SAP's local currency is whatever was configured. When they differ, the gap is modelled with a parallel currency or a freely defined currency type. See [Group currency and translation](../group_currency_and_translation/README.md).

## Two more, on every line

A company code can carry up to two *additional local currencies*, and the amounts in them go into BSEG-DMBE2 and BSEG-DMBE3 on every line item, with the rate used in BKPF-KURS2 and BKPF-KURS3. Because they are on every line, they are complete: a trial balance in the second local currency is a real trial balance, not a translation of one. That is the whole point of a parallel currency as opposed to a period-end translation.

### In ECC: OB22 and T001A

OB22 maintains T001A, one row per company code with, for each of the second and third local currency:

| Setting | Field (2nd / 3rd) | Meaning |
|---|---|---|
| Currency type | T001A-CURTP / CURTP2 | 30, 40, 50 or 60 (with a valuation view digit, 30 / 31 / 32 …). The key comes from where the type is defined: client, country or company. |
| Valuation | second digit of the type | 0 legal, 1 group, 2 profit center |
| Exchange rate type | T001A-KURST2 / KURST3 | Usually M; a valuation-specific type is possible. |
| Source currency | T001A-CURSR2 / CURSR3 | 1 = translate from the document currency, 2 = translate from the first local currency. |
| Translation date type | T001A-CURDT2 / CURDT3 | 1 = document date, 2 = posting date, 3 = translation date (BKPF-WWERT). |

### In S/4HANA: FINSC_LEDGER

The same settings moved into the ledger configuration. In FINSC_LEDGER, for a ledger and a company code, every currency type the ledger carries is listed with the same three conversion settings (source currency type, exchange rate type, translation date type; KBA 2542937 explains them). On the overview screen of the company code assignment there are three columns on the right, **1st, 2nd and 3rd FI currency**, which pick from the configured types the ones that are also written to BSEG: the 1st is always 10, and the 2nd and 3rd become DMBE2 and DMBE3. A freely defined type cannot be chosen there (KBA 2543240), and a type that is BSEG-relevant in the leading ledger and also configured in a non-leading ledger must be BSEG-relevant there too (SAP Note 2344012).

The rest of the configured types are ACDOCA-only. They are just as complete as the BSEG ones — converted on every line in real time, balanced to zero per entry — but only the newer reports see them. See [Currencies in the Universal Journal](../universal_journal_currencies/README.md).

## Why the source currency matters

Translating the group currency *from the document currency* and *from the local currency* give the same result only if the rates are consistent, and they never quite are: the M rate USD→EUR and the M rate EUR→GBP, multiplied, is not the M rate USD→GBP, and each step rounds. Two practical consequences:

- **Consistency with the group.** A group that translates everything from its local currencies at period end will reconcile more easily to a parallel currency that also translates from the local currency. A group that wants the parallel currency to be the "true" foreign currency amount of the transaction translates from the document currency.
- **Exchange rate differences in the parallel currency.** When a USD item is cleared, the difference in DMBTR is realized in the local currency; the parallel currency amount also has to net to zero, and the difference there is a second difference line, posted with the same account determination but possibly with a different sign, and possibly non-zero when the local one is zero (a EUR item cleared in EUR has no local-currency difference and can still have a group-currency one). See [Exchange rate differences on clearing](../exchange_rate_differences_on_clearing/README.md).

## Manually entered parallel amounts

The second and third local currency amounts can be entered by hand on a document, in the same way as the local currency amount, when the document type allows it. The system then keeps the entered value and does not translate. Parked documents lose a manually entered local amount on posting in some configurations (SAP support content *Manually entered local currency amount of a parked document is overwritten during posting* covers the cases).

## Changing the choice later

Each of these changes has a different cost:

| Change | What it is |
|---|---|
| Add a freely defined currency type to a live company code | Supported since S/4HANA 1809 through the IMG tools under *Financial Accounting Global Settings → Tools → Manage Currencies*; historical data is converted by the tool. SAP Note 2334583. |
| Add a second or third BSEG-relevant currency to a live company code | Not supported by configuration or migration; a conversion project with SAP's or a partner's currency conversion service. |
| Change the exchange rate type or translation date of a parallel currency | Configuration, but the history was translated with the old settings and stays that way (KBA 1700266). |
| Change the local currency itself | A *local currency changeover* project: every open item, balance, asset, cost estimate and Material Ledger record is converted. The euro changeovers (Croatia 2023 being the most recent) are the template. |

See [Introducing, changing and retiring currencies](../introducing_and_changing_currencies/README.md).

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| The local currency | `OBY6`; `T001-WAERS` |
| The parallel currencies in ECC | `OB22`; `SE16N` on `T001A`: currency type, rate type, source currency and translation date type for the 2nd and 3rd currency |
| The parallel currencies in S/4HANA | `FINSC_LEDGER`, *Company Code Settings for the Ledger*: the 1st / 2nd / 3rd FI currency columns |
| The amounts and rates on a document | `SE16N` on `BSEG`: `DMBTR`, `DMBE2`, `DMBE3`; on `BKPF`: `KURSF`, `KURS2`, `KURS3` |
| Source currency and translation date per currency | `FINSC_LEDGER`, *Currency Conversion Settings*; in ECC the `T001A` fields above |
| A difference in the second currency with none in the first | Clear a EUR item in a EUR company code whose group currency is USD after the USD rate moved; read the clearing document in `FB03L` |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory.

## Related pages

- [Currency types](../currency_types/README.md) — what 30, 40, 50 and 60 mean and where their keys come from
- [Currencies in the Universal Journal](../universal_journal_currencies/README.md) — the fields beyond DMBE2 and DMBE3
- [Ledgers and their currencies](../ledgers_and_currencies/README.md) — FINSC_LEDGER in full
- [Exchange rates](../exchange_rates/README.md) — the rate types and translation dates referred to above
- [Introducing, changing and retiring currencies](../introducing_and_changing_currencies/README.md) — what each change costs

Back to the chapter map: [Currencies in SAP](../README.md).

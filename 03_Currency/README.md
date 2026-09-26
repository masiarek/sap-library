# Currencies in SAP

**Level:** 101 → 301 · for FI/CO consultants, ABAP developers and anyone who has to explain an amount

**One line:** An amount in SAP is never a number: it is a number, a currency key, a currency *type* that says which role the amount plays, and a rate with a date that produced it — and almost every currency question is about which of those four was not what you assumed.

## The map

The chapter is one argument in four movements. The first names the objects (keys, types, rates). The second follows one line item through the general ledger and finds a fourth currency on it that nobody asked for. The third widens to the Universal Journal, ledgers, Controlling, the Material Ledger and the group. The fourth is the practical side: code, payments, troubleshooting, change, and the reading list.

### 1. The objects

| # | Page | The question it answers |
|---|---|---|
| 1 | [Currency keys, codes and decimal places](currency_keys_and_decimals/README.md) | Why is 1,000 JPY stored as 10.00, and what do TCURC and TCURX each hold? |
| 2 | [Currency types](currency_types/README.md) | What is the difference between a currency *key* and a currency *type*, and what are 00, 10, 30, 40, 50, 60 and the Z types? |
| 3 | [Local currency and the parallel currencies](local_and_parallel_currencies/README.md) | What does a company code carry on every line, and why is it so hard to change? |
| 4 | [Exchange rates](exchange_rates/README.md) | Where did the rate on this posting come from, and in what order does the system look? Deepened, and confirmed on a system, by the three pages under [FI → Exchange rates](../01_FI/exchange_rates/README.md). |

### 2. One line item in the general ledger

| # | Page | The question it answers |
|---|---|---|
| 5 | [Update currency: PSWSL and PSWBT](update_currency_pswsl/README.md) | Which currency is the G/L *balance* kept in, if not the document currency? |
| 6 | ["Only manage balances in local currency"](only_balances_in_local_currency/README.md) | What does the SKB1-XSALH checkbox change, shown on one open item cleared at two rates? |
| 7 | [Exchange rate differences on clearing](exchange_rate_differences_on_clearing/README.md) | Why did clearing post a line nobody entered, and to which account? |
| 8 | [Foreign currency valuation and translation](foreign_currency_valuation/README.md) | What happens at month end to the items still open, and why does it get reversed? |

### 3. The whole system

| # | Page | The question it answers |
|---|---|---|
| 9 | [Currencies in the Universal Journal](universal_journal_currencies/README.md) | What are WSL, TSL, HSL, KSL, OSL … GSL, and which processes fill them properly? |
| 10 | [Ledgers and their currencies](ledgers_and_currencies/README.md) | How does FINSC_LEDGER tie a ledger, a company code and its currency types together? |
| 11 | [Universal Parallel Accounting](universal_parallel_accounting/README.md) | What changed in S/4HANA 2022 so that every currency is carried by every process? |
| 12 | [Currencies in Controlling](controlling_currencies/README.md) | What are the controlling area currency and the object currency, and what does a cross-company controlling area cost? |
| 13 | [Material Ledger currencies](material_ledger_currencies/README.md) | How does inventory get a second currency and a second valuation? |
| 14 | [Group currency and translation](group_currency_and_translation/README.md) | What is currency type 30, and how does a consolidation translate into it? |

### 4. The practical side

| # | Page | The question it answers |
|---|---|---|
| 15 | [Rounding and the amount field](rounding_and_amount_fields/README.md) | Why must a journal entry balance in every currency, and where does the rounding difference go? |
| 16 | [Currencies in ABAP](abap_currency_handling/README.md) | What do CURR, CUKY, `@Semantics.amount.currencyCode` and `CURRENCY_CONVERSION` each do? |
| 17 | [Payments and currency management](payments_and_currency_management/README.md) | Which account should a foreign-currency payment leave from, and whose rate must it be booked at? |
| 18 | [Reporting and troubleshooting](reporting_and_troubleshooting/README.md) | FS10N and FBL3N disagree; which table do I look in first? |
| 19 | [Introducing, changing and retiring currencies](introducing_and_changing_currencies/README.md) | Why is adding a currency key a table entry and adding a currency type a project? |
| 20 | [Resources](resources/README.md) | The SAP Notes, help pages, books and articles behind the chapter |

## The through-line

Start with a single G/L line item. It has an amount in the currency the document was entered in (BSEG-WRBTR in BKPF-WAERS). It has the same amount in the company code's local currency (BSEG-DMBTR in T001-WAERS), and possibly in two more (DMBE2, DMBE3). Those are the currencies everyone knows about. The line also has a fourth pair, BSEG-PSWSL and BSEG-PSWBT, the *update currency*, and it is that pair, not the document currency, that the account balance is kept in. Whether it equals the document currency or the local currency is decided by one checkbox on the G/L account master, SKB1-XSALH, and the answer changes what a clearing does, whether an exchange rate difference is posted, and why FS10N and FBL3N can appear to disagree.

Widen the view and the same pattern repeats at every level. A company code has one local currency and up to two parallel ones; a ledger lists which currency *types* it carries and how each is converted; the Universal Journal has room for thirteen amount fields on every line, of which only three reach BSEG; Controlling and the Material Ledger have currencies of their own that in S/4HANA are just more of those fields; the group has one currency that everything is translated into. At each level the questions are the same: which key, which type, which rate, which date, and what happens when the amounts in one currency net to zero and the amounts in another do not.

## A note on the code

The programs in this chapter are stdlib Python, and they simulate SAP's arithmetic, not SAP. They use `decimal` because SAP's amount field is a packed decimal, and they follow the rules the pages quote (ratio factors, commercial rounding, decimal shifting from TCURX, the update-currency test from SAPMF05A) closely enough that the numbers they print are the numbers the screenshots in the source documents show: 10,000 JPY with the flag on, 11,000 without, and a 1,000 JPY difference that has to be charged off.

## Sources

The chapter draws on the SAP Help support-content pages on the update currency, SAP Note 2344012 (Currencies in Universal Journal), the ABAP keyword documentation glossary entries for the currency key and currency field, and a set of working notes on multicurrency architecture, listed in full under [Resources](resources/README.md).

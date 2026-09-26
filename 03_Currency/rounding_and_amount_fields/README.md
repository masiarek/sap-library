# Rounding, rounding differences and the amount field

**Level:** 201 · for developers and FI consultants

**One line:** Money in SAP is a packed decimal with the currency's decimal places, rounded commercially at every conversion, and a journal entry must balance to zero in *every* currency field — so the rounding difference is a real posting, not a display artefact.

## The amount field

An amount in the ABAP Dictionary is of type CURR: a packed decimal (BCD, ABAP type `p`) with a fixed number of decimal places, which for every SAP-delivered amount is two. The classic length is 13 digits, that is 11 before the point and 2 after, so the largest amount BSEG-DMBTR could hold was 99,999,999,999.99 in the currency's units — or, because a zero-decimal currency is stored shifted, a hundred times that in JPY. Hyperinflation currencies and large groups reporting in IDR or VND hit the ceiling, and S/4HANA 1809 introduced the **amount field length extension** (AFLE): currency amount fields of length 9 to 22 became 23 digits with 2 decimals. It is activated once per system (transaction FLETS, IMG *Cross-Application Components → General Application Functions → Field Length Extension*), cannot be reverted, cannot be combined with Central Finance, and every custom program with a `TYPE p DECIMALS 2` local variable or a hard-coded length is a candidate for overflow (SAP Notes 2628654 as the S4TWL master note, 2610650 for the code adaptations, 2601956 for the restrictions; the ATC variants S4HANA_READINESS_* find the code). In S/4HANA Cloud the extension is not available and an amount over 13 digits is simply refused (message AFLE007, KBAs 3509051, 3584195, 3613316).

Type CURR must always be paired with a currency key (type CUKY) through the reference field of the Dictionary structure; see [Currencies in ABAP](../abap_currency_handling/README.md).

## Commercial rounding

Every conversion in SAP rounds *commercially*: half away from zero, to the number of decimals of the target currency (TCURX, default two). ABAP's `round( )` function and the `ROUND` function module do the same by default; the ABAP SQL and CDS `CURRENCY_CONVERSION` functions round on the database with a `round` parameter and the documentation warns that their result "cannot be expected" to equal the function modules' in every case because part of the arithmetic runs under the database's rules. Two rules of thumb that are not SAP's but that the program below justifies:

- Banker's rounding (half to even), the default of Python's `round()` and of `Decimal` with `ROUND_HALF_EVEN`, disagrees with SAP on exactly the halves, so a re-implementation of a posted amount in another language will be a cent off on those lines and nowhere else.
- Binary floating point (`float`, ABAP type `f`) cannot represent most decimal amounts at all; 0.1 + 0.2 is not 0.3. It is never the right type for money, and a `TYPE f` intermediate in an amount calculation is a defect even when the output happens to look right.

## Rounding rules per currency

Some currencies are not settled in their smallest decimal. Swiss francs are paid in cash to five centimes, and invoices in some countries are legally rounded to the nearest unit. **OB90** (*Define Rounding Rules for Currencies*, table T001R) sets a rounding unit per company code and currency, and the amount to be paid or invoiced is rounded to that unit, with the difference going to the rounding differences account (OBA1, transaction key RDF; a separate account determination, *not* an exchange rate difference). The same mechanism rounds cash discount, tax and payment amounts in the payment program.

## Balance zero per currency

A document balances in its document currency by construction: the user cannot save it otherwise. It has to balance in every other currency field as well, and after converting each line separately and rounding each result to two decimals it usually does not, by a cent or two. The accounting interface guarantees balance zero per journal entry in every currency (it is the second row of SAP Note 2344012's matrix, supported for every currency) by adjusting the rounding difference onto one line item of the document, so that a line's local-currency amount can differ by a cent from its own converted document-currency amount. There is no separate rounding line and no account for it in the normal case; the cent is inside a line. The program below shows the mechanism.

Where a rounding difference *is* posted to an account:

- **Clearing.** Items in the same currency whose local amounts differ by less than the tolerance in OBA4/OBA3 (tolerance groups) are cleared and the difference posted to the account for *payment differences* or, when it comes from currency arithmetic, exchange rate differences.
- **Tax.** Tax computed per line and per document differ by rounding; the tax procedure decides which (the *tax rounding* settings in the country and the procedure), and the difference lands on the tax account.
- **Material Ledger and allocations.** A periodic unit price times a quantity rarely reproduces the value it was derived from; the ML posts the remainder as a price difference or rounding, and CO allocations distribute the sender's amount over receivers with the last receiver taking the rounding remainder (KBA 3300701 is the version where the object currency then does not balance).
- **Artificial currencies** with more than two decimals (KBA 2169454) and group reporting's translation difference item (KBA 3756349) are the same problem in other clothes.

## What the program prints

<!-- output:currency_rounding -->
*Verified output of [`currency_rounding.py`](examples/currency_rounding.py) — regenerated by `tools/run_examples.py`, never hand-typed.*

```text
1. COMMERCIAL ROUNDING IS NOT PYTHON'S DEFAULT
   value     Python round()   Decimal HALF_EVEN   SAP (HALF_UP, away from zero)
   2.345           2.35            2.34            2.35
   2.355           2.35            2.36            2.36
   -2.345         -2.35           -2.34           -2.35
   0.125           0.12            0.12            0.13
   Two of the four disagree. A report that re-derives a posted amount in another
   language will be a cent off exactly on the halves.

2. ROUND TO THE CURRENCY'S DECIMALS, NOT TO TWO
       1234.5 ->       1235 JPY   (0 decimals)
      1.23456 ->      1.235 KWD   (3 decimals)
        0.005 ->       0.01 EUR   (2 decimals)

3. A ROUNDING RULE PER CURRENCY (OB90): CHF TO THE NEAREST 0.05
     12.32 CHF ->   12.30 CHF
     12.33 CHF ->   12.35 CHF
     12.37 CHF ->   12.35 CHF
     12.38 CHF ->   12.40 CHF
     -7.11 CHF ->   -7.10 CHF
   Used for cash payments and invoices where the smallest coin is five centimes; the
   difference goes to the rounding differences account.

4. SPLIT A TOTAL OVER LINES AND THE PARTS NO LONGER ADD UP
   100.00 EUR over 3 lines: each 33.33, sum 99.99, short by 0.01
   The same thing happens to a document translated line by line into a parallel currency:
   lines 33.33, 33.33, 33.34 EUR x 1.0875 -> 36.25, 36.25, 36.26 USD, sum 108.76;
   the total converted at once is 108.75. Difference: -0.01.
   The accounting interface puts that cent on one line so the entry balances in USD too.

5. FLOAT IS THE WRONG TYPE FOR MONEY
   0.1 + 0.2 == 0.3                 False
   0.01 added a hundred times       1.0000000000000007
   Decimal('0.01') * 100            1.00
   ABAP's type P (packed) and DECFLOAT34 are decimal; type F is binary floating point,
   which is why CURR fields are packed and why a float in an amount calculation is a defect.

6. THE AMOUNT FIELD HAS A SIZE
   ECC      CURR length 13, 2 decimals: up to 99,999,999,999.99 in the currency's units
   S/4HANA  CURR length 23, 2 decimals: up to 999,999,999,999,999,999,999.99   (amount field length extension)
   For a 0-decimal currency the stored value is divided by 100, so the ceiling in JPY is
   9,999,999,999,999 JPY in ECC. Hyperinflation currencies are where it used to bind.
```
<!-- /output -->

Run it yourself from the folder that holds it:

```bash
cd 03_Currency/rounding_and_amount_fields/examples
python3 currency_rounding.py
```

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| The decimals rounding targets | `OY04`; `TCURX` |
| Commercial rounding | `SE38` test of `round( )` on a half value with and without `mode`; `SE37` test of `ROUND` |
| A rounding rule per currency | `OB90`; `SE16N` on `T001R`; a CHF invoice for 12.33 and its payment amount |
| Balance zero per currency | `SE16N` on `ACDOCA` for one document: sum `HSL` and `KSL`, find the adjusted line |
| The amount field's length | `SE11` on the data element behind `BSEG-DMBTR` (13 or 23 digits); `FLETS` for the extension's status |
| The rounding differences account | The automatic postings for rounding differences (transaction key RDF) in the same IMG area as `OBA1` |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory.

## Related pages

- [Currency keys, codes and decimal places](../currency_keys_and_decimals/README.md) — the decimals the rounding targets
- [Currencies in ABAP](../abap_currency_handling/README.md) — CURR, CUKY, `round( )`, AFLE in code
- [Currencies in the Universal Journal](../universal_journal_currencies/README.md) — balance zero in every field
- [Exchange rates](../exchange_rates/README.md) — the five-decimal rate the conversion multiplies by

Back to the chapter map: [Currencies in SAP](../README.md).

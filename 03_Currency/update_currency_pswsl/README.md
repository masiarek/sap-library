# Update currency: BSEG-PSWSL and BSEG-PSWBT

**Level:** 301 · for anyone who has seen FS10N and FBL3N disagree

**One line:** Besides the document currency and the local currencies, every G/L line carries a fourth pair, the *update currency* and its amount, and it is this pair — not the document currency — that the balance tables GLT0, FAGLFLEXT and ACDOCA-TSL are kept in.

## Four pairs on one line

A G/L line item in BSEG carries its amount four times over:

| Pair | Currency key | Amount | What it is |
|---|---|---|---|
| Document currency | BKPF-WAERS (header) | BSEG-WRBTR | The currency the document was entered in. Same for every line of the document. |
| Local currency | T001-WAERS (company code) | BSEG-DMBTR | The company code currency. Same for every line of every document of the company code. |
| Parallel currencies | configured per company code | BSEG-DMBE2, DMBE3 | The second and third local currency, if configured. |
| **Update currency** | **BSEG-PSWSL** | **BSEG-PSWBT** | The currency in which *this line* updates the balance of its account. **Can differ from line to line.** |

The first three are well known. The fourth is the one nobody asks for, and it is the one the general ledger's transaction figures are kept in: the per-account, per-period, per-currency totals that FS10N, FAGLB03 and the financial statement read.

## Why a balance needs an update currency

A line item can afford to remember every currency. A *balance* cannot: it is one number per account and period, and "the balance of account 31010 in the first period" has to be in some currency. SAP keeps two totals per account: one in local currency (GLT0-HSL, FAGLFLEXT-HSL, ACDOCA-HSL) and one in *transaction* currency, per currency (GLT0-TSL, FAGLFLEXT-TSL, ACDOCA-TSL, with the key in RTCUR). The second is what lets a bank account in USD show a USD balance and a supplier account show what is owed in each currency.

For most accounts that per-currency total is simply the document currency amount. But for some accounts a per-currency total is useless or harmful: a cash discount clearing account, a GR/IR account, an expense account posted in thirty currencies. For those the balance is kept in local currency only, and every line updates it with its local-currency amount. So each line has to say which of the two it did, and that is PSWSL: the currency in which this line updated the balance, and PSWBT, the amount it updated it by. SAP Note 391532 (*Update currency in line items*) is the canonical description.

## The rule

The decision is made per G/L account, by the *Only balances in local currency* indicator on the company code segment of the account master (SKB1-XSALH, [its own page](../only_balances_in_local_currency/README.md)), and it comes down to three lines of logic in SAPMF05A, paraphrased here:

```abap
IF skb1-xsalh = space.
  bseg-pswsl = bkpf-waers.      " balances per document currency
  bseg-pswbt = bseg-wrbtr.
ELSE.
  bseg-pswsl = t001-waers.      " balances in local currency only
  bseg-pswbt = bseg-dmbtr.
ENDIF.
```

Sub-ledger accounts (customers and vendors) always take the document currency: the indicator cannot be set on a reconciliation account (KBA 3270987 is the message you get when you try), because a customer's open items have to be tracked in the currency they were invoiced in.

## The exception: clearing

An account managed on an open item basis has to satisfy a second invariant: its balance must always equal the sum of its open items. When the items are cleared, the balance must return to zero — in local currency, and *in every update currency*. Now clear a EUR invoice with a USD payment on such an account. The payment line's document currency is USD; if it updated a USD bucket, the EUR bucket would keep the invoice forever and the USD bucket would hold the payment forever, and the account would never balance per currency although it has no open items.

So a line posted **in the course of a clearing** takes the update currency of the item it clears, not its own document currency: the USD payment line gets PSWSL = EUR and PSWBT = the EUR amount of the invoice. When one clearing settles items in several update currencies, the clearing document contains *additional lines*, one per update currency, so that every bucket returns to zero. SAP Note 391532 and the help-portal page on the logic of PSWBT describe exactly this; the program below reproduces the three scenarios of that page.

Two corollaries that generate tickets:

- **Resetting such a clearing (FBRA) must also reverse the document.** An open item on a foreign-currency-managed account whose update currency amount differs from its document currency amount makes no sense, so FBRA refuses *only resetting* when an exchange rate difference was posted (KBA 1796941) and forces *reset and reverse*.
- **A document without PSWSL cannot be cleared.** Message F1806 (KBA 1906780) is the symptom of a line, usually created by an interface, that never went through the FORM above.

## The exchange rate difference line follows the same test

When a clearing produces an exchange rate difference, the difference line is created in FORM KDFTAB_ABARBEITEN of SAPMF05A, and its update currency is decided by the same indicator, this time of the *difference account*:

```abap
IF skb1-xsalh = space.
  bseg-pswsl = kdbtab-waers.    " document currency of the ITEM BEING CLEARED
ELSE.
  bseg-pswsl = t001-waers.
ENDIF.
...
IF skb1-xsalh = space.
  bseg-pswbt = bseg-wrbtr.
ELSE.
  bseg-pswbt = bseg-dmbtr.
ENDIF.
```

The thing to notice is `kdbtab-waers`: not the currency of the clearing document, but of the open item. The SAP support page *Update currency (BSEG-PSWSL) in exchange rate difference line item* is a two-paragraph statement of this and nothing else. See [Exchange rate differences on clearing](../exchange_rate_differences_on_clearing/README.md).

## What the program prints

<!-- output:update_currency_logic -->
*Verified output of [`update_currency_logic.py`](examples/update_currency_logic.py) — regenerated by `tools/run_examples.py`, never hand-typed.*

```text
1. SCENARIO 1: ACCOUNT MANAGED IN LOCAL CURRENCY ONLY (SKB1-XSALH = 'X')
   post 120 USD = 100 EUR to 31010:
     account  WAERS  WRBTR      HWAER  DMBTR      PSWSL  PSWBT      -> TSL (balance)   HSL
     31010    USD       120.00  EUR       100.00  EUR       100.00  ->    100.00 EUR     100.00 EUR
   The update currency is EUR: the balance of 31010 is kept in EUR only, and TSL = HSL.

2. SCENARIO 2: THE SAME POSTING, FLAG OFF (BALANCES PER CURRENCY)
   post 120 USD = 100 EUR to 31010:
     account  WAERS  WRBTR      HWAER  DMBTR      PSWSL  PSWBT      -> TSL (balance)   HSL
     31010    USD       120.00  EUR       100.00  USD       120.00  ->    120.00 USD     100.00 EUR
   Now the balance of 31010 has a USD bucket: FS10N / FAGLB03 show 120 USD and 100 EUR.

3. SCENARIO 3: A CLEARING INHERITS THE UPDATE CURRENCY OF THE ITEM IT CLEARS
   invoice in EUR, then a payment document in USD that clears it:
     account  WAERS  WRBTR      HWAER  DMBTR      PSWSL  PSWBT      -> TSL (balance)   HSL
     31010    EUR      -100.00  EUR      -100.00  EUR      -100.00  ->   -100.00 EUR    -100.00 EUR
     31010    USD       120.00  EUR       100.00  EUR       100.00  ->    100.00 EUR     100.00 EUR
   balance of 31010 in update currency EUR: 0.00   USD bucket: none
   The payment line says PSWSL = EUR although its document currency is USD. That is
   normal: an open-item account's balance must be zero per update currency once its
   items are cleared, so the clearing line is booked in the *cleared* item's currency.

4. THE SAME TEST DECIDES THE EXCHANGE RATE DIFFERENCE LINE (FORM KDFTAB_ABARBEITEN)
   IF skb1-xsalh = space.  bseg-pswsl = kdbtab-waers.  bseg-pswbt = bseg-wrbtr.
   ELSE.                   bseg-pswsl = t001-waers.    bseg-pswbt = bseg-dmbtr.
   kdbtab-waers is the document currency of the ITEM BEING CLEARED, not of the clearing.
   A USD item is cleared by a USD payment at a worse rate; the difference line is
   -9.60 USD = -8.00 EUR on account KDF01:
     KDF01 with XSALH =  :  PSWSL USD  PSWBT -9.60
     KDF01 with XSALH = X:  PSWSL EUR  PSWBT -8.00

5. WHY FS10N AND FBL3N CAN SEEM TO DISAGREE
   FS10N / FAGLB03, currency filter 'EUR', reads TSL per update currency:
     31010 EUR: 0.00
   Drill down and the list contains a document whose *document* currency is USD.
   FBL3N, filtered on document currency USD, shows that same line as 120.00 USD.
   Neither is wrong: one is keyed by PSWSL, the other by WAERS.

6. WHERE THE PAIR ENDS UP IN EACH GENERATION OF THE GENERAL LEDGER
   classic G/L   GLT0-TSL      = PSWBT      GLT0-HSL      = DMBTR
   new G/L       FAGLFLEXT-TSL = PSWBT      FAGLFLEXT-HSL = DMBTR    (RTCUR = PSWSL, RWCUR = WAERS)
   S/4HANA       ACDOCA-TSL    = PSWBT      ACDOCA-HSL    = DMBTR    (WSL = WRBTR is the document currency)
   TSL is 'amount in balance transaction currency': the currency the balance is kept in.
```
<!-- /output -->

Run it yourself from the folder that holds it:

```bash
cd 03_Currency/update_currency_pswsl/examples
python3 update_currency_logic.py
```

## Where the pair ends up

| Ledger generation | Balance in transaction currency | Balance in local currency | Document currency amount |
|---|---|---|---|
| Classic G/L | GLT0-TSL ← PSWBT (key: GLT0-RTCUR ← PSWSL) | GLT0-HSL ← DMBTR | not in GLT0 |
| New G/L | FAGLFLEXT-TSL ← PSWBT (RTCUR) | FAGLFLEXT-HSL ← DMBTR | FAGLFLEXA-WSL ← WRBTR (RWCUR) |
| Universal Journal | ACDOCA-TSL ← PSWBT (RTCUR) | ACDOCA-HSL ← DMBTR | ACDOCA-WSL ← WRBTR (RWCUR) |

ACDOCA calls TSL *amount in balance transaction currency* and WSL *amount in transaction currency*, and SAP Note 2344012 spells out the difference: WSL is the original currency and is not contained in balances, because amounts in different currencies cannot be aggregated; TSL is the amount converted to the currency the G/L account is kept in, so that aggregation on account level is possible. RTCUR is not the document currency, and KBA 3651272 (*ACDOCA-RTCUR is updated incorrectly with LC*) is what it looks like when the rule misfires.

## The symptoms this explains

All of these are the update currency at work, not errors, and each has a first place to look on the [troubleshooting page](../reporting_and_troubleshooting/README.md):

- a clearing document contains lines nobody entered;
- FBL3N filtered on document currency USD shows lines whose *General ledger currency* on FB03 is EUR;
- FS10N or FAGLB03 with currency EUR, drilled down, lists documents whose document currency is not EUR;
- line items (FBL3N) and balances (FS10N) for the same account and currency appear to differ;
- FB03 shows an unexpected currency in the *General ledger currency* field (KBA 2219419).

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| The fourth pair on a line | `SE16N` on `BSEG`: `PSWSL` and `PSWBT` beside `WAERS`, `WRBTR`, `DMBTR`; `FB03` line item detail, *General ledger currency* |
| The indicator that decides it | `FS03`, *Control data*, *Only balances in local currency*; `SKB1-XSALH` |
| Balances are kept per update currency | `FS10N` or `FAGLB03` with a currency; `SE16N` on `GLT0` / `FAGLFLEXT` (`TSL`, `RTCUR`) or `ACDOCA` (`TSL`, `RTCUR`) |
| A clearing line inherits the cleared item's update currency | Post a EUR invoice to an open-item account without the indicator, clear it with a USD payment, read `PSWSL` on the payment line |
| Additional lines in a clearing | Clear items in two update currencies in one document and count the lines in `FB03` |
| The difference line follows the difference account's indicator | `FB03` on the exchange rate difference line of a clearing; `FS03` on the KDF account |
| The logic itself | `SE38`, `SAPMF05A`, search the includes for `xsalh`; FORM `KDFTAB_ABARBEITEN` |

## Provenance

Written from working FI knowledge, from SAP's support-content pages on the update currency and from the working document that quotes the SAPMF05A excerpts. The three scenarios are those of SAP's page *How the logic of the GL update currency amount (BSEG-PSWBT) works*; the ABAP excerpts were not re-read from a system for this page. Message numbers are quoted from the titles of the cited KBAs.

## Related pages

- ["Only manage balances in local currency"](../only_balances_in_local_currency/README.md) — the indicator, with the JPY example
- [Exchange rate differences on clearing](../exchange_rate_differences_on_clearing/README.md) — the difference line and its update currency
- [Currencies in the Universal Journal](../universal_journal_currencies/README.md) — TSL among the other amount fields
- [Reporting and troubleshooting](../reporting_and_troubleshooting/README.md) — the tickets this page answers

Back to the chapter map: [Currencies in SAP](../README.md).

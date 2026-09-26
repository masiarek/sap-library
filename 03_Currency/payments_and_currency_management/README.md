# Currency management in payments and treasury

**Level:** 101 · for treasury and accounts payable

**One line:** Every payment in a currency other than the paying account's is an FX deal in disguise: it costs a spread, it carries a rate risk until it settles, and in some countries it has to be booked at the central bank's rate whether the bank charged that rate or not.

## Pay from an account in the payment's currency

When a company that deals internationally pays a USD invoice from a EUR bank account, the bank converts at its own rate on the day and charges a spread, and the company's books record the payment at whatever rate the posting used. Three numbers are now in play — the invoice rate, the posting rate and the bank's rate — and the gap between them is cost that is easy not to see. The first rule of currency management is therefore to **pay from an account held in the currency of the payment**: a USD payable is paid from a USD account, funded in bulk on the company's own terms rather than deal by deal on the bank's.

In SAP that is a configuration of the payment program (F110, FBZP):

- the **house bank account** has a currency (its G/L account's SKB1-WAERS restricts postings to that currency);
- the **bank determination** per paying company code lists, per payment method and *currency*, which house bank account to pay from, in ranking order, with an available amount per account and currency;
- the **payment method** can be restricted to certain currencies, and the vendor's payment currency defaults from the invoice.

A payment run selects the bank account for the payment's currency first; only when none is available does it fall through to an account in another currency, and that fall-through should be a deliberate exception, not a default.

## Exotic currencies

For a currency the company pays in rarely (an occasional supplier in a currency with thin markets and high spreads), holding an account is a cost of its own: minimum balances, account fees, idle cash, and a balance that then has to be valuated every month. The sensible rule is to **pay such currencies from an operational account in a major currency**, accept the bank's conversion, and **monitor the volume and the cost**: a report of payments by currency against the bank's charges shows the point at which the business in that currency is large enough that opening an account is cheaper than paying spreads. That report is a query on the payment documents (currency, amount, house bank, and the realized exchange rate differences posted on clearing) joined to the bank statement's charges.

## Fees, spreads and the rate the bank used

The bank statement returns the payment at the rate the bank applied. Where it differs from the posting rate, the difference is realized on clearing the bank clearing account against the statement item, with the account determination in OBA1 (see [Exchange rate differences on clearing](../exchange_rate_differences_on_clearing/README.md)); KBA 1920513 covers the assignment case. Explicit fees come back as separate statement items and are posted to bank charges by the statement's posting rules. The invisible part is the spread inside the rate, and the only way to see it is to compare the bank's rate with a reference rate of the same day (the ECB reference rate, or the rate type the treasury uses), which is a report nobody delivers and every treasury should have.

## Central-bank mandated rates

In some jurisdictions the law says which rate a foreign-currency transaction is booked at: the national bank's official rate of the day (or the previous business day), not the bank's rate and not a market data provider's. The purpose is consistency, transparency and compliance with local accounting and tax rules, and the penalty for using another rate can be an adjustment of the tax base or a finding in the audit. Poland (NBP), the Czech Republic (CNB), Hungary (MNB), Turkey (TCMB), Russia (CBR), India (RBI and the customs rates) and many others have such rules for some or all postings, invoices or VAT amounts.

In SAP the rule is implemented, not remembered:

- a **dedicated exchange rate type** loaded daily from the central bank's publication (see [Exchange rates](../exchange_rates/README.md) for the import options: file, BAPI, datafeed, SAP Market Rates Management with a central-bank source);
- that rate type assigned where the law requires it: the document type (OBA7), the parallel currency's conversion settings, the tax procedure's rate for VAT in local currency, the valuation method for the statutory ledger;
- rate type M kept for the rest, so that the group's management view and the statutory view can differ where they must.

Where the law applies to the *tax* amount only (VAT must be shown in local currency at the official rate even when the invoice is in EUR), the tax rate type and the *translation date for tax* on the document are the relevant settings, and the difference between the tax at the official rate and the tax at the document rate is posted as an exchange rate difference on the tax account.

## Hedging and exposure

Treasury and Risk Management (FSCM-TRM) takes the currency question one step further: forward contracts, options and swaps against the FX exposure, with hedge accounting under IFRS 9 or ASC 815, and the *exposure management* that gathers planned and firm cash flows in foreign currency from purchase orders, sales orders and the liquidity forecast. The foreign currency valuation of the hedged item can then use the hedged rate (OB59, *exchange hedging*; KBAs 1714718 and 2561409). None of this changes the ledger's currencies; it changes which rate the valuation uses and which P&L line the difference goes to.

## In-house cash and payment factories

A group with an in-house bank (SAP In-House Cash) or a payment factory pays subsidiaries' invoices centrally from accounts held per currency at group level, nets intercompany balances per currency, and books the FX once, in bulk, at the centre. The subsidiaries' books see an intercompany settlement in their own currency, and the currency accounts, the spreads and the central-bank rules move to the centre, which is the point. Cash management (*Cash Position*, *Liquidity Forecast*) shows balances per currency across the group, which is where the "should we open an account in this currency" question gets its data.

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| A bank account has a currency | `FI12` (or the *Manage Bank Accounts* app); `FS03` on the bank's G/L account, currency |
| Bank determination per currency | `FBZP`, *Bank Determination*: ranking order and bank accounts by payment method and currency |
| Payment methods restrict currencies | `FBZP`, payment methods per country and company code, permitted currencies |
| The bank's rate reaches the books at clearing | `FEBAN` (or *Reprocess Bank Statement Items*) and the clearing document's difference line in `FB03` |
| A dedicated rate type where the law requires one | `OB07` for the type, `OB08` for its rows, `OBA7` and `FINSC_LEDGER` for where it is used |
| Balances per currency across the group | *Cash Position* and *Liquidity Forecast* by currency |

## Provenance

Written from working treasury and FI knowledge and from the working document on currency management in payments this page grew from; the regulatory statements about central-bank rates are general and the countries named are examples, not a legal survey. Nothing was confirmed against a named system for this page.

## Related pages

- [Exchange rates](../exchange_rates/README.md) — rate types, imports and central-bank feeds
- [Exchange rate differences on clearing](../exchange_rate_differences_on_clearing/README.md) — the realized cost of a mismatch
- [Foreign currency valuation](../foreign_currency_valuation/README.md) — the monthly cost of a currency balance
- [Currency keys, codes and decimal places](../currency_keys_and_decimals/README.md) — bank interfaces send ISO codes and external amounts

Back to the chapter map: [Currencies in SAP](../README.md).

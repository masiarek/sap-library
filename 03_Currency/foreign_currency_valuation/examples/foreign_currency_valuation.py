#!/usr/bin/env python3
"""Foreign currency valuation of one open item across three month-ends, then payment.

Run:  python3 foreign_currency_valuation.py

A vendor invoice for 10,000 USD is posted to a EUR company code at 0.90, so
it is a liability of 9,000 EUR. Nothing about the invoice changes, but the
rate does, and at each period end the liability is restated at the closing
rate. The restatement is an *unrealized* gain or loss: the invoice has not
been paid, so the number is provisional, and the valuation method decides
what happens to it next: reversed the next day (the classic reset), or
carried and only the change posted (the delta logic). When the invoice is
finally paid the *realized* difference is booked, and over the whole life of
the item the P&L is the same under every method: payment minus original.
What differs is when it is recognised and in which account.

Stdlib only. Decimal, commercial rounding, EUR with two decimals.
"""

from decimal import ROUND_HALF_UP, Decimal

D = Decimal
CENT = D("0.01")


def eur(x: D) -> D:
    return x.quantize(CENT, rounding=ROUND_HALF_UP)


def main() -> None:
    usd = D("10000")
    posting_rate = D("0.90")
    original_eur = eur(usd * posting_rate)
    closings = [("31.01", D("0.92")), ("28.02", D("0.88")), ("31.03", D("0.91"))]
    payment_rate = D("0.89")

    print("1. THE OPEN ITEM AND THE RATES")
    print(f"   vendor invoice 10,000 USD at {posting_rate} = {original_eur} EUR (BSEG-DMBTR), open until April")
    print("   closing rates: " + ", ".join(f"{d} {r}" for d, r in closings) + f";  paid 10.04 at {payment_rate}")
    print("   For a liability, a higher EUR value is a loss and a lower one is a gain.")
    print()

    print("2. VALUATION WITH RESET (POST ON THE KEY DATE, REVERSE ON THE NEXT DAY)")
    print("   Each run compares the closing value with the ORIGINAL amount, because the previous")
    print("   valuation was reversed on the first day of the period.")
    print("   key date   closing value   vs original   posting on key date            reversed on")
    for d, r in closings:
        value = eur(usd * r)
        diff = value - original_eur
        kind = "unrealized loss" if diff > 0 else "unrealized gain"
        print(f"   {d}      {value:>9} EUR   {diff:>+9}     {kind:<16} {abs(diff):>7} EUR   next day")
    print("   Accounts (OBA1, transaction KDF for the reconciliation account): the P&L side goes to")
    print("   the unrealized loss / gain account, the balance-sheet side to the adjustment account,")
    print("   so the vendor account itself is never touched.")
    print()

    print("3. VALUATION WITH DELTA LOGIC (NO REVERSAL; POST ONLY THE CHANGE)")
    print("   Each run compares the closing value with the LAST VALUATED amount; the item keeps a")
    print("   running valuation difference (BSEG-BDIFF in classic terms).")
    print("   key date   closing value   last valued   delta posted   cumulative BDIFF")
    last = original_eur
    cumulative = D(0)
    for d, r in closings:
        value = eur(usd * r)
        delta = value - last
        cumulative += delta
        print(f"   {d}      {value:>9} EUR   {last:>9}     {delta:>+9}      {cumulative:>+9}")
        last = value
    print("   Same balance-sheet value at every key date as in section 2; fewer postings, and the")
    print("   difference stays on the item until it is cleared.")
    print()

    print("4. THE LOWEST VALUE PRINCIPLE: ONLY VALUATE IN THE DIRECTION OF PRUDENCE")
    print("   For a liability, 'lowest value' means: post the loss, never the gain (the liability")
    print("   may go up in the books, not down). 'Always valuate' posts both directions.")
    print("   key date   diff vs original   always valuate   lowest value principle")
    for d, r in closings:
        diff = eur(usd * r) - original_eur
        prudent = diff if diff > 0 else D(0)
        print(f"   {d}      {diff:>+9}          {diff:>+9}         {prudent:>+9}")
    print("   'Strict lowest value' adds: once written up, do not write back down below the")
    print("   original in later runs either. 'Revalue only' is the mirror for assets.")
    print()

    print("5. PAYMENT ON 10.04 AT 0.89: THE REALIZED DIFFERENCE, AND THE LIFETIME P&L")
    paid_eur = eur(usd * payment_rate)
    realized = paid_eur - original_eur
    print(f"   paid {paid_eur} EUR for an item booked at {original_eur} EUR: realized {'gain' if realized < 0 else 'loss'} {abs(realized)} EUR")
    print("   Under reset, the March valuation was already reversed on 01.04, so the realized line")
    print("   is the whole story: -100.00 EUR gain to the realized gain account (KDF).")
    print("   Under delta logic, the item still carries BDIFF +100.00 from March; clearing reverses")
    print("   that (+100.00 back out of unrealized) and posts the realized -100.00.")
    print("   lifetime P&L, any method:  payment - original = "
          f"{paid_eur} - {original_eur} = {realized:+} EUR")
    print()

    print("6. TRANSLATION IS NOT VALUATION")
    group_rate_avg, group_rate_close = D("1.08"), D("1.12")   # EUR -> USD, for a USD group currency
    print("   Valuation restates ITEMS in a foreign currency into the local currency (FAGL_FC_VAL).")
    print("   Translation restates whole BALANCES from the local currency into another currency")
    print("   (FAGL_FC_TRANS, or the group's consolidation), with different rates per account type:")
    liability_eur = eur(usd * closings[-1][1])
    print(f"     liability {liability_eur} EUR at closing rate {group_rate_close} = {eur(liability_eur * group_rate_close)} USD group currency")
    expense_eur = original_eur
    print(f"     expense   {expense_eur} EUR at average rate {group_rate_avg} = {eur(expense_eur * group_rate_avg)} USD group currency")
    print("   The two rates leave a gap that is not anyone's gain or loss: the translation difference,")
    print("   which goes to equity (the currency translation adjustment).")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Rounding money the way SAP does, and the differences it leaves behind.

Run:  python3 currency_rounding.py

An amount in SAP is a packed decimal with the decimals of its currency, and
every conversion rounds *commercially*: half away from zero, to the target
currency's decimals. Python's default is banker's rounding, and a float is
not a decimal at all, so a program that reproduces SAP's numbers has to say
so explicitly. (The float section adds 0.01 in a loop rather than with sum(),
because Python 3.12's sum() quietly compensates float rounding error and
would hide the point on newer interpreters.) The rest of the program is about what rounding leaves behind:
a total split across lines that no longer adds up, a rule that rounds Swiss
francs to five centimes, and the size of the amount field itself.

Stdlib only.
"""

from decimal import ROUND_HALF_EVEN, ROUND_HALF_UP, Decimal, getcontext

D = Decimal
TCURX = {"JPY": 0, "KWD": 3}


def sap_round(amount: D, key: str) -> D:
    """Commercial rounding to the currency's decimals: what ABAP's ROUND and every conversion do."""
    return amount.quantize(D(1).scaleb(-TCURX.get(key, 2)), rounding=ROUND_HALF_UP)


def round_to_unit(amount: D, unit: D) -> D:
    """A rounding rule from OB90: round to the nearest multiple of `unit` (e.g. CHF 0.05)."""
    return (amount / unit).quantize(D(1), rounding=ROUND_HALF_UP) * unit


def main() -> None:
    print("1. COMMERCIAL ROUNDING IS NOT PYTHON'S DEFAULT")
    print("   value     Python round()   Decimal HALF_EVEN   SAP (HALF_UP, away from zero)")
    for v in ("2.345", "2.355", "-2.345", "0.125"):
        d = D(v)
        py = round(float(v), 2)
        even = d.quantize(D("0.01"), rounding=ROUND_HALF_EVEN)
        sap = d.quantize(D("0.01"), rounding=ROUND_HALF_UP)
        print(f"   {v:<8}  {py:>10}   {even:>13}   {sap:>13}")
    print("   Two of the four disagree. A report that re-derives a posted amount in another")
    print("   language will be a cent off exactly on the halves.")
    print()

    print("2. ROUND TO THE CURRENCY'S DECIMALS, NOT TO TWO")
    for amount, key in ((D("1234.5"), "JPY"), (D("1.23456"), "KWD"), (D("0.005"), "EUR")):
        print(f"   {amount:>10} -> {sap_round(amount, key):>10} {key}   ({TCURX.get(key, 2)} decimals)")
    print()

    print("3. A ROUNDING RULE PER CURRENCY (OB90): CHF TO THE NEAREST 0.05")
    for v in ("12.32", "12.33", "12.37", "12.38", "-7.11"):
        print(f"   {v:>7} CHF -> {round_to_unit(D(v), D('0.05')):>7} CHF")
    print("   Used for cash payments and invoices where the smallest coin is five centimes; the")
    print("   difference goes to the rounding differences account.")
    print()

    print("4. SPLIT A TOTAL OVER LINES AND THE PARTS NO LONGER ADD UP")
    total, n = D("100.00"), 3
    part = sap_round(total / n, "EUR")
    print(f"   {total} EUR over {n} lines: each {part}, sum {part * n}, short by {total - part * n}")
    print("   The same thing happens to a document translated line by line into a parallel currency:")
    rate = D("1.0875")
    lines = [D("33.33"), D("33.33"), D("33.34")]
    converted = [sap_round(x * rate, "USD") for x in lines]
    fmt = lambda xs: ", ".join(str(x) for x in xs)
    print(f"   lines {fmt(lines)} EUR x {rate} -> {fmt(converted)} USD, sum {sum(converted)};")
    print(f"   the total converted at once is {sap_round(total * rate, 'USD')}. Difference: {sap_round(total * rate, 'USD') - sum(converted)}.")
    print("   The accounting interface puts that cent on one line so the entry balances in USD too.")
    print()

    print("5. FLOAT IS THE WRONG TYPE FOR MONEY")
    running = 0.0
    for _ in range(100):
        running += 0.01          # accumulated one at a time, as a ledger would
    print(f"   0.1 + 0.2 == 0.3                 {0.1 + 0.2 == 0.3}")
    print(f"   0.01 added a hundred times       {running!r}")
    print(f"   Decimal('0.01') * 100            {D('0.01') * 100}")
    print("   ABAP's type P (packed) and DECFLOAT34 are decimal; type F is binary floating point,")
    print("   which is why CURR fields are packed and why a float in an amount calculation is a defect.")
    print()

    print("6. THE AMOUNT FIELD HAS A SIZE")
    getcontext().prec = 40
    ecc_max = D("99999999999.99")          # CURR 13, 2 decimals: 11 digits before the point
    s4_max = D("999999999999999999999.99")  # CURR 23, 2 decimals: 21 digits before the point
    print(f"   ECC      CURR length 13, 2 decimals: up to {ecc_max:,} in the currency's units")
    print(f"   S/4HANA  CURR length 23, 2 decimals: up to {s4_max:,}   (amount field length extension)")
    print("   For a 0-decimal currency the stored value is divided by 100, so the ceiling in JPY is")
    print(f"   {ecc_max * 100:,.0f} JPY in ECC. Hyperinflation currencies are where it used to bind.")


if __name__ == "__main__":
    main()

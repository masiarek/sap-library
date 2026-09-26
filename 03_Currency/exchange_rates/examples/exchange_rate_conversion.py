#!/usr/bin/env python3
"""How SAP finds an exchange rate: TCURR, ratios, inverse rates, reference currency.

Run:  python3 exchange_rate_conversion.py

An exchange rate is a row keyed by rate type, from-currency, to-currency and
a valid-from date, with a rate that is quoted per a *ratio* of units from
TCURF (1 : 1 for most pairs, 100 : 1 for currencies like JPY). When there is
no row for the pair the system may use the inverse of the opposite row, or
go through a reference currency and combine two rows. Which of those it did
is the answer to "why did this posting use that rate?", and the program
follows the same search order on a small rate table.

Stdlib only. Decimal, with SAP's commercial rounding (half away from zero).
"""

from datetime import date
from decimal import ROUND_HALF_UP, Decimal

# TCURV: exchange rate type -> (reference currency or None, inverse rate allowed?)
TCURV = {
    "M": (None, True),      # average rate for postings; no reference currency here
    "EURX": ("EUR", False),  # every rate is maintained against EUR
}

# TCURF: (rate type, from, to, valid from) -> (from factor, to factor). Missing means 1 : 1.
TCURF = {
    ("M", "JPY", "EUR", date(2000, 1, 1)): (100, 1),
    ("M", "EUR", "JPY", date(2000, 1, 1)): (1, 100),
}

# TCURR: (rate type, from, to, valid from) -> rate. The rate says how many `to`
# units the *from factor* worth of `from` units buys. A negative rate is SAP's
# way of storing an indirect quotation in the same column.
TCURR = {
    ("M", "USD", "EUR", date(2017, 4, 1)): Decimal("0.93000"),
    ("M", "USD", "EUR", date(2017, 4, 20)): Decimal("0.92000"),
    ("M", "JPY", "EUR", date(2017, 4, 1)): Decimal("0.83000"),    # per 100 JPY, see TCURF
    ("M", "USD", "JPY", date(2017, 4, 1)): Decimal("100.00000"),
    ("M", "USD", "JPY", date(2017, 4, 25)): Decimal("110.00000"),
    ("M", "GBP", "EUR", date(2017, 4, 1)): Decimal("-0.85000"),   # indirect: 1 EUR = 0.85 GBP
    ("EURX", "USD", "EUR", date(2017, 4, 1)): Decimal("0.92000"),
    ("EURX", "CHF", "EUR", date(2017, 4, 1)): Decimal("0.93500"),
}

TCURX = {"JPY": 0, "KWD": 3}


def q(amount: Decimal, key: str) -> Decimal:
    """Round to the currency's decimals, half away from zero, as SAP does."""
    return amount.quantize(Decimal(1).scaleb(-TCURX.get(key, 2)), rounding=ROUND_HALF_UP)


def latest_row(table: dict, kind: str, frm: str, to: str, on: date):
    """The row with the greatest valid-from date that is not after `on`."""
    hits = [(d, v) for (k, f, t, d), v in table.items() if k == kind and f == frm and t == to and d <= on]
    if not hits:
        return None
    d, v = max(hits)
    return d, v


def factors(kind: str, frm: str, to: str, on: date) -> tuple[int, int]:
    found = latest_row(TCURF, kind, frm, to, on)
    return found[1] if found else (1, 1)


def direct(kind: str, frm: str, to: str, on: date):
    """Rate per 1 unit of `frm` in `to`, from a stored row plus its ratio, or None."""
    found = latest_row(TCURR, kind, frm, to, on)
    if found is None:
        return None
    valid_from, rate = found
    ff, tf = factors(kind, frm, to, on)
    if rate < 0:  # indirect quotation: stored as -x meaning 1 `to` = x `frm`
        per_unit = (Decimal(1) / (-rate)) * Decimal(tf) / Decimal(ff)
        how = f"row {valid_from} indirect {-rate} ({ff}:{tf})"
    else:
        per_unit = rate * Decimal(tf) / Decimal(ff)
        how = f"row {valid_from} rate {rate} ({ff}:{tf})"
    return per_unit, how


def find_rate(kind: str, frm: str, to: str, on: date):
    """SAP's search order, simplified: same currency, direct row, inverse row, reference currency."""
    if frm == to:
        return Decimal(1), "same currency"
    hit = direct(kind, frm, to, on)
    if hit:
        return hit
    ref, inverse_ok = TCURV[kind]
    if inverse_ok:
        back = direct(kind, to, frm, on)
        if back:
            return Decimal(1) / back[0], f"inverse of {to}->{frm}: {back[1]}"
    if ref:
        a = direct(kind, frm, ref, on) if frm != ref else (Decimal(1), "is the reference")
        b = direct(kind, to, ref, on) if to != ref else (Decimal(1), "is the reference")
        if a and b:
            return a[0] / b[0], f"via {ref}: ({a[1]}) / ({b[1]})"
    raise LookupError(f"no rate {kind} {frm}->{to} on {on}")


def convert(amount: Decimal, frm: str, to: str, kind: str, on: date) -> tuple[Decimal, Decimal, str]:
    rate, how = find_rate(kind, frm, to, on)
    return q(amount * rate, to), rate, how


def main() -> None:
    print("1. A RATE IS PICKED BY VALID-FROM DATE: THE LATEST ROW NOT AFTER THE TRANSLATION DATE")
    for on in (date(2017, 4, 5), date(2017, 4, 20), date(2017, 4, 30)):
        value, rate, how = convert(Decimal("1000"), "USD", "EUR", "M", on)
        print(f"   1,000.00 USD on {on}: {value:>9} EUR   rate {rate:.5f}   <- {how}")
    print("   The translation date is BKPF-WWERT; it defaults to the posting date and can be entered.")
    print()

    print("2. THE RATIO FROM TCURF IS PART OF THE RATE")
    value, rate, how = convert(Decimal("100000"), "JPY", "EUR", "M", date(2017, 4, 10))
    print(f"   TCURR says JPY->EUR = 0.83000, TCURF says the ratio is 100 : 1, so 100 JPY = 0.83 EUR.")
    print(f"   100,000 JPY = {value} EUR   (per-unit rate {rate:.5f})   <- {how}")
    print("   Read 0.83000 without the ratio and 100,000 JPY becomes 83,000 EUR. OB08 shows the")
    print("   ratio next to the rate for exactly this reason.")
    print()

    print("3. NO ROW FOR THE PAIR: THE INVERSE OF THE OPPOSITE ROW, IF THE RATE TYPE ALLOWS IT")
    value, rate, how = convert(Decimal("1000"), "EUR", "USD", "M", date(2017, 4, 25))
    print(f"   1,000.00 EUR -> {value} USD   rate {rate:.5f}")
    print(f"   <- {how}")
    print("   Rate type M has 'inverse' allowed in OB07 (TCURV). Without it this lookup fails with")
    print("   'exchange rate not maintained' even though the opposite direction exists.")
    print()

    print("4. AN INDIRECT QUOTATION IS STORED AS A NEGATIVE RATE")
    value, rate, how = convert(Decimal("1000"), "GBP", "EUR", "M", date(2017, 4, 10))
    print(f"   TCURR holds GBP->EUR = -0.85000, meaning 1 EUR = 0.85 GBP (quoted the other way round).")
    print(f"   1,000.00 GBP = {value} EUR   per-unit rate {rate:.5f}   <- {how}")
    print("   OB08 shows the same row as 'indirect' 0.85000; the sign is only in the table.")
    print()

    print("5. A REFERENCE CURRENCY: TWO ROWS COMBINED INTO A CROSS RATE")
    value, rate, how = convert(Decimal("1000"), "USD", "CHF", "EURX", date(2017, 4, 10))
    print(f"   Rate type EURX keeps every rate against EUR, so USD->CHF is (USD->EUR) / (CHF->EUR):")
    print(f"   1,000.00 USD = {value} CHF   rate {rate:.5f}")
    print(f"   <- {how}")
    print("   Maintain n rates against the reference and every one of the n*(n-1) pairs is derived.")
    print()

    print("6. THE RATE ON THE DOCUMENT IS FROZEN THERE: BKPF-KURSF")
    on = date(2017, 4, 25)
    value, rate, how = convert(Decimal("100"), "USD", "JPY", "M", on)
    print(f"   Posting 100 USD to a JPY company code on {on}: rate {rate:.5f}, {value} JPY.")
    print(f"   BKPF-KURSF stores {rate:.5f}; changing OB08 tomorrow changes nothing on this document.")
    print("   A user may also type a rate. If it deviates from the table by more than the maximum")
    print("   exchange rate deviation per company code (OB64) the system warns, but posts.")
    typed = Decimal("120")
    dev = (typed / rate - 1) * 100
    print(f"   typed rate 120.00000 vs table {rate:.5f}: deviation {dev:.1f}%")
    print()

    print("7. THE SAME 100 USD, SEEN FROM THE CLEARING PAGE OF THIS CHAPTER")
    posted, r1, _ = convert(Decimal("100"), "USD", "JPY", "M", date(2017, 4, 10))
    cleared, r2, _ = convert(Decimal("100"), "USD", "JPY", "M", date(2017, 4, 26))
    print(f"   posted at 1 : {r1:.0f}  -> {posted:>7} JPY")
    print(f"   cleared at 1 : {r2:.0f} -> {cleared:>7} JPY")
    print(f"   difference {cleared - posted} JPY, which is the whole subject of the SKB1-XSALH page.")


if __name__ == "__main__":
    main()

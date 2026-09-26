#!/usr/bin/env python3
"""Currency keys and decimal places: what TCURC and TCURX each decide.

Run:  python3 currency_decimals_tcurx.py

SAP stores every amount with two decimal places, whatever the currency. For a
currency whose real number of decimals is not two, table TCURX says how many
it has, and the amount in the database is shifted so that it still fits the
two-decimal field: 1,000 JPY is stored as 10.00, and 1.500 KWD is stored as
15.00. Every screen, every conversion and every interface has to undo that
shift using the currency key next to the amount. Forget the key and the
number is wrong by a factor of 100, or 10, in a way that looks perfectly
plausible.

Stdlib only. Decimal, because a currency amount is a packed decimal in ABAP
and a float would already be a bug.
"""

from decimal import ROUND_HALF_UP, Decimal

# A slice of TCURC: currency key -> ISO code. Almost always the same string;
# the table exists so that they are allowed to differ.
TCURC = {"EUR": "EUR", "USD": "USD", "JPY": "JPY", "KWD": "KWD", "CLP": "CLP", "USDN": "USD"}

# A slice of TCURX: currency key -> number of decimals. A key that is not in
# the table has two decimals; that is the default and the reason the table
# is short.
TCURX = {"JPY": 0, "KRW": 0, "CLP": 0, "IDR": 0, "KWD": 3, "BHD": 3, "OMR": 3, "TND": 3, "USDN": 5}


def decimals(key: str) -> int:
    """TCURX lookup with the two-decimal default."""
    return TCURX.get(key, 2)


def to_internal(external: Decimal, key: str) -> Decimal:
    """External amount (what a person reads) -> the two-decimal stored value.

    The shift is 10 ** (decimals - 2): divide by 100 for a 0-decimal currency,
    multiply by 10 for a 3-decimal one. Nothing is lost; only the position of
    the point changes.
    """
    return (external * Decimal(10) ** (decimals(key) - 2)).quantize(Decimal("0.01"))


def to_external(internal: Decimal, key: str) -> Decimal:
    """Stored two-decimal value -> the amount in the currency's own decimals."""
    places = decimals(key)
    quantum = Decimal(1).scaleb(-places)  # 1, 0.1, 0.01, 0.001 ...
    return (internal / Decimal(10) ** (places - 2)).quantize(quantum, rounding=ROUND_HALF_UP)


def fmt(amount: Decimal, key: str) -> str:
    """Format the way WRITE ... CURRENCY key would: the key's decimals, grouped."""
    places = decimals(key)
    return f"{amount:,.{places}f} {key}"


def main() -> None:
    print("1. A CURRENCY KEY IS A ROW IN TCURC; ITS DECIMALS ARE A ROW IN TCURX")
    print("   key    ISO   decimals   source of the decimals")
    for key in ("EUR", "USD", "JPY", "KWD", "CLP", "USDN"):
        src = "TCURX" if key in TCURX else "default (not in TCURX)"
        print(f"   {key:<6} {TCURC[key]:<5} {decimals(key):^8}   {src}")
    print("   Two decimals is not stored anywhere: it is what a missing TCURX row means.")
    print()

    print("2. THE DATABASE HOLDS EVERY AMOUNT WITH TWO DECIMALS, SHIFTED")
    print("   what the user entered        what BSEG-WRBTR holds      shift")
    cases = [(Decimal("1000"), "JPY"), (Decimal("1.500"), "KWD"), (Decimal("1234.56"), "EUR"),
             (Decimal("250000"), "CLP"), (Decimal("0.12345"), "USDN")]
    for external, key in cases:
        internal = to_internal(external, key)
        power = decimals(key) - 2
        shift = f"x 10^{power}" if power else "none"
        print(f"   {fmt(external, key):>22}   ->   {internal:>12}        {shift}")
    print("   1,000 JPY and 10.00 EUR are the same bytes in the amount column. Only the")
    print("   currency key beside it tells them apart.")
    print()

    print("3. THE SHIFT IS REVERSIBLE, AND EVERY OUTPUT HAS TO REVERSE IT")
    for external, key in cases:
        internal = to_internal(external, key)
        back = to_external(internal, key)
        print(f"   {internal:>10} + {key:<5} -> {fmt(back, key):>18}   round trip {'ok' if back == external else 'LOST'}")
    print()

    print("4. THE CLASSIC BUG: READ THE COLUMN, FORGET THE KEY")
    internal = to_internal(Decimal("1000"), "JPY")
    print(f"   SE16 on BSEG shows WRBTR = {internal} for a 1,000 JPY item, and that is correct.")
    print(f"   A report that prints the field as a plain number says  {internal}")
    print(f"   A report that applies the key says                    {fmt(to_external(internal, 'JPY'), 'JPY')}")
    print(f"   A report that 'fixes' it by multiplying every JPY row by 100 and then")
    print(f"   also prints WITH the key says                          {fmt(to_external(internal * 100, 'JPY'), 'JPY')}")
    print("   All three are plausible numbers. Only one of them is the invoice.")
    print()

    print("5. THE SAME SHIFT, SEEN ON THE SOURCE DOCUMENT'S SCREENSHOT")
    print("   Company code Z013 has local currency JPY. A 100 USD document at 1 USD = 100 JPY")
    usd = Decimal("100")
    jpy = usd * 100
    print(f"   is {fmt(usd, 'USD')} = {fmt(jpy, 'JPY')}.  In the raw BSEG display it appears as:")
    print(f"     WRBTR (document currency, USD) = {to_internal(usd, 'USD')}")
    print(f"     DMBTR (local currency, JPY)    = {to_internal(jpy, 'JPY')}")
    print("   Both columns read 100,00 on the screen, and the JPY one means ten thousand.")
    print()

    print("6. YOU CANNOT ADD A COLUMN OF STORED AMOUNTS ACROSS CURRENCIES")
    rows = [(Decimal("1000"), "JPY"), (Decimal("10.00"), "EUR"), (Decimal("1.500"), "KWD")]
    total_internal = sum(to_internal(a, k) for a, k in rows)
    print("   rows:  " + ", ".join(fmt(a, k) for a, k in rows))
    print(f"   sum of the stored values = {total_internal}   (three currencies, one meaningless number)")
    print("   Every SAP total is per currency key, or converted into one currency first.")
    print()

    print("7. TWO BAPIs THAT EXIST BECAUSE OF THIS TABLE")
    print("   BAPI_CURRENCY_CONV_TO_INTERNAL  external -> stored   (what a screen field feeds to the DB)")
    print("   BAPI_CURRENCY_CONV_TO_EXTERNAL  stored -> external   (what an interface must call before sending)")
    print("   BAPI_CURRENCY_GETDECIMALS       the TCURX lookup on its own")
    print(f"   e.g. CONV_TO_EXTERNAL(15.00, KWD) = {fmt(to_external(Decimal('15.00'), 'KWD'), 'KWD')};"
          f"  CONV_TO_INTERNAL(1,000 JPY) = {to_internal(Decimal('1000'), 'JPY')}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""One open item, cleared at a different rate, with SKB1-XSALH on and off.

Run:  python3 xsalh_clearing.py

Company code Z013 has local currency JPY. G/L account 414100C is managed on
an open item basis. A 100 USD item is posted at 1 USD = 100 JPY, so its
local-currency amount is 10,000 JPY. It is cleared later, when the rate is
1 USD = 110 JPY.

With "Only manage balances in local currency" set, the item is remembered as
10,000 JPY and that is what clearing sees. Without it, the item is remembered
as 100 USD, and to clear it in JPY the system re-translates: 11,000 JPY.
Against a second item of 10,000 JPY that leaves 1,000 JPY that somebody has
to charge off, and the system posts it as an exchange rate difference.

Stdlib only. The numbers are the ones on the screenshots in the source
document; the raw BSEG display shows them divided by 100 because JPY has no
decimals (see currency_decimals_tcurx.py).
"""

from decimal import ROUND_HALF_UP, Decimal

LOCAL = "JPY"


def jpy(x: Decimal) -> Decimal:
    return x.quantize(Decimal("1"), rounding=ROUND_HALF_UP)


def post(belnr: str, waers: str, wrbtr: Decimal, rate: Decimal, xsalh: bool) -> dict:
    """A line on 414100C. DMBTR is translated at the posting rate; PSWSL follows the flag."""
    dmbtr = jpy(wrbtr * rate) if waers != LOCAL else wrbtr
    if xsalh:
        pswsl, pswbt = LOCAL, dmbtr
    else:
        pswsl, pswbt = waers, wrbtr
    return {"belnr": belnr, "waers": waers, "wrbtr": wrbtr, "dmbtr": dmbtr, "pswsl": pswsl, "pswbt": pswbt}


def amount_for_clearing(item: dict, clearing_rate: Decimal, xslta: bool = False) -> Decimal:
    """What F-03 shows in the JPY Gross column when the item is processed in local currency.

    Flag on: the item is a JPY balance, nothing to translate. Flag off: the item is a USD
    balance and is translated at the clearing rate -- unless T001-XSLTA says that clearing
    in local currency must not produce a rate difference, in which case DMBTR stands.
    """
    if item["pswsl"] == LOCAL or xslta:
        return item["dmbtr"]
    return jpy(item["pswbt"] * clearing_rate)


def raw(amount: Decimal, key: str) -> Decimal:
    """What SE16 shows: a JPY amount divided by 100, a USD amount as it is (TCURX)."""
    shown = amount / 100 if key == "JPY" else amount
    return shown.quantize(Decimal("0.01"))


def show(item: dict) -> None:
    print(f"     {item['belnr']}  WAERS {item['waers']}  WRBTR {item['wrbtr']:>8}  DMBTR {item['dmbtr']:>8} JPY  "
          f"PSWSL {item['pswsl']}  PSWBT {item['pswbt']:>8}   "
          f"(SE16: DMBTR {raw(item['dmbtr'], 'JPY')}, PSWBT {raw(item['pswbt'], item['pswsl'])})")


def main() -> None:
    post_rate, clear_rate = Decimal("100"), Decimal("110")

    print("1. THE OPEN ITEM: 100 USD POSTED TO 414100C AT 1 USD = 100 JPY")
    a = post("1800000200", "USD", Decimal("100"), post_rate, xsalh=True)
    b = post("1800000196", "USD", Decimal("100"), post_rate, xsalh=False)
    print("   a. SKB1-XSALH on:")
    show(a)
    print("   b. SKB1-XSALH off:")
    show(b)
    print("   Same document currency, same local amount. The only difference is the pair on the right:")
    print("   with the flag the account remembers a JPY balance, without it a USD balance.")
    print()

    print("2. PROCESS THE ITEM IN F-03, IN JPY, WHEN THE RATE IS 1 USD = 110 JPY")
    print(f"   a. flag on:   JPY Gross shown = {amount_for_clearing(a, clear_rate):>7}   DMBTR is not recalculated")
    print(f"   b. flag off:  JPY Gross shown = {amount_for_clearing(b, clear_rate):>7}   DMBTR is recalculated from 100 USD")
    print("   Case a clears against 10,000 JPY of anything. Case b needs 11,000 JPY, or a difference.")
    print()

    print("3. HOW THE FLAG CHANGES A CLEARING BETWEEN TWO ITEMS OF THE SAME LOCAL AMOUNT")
    usd_item = post("1800000196", "USD", Decimal("-100"), post_rate, xsalh=False)   # posting key 50
    jpy_item = post("1800000201", "JPY", Decimal("10000"), Decimal("1"), xsalh=False)  # posting key 40
    print("   flag off, two items, both 10,000 JPY in DMBTR, one posted in USD and one in JPY:")
    show(usd_item)
    show(jpy_item)
    net_usd = amount_for_clearing(usd_item, clear_rate)
    net_jpy = amount_for_clearing(jpy_item, clear_rate)
    print(f"   net amounts at the clearing rate:  {usd_item['belnr']} {net_usd:>7} JPY   {jpy_item['belnr']} {net_jpy:>7} JPY")
    residual = net_usd + net_jpy
    print(f"   balance in JPY = {residual}  -> the items cannot be cleared as they stand.")
    print(f"   Options: 'Charge off diff.' or a residual item of {abs(residual)} JPY, and the system posts an")
    print(f"   exchange rate difference of {abs(residual)} JPY to the account in OBA1 (transaction KDF).")
    print()

    print("   flag on for both items:")
    usd_on = post("1800000196", "USD", Decimal("-100"), post_rate, xsalh=True)
    jpy_on = post("1800000201", "JPY", Decimal("10000"), Decimal("1"), xsalh=True)
    net_on = amount_for_clearing(usd_on, clear_rate) + amount_for_clearing(jpy_on, clear_rate)
    print(f"   net amounts: {amount_for_clearing(usd_on, clear_rate):>7} and {amount_for_clearing(jpy_on, clear_rate):>7}  "
          f"balance {net_on} -> cleared with no difference line at all.")
    print()

    print("4. T001-XSLTA: 'NO FOREX RATE DIFF. WHEN CLEARING IN LC' (OBY6)")
    net = amount_for_clearing(usd_item, clear_rate, xslta=True) + amount_for_clearing(jpy_item, clear_rate, xslta=True)
    print(f"   flag off, XSLTA set, clearing entered in JPY: {usd_item['belnr']} keeps its DMBTR, balance {net}.")
    print("   The company code indicator switches the recalculation off for clearings done in local")
    print("   currency; the account keeps its USD balance and no difference is posted.")
    print()

    print("5. THE SAME NUMBERS SEEN AS BALANCES OF 414100C IN UPDATE CURRENCY")
    for label, items in (("flag off", [usd_item, jpy_item]), ("flag on ", [usd_on, jpy_on])):
        buckets: dict = {}
        for it in items:
            buckets[it["pswsl"]] = buckets.get(it["pswsl"], Decimal(0)) + it["pswbt"]
        print(f"   {label}: " + "   ".join(f"{cur} {amt:>8}" for cur, amt in sorted(buckets.items())))
    print("   With the flag off the account has a USD bucket and a JPY bucket, and clearing the")
    print("   two items against each other has to bring BOTH to zero -- which is why a clearing")
    print("   document can contain lines nobody entered.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""The update currency: how BSEG-PSWSL and BSEG-PSWBT are derived, and what they feed.

Run:  python3 update_currency_logic.py

Every G/L line item carries, besides the document currency (WAERS / WRBTR)
and the local currency (DMBTR), a pair called the update currency: PSWSL is
the key and PSWBT the amount. The G/L *balance* of the account is kept in
that currency, not in the document currency: it is what GLT0-TSL, FAGLFLEXT-TSL
and ACDOCA-TSL hold. The rule that fills it is three lines long and lives in
SAPMF05A:

    IF skb1-xsalh = space.   bseg-pswsl = <document currency>.
    ELSE.                    bseg-pswsl = t001-waers.
    ENDIF.

with one exception: a line posted in the course of a clearing takes the
update currency of the item it clears, because the balance of an open-item
account must return to zero in the update currency too.

Stdlib only. The example is the one in the SAP support-content pages:
company code 1000 with local currency EUR, account 31010, 120 USD = 100 EUR.
"""

from dataclasses import dataclass
from decimal import Decimal

T001 = {"1000": "EUR"}                                 # company code -> local currency
SKB1 = {("1000", "31010"): {"xsalh": True}}            # account control, per company code


@dataclass
class Line:
    account: str
    waers: str        # document currency (BKPF-WAERS)
    wrbtr: Decimal    # amount in document currency
    dmbtr: Decimal    # amount in local currency
    cleared_item: "Line | None" = None   # set when this line is posted by a clearing
    pswsl: str = ""
    pswbt: Decimal = Decimal(0)


def derive_update_currency(bukrs: str, line: Line) -> None:
    """FORM in SAPMF05A, in Python. The clearing exception comes first because it wins."""
    if line.cleared_item is not None:
        # The balance in update currency must net to zero against the item being cleared,
        # so the clearing line inherits the cleared item's update currency and, when it
        # clears the full item, its amount.
        line.pswsl = line.cleared_item.pswsl
        line.pswbt = -line.cleared_item.pswbt
        return
    if SKB1[(bukrs, line.account)]["xsalh"]:
        line.pswsl, line.pswbt = T001[bukrs], line.dmbtr          # only balances in local currency
    else:
        line.pswsl, line.pswbt = line.waers, line.wrbtr           # balances per document currency


def kdf_update_currency(bukrs: str, xsalh: bool, kdbtab_waers: str, wrbtr: Decimal, dmbtr: Decimal):
    """FORM KDFTAB_ABARBEITEN, the two IFs quoted in the docstring, for the difference line."""
    if not xsalh:
        return kdbtab_waers, wrbtr
    return T001[bukrs], dmbtr


def show(title: str, lines: list[Line]) -> None:
    print(f"   {title}")
    print("     account  WAERS  WRBTR      HWAER  DMBTR      PSWSL  PSWBT      -> TSL (balance)   HSL")
    for ln in lines:
        print(f"     {ln.account:<8} {ln.waers:<6} {ln.wrbtr:>9}  EUR    {ln.dmbtr:>9}  "
              f"{ln.pswsl:<6} {ln.pswbt:>9}  -> {ln.pswbt:>9} {ln.pswsl}  {ln.dmbtr:>9} EUR")


def balances(lines: list[Line]) -> dict:
    """GLT0 / FAGLFLEXT / ACDOCA totals: TSL per (account, update currency), HSL per account."""
    tsl: dict = {}
    hsl: dict = {}
    for ln in lines:
        tsl[(ln.account, ln.pswsl)] = tsl.get((ln.account, ln.pswsl), Decimal(0)) + ln.pswbt
        hsl[ln.account] = hsl.get(ln.account, Decimal(0)) + ln.dmbtr
    return {"TSL": tsl, "HSL": hsl}


def main() -> None:
    bukrs = "1000"
    usd, eur = Decimal("120.00"), Decimal("100.00")

    print("1. SCENARIO 1: ACCOUNT MANAGED IN LOCAL CURRENCY ONLY (SKB1-XSALH = 'X')")
    SKB1[(bukrs, "31010")]["xsalh"] = True
    ln = Line("31010", "USD", usd, eur)
    derive_update_currency(bukrs, ln)
    show("post 120 USD = 100 EUR to 31010:", [ln])
    print("   The update currency is EUR: the balance of 31010 is kept in EUR only, and TSL = HSL.")
    print()

    print("2. SCENARIO 2: THE SAME POSTING, FLAG OFF (BALANCES PER CURRENCY)")
    SKB1[(bukrs, "31010")]["xsalh"] = False
    ln = Line("31010", "USD", usd, eur)
    derive_update_currency(bukrs, ln)
    show("post 120 USD = 100 EUR to 31010:", [ln])
    print("   Now the balance of 31010 has a USD bucket: FS10N / FAGLB03 show 120 USD and 100 EUR.")
    print()

    print("3. SCENARIO 3: A CLEARING INHERITS THE UPDATE CURRENCY OF THE ITEM IT CLEARS")
    SKB1[(bukrs, "31010")]["xsalh"] = False
    invoice = Line("31010", "EUR", Decimal("-100.00"), Decimal("-100.00"))
    derive_update_currency(bukrs, invoice)
    payment = Line("31010", "USD", Decimal("120.00"), Decimal("100.00"), cleared_item=invoice)
    derive_update_currency(bukrs, payment)
    show("invoice in EUR, then a payment document in USD that clears it:", [invoice, payment])
    b = balances([invoice, payment])
    print(f"   balance of 31010 in update currency EUR: {b['TSL'][('31010', 'EUR')]}   "
          f"USD bucket: {b['TSL'].get(('31010', 'USD'), 'none')}")
    print("   The payment line says PSWSL = EUR although its document currency is USD. That is")
    print("   normal: an open-item account's balance must be zero per update currency once its")
    print("   items are cleared, so the clearing line is booked in the *cleared* item's currency.")
    print()

    print("4. THE SAME TEST DECIDES THE EXCHANGE RATE DIFFERENCE LINE (FORM KDFTAB_ABARBEITEN)")
    print("   IF skb1-xsalh = space.  bseg-pswsl = kdbtab-waers.  bseg-pswbt = bseg-wrbtr.")
    print("   ELSE.                   bseg-pswsl = t001-waers.    bseg-pswbt = bseg-dmbtr.")
    print("   kdbtab-waers is the document currency of the ITEM BEING CLEARED, not of the clearing.")
    print("   A USD item is cleared by a USD payment at a worse rate; the difference line is")
    print("   -9.60 USD = -8.00 EUR on account KDF01:")
    for flag in (False, True):
        pswsl, pswbt = kdf_update_currency(bukrs, xsalh=flag, kdbtab_waers="USD",
                                           wrbtr=Decimal("-9.60"), dmbtr=Decimal("-8.00"))
        print(f"     KDF01 with XSALH = {'X' if flag else ' '}:  PSWSL {pswsl}  PSWBT {pswbt}")
    print()

    print("5. WHY FS10N AND FBL3N CAN SEEM TO DISAGREE")
    SKB1[(bukrs, "31010")]["xsalh"] = False
    lines = [invoice, payment]
    b = balances(lines)
    print("   FS10N / FAGLB03, currency filter 'EUR', reads TSL per update currency:")
    for (acct, cur), amt in sorted(b["TSL"].items()):
        print(f"     {acct} {cur}: {amt}")
    print("   Drill down and the list contains a document whose *document* currency is USD.")
    print("   FBL3N, filtered on document currency USD, shows that same line as 120.00 USD.")
    print("   Neither is wrong: one is keyed by PSWSL, the other by WAERS.")
    print()

    print("6. WHERE THE PAIR ENDS UP IN EACH GENERATION OF THE GENERAL LEDGER")
    print("   classic G/L   GLT0-TSL      = PSWBT      GLT0-HSL      = DMBTR")
    print("   new G/L       FAGLFLEXT-TSL = PSWBT      FAGLFLEXT-HSL = DMBTR    (RTCUR = PSWSL, RWCUR = WAERS)")
    print("   S/4HANA       ACDOCA-TSL    = PSWBT      ACDOCA-HSL    = DMBTR    (WSL = WRBTR is the document currency)")
    print("   TSL is 'amount in balance transaction currency': the currency the balance is kept in.")


if __name__ == "__main__":
    main()

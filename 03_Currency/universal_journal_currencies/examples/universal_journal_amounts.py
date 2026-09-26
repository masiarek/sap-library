#!/usr/bin/env python3
"""One journal entry in every currency field of ACDOCA, balanced to zero in each.

Run:  python3 universal_journal_amounts.py

In S/4HANA the currency configuration is per ledger and company code
(FINSC_LEDGER). Each configured currency *type* owns one amount field of
ACDOCA: HSL for type 10, KSL for the group currency, OSL, VSL, ... GSL for
up to eight freely defined ones. The accounting interface converts every
line into every configured field and guarantees that the entry balances to
zero in each of them, which after rounding line by line is not automatic.

Stdlib only. The rates and the document are invented; the field names and
the rules are SAP Note 2344012's.
"""

from decimal import ROUND_HALF_UP, Decimal

D = Decimal

# FINSC_LEDGER, ledger 0L, company code 1010: currency type -> (ACDOCA field, currency key,
# converted from which type, BSEG field it also lands in or None).
LEDGER_0L = {
    "10": ("HSL", "EUR", "00", "DMBTR"),   # company code currency, 1st FI currency
    "30": ("KSL", "USD", "10", "DMBE2"),   # group currency, 2nd FI currency (BSEG relevant)
    "40": ("OSL", "CHF", "10", "DMBE3"),   # hard currency, 3rd FI currency (BSEG relevant)
    "Z1": ("VSL", "GBP", "10", None),      # freely defined: ACDOCA only, never in BSEG
}
CURRENCY_KEY_FIELD = {"WSL": "RWCUR", "TSL": "RTCUR", "HSL": "RHCUR", "KSL": "RKCUR", "OSL": "ROCUR", "VSL": "RVCUR"}
TCURX = {"JPY": 0}
RATE = {("JPY", "EUR"): D("0.00837"), ("EUR", "USD"): D("1.0873"), ("EUR", "CHF"): D("0.9837"), ("EUR", "GBP"): D("0.8553")}


def q(amount: D, key: str) -> D:
    return amount.quantize(D(1).scaleb(-TCURX.get(key, 2)), rounding=ROUND_HALF_UP)


def main() -> None:
    doc_cur = "JPY"
    # (account, description, XSALH flag on the account, amount in document currency)
    lines = [
        ("400000", "expense      ", False, D("1234567")),
        ("154000", "input tax 10%", True, D("123457")),
        ("160000", "vendor       ", False, D("-1358024")),
    ]

    print("1. THE CONFIGURATION: WHICH CURRENCY TYPE OWNS WHICH FIELD (tx FINSC_LEDGER, ledger 0L, CoCd 1010)")
    print("   type  field  key  converted from  in BSEG as")
    print("   00    WSL    JPY  (document currency itself)  WRBTR")
    for ct, (field, key, src, bseg) in LEDGER_0L.items():
        print(f"   {ct:<5} {field:<6} {key}  type {src:<11}     {bseg or '-- (ACDOCA only)'}")
    print("   TSL is not configured: it is derived per line (the update currency, see PSWSL).")
    print()

    print("2. CONVERT EVERY LINE INTO EVERY FIELD, ROUNDING EACH LINE")
    header = f"   {'account':<8} {'WSL JPY':>10} {'TSL':>14} {'HSL EUR':>10} {'KSL USD':>10} {'OSL CHF':>10} {'VSL GBP':>10}"
    print(header)
    rows = []
    for account, _, xsalh, wsl in lines:
        hsl = q(wsl * RATE[("JPY", "EUR")], "EUR")
        row = {"WSL": wsl, "HSL": hsl}
        row["KSL"] = q(hsl * RATE[("EUR", "USD")], "USD")
        row["OSL"] = q(hsl * RATE[("EUR", "CHF")], "CHF")
        row["VSL"] = q(hsl * RATE[("EUR", "GBP")], "GBP")
        # TSL: the balance is kept in local currency for an XSALH account, else in document currency.
        row["TSL"], row["RTCUR"] = (hsl, "EUR") if xsalh else (wsl, doc_cur)
        rows.append((account, row))
        print(f"   {account:<8} {row['WSL']:>10} {row['TSL']:>10} {row['RTCUR']:<3} {row['HSL']:>10} {row['KSL']:>10} {row['OSL']:>10} {row['VSL']:>10}")
    totals = {f: sum(r[f] for _, r in rows) for f in ("WSL", "HSL", "KSL", "OSL", "VSL")}
    print(f"   {'sum':<8} {totals['WSL']:>10} {'':>14} {totals['HSL']:>10} {totals['KSL']:>10} {totals['OSL']:>10} {totals['VSL']:>10}")
    off = [f for f, t in totals.items() if t != 0]
    print(f"   balanced in WSL; not balanced in {', '.join(off)}: rounding each line leaves a cent or two.")
    print()

    print("3. BALANCE ZERO PER JOURNAL ENTRY: THE DIFFERENCE IS ADJUSTED ON ONE LINE")
    print("   The accounting interface moves each field's rounding difference onto one line item")
    print("   (this program takes the last one) so that every field nets to zero. No extra line,")
    print("   no extra account: a line's HSL may differ by a cent from its own converted amount.")
    last_account, last = rows[-1]
    for f in ("HSL", "KSL", "OSL", "VSL"):
        if totals[f] != 0:
            print(f"     {f}: line {last_account} {last[f]} -> {last[f] - totals[f]}   (adjusted by {-totals[f]})")
            last[f] -= totals[f]
    totals = {f: sum(r[f] for _, r in rows) for f in ("WSL", "HSL", "KSL", "OSL", "VSL")}
    print("   sums now: " + "  ".join(f"{f} {t}" for f, t in totals.items()))
    print()

    print("4. TSL DOES NOT HAVE TO BALANCE PER ENTRY, ONLY PER ACCOUNT AND CURRENCY OVER TIME")
    buckets: dict = {}
    for account, row in rows:
        buckets[row["RTCUR"]] = buckets.get(row["RTCUR"], D(0)) + row["TSL"]
    print("   TSL by currency in this entry: " + ", ".join(f"{k} {v}" for k, v in buckets.items()))
    print("   The tax account has XSALH set, so its balance is kept in EUR while the other two")
    print("   lines keep JPY; TSL mixes currencies within one entry by design.")
    print()

    print("5. WHAT REACHES BSEG, AND WHAT DOES NOT")
    print("   field  currency key field  BSEG")
    for f in ("WSL", "TSL", "HSL", "KSL", "OSL", "VSL"):
        bseg = {"WSL": "WRBTR / WAERS (header)", "TSL": "PSWBT / PSWSL", "HSL": "DMBTR", "KSL": "DMBE2", "OSL": "DMBE3", "VSL": "-- not in BSEG"}[f]
        print(f"   {f:<6} {CURRENCY_KEY_FIELD[f]:<19} {bseg}")
    print("   BSEG has room for three parallel currencies and will not be extended; the Z1 amount")
    print("   in GBP is visible in FB03L, FAGLB03, FAGLL03H and the Fiori apps, not in FBL3N.")
    print()

    print("6. WHICH PROCESSES CONVERT WITH HISTORICAL RATES (X) AND WHICH FALL BACK (1..4), note 2344012, UPA off")
    matrix = [
        ("Realtime currency conversion           ", "X X X X"),
        ("Balance zero per journal entry         ", "X X X X"),
        ("Open item management (AP, AR, GL)      ", "X X X X"),
        ("Foreign currency valuation             ", "X X X X"),
        ("GL allocations                         ", "X X X X"),
        ("Regrouping                             ", "X X X 1"),
        ("Fixed asset accounting                 ", "X X X 1"),
        ("Material ledger                        ", "X X X 1"),
        ("CO allocations                         ", "X X 4 4"),
        ("CO settlement                          ", "X X 2 2"),
        ("CO reposting                           ", "X X 1 1"),
    ]
    print("   process                                  10 30 40 Z1")
    for name, cells in matrix:
        print(f"   {name}  {cells.replace(' ', '  ')}")
    print("   1 = converted at the current rate as a fallback; 2 = all currencies since 2020 if set in")
    print("   the settlement profile; 4 = accurate if the field is in the cycle. With Universal")
    print("   Parallel Accounting (2022+) every cell is X.")


if __name__ == "__main__":
    main()

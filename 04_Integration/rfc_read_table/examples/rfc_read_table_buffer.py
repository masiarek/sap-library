#!/usr/bin/env python3
"""RFC_READ_TABLE's three tables, simulated: FIELDS, OPTIONS and the 512-character DATA row.

Run:  python3 rfc_read_table_buffer.py

RFC_READ_TABLE reads any transparent table over RFC and returns the rows as
text. Its interface, as the Function Builder shows it, is three TABLES
parameters and a handful of scalars:

    QUERY_TABLE   the table to read
    DELIMITER     one character put between the fields, or space for none
    NO_DATA       anything but space: return the field catalogue only
    ROWSKIPS      skip this many rows (paging)
    ROWCOUNT      return at most this many rows (0 = all)
    FIELDS        in: the fields wanted (empty = all); out: name, offset, length, type
    OPTIONS       in: the WHERE clause, as lines of at most 72 characters
    DATA          out: one row per line, in a field WA of 512 characters (TAB512)

This program applies those rules to the identification numbers of a business
partner (table BUT0ID) and to a wider table, so that the two exceptions a
caller meets first, OPTION_NOT_VALID and DATA_BUFFER_EXCEEDED, come out of the
arithmetic rather than out of a story. Stdlib only. The field catalogue is
illustrative: lengths are the Dictionary lengths the page gives, the row data
is invented, and the real catalogue is read from DD03L in your own system.
"""

from __future__ import annotations

from dataclasses import dataclass

WA_LENGTH = 512        # TAB512-WA: the row buffer
OPTION_LENGTH = 72     # RFC_DB_OPT-TEXT: one line of the WHERE clause


@dataclass(frozen=True)
class Field:
    name: str
    length: int        # output length in characters
    abap_type: str     # the Dictionary type, returned in FIELDS-TYPE


# BUT0ID: identification numbers of a business partner, one row per partner,
# ID type and ID number. CLIENT is a field like any other to RFC_READ_TABLE.
BUT0ID = [
    Field("CLIENT", 3, "C"), Field("PARTNER", 10, "C"), Field("TYPE", 6, "C"),
    Field("IDNUMBER", 60, "C"), Field("INSTITUTE", 40, "C"), Field("ENTRY_DATE", 8, "D"),
    Field("COUNTRY", 3, "C"), Field("REGION", 3, "C"),
    Field("VALID_DATE_FROM", 8, "D"), Field("VALID_DATE_TO", 8, "D"),
]

ROWS = [
    {"CLIENT": "100", "PARTNER": "0017100001", "TYPE": "ZPESEL", "IDNUMBER": "90010112345",
     "INSTITUTE": "", "ENTRY_DATE": "20240115", "COUNTRY": "PL", "REGION": "",
     "VALID_DATE_FROM": "20240115", "VALID_DATE_TO": "99991231"},
    {"CLIENT": "100", "PARTNER": "0017100001", "TYPE": "HCM001", "IDNUMBER": "00001234",
     "INSTITUTE": "", "ENTRY_DATE": "20240115", "COUNTRY": "", "REGION": "",
     "VALID_DATE_FROM": "00000000", "VALID_DATE_TO": "00000000"},
    {"CLIENT": "100", "PARTNER": "0017100002", "TYPE": "ZNIP", "IDNUMBER": "5261040828",
     "INSTITUTE": "Urzad Skarbowy", "ENTRY_DATE": "20240301", "COUNTRY": "PL", "REGION": "",
     "VALID_DATE_FROM": "20240301", "VALID_DATE_TO": "99991231"},
]


def catalogue(table: list[Field], wanted: list[str]) -> list[tuple[str, int, int, str]]:
    """FIELDS on return: FIELDNAME, OFFSET, LENGTH, TYPE. Offsets count the delimiter-free row."""
    chosen = [f for f in table if not wanted or f.name in wanted]
    out, offset = [], 0
    for f in chosen:
        out.append((f.name, offset, f.length, f.abap_type))
        offset += f.length
    return out


def row_width(fields: list[tuple[str, int, int, str]], delimiter: str) -> int:
    widths = sum(length for _, _, length, _ in fields)
    return widths + (len(fields) - 1 if delimiter.strip() else 0)


def read_table(table: list[Field], rows: list[dict], fields: list[str] = (), delimiter: str = " ",
               rowskips: int = 0, rowcount: int = 0, no_data: str = " ") -> list[str]:
    """The DATA table RFC_READ_TABLE would return, or the exception it would raise."""
    cat = catalogue(table, list(fields))
    width = row_width(cat, delimiter)
    if width > WA_LENGTH:
        raise ValueError(f"DATA_BUFFER_EXCEEDED: the row would be {width} characters, the buffer holds {WA_LENGTH}")
    if no_data.strip():
        return []
    chosen = rows[rowskips:]
    if rowcount:
        chosen = chosen[:rowcount]
    out = []
    for r in chosen:
        cells = [r[name].ljust(length) for name, _, length, _ in cat]
        out.append((delimiter if delimiter.strip() else "").join(cells))
    return out


def options_lines(where: str) -> list[str]:
    """Split a WHERE clause into OPTIONS lines of 72 characters, breaking only at a space."""
    lines, current = [], ""
    for token in where.split(" "):
        candidate = token if not current else current + " " + token
        if len(candidate) > OPTION_LENGTH:
            lines.append(current)
            current = token
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines


def main() -> None:
    print("1. FIELDS on return: the catalogue of BUT0ID, all fields")
    print("   FIELDNAME         OFFSET  LENGTH  TYPE")
    for name, offset, length, typ in catalogue(BUT0ID, []):
        print(f"   {name:16}  {offset:6}  {length:6}  {typ}")
    print(f"   row width {row_width(catalogue(BUT0ID, []), ' ')} characters: fits in the {WA_LENGTH}-character buffer")

    print()
    print("2. DATA without a delimiter: fixed positions, cut with FIELDS-OFFSET and FIELDS-LENGTH")
    wanted = ["PARTNER", "TYPE", "IDNUMBER", "VALID_DATE_TO"]
    for line in read_table(BUT0ID, ROWS, wanted):
        print("   |" + line + "|")
    print("   catalogue for this call: " + ", ".join(f"{n}@{o}+{l}" for n, o, l, _ in catalogue(BUT0ID, wanted)))

    print()
    print("3. The same with DELIMITER = '|': the offsets in FIELDS still describe the undelimited row")
    for line in read_table(BUT0ID, ROWS, wanted, delimiter="|"):
        print("   " + line)

    print()
    print("4. Paging with ROWSKIPS and ROWCOUNT, on a SELECT with no ORDER BY")
    print("   ROWSKIPS=1 ROWCOUNT=1 ->", read_table(BUT0ID, ROWS, ["PARTNER", "TYPE"], delimiter="|", rowskips=1, rowcount=1))
    print("   the page is only stable if the database returns the rows in the same order every time;")
    print("   GET_SORTED asks for a sort by primary key, and without it two pages can overlap or miss a row")

    print()
    print("5. NO_DATA = 'X': the catalogue comes back, DATA stays empty")
    print("   DATA:", read_table(BUT0ID, ROWS, no_data="X"))

    print()
    print("6. OPTIONS: the WHERE clause as 72-character lines, broken only where a space is")
    where = "PARTNER = '0017100001' AND TYPE IN ('ZPESEL', 'ZNIP', 'HCM001') AND VALID_DATE_TO >= '20260101' AND COUNTRY = 'PL'"
    for i, line in enumerate(options_lines(where), 1):
        print(f"   line {i} ({len(line):2} chars): {line}")
    print("   the lines are concatenated with a space before the SELECT; a quoted value cut across two lines")
    print("   is a different value, and a keyword cut in two raises OPTION_NOT_VALID")

    print()
    print("7. DATA_BUFFER_EXCEEDED: a wide table, all fields at once")
    wide = [Field(f"TEXT{i:02}", 60, "C") for i in range(1, 10)]   # 9 x 60 = 540 > 512
    try:
        read_table(wide, [], [])
    except ValueError as e:
        print("   " + str(e))
    print("   the way out is the FIELDS table: ask for fewer fields per call, and join the calls by key")
    first = [f.name for f in wide[:5]]
    print(f"   {first} -> {row_width(catalogue(wide, first), ' ')} characters: fits")


if __name__ == "__main__":
    main()

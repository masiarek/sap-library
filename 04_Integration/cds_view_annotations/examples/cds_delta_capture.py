#!/usr/bin/env python3
"""Change data capture for a CDS extraction view, simulated on BUT0ID and BUT000.

Run:  python3 cds_delta_capture.py

The delivered view I_BuPaIdentification carries, under @Analytics.dataExtraction,
a delta.changeDataCapture.mapping with two entries:

    table BUT0ID, role MAIN
        view elements BusinessPartner, BPIdentificationType, BPIdentificationNumber
        table fields  partner, type, idnumber
    table BUT000, role LEFT_OUTER_TO_ONE_JOIN
        (the partner's general data, joined to-one on the partner number)

The mapping is what lets the system turn a change of a *table* row into the
key of a *view* row: a change in the main table names the view row directly;
a change in a joined table names every view row that joins to it. The
extractor then reads only those rows. A view without the mapping can only be
extracted in full, every time.

This program keeps three tables in memory (the two above and a change log),
replays a day of changes, and prints what a delta extraction would hand over
and what a full extraction would. Stdlib only; the rows are invented and the
mechanism is the one the annotation describes, not SAP's code.
"""

from __future__ import annotations

from dataclasses import dataclass

# ----------------------------------------------------------------- the tables

BUT000 = {                         # partner -> general data
    "0017100001": {"NAME_ORG1": "Kowalski Sp. z o.o.", "XBLCK": ""},
    "0017100002": {"NAME_ORG1": "Nowak S.A.", "XBLCK": ""},
}

BUT0ID = {                         # (partner, type, idnumber) -> the rest of the row
    ("0017100001", "ZNIP", "5261040828"): {"COUNTRY": "PL", "VALID_DATE_TO": "99991231"},
    ("0017100001", "HCM001", "00001234"): {"COUNTRY": "", "VALID_DATE_TO": "00000000"},
    ("0017100002", "ZNIP", "7010001234"): {"COUNTRY": "PL", "VALID_DATE_TO": "99991231"},
}

# The mapping, as the annotation states it: which view elements hold each table's key.
MAPPING = {
    "BUT0ID": {"role": "MAIN", "view_elements": ("BusinessPartner", "BPIdentificationType", "BPIdentificationNumber")},
    "BUT000": {"role": "LEFT_OUTER_TO_ONE_JOIN", "view_elements": ("BusinessPartner",)},
}


def view_rows() -> dict[tuple[str, str, str], dict]:
    """I_BuPaIdentification: BUT0ID left outer joined to BUT000 on the partner."""
    out = {}
    for (partner, typ, number), rest in BUT0ID.items():
        general = BUT000.get(partner, {})
        out[(partner, typ, number)] = {
            "BusinessPartner": partner, "BPIdentificationType": typ, "BPIdentificationNumber": number,
            "Country": rest["COUNTRY"], "ValidityEndDate": rest["VALID_DATE_TO"],
            "BusinessPartnerName": general.get("NAME_ORG1", ""),
        }
    return out


# ------------------------------------------------------------ the change log

@dataclass(frozen=True)
class Change:
    table: str
    operation: str          # I insert, U update, D delete
    key: tuple[str, ...]    # the table's key values


LOG: list[Change] = []


def insert_id(partner: str, typ: str, number: str, country: str) -> None:
    BUT0ID[(partner, typ, number)] = {"COUNTRY": country, "VALID_DATE_TO": "99991231"}
    LOG.append(Change("BUT0ID", "I", (partner, typ, number)))


def delete_id(partner: str, typ: str, number: str) -> None:
    del BUT0ID[(partner, typ, number)]
    LOG.append(Change("BUT0ID", "D", (partner, typ, number)))


def rename_partner(partner: str, name: str) -> None:
    BUT000[partner]["NAME_ORG1"] = name
    LOG.append(Change("BUT000", "U", (partner,)))


# ------------------------------------------------------------- the extractor

def delta_keys(log: list[Change]) -> dict[tuple[str, str, str], str]:
    """View keys affected by the logged table changes, with the image to send (D or U/I)."""
    affected: dict[tuple[str, str, str], str] = {}
    for change in log:
        role = MAPPING[change.table]["role"]
        if role == "MAIN":
            affected[change.key] = change.operation               # the view key is the table key
        else:
            # a to-one joined table: every view row whose BusinessPartner is this partner
            (partner,) = change.key
            for key in BUT0ID:
                if key[0] == partner:
                    affected.setdefault(key, "U")
    return affected


def extract_delta() -> list[str]:
    rows = view_rows()
    out = []
    for key, image in sorted(delta_keys(LOG).items()):
        if image == "D":
            out.append(f"D  {key}  (delete image: keys only, the row is gone)")
        else:
            out.append(f"{image}  {key}  name={rows[key]['BusinessPartnerName']!r} country={rows[key]['Country']!r}")
    LOG.clear()                                        # the delta is consumed
    return out


def extract_full() -> list[str]:
    return [f"   {key}  name={row['BusinessPartnerName']!r}" for key, row in sorted(view_rows().items())]


def main() -> None:
    print("initial load: a full extraction, every row of the view")
    for line in extract_full():
        print(line)

    print()
    print("a day of changes:")
    insert_id("0017100002", "ZPESEL", "85050512345", "PL")
    print("   insert BUT0ID (0017100002, ZPESEL, 85050512345)")
    rename_partner("0017100001", "Kowalski i Wspolnicy Sp. z o.o.")
    print("   update BUT000 0017100001: new name")
    delete_id("0017100001", "HCM001", "00001234")
    print("   delete BUT0ID (0017100001, HCM001, 00001234)")
    print("   change log:", [(c.table, c.operation, c.key) for c in LOG])

    print()
    print("delta extraction with the mapping: only the view rows the log names")
    for line in extract_delta():
        print("   " + line)
    print("   the BUT000 update produced one delta row per identification of that partner,")
    print("   because the mapping says BUT000 joins to-one on BusinessPartner; the deleted")
    print("   identification is sent as a delete image, which a full load could never express")

    print()
    print("a view without the mapping (the custom view on BUT0ID): full extraction, again")
    for line in extract_full():
        print(line)
    print("   the consumer gets every row and has to find the changes itself; a deleted row")
    print("   is simply absent, and nothing says which one")

    print()
    print("a second delta run with nothing logged:")
    print("   ", extract_delta() or "empty: the extractor has nothing to send")


if __name__ == "__main__":
    main()

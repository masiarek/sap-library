"""Build-time fixes that would otherwise cost a pinned plugin dependency.

MkDocs derives a sidebar *section* label from the folder name on disk, so
`01_FI/` would read as "01 FI" and `payments/` would be fine but `open_items/`
would read as "Open items" with the wrong casing on half of SAP's acronyms.

Two jobs:

1. **Clean section labels** — strip the ordering prefix, turn underscores into
   spaces, and fix the casing of SAP's many abbreviations (`fi` -> "FI",
   `ap_ar` -> "AP AR").
2. **Order the sections** — `NAV_ORDER` states the intended reading order per
   folder, keyed by folder path, listing children by their on-disk name.

Why order here rather than by renaming files: a filename is a permanent URL.
Renumbering `03_` to `04_` to insert a page would move every page after it and
break any link anyone saved. Ordering is presentation, so it belongs in the
presentation layer. Unlisted pages keep their alphabetical slot at the bottom,
so adding a page needs no edit here.
"""

from __future__ import annotations

import re

# Words the naive title-caser gets wrong, plus the abbreviations that must stay
# loud. Add to this list rather than renaming a folder, which moves a published
# URL.
FIXUPS = {
    "Vs": "vs",
    "And": "and",
    "Or": "or",
    "The": "the",
    "To": "to",
    "A": "a",
    "In": "in",
    "Of": "of",
    "Fi": "FI",
    "Co": "CO",
    "Mm": "MM",
    "Sd": "SD",
    "Ap": "AP",
    "Ar": "AR",
    "Gl": "G/L",
    "Ic": "IC",
    "Sap": "SAP",
    "Abap": "ABAP",
    "Idoc": "IDoc",
    "Bapi": "BAPI",
    "Cds": "CDS",
    "Bp": "BP",
    "Sd": "SD",
    "Rv": "RV",
    "Fec": "FEC",
}

# Reading order per folder, keyed by folder path relative to the repo root.
# A folder's README.md is pinned first regardless (navigation.indexes requires
# the index at children[0]).
NAV_ORDER: dict[str, list[str]] = {
    ".": ["01_FI", "02_Master_Data"],
    "01_FI": ["payments", "document_types_and_number_ranges", "exchange_rates", "posting_keys"],
    "01_FI/payments": [
        "f110_debit_vs_credit.md",
        "intercompany_settlement_worked_example.md",
        "intercompany_reconciliation_why_hard.md",
    ],
    "01_FI/exchange_rates": [
        "how_a_posting_picks_its_rate.md",
        "exchange_rate_check_report.md",
        "testing_foreign_currency_postings.md",
    ],
    "01_FI/posting_keys": [
        "comparing_posting_keys_between_clients.md",
    ],
    "02_Master_Data": ["addresses"],
    "02_Master_Data/addresses": [
        "postal_code_checks.md",
    ],
    "01_FI/document_types_and_number_ranges": [
        "document_types_and_number_ranges.md",
        "inbound_interface_numbering.md",
        "case_inbound_ar_interface.md",
    ],
}


def _label(folder_name: str) -> str:
    """`01_FI` -> `FI`; `open_items` -> `Open items`."""
    stripped = re.sub(r"^\d+[_-]", "", folder_name)
    words = stripped.replace("_", " ").replace("-", " ").split()
    out = []
    for i, w in enumerate(words):
        titled = w[:1].upper() + w[1:]
        fixed = FIXUPS.get(titled)
        if fixed is not None:
            # A lowercase-only fixup ("vs", "and") never leads a label.
            out.append(titled if i == 0 and fixed.islower() else fixed)
        else:
            # Sentence case, not title case: only the first word is capitalised,
            # so a folder reads "Document types and number ranges" rather than
            # shouting every word. Acronyms are handled by FIXUPS above and keep
            # their casing wherever they sit.
            out.append(titled if i == 0 else w.lower())
    return " ".join(out) or folder_name


def _sort_key(item, order: list[str]):
    """Listed children in listed order; everything else alphabetical, after."""
    name = getattr(item, "file", None)
    if name is not None:
        base = item.file.src_uri.rsplit("/", 1)[-1]
    else:
        base = (item.title or "").strip()
        # A section's on-disk name is the last segment of any child's path.
        for child in getattr(item, "children", []) or []:
            if getattr(child, "file", None) is not None:
                parts = child.file.src_uri.split("/")
                if len(parts) >= 2:
                    base = parts[-2]
                break
    if base in order:
        return (0, order.index(base), "")
    return (1, 0, base.lower())


def _walk(items, path: str) -> None:
    order = NAV_ORDER.get(path or ".", [])
    for item in items:
        if getattr(item, "children", None):
            # Recurse first so a section's own on-disk name is discoverable.
            child_path = None
            for child in item.children:
                if getattr(child, "file", None) is not None:
                    parts = child.file.src_uri.split("/")
                    if len(parts) >= 2:
                        child_path = "/".join(parts[:-1])
                    break
            if child_path:
                item.title = _label(child_path.rsplit("/", 1)[-1])
                _walk(item.children, child_path)
    if order:
        index_pages = [i for i in items if getattr(i, "file", None) is not None
                       and i.file.src_uri.rsplit("/", 1)[-1] in ("README.md", "index.md")]
        rest = [i for i in items if i not in index_pages]
        rest.sort(key=lambda i: _sort_key(i, order))
        items[:] = index_pages + rest


def on_nav(nav, config, files):  # noqa: ARG001 — MkDocs hook signature
    _walk(nav.items, "")
    return nav

# Resetting transaction data

Deleting a company code's postings: what the standard reset does, what it was built for, and why a copy of production is not that case.

| Page | What it answers |
| :-- | :-- |
| [OBR1 after a production copy](obr1_after_a_production_copy.md) | Whether `OBR1` still works in S/4HANA (on premise yes, public cloud no), the five gates a production copy meets (productive flag, controlling area, untouched logistics, no date selection, volume), what to do instead for each goal, and a checklist for the one case where running it is reasonable. |

## The one distinction to carry away

**A reset is for a company code that never went live.** On a copy of production the goal is usually a test system without history, or without personal data; neither is reached by deleting FI documents after the fact, because the rest of the system still remembers them. Build the client without the history, or mask it with a tool that keeps the modules consistent.

## Po polsku, w skrócie

`OBR1` czyści dokumenty jednostki, która jeszcze nie pracowała produkcyjnie. Kopii produkcji nie „resetuje” się po fakcie: buduje się klienta bez historii albo maskuje dane narzędziem, które zachowuje spójność modułów.

## Auf Deutsch: Stichwörter

Das Zurücksetzen von Bewegungsdaten ist für einen Buchungskreis vor dem Produktivstart gedacht, nicht für eine Produktionskopie.

Stichwörter: Bewegungsdaten · Buchungskreis · Produktivstart · Systemkopie · Testsystem.

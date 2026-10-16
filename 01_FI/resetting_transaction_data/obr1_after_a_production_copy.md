# OBR1 after a production copy

**Level:** 201 · for FI consultants and Basis teams who refresh a test system from production and want it without the accounting history

**One line:** `OBR1` (program `SAPF020`) still exists in S/4HANA on premise and in the private cloud, and it deletes a company code's accounting documents, the Universal Journal included; but it was built for a test company code before go-live, so on a copy of production it meets five things it was never meant to meet: the productive flag, the controlling area, the logistics documents it does not touch, the absence of any date selection, and the volume. Run there, it turns a consistent copy into an inconsistent one. A target without FI history is built without it, not emptied afterwards.

---

## What OBR1 does

`OBR1` is *reset transaction data* for one or more company codes. It is the step a project runs when a test company code has to start again, typically before a change that is only allowed while no postings exist (chart of accounts, fiscal year variant, local currency).

| It deletes | It leaves |
| :-- | :-- |
| Accounting documents of the company code: headers (`BKPF`), line items (`BSEG`) and the open and cleared item indexes | Master data: G/L accounts, customers, vendors, business partners, assets as objects. `OBR2` (`SAPF019`) is the separate program for master data. |
| Totals of the company code | Customizing, including the company code itself |
| In S/4HANA: the company code's lines in the Universal Journal, `ACDOCA` | Purchase orders, sales orders, deliveries, billing documents, material documents (`MATDOC`) and stock quantities |
| On request: CO data, asset values and other dependent data, chosen on the selection screen | Anything in another company code, *unless* it shares the controlling area (below) |

There is no posting-date or document-number selection: a company code is reset whole or not at all. A test run lists what would be deleted before anything is.

## Why a production copy is the case it was not built for

| Gate | On a copy of production | What follows |
| :-- | :-- | :-- |
| **The productive flag**, `T001-XPROD` | Set in production, so set in the copy: the copy is a copy of the table too. `OBR1` refuses a company code that carries it. | To run at all, the flag has to be removed in the target client. That is a Customizing change in that client only, with the client opened for it, never made in production and never transported. |
| **The controlling area** | CO data belongs to the controlling area, not to the company code. A company code can be reset on its own only while no costs or revenues were posted in it; otherwise the CO side is reset for the whole controlling area, every company code assigned to it. | In S/4HANA every revenue and expense line is one `ACDOCA` line with its CO object on it, so a productive company code always has CO data. In practice, the unit of deletion is the controlling area. |
| **Logistics is not touched** | Purchase orders with goods receipts, billing documents, material documents and stocks stay. | Goods receipts without a GR/IR line, billing documents without an accounting document, stock quantities with no value in the books. Tests in that client then fail for reasons production does not have, and pass for reasons it does not have either. |
| **No selection** | "Keep the last two years" or "keep the open items" cannot be expressed. | It is all of the company code's history or none of it. |
| **Volume** | The program was written for a test company code with a few thousand documents, not for years of production. | One long background job and a large database log; plan it like a mass deletion, not like a report. |

A sixth point is about intent, not the program. When "a clean test system" really means "no personal data in it", `OBR1` does not deliver it: the names, addresses and bank accounts sit in the master data it leaves.

## What to do instead

| The goal behind "reset FI in the target" | The route that reaches it |
| :-- | :-- |
| A test client with production's configuration and no history | Copy only the Customizing (client copy profile `SAP_CUST`, `SCCL` locally or `SCC9` from another system), then load master data the way the go-live did. Nothing to delete, because nothing was copied. |
| Production's data, without the personal part | A scrambling or masking tool run on the copy: SAP's test data tooling (historically TDMS; the product names change often) or a third-party tool. Built to keep the modules consistent with each other. |
| A smaller copy: fewer years, fewer company codes | A reduced copy that selects by time or company code *while copying*, across all modules, rather than a full copy cut back in FI only. |
| One company code gone for good | SAP Landscape Transformation's company code deletion scenario: master data, transaction data and Customizing of all modules, as a project with test runs. |
| Old years gone from the copy | Archiving (`SARA`): object `FI_DOCUMNT` and the logistics objects in their dependency order. Consistent by design; residence times and the archive files have to be thought through. |

## If you still run it

The case where `OBR1` on a copy is reasonable: a sandbox, one controlling area that may be emptied whole, and nobody testing logistics there.

1. Confirm the system and client you are logged on to. Then confirm them again.
2. Agree in writing that the controlling area, not the company code, is the unit, and list every company code assigned to it.
3. Remove `XPROD` for those company codes in the target client only; note who did it and when.
4. Run the test run and keep its list.
5. Run the deletion as a background job.
6. Afterwards: no `ACDOCA` lines left for the company codes; the logistics documents and their missing accounting side known and accepted; the current numbers in `FBN1` compared with those before (whether the number range levels are reset is not something this page claims).
7. Set `XPROD` back. It is the guard against the next accidental run.

## Where S/4HANA differs

- **HANA, the database, changes nothing here; S/4HANA, the data model, does.** One journal (`ACDOCA`) holds FI and CO in the same line, so the controlling area gate is always met, and `OBR1` has to delete Universal Journal lines rather than the classic totals tables, which are compatibility views in S/4HANA.
- The Material Ledger keeps an extract per valuation area (`ACDOCA_M_EXTRACT`). Deactivating the Material Ledger for a valuation area is refused while journal and extract still hold data for it, and the step named for clearing them is this reset.
- **S/4HANA Cloud, public edition:** no `OBR1` and no `OBR2`; neither an app nor a configuration step offers them. A test tenant is reset by SAP's tenant processes, not by a transaction.

## How to verify this in your own system

| Claim | Where to prove it | How sure |
| :-- | :-- | :-- |
| `OBR1` exists and runs `SAPF020` | `SE93`, transaction `OBR1`: the program it calls | High |
| The productive flag is `T001-XPROD` and is copied with production | `SE11`, table `T001`, field `XPROD`; `SE16` on `T001` in the copy | High |
| `OBR1` refuses a company code flagged productive | A test run in the copy before the flag is removed: read the message in your own system | High |
| CO data is reset per controlling area once costs or revenues exist | `OBR1`'s own documentation (the *i* button on the selection screen) for your release | Medium: from experience and from SAP's help as quoted in a community answer |
| In S/4HANA it deletes `ACDOCA` lines | The test run's list; then `SE16H` on `ACDOCA` by `RBUKRS` after a run in a sandbox | Medium: from experience, not confirmed against a system for this page |
| Logistics documents stay | `SE16H` on `MATDOC`, `EKKO`, `VBRK` for the company code's plants and sales organizations, before and after | High |
| No date selection | The selection screen of `OBR1` | High |
| Not in the public cloud | A community question on release 2302 found neither app nor configuration step; check your tenant's app library | Medium |

## Provenance and caveats

- Written **16 October 2026** from experience with the module, to a question from the owner. **Not confirmed against a system** for this page.
- SAP Help, SAP Community and SAP for Me were unreachable from the writing session; what came from a web search is marked as such above. Two SAP knowledge base articles turned up in that search, 1895961 (CO data of a whole controlling area deleted when one company code was meant) and 2788050 (resetting one company code without its CO data); their gist is from the search summary, their text was not read, and both need an S-user.
- Product names for test data tools (TDMS and its successors, the Landscape Transformation scenarios) change faster than the transactions; check the current name with SAP before quoting one in a plan.
- No message texts or menu paths are quoted, by the house rule: read the refusal and the documentation in your own system.

## Po polsku, w skrócie

`OBR1` nadal działa w S/4HANA on-premise i usuwa dokumenty księgowe jednostki gospodarczej, razem z wierszami `ACDOCA`, ale powstał do czyszczenia testowej jednostki przed startem. Na kopii produkcji trafia na pięć przeszkód: flagę „produktywna” (`T001-XPROD`), którą kopia dziedziczy; dane CO, kasowane dla całego obszaru rachunku kosztów, a nie jednej jednostki; logistykę (zamówienia, faktury SD, dokumenty materiałowe), której nie rusza, więc system zostaje niespójny; brak wyboru po dacie; i wolumen. Jeśli celem jest system testowy bez historii FI, trzeba go zbudować bez niej: kopia samego customizingu (`SAP_CUST`) i wczytanie danych podstawowych, a dane osobowe maskuje się narzędziem do tego przeznaczonym, nie przez `OBR1`.

## Auf Deutsch: Stichwörter

`OBR1` setzt die Bewegungsdaten eines Buchungskreises zurück, auch in S/4HANA, ist aber für einen Testbuchungskreis vor dem Produktivstart gebaut; auf einer Produktionskopie scheitert es am Produktivkennzeichen, wirkt über den ganzen Kostenrechnungskreis und lässt die Logistik inkonsistent zurück.

Stichwörter: Bewegungsdaten zurücksetzen · Buchungskreis · Produktivkennzeichen · Kostenrechnungskreis · Universal Journal · Systemkopie · Mandantenkopie mit Customizing · Datenanonymisierung · Archivierung · Konsistenz zwischen FI und Logistik.

## Related pages

- [Document types and number ranges](../document_types_and_number_ranges/document_types_and_number_ranges.md) — the number range levels to compare before and after
- [Comparing posting keys between clients](../posting_keys/comparing_posting_keys_between_clients.md) — another question of what a copy carries from one client to the next
- [Currencies in the Universal Journal](../../03_Currency/universal_journal_currencies/README.md) — the one journal that makes FI and CO one line

Back to the chapter map: [FI](../README.md).

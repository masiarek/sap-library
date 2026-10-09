# Where-used of a table in DDL sources: what fourteen hits on `BUT0ID` say

**Level:** 201 · for anyone asked "which view has this field"

**One line:** The where-used list of a table, restricted to DDL sources, returns every CDS view that selects from the table *directly* and none that reads it through another view; so the fourteen hits on `BUT0ID`, the identification numbers of a business partner, are the places where those numbers are raw material, and the prefixes of the fourteen names say who the consumers are: the business object behind the partner's maintenance screens, two filter views for data-privacy blocking, the released interface view the API is built on, six employee views that find a personnel number in the table, two business-user views, and one custom view.

## What the screenshot shows

*Where-used Database table BUT0ID in DDL Sources (14 Hits)*, run from the table in `SE11`, with the DDL source and its short description:

| DDL source | Short description |
| :-- | :-- |
| `/BOFU/CV_BPIDENTIFICATION` | BOPF: /BOFU/BuPa Node Identification |
| `/BOFU/CV_Q_BPIDENTIFICATION` | Root Query on Identification |
| `FNDEI_BUT0ID_BLOCKINGINFO` | Filter View for table BUT0ID |
| `FNDEI_BUT0ID_FILTER` | Filter View for table BUT0ID |
| `I_BPUSREXTERNALID` | Business Partner External ID (Business User Management) |
| `I_BUPAIDENTIFICATION` | Business Partner Identification |
| `I_EMPLOYEEOP` | Employee CDS view for OP |
| `I_HCMEMPLOYEEADDRESSBOOK` | Employee Address Book |
| `P_BPUSRPERSONEXTERNALID` | Business Partner Person External ID - BUM |
| `P_EMPLOYEECL` | Employee view for Cloud |
| `P_N_EMPLOYEE` | Employee |
| `P_N_EMPLOYEEOP` | Employee view for OnPremise |
| `P_O_EMPLOYEEOP` | Employee view for OnPremise |
| `ZI_BUT0ID` | BP ID Numbers |

## Reading the list by prefix

A DDL source name carries its family in its first characters, and the family says why the view reads the table:

| Family | Hits | Why it reads `BUT0ID` | How sure |
| :-- | :-- | :-- | :-- |
| `/BOFU/CV_…` | 2 | The business object of the partner in the Business Object Processing Framework: a *combined view* per node (here the node *Identification*) and a *query view* for its root query. These are what the partner's Fiori maintenance and master data governance read and write through. | fairly sure |
| `FNDEI_…_FILTER`, `…_BLOCKINGINFO` | 2 | Filter views of the data-privacy blocking infrastructure: a partner whose purpose has ended is *blocked*, and a view annotated as requiring blocking (see [CDS view annotations](../cds_view_annotations/README.md)) is filtered through such a view so that the blocked partner's rows disappear. The same family exists for the other partner tables, which is the sign that it is one mechanism across tables, not one application. | fairly sure |
| `I_BUPAIDENTIFICATION` | 1 | The released interface view: the names, the authorization, the blocking and the delta for everyone above it, including [`API_BUSINESS_PARTNER`](../api_business_partner/README.md). | sure |
| `I_BPUSREXTERNALID`, `P_BPUSRPERSONEXTERNALID` | 2 | Business user management: a business user is a partner of category *person*, and the user's external identifier is stored as an identification number of a reserved type on that partner. | fairly sure |
| `I_EMPLOYEEOP`, `I_HCMEMPLOYEEADDRESSBOOK`, `P_EMPLOYEECL`, `P_N_EMPLOYEE`, `P_N_EMPLOYEEOP`, `P_O_EMPLOYEEOP` | 6 | The employee: in S/4HANA every employee is a business partner, and the link from the partner to the personnel number is an identification number of type `HCM001`. Six views, in on-premise and cloud variants, because the employee is read in six contexts (address book, authorizations, the employee's own data). | fairly sure, including the type |
| `ZI_BUT0ID` | 1 | A custom view in the same system, see [A custom view on `BUT0ID`](../custom_extraction_view/README.md). | sure |

So the one table serves four purposes: the identification numbers a user maintains (tax-office numbers, national IDs, registry numbers), the employee link, the business user link, and the blocking of all three. A custom view that reads the table directly reads all four at once, which is the first thing to know before building on it.

## What the list does not show

- **Views on views.** A view that selects from `I_BuPaIdentification` reads `BUT0ID` without appearing here. That is why the API's own view is absent: the chain to the service goes through the interface view, and the list stops at the first layer. To follow it, run the where-used of `I_BUPAIDENTIFICATION` next, and so on up.
- **Programs, function modules and classes.** They are the other categories of the same where-used dialog, unchecked here. `RFC_READ_TABLE`, which reads any table, appears in none of them, because it names the table at runtime; see [`RFC_READ_TABLE`](../rfc_read_table/README.md).
- **Other systems and other releases.** The list is of this system's DDL sources on this day: an S/4HANA release two years newer has more delivered views, and a system with more custom development has more `Z` ones.
- **Whether a hit is released.** `I_` and `P_` are naming conventions, not contracts. The release state of a view is in its properties in ADT (*API State*), and `P_` means private: a view SAP may change without notice.

## Running it

In `SE11` display the table, choose the where-used list, and in the dialog check only *DDL Sources* (named *Data Definitions* in some releases) before confirming. The list is built from the cross-reference index, so a view activated a minute ago may not be in it yet; and the same list can be built in ADT from the table's context menu, which is where the view's source is one click away. Run it from the table: run from inside a view's editor, the same function may report that it cannot generate the list for DDL sources, which is the message in one of the screenshots behind this chapter.

## How to verify this in your own system

| Claim | Where to prove it | How sure |
| :-- | :-- | :-- |
| The list holds direct readers only | Where-used of `I_BUPAIDENTIFICATION` and of `BUT0ID`; a view that selects from the former is in the first list and not the second | sure |
| The employee link is an identification of type `HCM001` | `SE16` on `BUT0ID` filtered by that type, for a partner you know to be an employee | fairly sure |
| The `FNDEI_` views exist for other partner tables | `SE11`, DDL source search `FNDEI_BUT*` | fairly sure |
| `P_` views are private, `I_` views may be released | ADT, *Properties* of each, *API State* | sure |
| The view names in the list | the screenshot; the same list in your system will differ | sure for that system |

## Provenance

The fourteen names and descriptions are read from a screenshot; everything about what each family does is from memory and graded. The identification type for employees is from memory of the employee integration and should be confirmed on a row. No claim was confirmed against a named system.

## Po polsku, w skrócie

Lista „gdzie użyto" tabeli, ograniczona do źródeł DDL, pokazuje tylko widoki CDS czytające tabelę bezpośrednio, nigdy widoki zbudowane na innych widokach. Czternaście trafień dla `BUT0ID` czyta się po przedrostkach: `/BOFU/` to obiekt biznesowy partnera, `FNDEI_` to filtry blokady danych osobowych, `I_BUPAIDENTIFICATION` to wydany widok interfejsowy, na którym stoi API, widoki pracownika czytają tabelę, bo numer osobowy jest w niej zapisany jako numer identyfikacyjny, a `ZI_BUT0ID` to widok własny. Jedna tabela służy więc czterem celom naraz, i widok własny czytający ją wprost dziedziczy wszystkie cztery.

## Auf Deutsch: Stichwörter

Die Verwendungsnachweis-Liste einer Tabelle in DDL-Quellen nennt nur die Views, die direkt aus der Tabelle lesen; die Präfixe der Treffer sagen, wer die Daten wofür braucht.

Stichwörter: Verwendungsnachweis · DDL-Quelle · Geschäftsobjekt · Sperrung personenbezogener Daten · Interface-View · Mitarbeiter als Geschäftspartner · Identifikationstyp · private View · Freigabezustand.

## Related pages

- [CDS view annotations](../cds_view_annotations/README.md) — the interface view from the list, line by line
- [A custom view on `BUT0ID`](../custom_extraction_view/README.md) — the `Z` view from the list, beside the delivered one
- [API_BUSINESS_PARTNER](../api_business_partner/README.md) — where the chain ends

Back to the chapter map: [Integration](../README.md).

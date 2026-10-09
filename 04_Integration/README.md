# Integration: one table, three ways out

**Level:** 201 → 301 · for ABAP developers, integration consultants, and anyone asked "where does this field come from"

**One line:** The identification numbers of a business partner live in one table, `BUT0ID`, and leave the system three ways: through the OData service `API_BUSINESS_PARTNER`, built in the Gateway Service Builder on CDS views; through those CDS views directly, as extraction sources with a change-data-capture delta; and through `RFC_READ_TABLE`, as 512-character rows of raw text; the chapter follows the one table along each path and shows what each path adds, a model and a contract, a delta, or nothing, and what each one costs.

## The map

| # | Page | The question it answers |
|---|---|---|
| 1 | [The Gateway Service Builder (SEGW)](service_builder_segw/README.md) | What does a `SEGW` project hold, what does generation derive from it, and why does my code go only into the `_EXT` classes? With a program that derives the names, `$metadata` and the methods. |
| 2 | [API_BUSINESS_PARTNER](api_business_partner/README.md) | What is the delivered service whose entity types fill the Service Builder's screen, set by set? |
| 3 | [Registering a service in the hub](registering_a_service_in_the_hub/README.md) | Why does *Add Service* propose `ZAPI_BUSINESS_PARTNER` for `API_BUSINESS_PARTNER`, and which of the two is in the URL? |
| 4 | [Finding a partner by its UCM number](finding_a_partner_by_identification/README.md) | The knowledge transfer: six steps from the table to the Gateway client, with what each proved. |
| 5 | [Where-used of a table](where_used_of_a_table/README.md) | What do fourteen hits on `BUT0ID` in DDL sources say about who reads it? |
| 6 | [CDS view annotations](cds_view_annotations/README.md) | What do the thirty lines above `I_BuPaIdentification`'s `select` promise, and how does the delta mapping work? With a program that replays a day of changes. |
| 7 | [A custom view on `BUT0ID`](custom_extraction_view/README.md) | What does a `Z` view on the same table lack, and when is it the right answer anyway? |
| 8 | [RFC_READ_TABLE](rfc_read_table/README.md) | What are the three tables of the function every "SAP table" connector calls, and where do its limits come from? With a program for the buffer, the catalogue and the clause. |
| 9 | [Resources](resources/README.md) | The books, courses, documentation and specifications behind the chapter, and how each connects to OData. |

## The through-line

Start with one row of `BUT0ID`: a partner number, an identification type, an identification number. A consumer outside the system can get it three ways.

Through the **API**, the row is an entry of `A_BuPaIdentification`: it has the names of the virtual data model, the partner number without its leading zeros, an initial date as `null`, the authorization and the blocking of the view it is built on, and a filter the server applies. Between the table and the entry stand a CDS interface view, a project in the Service Builder that references it, four generated classes, and a registration in the hub with two names, one for the administrator and one for the URL. Each layer is a place where a field can be dropped, and the chapter's first four pages are those layers.

Through the **CDS view**, the row is an extraction source: the same names, the same authorization, and, because the view's annotations map its key to the table's, a delta that names the changed rows and the deleted ones. A custom view on the same table that lacks the mapping gets a full load every time; the next three pages are the delivered view, the custom one, and the where-used list that found them both.

Through **`RFC_READ_TABLE`**, the row is 149 characters of text at fixed offsets, with leading zeros, dates of zeros, and no idea which partner is blocked. Nothing is added and nothing is checked beyond the table authorization and an allow-list, which is why the function is both the most used and the most restricted way out.

The chapter's claim is that the three ways are not three tools but three amounts of contract, and that the amount is visible: in the entity set's `$metadata`, in the view's annotations, and in the function's three tables.

## A note on the code

The three programs are stdlib Python and simulate rules, not SAP: the Service Builder's name and method derivation and the dispatch of a URL to a method; the conversion of logged table changes into view keys through the change-data-capture mapping; and the arithmetic of `RFC_READ_TABLE`'s field catalogue, row buffer and clause lines. Each page says how sure it is of the rule its program follows, and where to check it in a system.

## Po polsku, w skrócie

Jeden wiersz tabeli `BUT0ID` opuszcza system trzema drogami: przez serwis OData `API_BUSINESS_PARTNER`, zbudowany w Service Builderze na widokach CDS; przez same widoki CDS jako źródło ekstrakcji z deltą; i przez `RFC_READ_TABLE` jako surowy tekst. Każda droga dodaje inną ilość umowy: model i kontrakt, deltę, albo nic. Rozdział idzie za tą jedną tabelą każdą z dróg, od modelu w SEGW przez rejestrację w hubie po klienta Gateway, od listy „gdzie użyto" przez adnotacje widoku po widok własny, i kończy na funkcji, której wszystkie ograniczenia mieszczą się w trzech tabelach.

## Auf Deutsch: Stichwörter

Eine Tabelle, drei Wege hinaus: OData-Service, CDS-Extraktion mit Delta, `RFC_READ_TABLE` als Rohtext; der Unterschied ist die Menge an Vertrag, die jeder Weg mitbringt.

Stichwörter: Integration · Service Builder · OData · Gateway-Hub · CDS-View · Extraktion · Delta · Verwendungsnachweis · RFC · Geschäftspartner · Identifikationsnummer.

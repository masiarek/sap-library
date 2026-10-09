# Reading a delivered CDS view: `I_BuPaIdentification` and its annotations

**Level:** 201 · for anyone who opened a delivered view and found thirty lines before the `select`

**One line:** The DDL source of `I_BuPaIdentification` opens with twenty-nine lines of annotations, and each one is a contract with a different consumer: the layer of the virtual data model it belongs to, the authorization check and the personal-data blocking it insists on, the usage grade it promises, the analytic role it plays, and, under `@Analytics.dataExtraction`, a change-data-capture mapping that lets an extractor fetch only the rows that changed, deletions included, because the mapping tells the system which *view* row a changed *table* row belongs to.

## What the screenshot shows

*Display Data Definition* for `I_BUPAIDENTIFICATION`, status *Active*, tab *Content*, with an ADT link to the source and the first twenty-nine lines:

```text
@EndUserText.label: 'Business Partner Identification' //same as DDL description
@VDM.viewType: #BASIC
@AccessControl.authorizationCheck: #CHECK
@AccessControl.personalData.blocking: #REQUIRED
@ObjectModel.usageType.serviceQuality: #A
@ObjectModel.usageType.sizeCategory: #XXL
@ObjectModel.usageType.dataClass: #MASTER
@ObjectModel.supportedCapabilities: [#SQL_DATA_SOURCE,
                                     #CDS_MODELING_DATA_SOURCE,
                                     #CDS_MODELING_ASSOCIATION_TARGET,
                                     #EXTRACTION_DATA_SOURCE,
                                     #ANALYTICAL_DIMENSION]
@ObjectModel.modelingPattern: #ANALYTICAL_DIMENSION
@ObjectModel.representativeKey: 'BPIdentificationNumber'
@Analytics.technicalName: 'IBUPAID'
@Metadata.ignorePropagatedAnnotations: true
@Analytics: {
  dataCategory: #DIMENSION,
  dataExtraction: {
    enabled: true,
    delta.changeDataCapture: {
      mapping:[
                {
                  table: 'BUT0ID', role: #MAIN,
                  viewElement: ['BusinessPartner','BPIdentificationType' , 'BPIdentificationNumber'],
                  tableElement: ['partner','type','idnumber']
                },
                {
                  table: 'BUT000', role: #LEFT_OUTER_TO_ONE_JOIN,
```

The `define view` line and the select list are below the fold; this page is about the lines above it.

## Annotation by annotation

| Annotation | What it says | Who reads it | How sure |
| :-- | :-- | :-- | :-- |
| `@EndUserText.label` | The text shown for the view in value helps, in Fiori, and in the description column of a where-used list | every UI | sure |
| `@VDM.viewType: #BASIC` | The view's layer in the virtual data model: a *basic* view sits directly on tables and states the semantics once; *composite* views combine basic ones; *consumption* views serve one application or API. Build on a basic view, not beside it. | modellers; the ATC checks | sure |
| `@AccessControl.authorizationCheck: #CHECK` | An access control (a DCL source) exists for the view and every `SELECT` through it is filtered by it. Without a DCL the same annotation gives a warning at activation and no filtering. | the CDS runtime | sure |
| `@AccessControl.personalData.blocking: #REQUIRED` | The rows are personal data under end-of-purpose blocking: a partner whose purpose has ended is blocked, and the view must not show its rows. The `FNDEI_BUT0ID_FILTER` view in the [where-used list](../where_used_of_a_table/README.md) is that mechanism. | the blocking framework | fairly sure |
| `@ObjectModel.usageType.serviceQuality: #A` | A grade of the view's runtime behaviour that its author promises, `A` the best; `D` means under development, `P` private, `X` not for use. | query designers, the extraction, ATC | fairly sure on the letters |
| `@ObjectModel.usageType.sizeCategory: #XXL` | The expected data volume, `S` to `XXL`. Consumers decide from it what they may do with the view (a query on an `XXL` dimension is handled differently from one on `S`). | the same | sure |
| `@ObjectModel.usageType.dataClass: #MASTER` | Master data, as opposed to transactional, organisational, customizing, meta or mixed. | the same | sure |
| `@ObjectModel.supportedCapabilities` | What the view is released for: a data source in SQL and in other CDS views, an association target, an extraction source, an analytical dimension. A use outside the list is an ATC finding on the custom view that does it. | ATC; readers | fairly sure |
| `@ObjectModel.modelingPattern: #ANALYTICAL_DIMENSION` | The modelling pattern the view follows, here a dimension of the analytic model | the analytic engine | sure |
| `@ObjectModel.representativeKey: 'BPIdentificationNumber'` | Which key element represents the entity the view describes; the element the dimension is *of*. | associations, analytics | fairly sure |
| `@Analytics.technicalName: 'IBUPAID'` | A short technical name for the view as an analytic object, the one BW shows (as a transient provider named `2C` plus this) | BW, the query | fairly sure |
| `@Metadata.ignorePropagatedAnnotations: true` | Annotations propagated from the data elements and the underlying objects are not inherited; the view states its own | the CDS compiler | sure |
| `@Analytics.dataCategory: #DIMENSION` | For analytics the view is a dimension (master data), not a fact (transactions with measures) | the analytic engine, BW | sure |
| `@Analytics.dataExtraction.enabled: true` | The view is an extraction source: it appears in the ODP context for ABAP CDS and can be loaded into BW, BW/4HANA, Datasphere and the other ODP consumers | ODP | sure |
| `delta.changeDataCapture.mapping` | The change-data-capture mapping: for each table the view reads, its role in the join and which view elements hold its key, so that a logged change of a table row can be turned into the key of a view row. `#MAIN` is the table whose rows are the view's rows; `#LEFT_OUTER_TO_ONE_JOIN` is a table joined to-one, whose change touches every view row that joins to it. | the ODP delta | sure on the mechanism, fairly sure on the internals |

## The mapping at work

Change data capture is what makes a delta possible on a table that has no timestamp: the system logs the key of every changed row of the mapped tables, and the mapping converts those keys into view keys. The program below keeps the two tables in memory, replays three changes, and prints what a delta extraction hands over against what a full extraction would:

<!-- output:cds_delta_capture -->
*Verified output of [`cds_delta_capture.py`](examples/cds_delta_capture.py) — regenerated by `tools/run_examples.py`, never hand-typed.*

```text
initial load: a full extraction, every row of the view
   ('0017100001', 'HCM001', '00001234')  name='Kowalski Sp. z o.o.'
   ('0017100001', 'ZNIP', '5261040828')  name='Kowalski Sp. z o.o.'
   ('0017100002', 'ZNIP', '7010001234')  name='Nowak S.A.'

a day of changes:
   insert BUT0ID (0017100002, ZPESEL, 85050512345)
   update BUT000 0017100001: new name
   delete BUT0ID (0017100001, HCM001, 00001234)
   change log: [('BUT0ID', 'I', ('0017100002', 'ZPESEL', '85050512345')), ('BUT000', 'U', ('0017100001',)), ('BUT0ID', 'D', ('0017100001', 'HCM001', '00001234'))]

delta extraction with the mapping: only the view rows the log names
   D  ('0017100001', 'HCM001', '00001234')  (delete image: keys only, the row is gone)
   U  ('0017100001', 'ZNIP', '5261040828')  name='Kowalski i Wspolnicy Sp. z o.o.' country='PL'
   I  ('0017100002', 'ZPESEL', '85050512345')  name='Nowak S.A.' country='PL'
   the BUT000 update produced one delta row per identification of that partner,
   because the mapping says BUT000 joins to-one on BusinessPartner; the deleted
   identification is sent as a delete image, which a full load could never express

a view without the mapping (the custom view on BUT0ID): full extraction, again
   ('0017100001', 'ZNIP', '5261040828')  name='Kowalski i Wspolnicy Sp. z o.o.'
   ('0017100002', 'ZNIP', '7010001234')  name='Nowak S.A.'
   ('0017100002', 'ZPESEL', '85050512345')  name='Nowak S.A.'
   the consumer gets every row and has to find the changes itself; a deleted row
   is simply absent, and nothing says which one

a second delta run with nothing logged:
    empty: the extractor has nothing to send
```
<!-- /output -->

Two things to read off it:

- **A change in the joined table fans out.** The partner's name changed once in `BUT000`; the delta carried every identification of that partner, because the mapping says `BUT000` joins to-one on `BusinessPartner` and the view's rows all carry that name. The fan-out is the price of a delta on a join, and it is why a view with many to-one joins to large tables is a slow extraction source.
- **A deletion is a record.** The deleted identification arrived as a delete image with its key. A full extraction can only omit the row, and a consumer that compares two full loads to find deletions has to keep both. The custom view on the same table has no mapping and no delta, see [A custom view on `BUT0ID`](../custom_extraction_view/README.md).

## What the annotations do not say

- **The select list, the joins and the associations** are below the fold, and the first twenty-nine lines cannot tell you whether the view is a classic `define view` with an SQL view name or a `define view entity`; the `define` line does.
- **Whether the view is released** for use in custom code with a stability contract. `I_` is a naming convention; the release state is in the view's properties in ADT (*API State*) and nowhere in the DDL source.
- **The access control itself**: the DCL is a separate source with the same name; read it to know what the check filters by.

## Where S/4HANA differs

In ABAP Cloud (S/4HANA Cloud, and on premise under the cloud development rules) only released objects may be used in custom code, so a custom view on `BUT0ID` is not allowed there and a view on `I_BuPaIdentification` is, if the release contract permits it; the ATC check `S4HANA_READINESS` and the cloud variant report the difference. Newer releases rewrite delivered views as view entities, which changes nothing above except that the SQL view name disappears.

## How to verify this in your own system

| Claim | Where to prove it | How sure |
| :-- | :-- | :-- |
| The annotation lines as quoted | `SE11`, *Data Definition* `I_BUPAIDENTIFICATION`, tab *Content*; or ADT | sure (the screenshot) |
| `#CHECK` without a DCL warns and does not filter | activate a copy of the view with `#CHECK` and no DCL; read the warning; `SELECT` through it | sure |
| The view is an ODP extraction source | `RSA3`-style ODP test, or the ODP source list in the consumer (context `ABAP_CDS`) | sure |
| The delta carries delete images | extract once, delete an identification, extract the delta | fairly sure |
| A to-one join change fans out | change a partner name, extract the delta, count the rows | fairly sure |
| The release state is in ADT, not in the DDL | ADT, *Properties* of the view, *API State* | sure |
| `P_` views are private | the same tab on `P_N_EMPLOYEE` | sure |
| The meaning of `serviceQuality` letters | the annotation documentation, or F2 on the annotation in ADT | fairly sure |

## Provenance

The twenty-nine lines are transcribed from a screenshot of the development system that showed them; the system's name is left out at the owner's request. The meaning of each annotation is from memory of the ABAP CDS annotation documentation, graded in the tables. The program simulates the mechanism the mapping describes; it is not the ODP implementation. No claim was confirmed against a named system.

## Po polsku, w skrócie

Dostarczony widok CDS zaczyna się od trzydziestu linii adnotacji i każda z nich jest umową z innym odbiorcą: `@VDM.viewType` mówi, w której warstwie wirtualnego modelu danych widok leży, `@AccessControl` wymusza kontrolę uprawnień i blokadę danych osobowych, `@ObjectModel.usageType` obiecuje jakość i rozmiar, `@Analytics` nadaje rolę analityczną. Najważniejsza jest mapa `changeDataCapture`: mówi, które elementy widoku są kluczem każdej czytanej tabeli, dzięki czemu zmiana wiersza tabeli zamienia się w klucz wiersza widoku, a ekstraktor dostaje tylko zmienione wiersze, razem z usunięciami. Widok bez tej mapy można wyciągać tylko w całości.

## Auf Deutsch: Stichwörter

Jede Annotation einer ausgelieferten CDS-View ist ein Vertrag mit einem anderen Verbraucher, und die Change-Data-Capture-Zuordnung macht aus einer geänderten Tabellenzeile den Schlüssel einer View-Zeile.

Stichwörter: Virtuelles Datenmodell · Basis-View · Zugriffskontrolle · Sperrung personenbezogener Daten · Nutzungstyp · unterstützte Fähigkeiten · Dimension · Datenextraktion · Delta · Change Data Capture · Löschsatz · Freigabezustand.

## Related pages

- [Where-used of a table](../where_used_of_a_table/README.md) — how this view was found
- [A custom view on `BUT0ID`](../custom_extraction_view/README.md) — the same table without the contracts
- [API_BUSINESS_PARTNER](../api_business_partner/README.md) — the service built on views like this one

Back to the chapter map: [Integration](../README.md).

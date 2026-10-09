# A custom view on `BUT0ID` beside the delivered one

**Level:** 201 · for whoever is about to write `select from but0id`

**One line:** The custom view `ZI_BUT0ID` reads the same table as `I_BuPaIdentification` and carries half of its annotations, and the missing half is the half that costs at runtime: without a change-data-capture mapping it can only be extracted in full, as a `#FACT` it tells the analytic engine the opposite of what an identification table is, with `Partner` as representative key it names an element that does not identify a row, and as a classic view with an SQL view name it uses the form S/4HANA is retiring; what it has that the delivered view does not is the owner's choice of columns and the freedom to change them.

## What the screenshot shows

*Display Data Definition* for `ZI_BUT0ID`, with the first twenty-nine lines:

```text
@AbapCatalog.sqlViewName: 'ZIBUT0ID'
@AbapCatalog: {
   preserveKey: true
}
@VDM.viewType: #BASIC

@AccessControl: {
  authorizationCheck: #CHECK
}
@EndUserText.label: 'BP ID Numbers'
@ObjectModel.representativeKey: 'Partner'
@Analytics.dataCategory: #FACT
@ObjectModel.usageType.serviceQuality: #A
@ObjectModel.usageType.sizeCategory : #L
@ObjectModel.usageType.dataClass: #MASTER
@ClientHandling.algorithm: #SESSION_VARIABLE
@Metadata.allowExtensions:true
@Metadata.ignorePropagatedAnnotations: true
@Analytics:{
    dataExtraction: {
        enabled: true
  }
}
define view ZI_BUT0ID as select from but0id
 {
 key partner as Partner,
 key type as Type,
 key idnumber as Idnumber,
     institute as Institute,
```

## Side by side

| Aspect | `ZI_BUT0ID` | `I_BuPaIdentification` | What follows | How sure |
| :-- | :-- | :-- | :-- | :-- |
| Form | `define view` with `@AbapCatalog.sqlViewName: 'ZIBUT0ID'`: a classic view that generates a Dictionary SQL view | not visible in the first lines; a view entity has no SQL view name | Classic views still work; new ones should be `define view entity`, and the ATC says so. A view entity needs no SQL view name and no `preserveKey`. | sure |
| `@AbapCatalog.preserveKey: true` | present | not applicable | The SQL view's key is the CDS key (`partner`, `type`, `idnumber`) rather than one derived by the Dictionary. Right for a classic view; irrelevant for an entity. | sure |
| `@VDM.viewType: #BASIC` | basic | basic | Two basic views on one table. The VDM rule is that a table has one basic view and everything else builds on it; a second basic view duplicates the semantics and misses every later change SAP makes to the first. | fairly sure on the rule |
| `@AccessControl.authorizationCheck: #CHECK` | `#CHECK` | `#CHECK` | Both insist on a DCL. The delivered view has one. The custom view needs its own, or the annotation is a warning and the data is unfiltered. | sure |
| `@AccessControl.personalData.blocking` | absent | `#REQUIRED` | The custom view shows blocked partners' identification numbers. | fairly sure |
| `@EndUserText.label` | *BP ID Numbers* | *Business Partner Identification* | | sure |
| `@ObjectModel.representativeKey` | `Partner` | `BPIdentificationNumber` | The representative key names the element the entity is *of*. A row of this view is an identification number, not a partner; `Partner` does not identify a row. | fairly sure |
| `@Analytics.dataCategory` | `#FACT` | `#DIMENSION` | A fact view is transaction data with measures; identification numbers have none. An analytic consumer treats the custom view as a fact table and offers it where a dimension belongs. | fairly sure |
| `@ObjectModel.usageType` | `A`, `L`, `MASTER` | `A`, `XXL`, `MASTER` | Two estimates of the same table's size. The table is the same, so one of them is wrong; `SE16` with a count says which. | sure |
| `@ClientHandling.algorithm: #SESSION_VARIABLE` | present | not shown | The client is taken from the session variable rather than from the table's client field. For a plain view on one client-dependent table the result is the same rows. | fairly sure |
| `@Metadata.allowExtensions: true` | present | not shown | A metadata extension (DDLX) may add annotations without changing this source. Harmless; useful for UI annotations. | sure |
| `@Metadata.ignorePropagatedAnnotations: true` | present | present | | sure |
| `@Analytics.dataExtraction.enabled: true` | present, nothing else | present, with `delta.changeDataCapture` | The custom view is an ODP source with full extraction only; the delivered one has a delta with delete images. The program on the [annotations page](../cds_view_annotations/README.md) shows the difference on three changes. | sure |
| Element names | `Partner`, `Type`, `Idnumber`, `Institute` | `BusinessPartner`, `BPIdentificationType`, `BPIdentificationNumber` | The delivered names are the VDM's, shared with every other partner view and with the API; the custom names are the table's with a capital. A consumer that joins this view to a delivered one maps the names by hand. | sure |

## When a custom view is the right answer

A custom basic view on a delivered table is right when the delivered view hides a column you need, joins differently from what you need, or does not exist. None of the three holds for `BUT0ID`: `I_BuPaIdentification` is released as an extraction source and a modelling source, and it carries authorization, blocking and delta.

So the better shape of the same requirement is one of two:

- **Extract the delivered view as it is** and rename elements in the target. The delta comes with it.
- **Build on the delivered view**, `select from I_BuPaIdentification`, for a different column set or a join; then the names, the authorization and the blocking are inherited. A delta on the new view needs its own `@Analytics.dataExtraction` with a change-data-capture mapping that names the tables (the mapping follows the view stack down to the tables, so it can be written), and that is the only part that must be written again.

If the custom view stays, the four lines that cost nothing to fix: `#DIMENSION` instead of `#FACT`; `Idnumber` as representative key; a DCL, or `#NOT_REQUIRED` written consciously; and the change-data-capture mapping copied from the delivered view with the three element names adjusted, which turns the full load into a delta.

## How to verify this in your own system

| Claim | Where to prove it | How sure |
| :-- | :-- | :-- |
| The custom view has no DCL | `SE11` or ADT, access control with the view's name; the activation log of the view | sure |
| `#CHECK` without a DCL leaves the data unfiltered | `SELECT` through the view with a user who lacks the authorization the delivered DCL checks | sure |
| Full load only without a mapping | the ODP source's delta capability in the consumer (BW: the DataSource's delta method) | fairly sure |
| The ATC flags a classic view | ATC with the readiness or cloud variant on the view | fairly sure |
| `#FACT` changes how an analytic consumer treats the view | the query designer or the analytic query on top of each view | fairly sure |
| The table's row count | `SE16` on `BUT0ID`, *Number of Entries* | sure |

## Provenance

The twenty-nine lines are transcribed from a screenshot; the system is left out at the owner's request. The comparison is from memory of the annotation documentation and the VDM guidelines, graded. No claim was confirmed against a named system.

## Po polsku, w skrócie

Widok własny `ZI_BUT0ID` czyta tę samą tabelę co dostarczony `I_BuPaIdentification`, ale ma tylko połowę jego adnotacji, i brakuje właśnie tej połowy, która coś kosztuje: nie ma mapy change data capture, więc ekstrakcja jest zawsze pełna; jest oznaczony jako `#FACT`, choć numery identyfikacyjne to dane podstawowe bez miar; klucz reprezentatywny `Partner` nie identyfikuje wiersza; a klasyczna składnia z nazwą widoku SQL jest wycofywana. Lepszy kształt tej samej potrzeby to ekstrakcja widoku dostarczonego albo widok zbudowany na nim, który dziedziczy nazwy, uprawnienia i blokadę.

## Auf Deutsch: Stichwörter

Eine eigene Basis-View auf einer Tabelle, für die SAP schon eine ausliefert, verdoppelt die Semantik und verliert Delta, Sperrung und Berechtigung; besser auf der gelieferten View aufsetzen.

Stichwörter: eigene View · SQL-View-Name · View-Entität · Zugriffskontrolle fehlt · Faktum oder Dimension · repräsentativer Schlüssel · Vollextraktion · Delta-Zuordnung · Namenskonvention.

## Related pages

- [CDS view annotations](../cds_view_annotations/README.md) — the delivered view, line by line, with the delta program
- [Where-used of a table](../where_used_of_a_table/README.md) — where both views were found
- [RFC_READ_TABLE](../rfc_read_table/README.md) — the way out that has no annotations at all

Back to the chapter map: [Integration](../README.md).

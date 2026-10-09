# API_BUSINESS_PARTNER: the Business Partner API, read in the Service Builder

**Level:** 201 · for anyone who met `A_BusinessPartnerType` in `SEGW` and asked what this is

**One line:** `API_BUSINESS_PARTNER` is the released OData V2 service of S/4HANA for the business partner: one entity set per aspect of a partner (general data, roles, addresses with their phone numbers and e-mail addresses, identification numbers, tax numbers, bank details, contact persons) and one per aspect of the customer and supplier views (company code, sales area, purchasing organisation, dunning, texts); it is a Service Builder project on CDS views, so `SEGW` shows its model, and the entity type names ending in `Type` are the project's convention for a type whose entity set, the name in the URL, drops the suffix.

## What the screenshot shows

The Service Builder with the project `API_BUSINESS_PARTNER` open at *Data Model → Entity Types*, the first eleven in alphabetical order: `A_BusinessPartnerRoleType`, `A_BusinessPartnerTaxNumberType`, `A_BusinessPartnerType`, `A_BusPartAddrDepdntTaxNmbrType`, `A_CustAddrDepdntExtIdentifierType`, `A_CustAddrDepdntInformationType`, `A_CustomerCompanyTextType`, `A_CustomerCompanyType`, `A_CustomerDunningType`, `A_CustomerSalesAreaTaxType`, `A_CustomerSalesAreaTextType`. The list continues below the fold.

Three things the names alone say:

- **`A_`** is SAP's prefix for API entities, as `I_` is for interface views, `C_` for consumption views and `P_` for private ones, see [CDS view annotations](../cds_view_annotations/README.md). The entity sets of this service all start with it.
- **`Type`** at the end is the *entity type*; the *entity set* has the same name without it, and the set is what a URL addresses: `/sap/opu/odata/sap/API_BUSINESS_PARTNER/A_BusinessPartner`. In `$metadata` the type is `API_BUSINESS_PARTNER.A_BusinessPartnerType` and the set `A_BusinessPartner`.
- **The abbreviations** (`BusPartAddrDepdntTaxNmbr`) are the 30-character limit on the name of a CDS view, which the entity type was named after; the Service Builder's own limit on method names is the one in [the Service Builder page](../service_builder_segw/README.md).

## What the service is

| | |
|---|---|
| Listed on | the SAP Business Accelerator Hub (api.sap.com, formerly the API Business Hub) as *Business Partner (A2X)*, OData V2, for S/4HANA Cloud and on premise |
| Service document | `/sap/opu/odata/sap/API_BUSINESS_PARTNER/`; `$metadata` behind it |
| What it does | reads and maintains business partners together with their customer and supplier views: GET on every set, POST with a deep body (a partner with its roles, addresses and customer view in one request), PATCH or PUT, DELETE on some sets; which operation each set allows is in the `sap:` attributes of its `EntitySet` element in `$metadata`, not in this page |
| Who calls it | integration middleware (SAP Integration Suite and its predecessors), master data distribution, third-party CRM and e-commerce systems, custom applications, and anyone who needs partner data without an RFC user |
| Access, on premise | a user with the business partner authorizations, and the service registered and active in the Gateway hub, see [Registering a service in the hub](../registering_a_service_in_the_hub/README.md) |
| Access, S/4HANA Cloud | a communication arrangement for the scenario `SAP_COM_0008`, *Business Partner, Customer and Supplier Integration*, with a communication user |

## The entity sets, by aspect of the partner

The service follows the partner's own data model, one set per table family. The table names are the ones the sets' data ultimately comes from; the view each set is referenced from is read in the project, not here.

| Entity set | Aspect | Tables behind it | How sure |
| :-- | :-- | :-- | :-- |
| `A_BusinessPartner` | general data: category, grouping, names, created on | `BUT000` | sure |
| `A_BusinessPartnerRole` | roles (`FLCU00`, `FLCU01`, `FLVN00`, `FLVN01` and the rest) | `BUT100` | sure |
| `A_BusinessPartnerAddress` | addresses and their usages | `BUT020`, `BUT021_FS`, `ADRC` | sure on `BUT020` and `ADRC` |
| `A_AddressEmailAddress`, `A_AddressPhoneNumber`, `A_AddressFaxNumber`, `A_AddressHomePageURL` | communication data of one address | `ADR6`, `ADR2`, `ADR3`, `ADR12` | fairly sure |
| `A_BuPaIdentification` | identification numbers: a type and a number, with validity and issuer | `BUT0ID` | sure |
| `A_BusinessPartnerTaxNumber` | tax numbers by tax category | `DFKKBPTAXNUM` | fairly sure |
| `A_BusinessPartnerBank` | bank details | `BUT0BK` | sure |
| `A_BusinessPartnerContact`, `A_BPContactToAddress`, `A_BPContactToFuncAndDept` | contact persons: the relationship, its address, function and department | `BUT050`, `BUT051`, `BUT052` | fairly sure |
| `A_Customer`, `A_CustomerCompany`, `A_CustomerSalesArea`, `A_CustomerDunning`, `A_CustomerSalesAreaTax`, `A_CustomerWithHoldingTax` | the customer view: general, company code, sales area, dunning per company code, tax classification, withholding tax | `KNA1`, `KNB1`, `KNVV`, `KNB5`, `KNVI`, `KNBW` | sure on the tables, fairly sure on every set name |
| `A_CustomerCompanyText`, `A_CustomerSalesAreaText` | long texts of the two segments | text objects | from the screenshot only |
| `A_Supplier`, `A_SupplierCompany`, `A_SupplierPurchasingOrg`, `A_SupplierDunning`, `A_SupplierPartnerFunc`, `A_SupplierWithHoldingTax` | the supplier view: general, company code, purchasing organisation, dunning, partner functions, withholding tax | `LFA1`, `LFB1`, `LFM1`, `LFB5`, `WYT3`, `LFBW` | sure on the tables, fairly sure on the set names |
| `A_BusPartAddrDepdntTaxNmbr`, `A_CustAddrDepdntExtIdentifier`, `A_CustAddrDepdntInformation` | address-dependent tax numbers and customer data, added in later releases | | from the screenshot only |

Navigation properties tie the sets together from the partner down: `to_BusinessPartnerRole`, `to_BusinessPartnerAddress`, `to_BuPaIdentification`, `to_BusinessPartnerTax`, `to_BusinessPartnerBank`, `to_Customer`, `to_Supplier`, `to_BusinessPartnerContact` on `A_BusinessPartner`; `to_EmailAddress`, `to_PhoneNumber`, `to_FaxNumber`, `to_URLAddress` on the address; `to_CustomerCompany` and `to_CustomerSalesArea` on `A_Customer`; `to_SupplierCompany` and `to_SupplierPurchasingOrg` on `A_Supplier` (fairly sure on each name; `$metadata` is the list). A `$expand` along them is how one request fetches a whole partner.

## Reading it in `SEGW`

Open the project and read, do not change: a delivered project is overwritten by the next upgrade, and extensions go either through the key-user *Custom Fields* app, whose fields can be enabled for this API, or through a project of your own that *redefines* this service (*Redefine → OData Service (SAP GW)*), which copies the model and lets you add to it.

What the four nodes hold for this project:

- **Data Model → Entity Types**: the screenshot. Expand one and its *Properties* node lists the elements with their EDM types; the type's data source is the CDS view it is referenced from, and that view's name is the answer to "where does this field come from".
- **Runtime Artifacts**: the four classes. The default names would have been 31 characters, so they were chosen by hand, see the first section of the output on [the Service Builder page](../service_builder_segw/README.md). Their names are read here, not derived.
- **Service Maintenance**: the hub systems the service is registered in, with the registration status.

## From the table to the entity set

The chain for one field, worked backwards from a consumer:

1. The consumer reads `A_BuPaIdentification` with `BPIdentificationType` and `BPIdentificationNumber`.
2. The entity type `A_BuPaIdentificationType` in `SEGW` is referenced from a CDS view, which is where the EDM names come from.
3. The [where-used list of `BUT0ID`](../where_used_of_a_table/README.md) in DDL sources names `I_BuPaIdentification`, the released interface view with those element names, which [its annotations](../cds_view_annotations/README.md) show to be the one with authorization, blocking and delta.
4. The table is `BUT0ID`: `PARTNER`, `TYPE`, `IDNUMBER` and the rest.

Each layer adds something the layer below does not have: the table has the data, the interface view the names, the authorization and the delta, the API view the stable release contract, and the service the HTTP surface. A field that is in the table but not in the service was dropped at one of the three steps, and the step is where to look.

## Calling it

```text
GET  /sap/opu/odata/sap/API_BUSINESS_PARTNER/A_BusinessPartner('17100001')?$expand=to_BuPaIdentification
GET  /sap/opu/odata/sap/API_BUSINESS_PARTNER/A_BuPaIdentification?$filter=BPIdentificationType eq 'ZUCM01' and BPIdentificationNumber eq 'UCM0815'&$select=BusinessPartner
GET  /sap/opu/odata/sap/API_BUSINESS_PARTNER/A_BusinessPartner?$top=50&$skip=0&$inlinecount=allpages
POST /sap/opu/odata/sap/API_BUSINESS_PARTNER/A_BusinessPartner        with a deep body: roles and addresses inside the partner
```

Two things every first caller meets:

- **The CSRF token.** A GET with the header `X-CSRF-Token: Fetch` returns a token, and every POST, PATCH or DELETE must send it back, in the same session (cookie). Without it the hub answers with an error on the token, not on the data.
- **The partner number comes without its leading zeros.** `BUT000-PARTNER` holds `0017100001`; the entry returns `BusinessPartner` as `17100001`, because the service applies the field's conversion exit on output, and a key sent back must be in that form too. Seen on a response, see [the knowledge-transfer page](../finding_a_partner_by_identification/README.md).
- **An initial date is `null`.** `BUT0ID` holds `00000000` in the validity dates of most identifications; the entry carries `ValidityStartDate` and `ValidityEndDate` with `m:null="true"`, not an error and not a date. Seen on the same response.

The properties of one `A_BuPaIdentification` entry, as returned: `BusinessPartner`, `BPIdentificationType`, `BPIdentificationNumber`, `BPIdnNmbrIssuingInstitute`, `BPIdentificationEntryDate`, `Country`, `Region`, `ValidityStartDate`, `ValidityEndDate`, `AuthorizationGroup`. That is `BUT0ID` with the view's names and without the client, the GUID and the extension include.

## How to verify this in your own system

| Claim | Where to prove it | How sure |
| :-- | :-- | :-- |
| The service document and `$metadata` URL | `/IWFND/GW_CLIENT`, GET on `/sap/opu/odata/sap/API_BUSINESS_PARTNER/$metadata` | sure |
| Entity set name = entity type name without `Type` | the `EntityContainer` section of that `$metadata` | sure |
| Which operations each set allows | the `sap:creatable`, `sap:updatable`, `sap:deletable` attributes on each `EntitySet` | sure |
| The CDS view behind an entity type | `SEGW`, the project, the entity type's node and its data source | sure |
| The class names were chosen by hand | `SEGW`, *Runtime Artifacts*: compare with the default pattern | sure |
| The navigation property names | `$metadata`, `NavigationProperty` elements of `A_BusinessPartnerType` | fairly sure |
| The partner number is returned without leading zeros; initial dates as `null` | a GET on one `A_BuPaIdentification` entry in `/IWFND/GW_CLIENT`, against the row in `SE16` | sure (seen) |
| The properties of `A_BuPaIdentification` | the same response, or `$metadata` | sure (seen) |
| `SAP_COM_0008` is the Cloud scenario | the *Communication Arrangements* app in S/4HANA Cloud | sure |
| Tables behind each set | the view behind the entity type, then its `select from` | as per the table above |

## Provenance

Written from working knowledge of the S/4HANA business partner and of this service as consumed from integration middleware, from memory, with no SAP documentation reachable from the writing session. The entity type names in the first section are read from a screenshot of the Service Builder, and the properties of `A_BuPaIdentification`, the leading zeros and the `null` dates from a screenshot of one response; everything below the fold of that list is from memory and marked as such in the table. No claim was confirmed against a named system.

## Po polsku, w skrócie

`API_BUSINESS_PARTNER` to standardowy serwis OData V2 systemu S/4HANA dla partnera biznesowego. Każdy aspekt partnera (dane ogólne, role, adresy, numery identyfikacyjne, numery podatkowe, banki, osoby kontaktowe) i każdy segment widoku klienta i dostawcy (jednostka gospodarcza, obszar zbytu, organizacja zakupów) ma własny zbiór encji o nazwie z przedrostkiem `A_`. Serwis zbudowano w SEGW na widokach CDS, więc projekt można otworzyć i przeczytać: typ encji kończy się na `Type`, a zbiór, czyli nazwa w adresie URL, tej końcówki nie ma. Łańcuch od tabeli do serwisu biegnie przez widok interfejsowy `I_`, który dodaje nazwy, uprawnienia i deltę, i przez widok API, który dodaje kontrakt wydania.

## Auf Deutsch: Stichwörter

`API_BUSINESS_PARTNER` ist der freigegebene OData-V2-Service für den Geschäftspartner, im Service Builder auf CDS-Views gebaut, mit einer Entitätsmenge je Aspekt des Partners.

Stichwörter: Geschäftspartner · Entitätsmenge `A_` · Entitätstyp mit `Type` · Rollen · Adressen · Identifikationsnummern · Steuernummern · Kundensicht und Lieferantensicht · Kommunikationsszenario · CSRF-Token.

## Related pages

- [The Gateway Service Builder](../service_builder_segw/README.md) — what a project is and what it generates
- [Registering a service in the hub](../registering_a_service_in_the_hub/README.md) — the *Add Service* dialog with this very service
- [Finding a partner by its UCM number](../finding_a_partner_by_identification/README.md) — one lookup through `A_BuPaIdentification`, end to end
- [Where-used of a table](../where_used_of_a_table/README.md) — finding the view behind `A_BuPaIdentification`
- [CDS view annotations](../cds_view_annotations/README.md) — `I_BuPaIdentification` line by line

Back to the chapter map: [Integration](../README.md).

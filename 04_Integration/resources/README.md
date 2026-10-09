# Resources: books, courses, documentation and specifications for Gateway, OData, CDS and RFC

**Level:** reference · for everyone

**One line:** The reading list behind this chapter: the books on SAP Gateway and OData, on Core Data Services and on the RESTful programming model that replaced the Service Builder for new work, the courses and tutorials that teach them, the documentation and specifications they rest on, and, for each, which page of this chapter it serves.

## Provenance, first

Nothing on this page could be opened from the session that wrote it: the publishers' sites, the help portal and the SAP Community are blocked by its network policy. Titles, authors and editions are from memory, and the chapter descriptions are what the author remembers the books covering, not their tables of contents. The *How sure* column says how far to trust each line; a title marked *check* should be searched at the publisher before it is bought. No ISBNs are given for that reason.

## Books

| Book | Authors, publisher, edition | What it covers for this chapter | Read first | How sure |
| :-- | :-- | :-- | :-- | :-- |
| *SAP Gateway and OData: The Comprehensive Guide* | Carsten Bönnen, Volker Drees, André Fischer, Ludwig Heinz, Karsten Strothmann. SAP Press; 1st edition 2014 as *OData and SAP NetWeaver Gateway*, 2nd 2016, 3rd 2019. German edition *SAP Gateway und OData*, Rheinwerk. | The book on this chapter's Gateway pages. OData from the protocol up; the Service Builder step by step: data model, generation, the five methods, query options, `$expand`, deep insert, function imports, media; service generation from RFC, search helps, CDS reference data sources, redefinition and `@OData.publish`; deployment (hub and embedded), administration (registration, caches, logs), security; the 3rd edition adds OData V4 and the RESTful model. | The OData introduction; the service creation chapters, with `GWSAMPLE_BASIC` open beside them; the administration chapter before the first registration | sure on title, authors and editions; chapter list from memory |
| *Core Data Services for ABAP* | Renzo Colle, Ralf Dentzer, Jan Hrastnik. SAP Press, 2021; 2nd edition 2024. | Views, associations, annotations (`@ObjectModel`, `@Analytics`, `@VDM`, `@AccessControl`), access control (DCL), the virtual data model, CDS for analytics, extensibility, testing and performance. The book behind [CDS view annotations](../cds_view_annotations/README.md). | The annotation chapters and the access control chapter | sure on title and authors; edition and chapters from memory |
| *ABAP RESTful Application Programming Model* | Lutz Baumbusch, Matthias Jäger, Michael Keller. SAP Press, 2022. | Where `SEGW` ends: service definitions and bindings (OData V2 and V4), behaviour definitions, managed and unmanaged scenarios, the path from a CDS model to a published service without a project. | The service binding chapter, to see the Service Builder's successor | fairly sure on title, authors and year; check |
| *ABAP to the Future* | Paul Hardy. SAP Press, 3rd edition 2021. | Opinionated chapters on CDS views, on the RESTful model, and in older editions on BOPF, the framework behind the `/BOFU/` views of the [where-used list](../where_used_of_a_table/README.md). Funny, and honest about what hurts. | The CDS chapter | fairly sure on the edition |
| *SAP Interface Programming* | Michael Wegelin, Michael Englbrecht. SAP Press, 2010; German *SAP-Schnittstellenprogrammierung*, Rheinwerk. | RFC, BAPIs, the connectors (JCo, .NET), IDocs: the world `RFC_READ_TABLE` belongs to, and the background for [its page](../rfc_read_table/README.md). Old, and the RFC part has not changed much. | The RFC chapters | fairly sure on title and authors; check |
| *Business Partner in SAP S/4HANA* | SAP Press, 2020s. | The partner's data model (roles, addresses, identification, the customer and supplier views, customer–vendor integration), which [API_BUSINESS_PARTNER](../api_business_partner/README.md) mirrors set for set. | The data model chapter | title from memory, check |

## Courses, tutorials and samples

| Resource | What it is | Serves | How sure |
| :-- | :-- | :-- | :-- |
| openSAP, *Building Apps with the ABAP RESTful Application Programming Model* (2020) | A free course on the model that replaced the Service Builder for new services; the first week explains why. | [The Gateway Service Builder](../service_builder_segw/README.md), the S/4HANA section | sure the course exists |
| SAP training `GW100`, *SAP Gateway – Building OData Services* | The classroom course on the Service Builder, hub configuration and service development. | the same | sure the course exists |
| SAP Developers tutorials (developers.sap.com), the groups on creating an OData service with the Service Builder and on the RESTful model | Step-by-step tutorials with screenshots, kept current with releases; the Service Builder ones use the EPM sample data. | the same | fairly sure on the group names |
| The sample service `GWSAMPLE_BASIC` in every Gateway system, on the EPM demo data (generated with the data generator transaction `SEPM_DG`) | A delivered project to open in `SEGW` beside this chapter's pages: entity sets, associations, function imports, deep insert, all implemented. Its classes are the clipped-name example on the Service Builder page. | the same | sure on the service; fairly sure on the transaction |
| SAP Learning (learning.sap.com), the journeys on ABAP Cloud and on CDS | The successor of openSAP for the cloud development model, with the CDS and RAP material. | the CDS pages | fairly sure |

## Documentation and specifications

| Resource | What it holds | Serves | How sure |
| :-- | :-- | :-- | :-- |
| help.sap.com, *SAP Gateway Foundation (SAP_GWFND)*: the sections *SAP Gateway Service Builder*, *OData Channel*, *Service Maintenance* and the developer guide | The authoritative description of the project nodes, the generation, the registration dialog and every field this chapter graded as *from memory* | every Gateway page | sure the guide exists |
| The ABAP keyword documentation, *ABAP CDS* and the annotation references; the *SAP annotations* reference for `@ObjectModel`, `@Analytics`, `@VDM`, `@AccessControl` | The meaning of every annotation on the [annotations page](../cds_view_annotations/README.md), and the value lists this chapter graded | the CDS pages | sure |
| help.sap.com, *CDS-Based Data Extraction* (in the S/4HANA integration and BW/4HANA source-system documentation), with the change-data-capture section | How `@Analytics.dataExtraction` and the delta mapping are implemented, including the fan-out on joins | the CDS pages | fairly sure on the title |
| SAP Community, Simon Kranig's series on CDS-based data extraction and delta (2019) | The best explanation in print of change data capture on CDS views, with the mapping worked through | the CDS pages | fairly sure on author and year |
| odata.org: the OData Version 2.0 documentation; OASIS: *OData Version 4.01* parts 1 (protocol), 2 (URL conventions) and the CSDL | The protocol the Service Builder implements (V2) and the one the RESTful model adds (V4): query options, the key predicate, `$metadata`, `$batch`, the type system | [The Gateway Service Builder](../service_builder_segw/README.md) | sure |
| github.com/SAP/odata-vocabularies, and the older *SAP Annotations for OData Version 2.0* document | The `sap:` attributes the Service Builder writes into `$metadata` (`creatable`, `pageable`, `display-format`, `unit`) and their V4 equivalents | the same | fairly sure on where the V2 document now lives |
| SAP Business Accelerator Hub (api.sap.com), *Business Partner (A2X)* | The published description of `API_BUSINESS_PARTNER`: entity sets, properties, operations, a sandbox to try requests against | [API_BUSINESS_PARTNER](../api_business_partner/README.md) | sure |
| SAP Note 2246160 | The extension of `RFC_READ_TABLE` named in its own source: the allow-list check, the sort and the string return | [RFC_READ_TABLE](../rfc_read_table/README.md) | sure on the number (read from the source); title not seen |
| github.com/SAP/PyRFC and the SAP NetWeaver RFC SDK | The Python binding and the C library every RFC connector is built on; the PyRFC examples include a `RFC_READ_TABLE` call | the same | sure |

## How it connects to OData

Every page of the chapter touches OData from a different side, and the resources above line up the same way:

- **The protocol** is OData V2: the specification at odata.org is the law, the Gateway book is the commentary, and `$metadata` of any service is the evidence.
- **The producer** is the Service Builder for classic services and the RESTful model for new ones; the Gateway book for the first, the RAP book and the openSAP course for the second.
- **The model** behind a modern service is CDS: the CDS book and the annotation reference, with `I_BuPaIdentification` as the worked example.
- **The consumer** sees the `sap:` annotations and the entity sets: the vocabularies repository and the Business Accelerator Hub.
- **The alternative** that is not OData, `RFC_READ_TABLE`, is the measure of what the protocol adds: a model, a contract, and a filter the server applies.

## Po polsku, w skrócie

Lista lektur rozdziału: książka Bönnena i współautorów o SAP Gateway i OData (po niemiecku w Rheinwerk), książka Colle, Dentzera i Hrastnika o Core Data Services, książka o modelu RESTful, który zastąpił Service Builder w nowych projektach, kurs openSAP i szkolenie GW100, dokumentacja Gateway na help.sap.com, specyfikacja OData i słowniki adnotacji SAP na GitHubie, katalog API na api.sap.com oraz nota SAP o rozszerzeniu `RFC_READ_TABLE`. Tytuły są z pamięci, bez dostępu do sieci; kolumna „jak pewne" mówi, co sprawdzić przed zakupem.

## Auf Deutsch: Stichwörter

Die Leseliste des Kapitels: das Gateway-und-OData-Buch, das CDS-Buch, das RAP-Buch, der openSAP-Kurs, die Gateway-Dokumentation, die OData-Spezifikation und der API-Katalog, jeweils mit der Seite, der sie dienen.

Stichwörter: Lehrbuch · Rheinwerk · SAP Press · Kurs · Tutorial · Beispielservice · Dokumentation · Spezifikation · Vokabular · API-Katalog · SAP-Hinweis.

## Related pages

Every page of [Integration](../README.md).

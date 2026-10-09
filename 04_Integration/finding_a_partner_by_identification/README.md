# Finding a business partner by its UCM number through the API: what we did

**Level:** 201 · a knowledge transfer, written to be followed on another machine by someone who was not there

**One line:** A legacy customer number, the *UCM number*, is stored on the business partner as an identification number of the custom type `ZUCM01` in table `BUT0ID`, so the partner behind a UCM number is one GET on `A_BuPaIdentification` of `API_BUSINESS_PARTNER` with a filter on `BPIdentificationNumber`; getting there took six steps, from the table to the view to the project, through the hub registration and a client copy, to the Gateway client, and this page is those six steps with what each one proved and what each one needs when it is done again.

Names, numbers and hosts on this page are invented where the real ones would identify a company, a system, a transport or a customer. The process is exact.

## The question

A message from a colleague carried the URL of an older custom OData service, filtered on three legacy fields (`IDNum`, `IDKey`, `IDSubKey`), as the known way to get at a partner's data by its UCM number. The ask: do the same through the standard API, so that the custom service can retire, and so that the lookup works on the quality and production systems where it is registered and the custom one is not.

## Step 1: where the UCM number lives

`SE16` on `BUT0ID` in the data client, filtered on `TYPE = ZUCM01`: one row per partner, the UCM number in `IDNUMBER`, the partner in `PARTNER` with its leading zeros (`0017100001`), the institute, the dates and the country empty.

Proved: the UCM number is an identification number of a custom type, nothing more exotic; and it is the number as typed, so the filter must match it exactly, case and all. Also seen: in the development system several rows are obvious test values, so a lookup there can return a partner that does not exist in production.

## Step 2: which views read the table

The [where-used list of `BUT0ID` in DDL sources](../where_used_of_a_table/README.md): fourteen hits, among them the released interface view `I_BuPaIdentification` and a custom view on the same table. Opening the [interface view](../cds_view_annotations/README.md) gave the element names the rest of the chain uses: `BusinessPartner`, `BPIdentificationType`, `BPIdentificationNumber`.

Proved: the names in the API are the view's names, not the table's. The filter will not say `IDNUMBER` and it will not say `IDNum`.

## Step 3: which API exposes it

`SEGW`, project `API_BUSINESS_PARTNER`, *Data Model → Entity Types*, `A_BuPaIdentificationType`, whose entity set is `A_BuPaIdentification`, with exactly those three properties as keys. The [API page](../api_business_partner/README.md) has the rest of the model.

Proved: the standard service has the entity set; no custom service is needed.

## Step 4: register the service in the hub

Done in the configuration client (client 100 of the development system), as [the registration page](../registering_a_service_in_the_hub/README.md) describes:

1. `/IWFND/MAINT_SERVICE`, *Add Service*; system alias `LOCAL` (the hub is embedded); *Get Services*; `API_BUSINESS_PARTNER` in the list.
2. The dialog proposed the technical name `ZAPI_BUSINESS_PARTNER`, version 1, external name `API_BUSINESS_PARTNER`, ICF node *SAP Gateway OData V2*. Package: the team's transportable package, not *Local Object*, so that the registration can move to quality and production.
3. *Continue* asked for a workbench request; the ICF service (a generated hash name) and the registration went into it.
4. The result in the Customizing view *Assign SAP System Aliases to OData Service*: one row, service document identifier `ZAPI_BUSINESS_PARTNER_0001`, alias `LOCAL`, *Default System* ticked, technical name with the `Z`, external name without.

Proved: the two names, and that the registration is two objects, a workbench one (service, model, ICF node) and a customizing one (the alias assignment).

## Step 5: make it answer in the data client

The service, its model and its ICF node are client-independent; the alias assignment is customizing and so client-dependent. Registered in client 100, the service existed in client 200 without an alias, which the Gateway client reports as an error about the system alias.

The fix was a client copy by transport request: `SCC1` in client 200, source client 100, the customizing request that held the alias assignment, *Include tasks in request* ticked, no test run, and *Yes* to *Copy client-specific data from 100 to 200?*.

Proved, with a caveat: the service answered in client 200 after the copy. That the alias assignment was the object the copy carried is the explanation that fits; the check is the Customizing view above, opened in client 200 before and after.

## Step 6: call it in the Gateway client

`/IWFND/GW_CLIENT` in client 200, protocol HTTP, method GET:

1. `/sap/opu/odata/sap/API_BUSINESS_PARTNER/?$format=xml`: the service document, a list of the entity sets. Proves the registration, the alias and the ICF node at once.
2. The first filter was copied from the old URL: `/A_BuPaIdentification?$filter=(IDNum eq '…' and IDKey eq 'P' and IDSubKey eq 'R')`. The properties do not exist in this entity type, and the framework rejects the filter before any data is read. The old service's names belong to the old service.
3. `/sap/opu/odata/sap/API_BUSINESS_PARTNER/A_BuPaIdentification?$filter=BPIdentificationType eq 'ZUCM01' and BPIdentificationNumber eq 'UCM0815'`: one entry. The type belongs in the filter, because the same string can exist under another identification type.
4. *Response in Browser* saves the Atom XML to a file and opens it. The entry's properties:

```text
BusinessPartner            17100001      <- without the leading zeros the table shows
BPIdentificationType       ZUCM01
BPIdentificationNumber     UCM0815
BPIdnNmbrIssuingInstitute  (empty)
BPIdentificationEntryDate  m:null="true" <- the table holds 00000000
Country, Region            (empty)
ValidityStartDate          m:null="true"
ValidityEndDate            m:null="true"
AuthorizationGroup         (empty)
```

Proved: the API applies the partner number's conversion exit on output, so a consumer gets `17100001` and must send `17100001`, not `0017100001`, as a key; and an initial date comes out as `null`, not as an error and not as a date.

## What a consumer needs, in one place

| Item | Value or rule |
| :-- | :-- |
| Service root | `https://<hub host>:<port>/sap/opu/odata/sap/API_BUSINESS_PARTNER/` |
| The lookup | `A_BuPaIdentification?$filter=BPIdentificationType eq 'ZUCM01' and BPIdentificationNumber eq '<number>'&$select=BusinessPartner` |
| JSON instead of Atom | add `&$format=json`, or send `Accept: application/json` |
| The client | `&sap-client=<client>` whenever the hub's ICF node does not default to the data client |
| The user | one with the business partner display authorization and the service's `S_SERVICE` entry in the hub; basic authentication or the landscape's single sign-on |
| The partner number returned | without leading zeros; send it back the same way |
| Nothing found | an empty feed, not an error; the number is wrong, in another type, or in another client |
| Quality and production | the workbench request carries the registration, the customizing request the alias assignment; import both, then, if the data client differs from the configuration client, the client copy or a customizing import into the data client |

## What we learned, as rules

1. **Names come from the entity type**, read in `SEGW` or in `$metadata`, never from an older service's URL.
2. **The registration is two transports.** Service, model and ICF node are workbench; the alias assignment is customizing and client-dependent. A service that works in one client and not in another is missing the second.
3. **The API converts on output.** Partner numbers lose their leading zeros, initial dates become `null`. Build the consumer on what the API returns, not on what `SE16` shows.
4. **Filter on the type too.** The identification number alone is ambiguous by design: the table's key is partner, type and number.
5. **Test in the Gateway client first**, service document, then one entity set, then the filter. Each step eliminates one layer: registration, model, data.

## How to verify this in your own system

| Claim | Where to prove it | How sure |
| :-- | :-- | :-- |
| The UCM number is `BUT0ID-IDNUMBER` with `TYPE = ZUCM01` | `SE16`, as in step 1 | sure (seen) |
| The entity set and its property names | `$metadata` of the service, or `SEGW` | sure (seen) |
| The alias assignment is client-dependent customizing | the view *Assign SAP System Aliases to OData Service* in two clients of one system | fairly sure; the copy worked |
| The partner number is returned without leading zeros | the response in step 6 | sure (seen) |
| Initial dates come back as `null` | the same response | sure (seen) |
| A filter on properties of another service is rejected | step 6, second request | sure (seen) |
| The old filter names belong to a custom service | its `$metadata` | sure |

## Provenance

Written from the screenshots of the session that did the work, one per step, which show each screen as it was; the explanations of *why* each step was needed are from memory and graded. Host names, system IDs, transport numbers, the package name, user IDs, partner numbers and identification numbers are left out at the owner's request and replaced by invented ones. No message text is quoted.

## Po polsku, w skrócie

Numer UCM, czyli dawny numer klienta, jest zapisany na partnerze biznesowym jako numer identyfikacyjny własnego typu `ZUCM01` w tabeli `BUT0ID`. Partnera dla danego numeru UCM zwraca jedno wywołanie GET na `A_BuPaIdentification` w serwisie `API_BUSINESS_PARTNER` z filtrem na typ i numer. Droga do tego wiodła przez `SE16` (gdzie leży numer), listę „gdzie użyto" (który widok go czyta), SEGW (który zbiór encji go wystawia), rejestrację serwisu w hubie w kliencie konfiguracyjnym, kopię klienta `SCC1` (bo przypisanie aliasu systemu jest customizingiem zależnym od klienta) i klienta Gateway. Odpowiedź zwraca numer partnera bez zer wiodących, a puste daty jako `null`; nazwy właściwości pochodzą z typu encji, nie ze starego serwisu.

## Auf Deutsch: Stichwörter

Die UCM-Nummer liegt als Identifikationsnummer vom Typ `ZUCM01` in `BUT0ID`, und der Geschäftspartner dazu ist ein GET auf `A_BuPaIdentification` mit Filter auf Typ und Nummer, sobald der Service im Hub registriert und der Systemalias in den Datenmandanten kopiert ist.

Stichwörter: Wissenstransfer · Identifikationstyp · Verwendungsnachweis · Entitätsmenge · Service hinzufügen · Workbench-Auftrag · Customizing-Auftrag · Mandantenkopie · Gateway-Client · Servicedokument · Filter · führende Nullen · Nullwert.

## Related pages

- [Registering a service in the hub](../registering_a_service_in_the_hub/README.md) — step 4 in full
- [API_BUSINESS_PARTNER](../api_business_partner/README.md) — the whole model
- [Where-used of a table](../where_used_of_a_table/README.md) and [CDS view annotations](../cds_view_annotations/README.md) — steps 2 and 3
- [RFC_READ_TABLE](../rfc_read_table/README.md) — what the lookup would have looked like without the API

Back to the chapter map: [Integration](../README.md).

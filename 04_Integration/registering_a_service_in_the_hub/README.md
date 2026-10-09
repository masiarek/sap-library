# Registering a service in the hub: *Add Service* in `/IWFND/MAINT_SERVICE`

**Level:** 201 · for whoever has generated a service and cannot reach its URL

**One line:** A service generated in the backend is invisible to HTTP until the hub registers it: *Add Service* reads the backend's registration through a system alias, creates a service and a model on the hub side in the customer namespace, which is why the proposed technical name of `API_BUSINESS_PARTNER` starts with a `Z`, keeps the backend's name as the *external service name*, which is the segment in the URL, and activates the ICF node under `/sap/opu/odata/sap/` through which every request arrives.

## What the screenshot shows

The *Add Service* dialog of `/IWFND/MAINT_SERVICE`, reached by *Add Service*, a system alias, *Get Services* and a double-click on `API_BUSINESS_PARTNER` in the list, as it stands before *Continue*:

| Field | Value shown | What it is | How sure |
| :-- | :-- | :-- | :-- |
| Technical Service Name | `ZAPI_BUSINESS_PARTNER` | The hub's own object for this service. The hub registration is a customer object in the hub system, so for a delivered service the proposal adds a `Z`; for a customer service such as `ZBP_IDNUMBERS_SRV` the name is already in the customer namespace and is proposed unchanged. In the catalogue, and in the Customizing view *Assign SAP System Aliases to OData Service*, it appears as the *service document identifier* with the version appended, `ZAPI_BUSINESS_PARTNER_0001`. | sure |
| Service Version | `1` | A second version of the same backend service is a second registration with its own classes. | sure |
| Description | *Remote API for Business Partner* | Copied from the backend's registration. | sure |
| External Service Name | `API_BUSINESS_PARTNER` | The backend's technical service name, and the segment in the URL: `/sap/opu/odata/sap/API_BUSINESS_PARTNER/`. The `Z` of the technical name never reaches the URL. | sure |
| Namespace | empty | For a service registered in a namespace, such as SAP's sample `GWSAMPLE_BASIC` in `/IWBEP/`, whose URL is `/sap/opu/odata/IWBEP/GWSAMPLE_BASIC/`: the namespace replaces the `sap` segment. | sure |
| External Mapping ID, External Data Source Type | empty, `C` | Fields of the registration record; `C` is what a backend service built on the `/IWBEP/` framework shows. Their value list is in the F1 help of the field, which this page does not quote. | from memory, check |
| Technical Model Name, Model Version | `ZAPI_BUSINESS_PARTNER`, `1` | The hub-side model object, named like the service. | sure |
| Package Assignment, *Local Object* | empty | Where the registration is saved. *Local Object* puts it in `$TMP`, which never leaves this system; a hub with a transport landscape wants a package, so that the registration moves with the rest. | sure |
| Enable OAuth for Service | unchecked | Creates the OAuth 2.0 scope that lets clients call this service with an OAuth token instead of basic authentication or a certificate. | fairly sure |
| ICF Node | *SAP Gateway OData V2* / *None* | Which ICF node serves the service: the standard OData V2 node `/sap/opu/odata/`, or none yet. With *None* the registration exists and the URL does not answer. | sure |

The dialog is the moment the two names part: everything the hub administrator sees (the catalogue, the error log, the authorization object) carries the technical name with its `Z`; everything a consumer sees carries the external name.

## The three steps around the dialog

1. **Before: the system alias.** The hub needs a name for the backend: an alias pointing at an RFC destination, with the software version, maintained in the Gateway Customizing under *Connection Settings → SAP Gateway to SAP System → Manage SAP System Aliases*. In an embedded deployment, where hub and backend are one system, the alias is `LOCAL` with no destination. *Add Service* lists only the backend services the alias reaches, and the list is filtered by technical service name, so an empty list means a wrong alias or a wrong filter before it means a missing service.
2. **The dialog**, as above. *Continue* asks for a workbench request when a package was chosen: the registration and the ICF service, whose name in the prompt is a generated hash rather than the service name, go into it. After that the hub has a service, a model and the ICF node, and the alias is assigned to the service: the Customizing view *Assign SAP System Aliases to OData Service* shows one row, the service document identifier `ZAPI_BUSINESS_PARTNER_0001`, the alias `LOCAL`, *Default System* ticked, and the two names side by side.
   The two halves live in different transports. The service, the model and the ICF node are workbench objects and client-independent; the alias assignment is Customizing, client-dependent, and goes into a customizing request. A service registered in the configuration client therefore exists in the data client without an alias until that request is imported there or copied with a client copy by transport request (`SCC1`), which is what [the knowledge-transfer page](../finding_a_partner_by_identification/README.md) did.
3. **After: the test.** In the catalogue (`/IWFND/MAINT_SERVICE`, *Activate and Maintain Services*) the service shows its ICF node as active and its system alias in the lower pane. *SAP Gateway Client* on the row opens `/IWFND/GW_CLIENT` with the service document; a GET on `$metadata` is the first request to send, and a GET on one entity set the second. A request that fails lands in `/IWFND/ERROR_LOG` in the hub, and, if it got as far as the backend, in `/IWBEP/ERROR_LOG` there too, with the same transaction ID in both.

## Where S/4HANA differs

- **Embedded is the default.** S/4HANA runs the Gateway hub in the same system as the backend, so the alias is `LOCAL` and *Add Service* lists the system's own services. A separate hub remains possible and is still common in landscapes that serve several backends.
- **S/4HANA Cloud has no transaction.** A delivered API is enabled by a communication arrangement for its scenario (`SAP_COM_0008` for the business partner), which creates the user and the inbound service at once; the Service Builder and the hub catalogue are not exposed.
- **OData V4 services are published elsewhere.** A RAP service binding of type OData V4 is published in `/IWFND/V4_ADMIN` as part of a *service group*, and its URL is `/sap/opu/odata4/sap/<group>/srvd/sap/<service definition>/0001/`; `/IWFND/MAINT_SERVICE` is the V2 catalogue only.

## The classic bugs

1. **Registered, no alias assigned.** The catalogue shows the service, the request fails in the hub with an error about the system alias. Assign it in the lower pane.
2. **ICF node inactive**, because *None* was chosen or the node was deactivated in `SICF`: the URL answers *not found* while the catalogue looks fine. Activate the node from the catalogue's lower pane.
3. **The backend was regenerated, the hub answers the old model.** Clear the hub cache (`/IWFND/CACHE_CLEANUP`) and the backend cache (`/IWBEP/CACHE_CLEANUP`).
4. **No authorization for the service.** The hub creates an authorization object for each registered service (`S_SERVICE`, with the service's hash), and a user without it gets an error in the hub before the backend is called. The error log names the object.
5. **Three hubs, one registration.** Registered as a local object in development, the service is missing in quality and production. Register it in each hub, or save the registration in a package and transport it.
6. **Works in one client, not in another.** The alias assignment is client-dependent Customizing. The Gateway client in the second client reports an error about the system alias; the fix is the customizing request imported into that client, or `SCC1`.

## How to verify this in your own system

| Claim | Where to prove it | How sure |
| :-- | :-- | :-- |
| The proposed technical name gets a `Z`, the external name does not | `/IWFND/MAINT_SERVICE`, *Add Service* on any delivered service: read the two fields | sure |
| The URL carries the external name | the catalogue's *Call Browser*, or `/IWFND/GW_CLIENT` from the row | sure |
| A namespace replaces the `sap` segment | the URL of `GWSAMPLE_BASIC` in a system that has it | sure |
| *None* as ICF node leaves the URL unanswered | register a test service with *None*, call it, then add the node | sure |
| The version is appended to the technical name as the service document identifier | the view *Assign SAP System Aliases to OData Service* after *Add Service* | sure (seen) |
| The alias assignment is client-dependent | the same view in two clients of one system | fairly sure; a client copy made the service answer |
| An `S_SERVICE` entry per registered service | `SU53` after a failed call by a user without it, or the role's authorization data | fairly sure |
| The meaning of External Data Source Type `C` | F1 help on the field | from memory, check |
| V4 services are published in `/IWFND/V4_ADMIN` | the transaction, in a system with a RAP service binding | sure |

## Provenance

Written from working knowledge of Gateway hub administration, from memory. The field values in the first table, the workbench request prompt, the alias view with its `_0001` identifier and the client copy are read from screenshots of one registration done in a development system; the system, its hosts, the package and the request numbers are left out at the owner's request. The meaning of each field is from memory and graded in the *How sure* column. No claim was confirmed against a named system, and no message text is quoted.

## Po polsku, w skrócie

Serwis wygenerowany w systemie zapleczowym nie odpowiada na żaden adres, dopóki hub Gateway go nie zarejestruje. Okno *Add Service* w `/IWFND/MAINT_SERVICE` czyta rejestrację zaplecza przez alias systemu i tworzy po stronie huba własny serwis i model w przestrzeni klienta, stąd proponowane `Z` przed nazwą `API_BUSINESS_PARTNER`. W adresie URL pojawia się jednak *zewnętrzna* nazwa serwisu, czyli nazwa z zaplecza bez `Z`. Węzeł ICF pod `/sap/opu/odata/` musi być aktywny, alias przypisany, a pamięć podręczna huba i zaplecza wyczyszczona po każdej regeneracji; test to zawsze `$metadata` w kliencie Gateway.

## Auf Deutsch: Stichwörter

Erst die Registrierung im Gateway-Hub macht einen generierten Service per HTTP erreichbar: der technische Name bekommt das `Z`, der externe Name steht in der URL.

Stichwörter: Systemalias · Service hinzufügen · technischer Servicename · externer Servicename · ICF-Knoten · Paketzuordnung · Gateway-Client · Fehlerprotokoll · Cache bereinigen · eingebettete Bereitstellung.

## Related pages

- [The Gateway Service Builder](../service_builder_segw/README.md) — the backend half of the path
- [API_BUSINESS_PARTNER](../api_business_partner/README.md) — the service in the dialog
- [Finding a partner by its UCM number](../finding_a_partner_by_identification/README.md) — the registration done, step by step, with the client copy after it

Back to the chapter map: [Integration](../README.md).

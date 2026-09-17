# 02_Master_Data — Master data

Pages on the data every module reads and no module owns: countries, addresses, business partners — and the central checks that decide whether an interface can save them.

## [Addresses](addresses/README.md)

| Page | What it answers |
| :-- | :-- |
| [Postal code checks per country](addresses/postal_code_checks.md) | Where the check lives (`T005`, two fields, nine rules), what it cannot express, a five-country request worked through to settings, the SAP Notes on the subject, and how to change it safely. |

## Recurring themes across these pages

- **Central settings have no owner until they break.** The country table is Basis Customizing that FI, SD, MM and every interface depend on. The person who receives the error is rarely the person who can change the setting.
- **A check that runs on save runs for interfaces.** What is a message under a field for a user is a failed message in a queue for a replication — see also the FI pages on [inbound interfaces](../01_FI/document_types_and_number_ranges/inbound_interface_numbering.md).
- **Stored data is not re-checked.** A stricter rule takes effect on the next save of each record, one surprised user at a time.

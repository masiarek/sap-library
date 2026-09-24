# Posting keys

What a posting key carries, where it lives per client, and how to see — per posting key, in words — whether the two fields that usually matter are suppressed, required or optional.

| Page | What it answers |
| :-- | :-- |
| [Comparing posting keys between clients](comparing_posting_keys_between_clients.md) | Where `OB41` stores a posting key, why the field status is two character strings, the three ways to compare clients and what each one can and cannot tell you, and what else decides whether Profit Center and Business Area are required. |
| [`z_adam_posting_key_status.abap`](z_adam_posting_key_status.abap) | The report: client, posting key, and Business Area, Profit Center and Segment as required / optional / suppressed. Looks the positions up in the field-selection definition itself; run it in each client to compare. Read-only. |

## The one distinction to carry away

**A posting key is one row per client.** `TBSL` has the client in its key, so two clients agree only for as long as nothing has been changed in one of them without a transport to the other. Comparing them is not a configuration question but a data question: read the row from both sides and diff it.

**And the field status is not a field.** It is two strings of single characters, one per screen field, and no comparison tool reads them for you. That is why *"the posting keys are the same"* from a standard comparison can be true at the level of the row and false at the level of the profit center.

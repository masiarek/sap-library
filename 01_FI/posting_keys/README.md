# Posting keys

What a posting key carries, where it lives per client, and how to tell two clients apart on the two fields that usually matter.

| Page | What it answers |
| :-- | :-- |
| [Comparing posting keys between clients](comparing_posting_keys_between_clients.md) | Where `OB41` stores a posting key, why the field status is two character strings, the three ways to compare clients and what each one can and cannot tell you, how to find the position of Profit Center and Business Area once, and what else decides whether those fields are required. |
| [`z_adam_posting_key_compare.abap`](z_adam_posting_key_compare.abap) | The comparison report: this client's `TBSL` against the client behind an RFC destination, two chosen fields decoded side by side, every differing position listed, traffic light per key. Read-only. |

## The one distinction to carry away

**A posting key is one row per client.** `TBSL` has the client in its key, so two clients agree only for as long as nothing has been changed in one of them without a transport to the other. Comparing them is not a configuration question but a data question: read the row from both sides and diff it.

**And the field status is not a field.** It is two strings of single characters, one per screen field, and no comparison tool reads them for you. That is why *"the posting keys are the same"* from a standard comparison can be true at the level of the row and false at the level of the profit center.

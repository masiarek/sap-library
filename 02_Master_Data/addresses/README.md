# Addresses

Business Address Services: the one place every SAP address is checked and stored, whichever application it belongs to.

| Page | What it answers |
| :-- | :-- |
| [Postal code checks per country](postal_code_checks.md) | The two `T005` fields and nine rules behind every postal code message; what rule 9 and the S/4 template table add; a five-country request worked through to settings, with what each setting also lets through; the SAP Notes and KBAs on the subject, separated into read and title-only; and how to change the setting without surprising the next person who edits an old address. |

## The one distinction to carry away

**A postal code rule is a length and a character class, not a format.** A requirement written as *"4 digits or `A9999AAA`"* has no exact equivalent among the generic rules, and the S/4 template table holds one template per country. So the implemented setting is usually looser than the requirement — and the change record should say by how much, because the next request will be *"why did SAP accept this?"*

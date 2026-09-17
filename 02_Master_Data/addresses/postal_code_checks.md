# Postal code checks per country — what the setting can and cannot enforce

**Level: 201 · for master data and Basis-adjacent consultants, and for whoever owns an interface that carries addresses** — written after an upstream customer master system started sending postal codes that the postal authorities accept and SAP rejected.

**One line:** The postal code check is two fields per country in `T005` — a length and a rule from 1 to 9. The eight generic rules can say *"at most n"* or *"exactly n"*, *"digits only"* or *"anything"*, *"blanks allowed"* or *"not"*. They cannot say *"four digits **or** one letter, four digits, three letters"*. Most requirements that arrive as a list of country formats are therefore implemented as the **loosest rule that accepts every valid code**, and the page that records the change should say what else that rule lets through.

Section landing page: [Addresses](README.md).

---

## 1. Where the check lives

| Field | Meaning |
| :-- | :-- |
| `T005-LNPLZ` | Postal code length for the country. Whether it is a maximum or an exact length is decided by the rule. |
| `T005-PRPLZ` | The check rule, `1`–`9`. Blank means no check. |
| `T005-XPLZS` | Postal code is a required entry for a street address. |
| `T005-XPLPF` | Postal code is a required entry for a P.O. box address. |

They are maintained in the IMG under *General Settings → Set Countries → Set Country-Specific Checks* (transaction `OY17`). The check itself is function module `ADDR_POSTAL_CODE_CHECK`, called by Business Address Services (`BC-SRV-ADR`).

Two properties of that placement decide who feels a change:

- **It is central.** Every object that stores its address through Business Address Services goes through it: business partners, customers and vendors, plants, one-time addresses in documents, bank addresses. There is no setting "for customers only".
- **It runs for interfaces too.** SAP's documentation says an address that fails the check *"is not accepted in this form and cannot be saved"*. On a screen that is a message under the field. In an IDoc, a replication from a governance hub, or a web service, it is a failed message in somebody's error queue — usually far from the person who can change `T005`. This is the normal way a wrong postal code setting is discovered.

`T005` is **client-dependent** Customizing. A change is recorded in a Customizing request, and other clients of the same system do not see it until it is copied there.

## 2. The nine rules

| Rule | Length is | Characters | Blanks inside |
| :-- | :-- | :-- | :-- |
| `1` | maximum | any | not allowed |
| `2` | maximum | digits | not allowed |
| `3` | exact | any | not allowed |
| `4` | exact | digits | not allowed |
| `5` | maximum | any | allowed |
| `6` | maximum | digits | allowed |
| `7` | exact | any | allowed |
| `8` | exact | digits | allowed |
| `9` | — | checked against a country-specific template | — |

What follows from the table, before any country is looked at:

- There is **one** length per country. *"5 or 6 digits"* can only be written as *"at most 6 digits"* — which also accepts 3.
- *"Digits"* and a separator do not combine. A code such as `12345-6789` is not numeric; under a generic rule it needs one of the *any character* rules. (That a hyphen fails the numeric rules is how I remember the function module — test it, see §8.)
- Nothing generic knows about **letters in fixed positions**. `C1425ABC` and `ABCDEFGH` are the same to rules 1, 3, 5 and 7.

## 3. Rule 9 — templates

Rule 9 compares the code with a template in which `N` is a digit, `A` a letter, and a hyphen or blank stands for itself.

- **Classic documentation** lists templates for Canada (`ANA NAN`), the Netherlands (`NNNN AA`), Poland (`NN-NNN`), Sweden, Slovakia and the Czech Republic (`NNN NN`), South Korea and Portugal. The USA is checked for `NNNNN` or `NNNNN-NNNN` *independently of rule 9*.
- **An SAP blog for the cloud products** (2019) gives a longer list — 25 countries, among them Argentina as `ANNNNAAA`, Brazil, Japan, the United Kingdom with six templates — and adds two warnings worth repeating: for several of those countries SAP's own delivered default is a *more lenient generic rule*, not rule 9; and setting rule 9 for a country that has no routine is *"highly discouraged"*. The author believed the on-premise routines to be identical, without being certain.
- **In S/4HANA the templates are a Customizing table.** The IMG activity *Define Postal Code* (next to *Set Country-Specific Checks*) maintains `ADDR_PCDFORMAT`. Its documentation says `ADDR_POSTAL_CODE_CHECK` checks the format specified there, that you can adjust it when a country changes its format, and that countries with special requirements are not in it. The table's key is client and country, and the template field is 10 characters.

That key is the important part: **one template per country**. Rule 9 can enforce `ANNNNAAA` for Argentina, or `NNNNN-NNNN` for Saudi Arabia. It cannot enforce *that template or a shorter one* — the alternative would be rejected.

## 4. A worked request: five countries

The request, as it arrived: the upstream system validates against the formats the postal authorities publish, SAP rejects some of those codes, please align SAP.

| Country | Valid codes | Closest setting | Accepts, as wanted | Also accepts |
| :-- | :-- | :-- | :-- | :-- |
| Argentina `AR` | 4 digits (pre-1999), or the 8-character CPA `ANNNNAAA` | length `8`, rule `1` | `2121`, `C1425ABC`, and the 5-character `B1636` | anything up to 8 characters without a blank |
| Honduras `HN` | 5 digits | length `5`, rule `4` | `12101` | — |
| Nepal `NP` | 5 digits | length `5`, rule `4` | `44600` | — |
| Saudi Arabia `SA` | 5 digits, or `NNNNN-NNNN` | length `10`, rule `1` | `12337`, `12987-7318` | anything up to 10 characters without a blank |
| Vietnam `VN` | 5 digits; 6-digit codes from before the change still circulate | length `6`, rule `2` | `70000`, `700000` | 1 to 4 digits |

Three of the five are decisions, not transcriptions:

**Argentina.** SAP's Universal Postal Union reading is the 8-character CPA, and the rule 9 template is exactly that. But a 4-digit code is what Argentine companies print on their own letterhead, and what the post office itself gives out — an SAP Community thread from 2020 has a customer who could not obtain an 8-character code from anyone. SAP answers this case with KBA **2537879**, *Customize the length of the Argentina postal code*, which is about going back to codes of 4, 5 or 8 characters. The price of accepting all three is that the letter pattern is no longer checked.

**Vietnam.** SAP's own correction goes the other way. KBA **3636960** (S/4HANA Cloud Public Edition) sets Vietnam to length `5`, rule `4` — exactly five digits — and refers to SAP Note **2263096**, *Incorrect postcode for Nicaragua and Vietnam*. That is the right setting if old 6-digit codes are to be cleansed at the source. If they are to be accepted, it is length `6`, rule `2`, and the requirement should say so in words, because it contradicts the note.

**Honduras.** Wikipedia's list of postal codes gives two formats for Honduras, `NNNNN` and `AANNNN`, and says the numeric one *"is still being used"*. If the upstream system accepts only five digits, length `5` with rule `4` matches it. If it could ever send the six-character form, the setting is length `6`, rule `1`. Ask before transporting.

Saudi Arabia is the clean illustration of §3: rule 9 with `NNNNN-NNNN` would be stricter and would reject every plain 5-digit code, which is the P.O. box format.

## 5. What SAP has published

Notes and KBAs need an S-user; the public preview of a KBA shows symptom, environment and keywords but not the resolution. So this table separates what was read from what is known by title only.

| Number | Title | What is known |
| :-- | :-- | :-- |
| [1381564](https://me.sap.com/notes/1381564) | Postal codes | The general note. SAP Community threads cite it whenever a delivered postal code setting disagrees with a country — a member in 2014 (Japan, the UK and five others), an SAP advisor in 2020 (Argentina, beside KBA 2537879). **Title only; body not read.** |
| [2087545](https://userapps.support.sap.com/sap/support/knowledge/en/2087545) | Address and Postal code format for a Country | Symptom: how SAP decides on formats per country. Keywords: Universal Postal Union, UPU, standard. Resolution not read. |
| [2497091](https://userapps.support.sap.com/sap/support/knowledge/en/2497091) | How to edit the length and format of a Postal code for a Country | Release-independent how-to. Keywords name `OY17`, `OY01`, `OY07`, `T005`, and the message for a wrong length. Resolution not read. |
| [2537879](https://userapps.support.sap.com/sap/support/knowledge/en/2537879) | Customize the length of the Argentina postal code | Symptom read: going back to 4, 5 or 8 characters instead of the 8-character UPU standard. Basis 700 and later. Resolution not read. |
| [3636960](https://userapps.support.sap.com/sap/support/knowledge/en/3636960) | Vietnam postal code validation failing… | **Read in full:** cause is an incomplete delivered configuration; resolution is length 5, rule 4. Public cloud. |
| [2263096](https://me.sap.com/notes/2263096) | Incorrect postcode for Nicaragua and Vietnam | Referenced by 3636960. Title only. |
| [1123588](https://me.sap.com/notes/1123588) | Postal code check for different countries | Cited beside 1381564 in a 2010 thread. Title only. |
| [534386](https://me.sap.com/notes/534386) | Argentine postal code check | Title only. |
| [1164216](https://me.sap.com/notes/1164216) | T005, T005S Content | About delivered country and region content; referenced by KBA 3524593 on postal code lengths after a legal change. Title only. |

Nothing was found for Honduras, Nepal or Saudi Arabia specifically. The pattern in what *was* found is consistent: SAP delivers a starting value that follows the UPU, does not push later changes into existing clients, and treats the setting as the customer's to maintain. **There does not seem to be one note with a table of recommended values per country** — the recommendation is the UPU format, and the note tells you where to type it.

## 6. Changing it without breaking something else

1. **Record the current values first.** `SE16N` on `T005` for the countries in scope: `LNPLZ`, `PRPLZ`, `XPLZS`, `XPLPF`. On S/4, also `ADDR_PCDFORMAT`. Do it in every system you are about to change *and* in production — development systems drift, and the before-picture is the only rollback plan this change has.
2. **Know which way you are moving.** Loosening a rule cannot invalidate stored data. Tightening one can — see the next point.
3. **Stored addresses are not re-checked.** A new rule applies when an address is next saved. After a tightening, the first person to change a phone number on an old customer gets a postal code error for a code they never touched. Count the non-conforming rows before you transport: `ADRC` by `COUNTRY`, compare `POST_CODE1` (and `POST_CODE2` for P.O. boxes) with the new rule.
4. **Leave the required-entry flags alone unless asked.** Format and obligation are separate fields. A request about formats is not a request to make the code mandatory, and the reverse.
5. **One Customizing request per transport route.** If two landscapes need the change, that is two requests and two sets of test evidence, not one request imported twice.
6. **Other clients.** The change exists in the client where it was made. Test clients in the same system need a client copy of the request.
7. **The neighbours have the same setting.** A cloud CRM, a governance hub, a middleware mapping — each may hold its own length and rule per country. SAP's KBA 3524593 describes replication errors caused by exactly that disagreement. Aligning one system moves the error to the next one that was not aligned.

## 7. When the rule cannot say it

If the business really needs *"4 digits or `ANNNNAAA`, nothing else"*, the options are, in order of cost:

- **Accept the loose rule** and let the upstream system be the strict one. If every address arrives through that system, SAP's check is a second line, not the first.
- **Rule 9 with the strict template** and cleanse the exceptions at the source. Only where the country truly has one format.
- **A custom check** in the address check BAdI of Business Address Services. It runs for every address in the country, in every application and every interface, so it needs the same care as the standard check — and a way to switch it off. Written from experience; not built for this page.

## 8. Test values

Enter each on a business partner address for the country, in the development client, after the change.

| Country | Must be accepted | Must be rejected | Tells you |
| :-- | :-- | :-- | :-- |
| `AR` | `2121` · `B1636` · `C1425ABC` | `C1425ABCD` (9) · `C1425 ABC` (blank) | length 8, no blanks |
| `HN` | `12101` | `1210` · `121011` · `1210A` | exact 5, digits |
| `NP` | `44600` | `4460` · `446000` · `4460A` | exact 5, digits |
| `SA` | `12337` · `12987-7318` | `12987-73189` (11) · `12987 7318` (blank) | length 10, no blanks |
| `VN` | `70000` · `700000` | `7000000` (7) · `7000A` | max 6, digits |

Two extra probes settle the things this page only remembers: `12987-7318` for a country on rule `2` (does a hyphen fail the numeric check?), and — on S/4 — a country set to rule `9` with no row in `ADDR_PCDFORMAT` (what does the check do then?).

## S/4 differences

`T005`, the two fields and the nine rules are unchanged. What is new is that rule 9 templates are data (`ADDR_PCDFORMAT`) rather than code, so a country that changes its format no longer needs a note. Customers and vendors are business partners, so the place to test is the business partner address; the check behind it is the same function module.

## How to verify all of this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Length, rule and required flags per country | `OY17`; `SE16N` on `T005`, fields `LNPLZ`, `PRPLZ`, `XPLZS`, `XPLPF` |
| The list of rules and their wording | F4 on the rule field in `OY17` — read it there, the wording differs slightly between releases |
| Templates used by rule 9 | S/4: IMG *Set Countries → Define Postal Code*; `SE16N` on `ADDR_PCDFORMAT`. Older releases: the source of `ADDR_POSTAL_CODE_CHECK` |
| The check in action | `SE37` test of `ADDR_POSTAL_CODE_CHECK`, or a breakpoint in it while saving an address |
| The message a user sees | Save a wrong code and read it — do not quote it from a page |
| Stored codes that would fail a new rule | `SE16N` on `ADRC`, `COUNTRY` = the country, then `POST_CODE1` by length |
| That `T005` is client-dependent | `SE11`: the first key field is the client; or compare two clients in `SE16N` |

## Provenance and caveats

Written from public sources read on **17 September 2026**, and from working knowledge. **Nothing on this page has been confirmed on a system yet.**

- **§1 and §2** — fields, rule list, the classic rule 9 countries, the USA exception and the *"cannot be saved"* wording: SAP Help, *Country Table T005* (Business Address Services, NetWeaver 7.31).
- **§3, the cloud list** — the SAP Community blog *SAP Cloud for Customer Postal Code Check* by an SAP employee, February 2019.
- **§3, `ADDR_PCDFORMAT`** — the IMG documentation of *Define Postal Code* as shown in a screenshot in an SAP Community answer of March 2023, plus a public table reference for the key and field length. I have not opened the activity myself.
- **§4** — formats from Wikipedia's *List of postal codes*; the Argentine customer from the SAP Community thread *Postal Code for Argentina in SAP S4 Hana Cloud*, June 2020, where an SAP advisor answers with KBA 2537879 and Note 1381564.
- **§5** — public KBA previews; note titles from SAP Community threads that cite them. Where the table says *title only*, that is literal.
- **From memory, to be tested:** that a hyphen fails the numeric rules (§2); the behaviour of rule 9 without a template (§8); the address check BAdI (§7).

The message for a wrong length is named in the keywords of KBA 2497091; it is not repeated here because this page has not read it from a system.

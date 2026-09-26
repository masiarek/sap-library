# Ledgers and their currencies: FINSC_LEDGER

**Level:** 201 · for FI consultants setting up S/4HANA

**One line:** In S/4HANA the ledger and its currencies are one configuration object: each ledger, per company code, lists the currency types it carries and how each is converted — so a non-leading ledger can add a currency but never drop one the leading ledger has in BSEG.

## Three kinds of ledger

| Kind | What it is | Currencies |
|---|---|---|
| **Leading ledger** (0L) | The ledger every company code posts to, tied to the group's main accounting principle; the one classic FI reads. There is exactly one. | Defines the BSEG-relevant currencies. |
| **Non-leading standard ledger** (2L, 3L …) | A complete second set of books for another accounting principle (local GAAP beside IFRS, or the other way round), with its own fiscal year variant and posting period variant if needed. | Its first two currency types (10 and the global currency) equal the leading ledger's. It may add freely defined types of its own, and may leave out non-BSEG types it does not need. KBA 3485630: the types cannot be changed on a non-leading ledger after a shell conversion. |
| **Extension ledger** | Not a ledger of its own but a delta on top of an *underlying* ledger: reports on it read the underlying ledger plus the extension's own entries. Used for adjustments to another principle, management adjustments, predictive accounting, commitments. Three extension ledger types: standard journal entries, line items with technical numbers without deletion, line items with technical numbers with deletion. | Inherits all currency types of its underlying ledger; cannot define its own. |

Parallel accounting by ledgers (the *ledger approach*) is the S/4HANA norm; the *accounts approach*, in which one ledger holds account ranges per principle, still exists and has no currency implications of its own beyond the single ledger's. The help-portal pages *Ledger Group*, *Portrayal Using Parallel Ledgers* and *Extension Ledger* are the definitions; SAP Note 3015594 is the FAQ on ledger and currency Customizing.

## The view cluster

Transaction FINSC_LEDGER (IMG: *Financial Accounting → Financial Accounting Global Settings → Ledgers → Ledger → Define Settings for Ledgers and Currency Types*) has these nodes:

1. **Ledger.** Leading flag, ledger type (standard or extension), underlying ledger and extension ledger type.
2. **Currency types.** The standard types 00 to 70 and the customer types Y*/Z*, each with a valuation view (legal, group, profit center; 11/12 and 31/32 are the company code and group currency in group and profit-center valuation).
3. **Global currency conversion settings.** Defaults per currency type: source currency type, exchange rate type, translation date type.
4. **Company code settings for the ledger.** Per ledger and company code: fiscal year variant, posting period variant, the *parallel G/L accounts* flag (accounts approach), and the list of currency types in the order they occupy the ACDOCA fields, with the 1st / 2nd / 3rd FI currency columns for BSEG. The 1st currency is always 10 and the 2nd is the global currency (the controlling area's type, usually 30); both must be the same in every ledger of the company code.
5. **Accounting principles for ledger and company code.** Which principle each ledger portrays for each company code.
6. **Currency conversion settings for company codes.** Overrides of the global settings per company code and type, including the real-time conversion indicator.

Behind it are the tables FINSC_LEDGER (ledgers), FINSC_LD_CMP (ledger × company code), FINSC_LD_CMP_CT (ledger × company code × currency type) and FINSC_CURTYPE (currency type definitions), and the ECC tables T881 and T882G are still updated for compatibility. The KBAs that fire during configuration: 2446407 and 3009909 (currency type 30 cannot be assigned or is missing, usually because the client's group currency or the controlling area's type is not what was assumed), 2810569 (message FINS_ACDOC_CUST298), 3548366 (the key of a standard type is not editable, because it comes from the client, country, company or company code), 3706725 (a company code relevant for group reporting must have consistent group currency types).

## Ledger groups and accounting principles

A **ledger group** is a set of standard ledgers a posting can be addressed to; a ledger's own name is a group with one member. Each group has a **representative ledger**, used to check the posting period; if the leading ledger is in the group it must be the representative. An **accounting principle** (IFRS, local GAAP …) is assigned to exactly one ledger group, and it is the accounting principle that the period-end programs are keyed by: foreign currency valuation runs per valuation area, a valuation area belongs to an accounting principle, and the postings go to that principle's ledger group. That is how IFRS can *always valuate* while local GAAP applies the *lowest value principle* on the same items; see [Foreign currency valuation](../foreign_currency_valuation/README.md).

## Which currency settings may differ per ledger

| Setting | Per ledger? |
|---|---|
| Company code currency (10) | No: the same in all ledgers |
| Global currency (KSL) | No: the same in all ledgers |
| Freely defined types 3–10 | Yes: each non-leading ledger chooses its own set, within the rules |
| Exchange rate type and translation date per type | On premise: yes, per ledger and company code; S/4HANA Cloud: no (KBA 3512760) |
| Fiscal year variant, posting period variant | Yes |
| Valuation method for foreign currency valuation | Yes, through the accounting principle |
| Depreciation areas, ML valuation | Ledger-specific with UPA; before UPA the three BSEG currencies only |

The ECC ancestry explains the constraints. In the new G/L, "as a second and third currency of a non-leading ledger you may only use currency types that you have already assigned to the relevant company code for the leading ledger": non-leading ledgers held a *subset*. In S/4HANA the two mandatory currencies are shared and the rest is ledger-dependent, which is a superset rule for the freely defined types and the same subset rule for the BSEG ones.

## Migration from ECC

In a system conversion the currency configuration is migrated as it is: the local currency, the two parallel currencies from OB22 with their conversion settings, the controlling area currency into KSL, and the non-leading ledger currencies. No new currency is introduced along with the conversion, and SAP Note 2344012 says why: the existing data does not contain the new currency and the open processes would not work if the configuration changed underneath them. Installations that used transfer prices in ECC get their currency and valuation combinations migrated into the same ledger, which is the one case in which a converted system starts with more than three currencies. See [Introducing, changing and retiring currencies](../introducing_and_changing_currencies/README.md).

## How to verify this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| Ledgers and their kind | `FINSC_LEDGER`, *Ledger* node; `SE16N` on `FINSC_LEDGER` |
| Currency types per ledger and company code | `FINSC_LEDGER`, *Company Code Settings for the Ledger* |
| Ledger groups and the representative ledger | IMG *Define Ledger Group* |
| Accounting principle to ledger group | IMG *Assign Accounting Principle to Ledger Groups*; the *Accounting Principles for Ledger and Company Code* node of `FINSC_LEDGER` |
| An extension ledger has no currencies of its own | `FINSC_LEDGER`: an extension ledger shows its underlying ledger and no currency list |
| The ECC tables still updated | `SE16N` on `T881` and `T882G` after saving `FINSC_LEDGER` |

## Provenance

Written from working FI/CO knowledge and from the SAP Notes, KBAs and help-portal pages cited on the page, whose titles were verified in September 2026. None of the claims was confirmed against a named system for this page. Message numbers that appear on the page are quoted from the titles of the cited KBAs, not from memory. The names of the tables behind the view cluster are given from working knowledge and were not read from a system.

## Related pages

- [Currencies in the Universal Journal](../universal_journal_currencies/README.md) — the fields the configuration fills
- [Local currency and the parallel currencies](../local_and_parallel_currencies/README.md) — the BSEG-relevant three
- [Currency types](../currency_types/README.md) — the types listed in node 2
- [Universal Parallel Accounting](../universal_parallel_accounting/README.md) — ledger-specific everything
- [Foreign currency valuation](../foreign_currency_valuation/README.md) — valuation areas and accounting principles

Back to the chapter map: [Currencies in SAP](../README.md).

# Comparing posting keys between clients

**Level: 201 · for FI consultants and the ABAP developer they borrow** — where a posting key is stored, what a comparison tool can and cannot see in it, and a read-only report that shows, for every posting key of the client you are in, whether two chosen fields (Profit Center and Business Area by default) are suppressed, required or optional.

**One line:** A posting key is one row of `TBSL` per client, and its field status is two character strings inside that row. A standard table comparison tells you *that* the string differs between clients; only decoding a position tells you *whether it is the profit center* — so the useful unit of work is a list of decoded statuses per client, which can then be compared like any other list.

Source: [`z_adam_posting_key_status.abap`](z_adam_posting_key_status.abap) — one executable program, one local class, no function modules, nothing outside the client it runs in.

---

## What you are comparing

`OB41` maintains table `TBSL`, and the row it maintains is per client: the client is the first field of the key, so every client holds its own copy of every posting key, and two clients agree only for as long as nothing was changed in one of them without a transport (or a client copy) to the other.

One posting key is one row. The fields that matter:

| Field | What it is | Seen in `OB41` as |
| :-- | :-- | :-- |
| `BSCHL` | The posting key itself | the key |
| `SHKZG` | Debit or credit | *Debit/Credit indicator* |
| `KOART` | Account type: `S` G/L, `D` customer, `K` vendor, `A` asset, `M` material | *Account type* |
| `STBSL` | The reversal posting key | *Reversal posting key* |
| `XSONU` | Special G/L flag | *Special G/L* |
| `XUMSW` | Sales-related flag | *Sales-related* |
| `XZAHL` | Payment transaction flag | *Payment transaction* |
| `FAUS1`, `FAUS2` | **The field status** — see below | the *Maintain Field Status* screen |

Texts are in `TBSLT` — one row per language **and, for the special G/L posting keys, one per special G/L indicator**: the table has a third key field, which the first run of the report found the hard way (below). `SE11` lists the full field set; the ones above are the ones the report reads.

### The field status is two strings

The *Maintain Field Status* screen in `OB41` shows fields in groups — general data, additional account assignments, payment transactions and so on — each with three radio buttons: suppressed, required, optional. None of that is stored as fields. It is stored as **one character per screen field** in two strings, `FAUS1` and `FAUS2`, with the second string continuing the numbering of the first:

| Character | Meaning |
| :-- | :-- |
| `-` | suppressed |
| `+` | required entry |
| `.` | optional entry |

So *"Profit Center is required on posting key 40"* means: at the profit center's position, the string in row `40` holds a `+`. Which position that is comes from the field-selection definition tables behind the maintenance screen (the tables whose names start `TMOD`), and it is the same position for every posting key, because every key's screen is built from the same definition.

Two consequences that shape everything below:

1. **A table comparison sees `FAUS1` as one field.** It will report that the string differs and show you both strings. It will not tell you that the difference is at the profit center rather than at the purchasing document.
2. **A report can decode it in one line**, once the position is known — and the position can be looked up.

## Three ways to compare, and which one to use

| Route | What it needs | What it tells you | Use it when |
| :-- | :-- | :-- | :-- |
| **Standard comparison**: `SCMP` (view/table comparison) with table `TBSL` and an RFC destination; `SM30` offers the same comparison from its menu; `SCU0` (once `OY19`) does the same for whole IMG areas or a transport request's objects | An RFC destination to the other client (`SM59`), and a user there allowed to display the table | Which posting keys exist on one side only, and which rows differ, field by field — `FAUS1` counted as one field | First pass: *is anything different at all?* — and for comparing an entire FI area after a transport or a refresh |
| **Download and decode**: `SE16N` (or `SE16`) on `TBSL` in each client, export, decode the two positions with `MID()` in a spreadsheet | A logon in each client, nothing else | Profit center and business area status per key on each side | A client you can reach but where you cannot create a program |
| **The report below**, run in each client: `Z_ADAM_POSTING_KEY_STATUS` | `SE38` in the client | The decoded status of both fields per key, already in words — export the list from each client and put the two side by side | Whenever the question is about specific fields, and whenever it will be asked again |

The standard route and the report are not rivals. `SCMP` on `TBSL` answers *"did the transport arrive?"* in a minute. The report answers *"is the profit center required here?"*, which `SCMP` cannot, and it answers it for fifty posting keys at once.

## The report

### What it shows

One row per posting key of the client you are logged on to:

| Column | What it holds |
| :-- | :-- |
| Posting key, Name | `BSCHL` and its text in your logon language |
| *Profit Center*, *Business Area* | `required`, `optional`, `suppressed`, or `(blank)` for a position the strings do not use. `?` means the position is not known — see the next section |
| Account type, D/C, Reversal key, Special G/L, Sales-related, Payment transaction | The rest of the row |
| `FAUS1|FAUS2` | The raw strings, for reading a status the two decoded columns do not cover |

### How it finds the positions

It does not hard-code them. With the position fields left at 0 it reads the field-selection definition tables — `TMODU` and its siblings — **dynamically**: each table is read as a whole, every row is flattened to text, and a row counts when it mentions the field name (`PRCTR`, `GSBER`). The short numbers such a row carries are the position candidates. When every matching row agrees on one number, that number is used and the list shows the statuses straight away.

When they do not agree, or no row matches, the report first displays the matching definition rows — table, which field they matched, the candidate number, every number in the row, and the row's content — so that the position can be read off and entered on the selection screen. *Show the definition rows* forces that display even when the lookup succeeded, which is how you check that it picked the right number.

Reading the tables dynamically is deliberate: their layout is not asserted anywhere in the program, so it activates whatever the release, and the page does not have to vouch for their columns.

### Selection screen

| Block | Parameter | Meaning |
| :-- | :-- | :-- |
| Posting keys | *Posting key* | Restrict to some keys; blank means all |
| Fields to decode | *Field A: name*, *field name to look up*, *position* | The name the list uses (default *Profit Center*), the field name searched in the definition (default `PRCTR`), and the position, 0 to look it up |
| | *Field B: ...* | Same, defaults *Business Area* and `GSBER` |
| Output | *Show raw status strings* | Add the `FAUS1|FAUS2` column |
| | *Show the definition rows* | Display what the lookup found before the list |

Any two fields of the field status can be decoded by changing the field names — `KOSTL` for the cost center, `AUFNR` for the order, and so on.

### Checking a position independently

Two ways, neither needing the definition tables:

1. **Against the screen.** Open one posting key in `OB41`, *Maintain Field Status*, and read the profit center's radio button. The report's column for that key must say the same. Do it for a key where the field is *not* optional, so that a wrong position is unlikely to agree by chance.
2. **By changing one field in a sandbox.** Set Profit Center to *required* on one posting key in a sandbox client, then read that key's `FAUS1` and `FAUS2` in `SE16` before and after: the character that changed is the position. The report's *raw strings* column shows the same strings.

### Installing it

1. `SE38`: create an executable program and paste the [source](z_adam_posting_key_status.abap). Rename to your convention.
2. Activate. No text elements need maintaining: frame titles and selection texts are set at `INITIALIZATION` — the same technique as the [exchange rate report](../exchange_rates/exchange_rate_check_report.md#installing-it), with the same caveat that the generated `%_<name>_%_app_%-text` fields are widely used but not documented.
3. Run it. Nothing else: it reads `TBSL`, `TBSLT` and the definition tables of the client you are in.

## What the first runs got wrong

Recorded here in the spirit of the [exchange rate report](../exchange_rates/exchange_rate_check_report.md#what-the-first-runs-got-wrong): every assumption the system corrected, with the fix.

**1. `TBSLT` is not one row per language and posting key.** The first run ended in a short dump on the text read — a duplicate key while filling a unique table, on posting key `09`. That key is the customer special G/L debit, and `TBSLT` keeps one text for it per special G/L indicator, so the table has a third key field and the block insert met the same posting key twice. *Fix:* read the texts in primary key order, which puts the blank indicator first, and insert them one row at a time — a single-row insert on an existing key sets `sy-subrc` to 4 and keeps the first text instead of terminating. The posting key rows in `TBSL` are not affected: that table's key is client and posting key only.

**2. A position nobody knows is a status nobody sees.** The second run listed every posting key with the two status columns empty, because the first version expected the positions to be entered and offered a trick for finding them that needed a second client. *Fix:* the report looks the positions up itself, in the definition tables, and shows what it found when the lookup is not unambiguous. The same evening the cross-client comparison the report had started as was dropped: the question was about the current client, and a list per client compares well enough.

## What else decides whether Profit Center and Business Area are required

The posting key is one of several inputs to the field status a user actually meets:

- **The G/L account's field status group.** `SKB1-FSTAG` names a group in the field status variant assigned to the company code (`T001-FSTVA`), and the group's definition in `T004F` (`OBC4`) is two strings with the **same layout** — the same position means the same field. At posting time the two are combined position by position: required beats optional, suppressed beats optional, and suppressed against required is an error at entry. So a posting key with the profit center *optional* still behaves as *required* on an account whose group requires it. The position the report finds applies to `T004F` too.
- **Business area financial statements per company code** (`T001-XGSBE`, `OB65`). Read at posting time as well; check it before blaming the posting key for a business area that is demanded in one company code and not another.
- **Document splitting characteristics** for the profit center — mandatory or not, zero-balance or not, and the default (constant) that fills an underivable line. A profit center that is *optional* on both key and account can still be non-blank on every line, and one that is *required* can still be inherited rather than entered.
- **Derivation.** The profit center usually arrives from the cost center, order, WBS element or material rather than from the keyboard. *Optional on the posting key* says nothing about whether it will be blank.

If the question behind a comparison is *"which client is right?"*, the transport log is the tie-breaker: a Customizing change in `OB41` is recorded in a request, and a client that lacks the change either never received it or was refreshed from a source that lacked it.

## How to verify all of this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| `TBSL` is per client | `SE11`, table `TBSL`: the first key field is the client |
| The fields the report reads exist under these names | `SE11`, `TBSL` field list; `SE16` on `TBSL` for posting key `40` — and the report activated against them |
| `TBSLT` has a third key field | `SE11`, table `TBSLT` — and the dump on posting key `09` |
| `-`, `+`, `.` are the three statuses | `SE16` on `TBSL` for one key, beside its *Maintain Field Status* screen in `OB41` |
| The position the lookup found is right | *Show the definition rows*, then the two checks under [checking a position independently](#checking-a-position-independently) |
| The position is the same for every posting key | The sandbox check on two keys; both name the same number |
| `T004F` uses the same layout | `SE11`: compare the data elements of `TBSL-FAUS1` and `T004F-FAUS1`; then the screen check in `OBC4` on one group |
| Key and account group combine as described | `FB01`: a key with the profit center optional against an account whose group requires it, and the reverse |
| `SCMP` compares a table across a destination | `SCMP` with `TBSL` and the destination: rows and differing fields, with `FAUS1` shown whole |
| A trailing blank in `FAUS1` is a position the screen does not use | `SE16` on `TBSL` with the string shown in full: the used positions end before the field does |

## Provenance and caveats

- Written **24 September 2026** from experience with the module. Field and table names are given because they are the stable core; message texts, menu paths and the columns of the `TMOD*` tables are deliberately not quoted — the report reads those tables without assuming any column.
- The program was parsed and syntax-checked with `abaplint` (release 7.58 syntax) before every version. **The first version activated without correction on 24 September 2026** on an S/4HANA system (ID withheld — public page); its first run dumped on the `TBSLT` read, and its second run listed all posting keys with empty status columns, which is what led to the position lookup. **The version with the lookup has been parsed but not yet run**; whether the definition tables yield an unambiguous position on that release is the open question, and this page will record the answer.
- The three status characters and the combination rule are as remembered; the verification table names the check for each. If your system shows a fourth character, the report prints it in quotes rather than guessing.

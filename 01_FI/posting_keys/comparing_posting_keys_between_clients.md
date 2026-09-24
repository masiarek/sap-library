# Comparing posting keys between clients

**Level: 201 · for FI consultants and the ABAP developer they borrow** — where a posting key is stored, what a comparison tool can and cannot see in it, and a read-only report that lists, for every posting key of the client you are in, whether Business Area, Profit Center and Segment are suppressed, required or optional.

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
| **The report below**, run in each client: `Z_ADAM_POSTING_KEY_STATUS` | `SE38` in the client | Client, posting key, and the status of Business Area, Profit Center and Segment in words — export the list from each client and put the two side by side | Whenever the question is about specific fields, and whenever it will be asked again |

The standard route and the report are not rivals. `SCMP` on `TBSL` answers *"did the transport arrive?"* in a minute. The report answers *"is the profit center required here?"*, which `SCMP` cannot, and it answers it for fifty posting keys at once.

## The report

### What it shows

One row per posting key of the client you are logged on to, five columns:

| Column | What it holds |
| :-- | :-- |
| Client | `sy-mandt`, so that lists exported from several clients can be stacked |
| Posting key | `BSCHL` |
| *Business Area*, *Profit Center*, *Segment* | `required`, `optional`, `suppressed`, or `not maintained` for a position the row carries no character at — see [blank is not a status](#blank-is-not-a-status). `?` means the position is not known — see the next section |

*More columns* adds the name, account type, D/C, reversal key, the three flags and the raw `FAUS1|FAUS2` strings.

### How it finds the positions

It does not hard-code them. With the position fields left at 0 it reads the field-selection definition table `TMODU` (and its siblings, if present) **dynamically**: the table is read as a whole, every row is flattened to text with `|` between the columns, and a row counts when it belongs to the FI document's field selection — the rows whose first column is `SKB1-FAUS1` — and names the field (`GSBER`, `PRCTR`, `SEGMENT`) as a whole column value. The short numbers such a row carries are the position candidates. When every matching row agrees on one number, that number is used and the list shows the statuses straight away.

On the system it ran on, the rows looked like this (client, table and flag columns as shown by the report):

```text
SKB1-FAUS1|033|BSEG|GSBER|D||X
SKB1-FAUS1|042|BSEG|PRCTR|S||X
```

— one row per account type, all with the same number, so **Business Area is position 33 and Profit Center position 42** there; the next run found **Segment at 101**, which lies in the second string. The same table also holds other applications' field selections with their own numbering; Real Estate (`TIV01-AUSWA`) puts its profit center at 29, which is why the lookup is restricted to `SKB1-FAUS1` and why the field name must match a whole column and not a substring (`PSEGMENT` and `PPRCTR`, the partner fields, would otherwise match).

When the rows do not agree, or none matches, the report first displays them — table, field, candidate number, every number in the row, and the row's content — so that the position can be read off and entered on the selection screen. *Show the definition rows* forces that display even when the lookup succeeded, which is how you check that it picked the right number.

Reading the table dynamically is deliberate: its layout is not asserted anywhere in the program, so it activates whatever the release, and the page does not have to vouch for its columns beyond what a run displayed.

### Selection screen

| Block | Parameter | Meaning |
| :-- | :-- | :-- |
| Posting keys | *Posting key* | Restrict to some keys; blank means all |
| Positions (0 = look up) | *Field selection* | The field selection name the lookup is restricted to; `SKB1-FAUS1` is the FI document's |
| | *Business Area position*, *Profit Center position*, *Segment position* | 0 to look up; a number overrides the lookup for that field |
| Output | *More columns* | Name, attributes and raw strings |
| | *Show the definition rows* | Display what the lookup found before the list |

### Blank is not a status

The first full list showed Segment as blank on almost every posting key and `optional` on one. That is not a fourth status. A posting key row gets a character at a position only when it is saved in `OB41` after that field exists in the definition. Segment sits at position 101 — in `FAUS2`, the second string, which exists because the field list outgrew the first one — and the standard posting keys were delivered and last saved long before Segment was added to the definition. So their second string is empty there. The one key that showed `optional` is simply a row that was saved after Segment existed, by SAP or by someone on site.

What an unmaintained position does at posting time is not decidable from the string. From experience, the entry screens treat it as suppressed: the field is not offered until a status is set explicitly, which is the familiar *"Segment does not appear in the coding block"* problem and its fix in `OB41` and `OBC4`. Two checks settle it in your system, and neither takes a minute:

1. `OB41`, a posting key the list shows as `not maintained`, *Maintain Field Status*, additional account assignments: which radio button Segment shows, against a key the list shows as `optional`.
2. `FB01` with a G/L posting key: whether Segment is offered on the line.

For Segment specifically it rarely matters: the field is derived from the profit center rather than typed, and the field status governs manual entry only. For a field that *is* typed, `not maintained` is a row to maintain, not a status to reason about.

### Checking a position independently

Two ways, neither needing the definition tables:

1. **Against the screen.** Open one posting key in `OB41`, *Maintain Field Status*, and read the profit center's radio button. The report's column for that key must say the same. Do it for a key where the field is *not* optional, so that a wrong position is unlikely to agree by chance.
2. **By changing one field in a sandbox.** Set Profit Center to *required* on one posting key in a sandbox client, then read that key's `FAUS1` and `FAUS2` in `SE16` before and after: the character that changed is the position. The report's raw strings column (under *More columns*) shows the same strings.

### Installing it

1. `SE38`: create an executable program and paste the [source](z_adam_posting_key_status.abap). Rename to your convention.
2. Activate. No text elements need maintaining: frame titles and selection texts are set at `INITIALIZATION` — the same technique as the [exchange rate report](../exchange_rates/exchange_rate_check_report.md#installing-it), with the same caveat that the generated `%_<name>_%_app_%-text` fields are widely used but not documented.
3. Run it with the defaults. Nothing else: it reads `TBSL`, `TBSLT` and the definition table of the client you are in.

## What the first runs got wrong

Recorded here in the spirit of the [exchange rate report](../exchange_rates/exchange_rate_check_report.md#what-the-first-runs-got-wrong): every assumption the system corrected, with the fix.

**1. `TBSLT` is not one row per language and posting key.** The first run ended in a short dump on the text read — a duplicate key while filling a unique table, on posting key `09`. That key is the customer special G/L debit, and `TBSLT` keeps one text for it per special G/L indicator, so the table has a third key field and the block insert met the same posting key twice. *Fix:* read the texts in primary key order, which puts the blank indicator first, and insert them one row at a time — a single-row insert on an existing key sets `sy-subrc` to 4 and keeps the first text instead of terminating. The posting key rows in `TBSL` are not affected: that table's key is client and posting key only.

**2. A position nobody knows is a status nobody sees.** The second run listed every posting key with the two status columns empty, because the first version expected the positions to be entered and offered a trick for finding them that needed a second client. *Fix:* the report looks the positions up itself, in the definition tables, and shows what it found when the lookup is not unambiguous. The same evening the cross-client comparison the report had started as was dropped: the question was about the current client, and a list per client compares well enough.

**3. The definition table serves more than FI.** The third run found Business Area at 33 without doubt and refused to name a position for Profit Center: the FI rows all said 42, and one Real Estate row said 29. The lookup had matched any row mentioning the field. *Fix:* restrict the rows to the field selection asked for (`SKB1-FAUS1`), and match the field name as a whole column value, so that the partner fields `PSEGMENT` and `PPRCTR` cannot widen the search again once Segment was added to the list.

**4. The fourth run found all three positions by itself** — 33, 42 and 101 — and raised the question above: the Segment column was blank on nearly every key. Not a mistake in the program, but a mistake waiting to happen in the reader, so the list now prints `not maintained` for a blank character instead of `(blank)`.

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
- The program was parsed and syntax-checked with `abaplint` (release 7.58 syntax) before every version. **Activated and run on an S/4HANA system on 24 September 2026** (ID withheld — public page), three runs: the first dumped on the `TBSLT` read; the second listed all posting keys with empty status columns; the third, with the lookup, displayed the `TMODU` rows quoted above and named 33 for Business Area. The fourth run, with the `SKB1-FAUS1` restriction, whole-column matching and the Segment column, listed all posting keys with the three statuses filled. **Confirmed against that system, 24 September 2026:** `TMODU` exists, is readable, and holds `SKB1-FAUS1` rows naming `033` for `GSBER`, `042` for `PRCTR` and `101` for `SEGMENT`; the standard customer posting keys carry `.` at 33, `-` at 42 on all but `01` and `09`, and a blank at 101 on all but `06`. **Not confirmed:** what the posting screens do with a blank position — see [blank is not a status](#blank-is-not-a-status) for the two checks. The `not maintained` wording is parsed, not yet run.
- The three status characters and the combination rule are as remembered; the verification table names the check for each. If your system shows a fourth character, the report prints it in quotes rather than guessing.

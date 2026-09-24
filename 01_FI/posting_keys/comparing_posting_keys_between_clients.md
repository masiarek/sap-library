# Comparing posting keys between clients

**Level: 201 · for FI consultants and the ABAP developer they borrow** — where a posting key is stored, what a comparison tool can and cannot see in it, and a read-only report that decodes the field status of two chosen fields (Profit Center and Business Area by default) in this client and in another — a client of the same system read directly, or a client of another system read over an RFC destination.

**One line:** A posting key is one row of `TBSL` per client, and its field status is two character strings inside that row. Comparing clients means reading the row from both sides and decoding the positions you care about — a standard table comparison tells you *that* the string differs, and only decoding tells you *whether it is the profit center*.

Source: [`z_adam_posting_key_compare.abap`](z_adam_posting_key_compare.abap) — one executable program, one local class, one standard function module (`RFC_READ_TABLE`, used only for another system), nothing to transport into the other client.

---

## What you are comparing

`OB41` maintains table `TBSL`, and the row it maintains is per client: the client is the first field of the key, so every client holds its own copy of every posting key, and two clients agree only for as long as nothing was changed in one of them without a transport (or a client copy) to the other.

One posting key is one row. The fields that matter for a comparison:

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
2. **A spreadsheet or a report can decode it in one line**, once the position is known — `MID(FAUS1, position, 1)` in the spreadsheet, a substring in the report.

## Three ways to compare, and which one to use

| Route | What it needs | What it tells you | Use it when |
| :-- | :-- | :-- | :-- |
| **Standard comparison**: `SCMP` (view/table comparison) with table `TBSL` and an RFC destination; `SM30` offers the same comparison from its menu; `SCU0` (once `OY19`) does the same for whole IMG areas or a transport request's objects | An RFC destination to the other client (`SM59`), and a user there allowed to display the table | Which posting keys exist on one side only, and which rows differ, field by field — `FAUS1` counted as one field | First pass: *is anything different at all?* — and for comparing an entire FI area after a transport or a refresh |
| **Download and decode**: `SE16N` (or `SE16`) on `TBSL` in each client, export, decode the two positions with `MID()` in a spreadsheet | A logon in each client, nothing else — no RFC destination, no development | Profit center and business area status per key on each side | A one-off, or a client you cannot reach by RFC |
| **The report below**: `Z_ADAM_POSTING_KEY_COMPARE` | `SE38` in one client. For another client of the **same system**, nothing else — it reads that client's rows directly. For another **system**, an RFC destination | Both chosen fields decoded side by side, every differing position listed, the attributes side by side, one traffic light per key | Whenever it will be done more than once: after each quality refresh, across several clients, or for more than two fields |

The standard route and the report are not rivals. `SCMP` on `TBSL` answers *"did the transport arrive?"* in a minute. The report answers *"and is the profit center required in both?"*, which `SCMP` cannot, and it answers it for fifty posting keys at once.

## Finding the position of a field — once

The report deliberately hard-codes no position. Two ways to find one:

**1. Change one field, compare, read the number.** In a sandbox client: `OB41`, posting key `40`, *Maintain Field Status*, set Profit Center to *required*, save. Run the report **from that client against an untouched client** — the golden client of the same system, entered by number, needs no destination — with both positions left blank. Posting key `40` comes back yellow with exactly one entry in *Differing positions* — that entry is the profit center's position. Do the same for Business Area, or set both in one go with *different* statuses (profit center required, business area suppressed) and read which of the two differing positions holds the `+` in the *raw strings* column. Revert the change afterwards, or leave it in a sandbox that will be refreshed anyway.

**2. Read the definition.** The `OB41` and `OBC4` screens read the position of each field from the field-selection definition tables (`TMOD*`). If you would rather read than experiment, `SE16` on those tables with the field name is the place to look. The report does not depend on them, so nothing on this page rests on their exact layout — which is why the first way is the recommended one: it proves the position in your release rather than reading it from a table whose columns this page does not vouch for.

**Check it on a second posting key.** The position is the same for every key. If the trick on `40` and the trick on `31` give different numbers, something else changed between the runs.

## The report

### Selection screen

| Block | Parameter | Meaning |
| :-- | :-- | :-- |
| Posting keys and other client | *Other client of this system* | A client number of the system you are logged on to. The report reads that client's `TBSL` directly — no RFC destination, nothing from Basis. Checked against `T000`, and refused if it is the client you are in |
| | *Or: RFC destination of other system* | A client of **another** system, over an RFC destination. Not together with the client number. **Both blank lists this client only**, decoded, with no comparison columns |
| | *Posting key* | Restrict to some keys; blank means all |
| Fields to decode | *Field A: position*, *Field A: name* | Position in `FAUS1`/`FAUS2`, and the name the list uses for it. Defaults to *Profit Center* with no position |
| | *Field B: position*, *Field B: name* | Same, defaults to *Business Area* |
| Output | *Only keys that differ* | Drop the green rows |
| | *Show raw status strings* | Add `FAUS1|FAUS2` from both sides as two columns |

Both positions blank is legitimate: the report then compares everything and lists the differing positions, which is how a position is found in the first place.

### Columns

One row per posting key found on either side. *Here* is the client the report runs in; *there* is the other client, by number or behind the destination.

| Column | What it holds |
| :-- | :-- |
| Traffic light | green = identical; yellow = differs, but not in field A or B; red = A or B differs, or the key exists on one side only |
| *Found in* | `both`, `this only`, `other only` |
| *Profit Center here* / *there*, *Business Area here* / *there* | `required`, `optional`, `suppressed`, or `(blank)` for a position the strings do not use |
| *Differing positions* (count and list) | Every position at which the two strings differ, as numbers — the column that finds a position for you |
| Account type, D/C, reversal key, special G/L, sales-related, payment transaction | Each once per side |
| `FAUS1|FAUS2` here / there | The raw strings, for reading a difference the two decoded columns do not cover |

### How it reads the other client

Locally, a `SELECT` on `TBSL`. **Another client of the same system:** the same `SELECT` with `USING CLIENT`, because `TBSL` is client-dependent and its rows for every client sit in the same database table — this is what makes the golden-client comparison a two-minute job with no destination. **Another system:** `RFC_READ_TABLE` — which returns each row as one 512-character line and, in its `FIELDS` table, the offset and length at which every requested field sits. The report slices by those offsets rather than asking for a delimiter, so the **trailing blanks** of `FAUS1` and `FAUS2` survive; a delimited read would trim them and shift nothing, but it would turn *(blank)* positions into *absent* ones. A `TBSL` row is well under the 512-character limit.

The remote side needs nothing installed: only a user who may call `RFC_READ_TABLE` and display `TBSL`. Run the report the other way round — from the other client against this one — as a cross-check: the differing positions must come out identical.

### Installing it

1. `SE38`: create an executable program and paste the [source](z_adam_posting_key_compare.abap). Rename to your convention.
2. Activate. No text elements need maintaining: frame titles and selection texts are set at `INITIALIZATION` — the same technique as the [exchange rate report](../exchange_rates/exchange_rate_check_report.md#installing-it), with the same caveat that the generated `%_<name>_%_app_%-text` fields are widely used but not documented.
3. For another client of the same system: nothing more. Enter the client number.
4. For another system only: an RFC destination (`SM59`, an ABAP connection) to a client there. Basis usually owns these. The user in the destination needs to call `RFC_READ_TABLE` (an `S_RFC` authorization for the function's group — `SE37` shows which) and to display `TBSL` (`S_TABU_DIS` for its authorization group, or `S_TABU_NAM` for the table).

## What the first run got wrong

Recorded here in the spirit of the [exchange rate report](../exchange_rates/exchange_rate_check_report.md#what-the-first-runs-got-wrong): every assumption the system corrected, with the fix.

**1. `TBSLT` is not one row per language and posting key.** The first run ended in a short dump on the text read — a duplicate key while filling a unique table, on posting key `09`. That key is the customer special G/L debit, and `TBSLT` keeps one text for it per special G/L indicator, so the table has a third key field and the block insert met the same posting key twice. *Fix:* read the texts in primary key order, which puts the blank indicator first, and insert them one row at a time — a single-row insert on an existing key sets `sy-subrc` to 4 and keeps the first text instead of terminating. The posting key rows in `TBSL` are not affected: that table's key is client and posting key only.

## What else decides whether Profit Center and Business Area are required

Comparing posting keys settles whether the *posting keys* differ. It does not by itself settle *"why is the field required in one client and not the other"*, because the posting key is one of several inputs to the field status a user actually meets:

- **The G/L account's field status group.** `SKB1-FSTAG` names a group in the field status variant assigned to the company code (`T001-FSTVA`), and the group's definition in `T004F` (`OBC4`) is two strings with the **same layout** — the same position means the same field. At posting time the two are combined position by position: required beats optional, suppressed beats optional, and suppressed against required is an error at entry. So a posting key with the profit center *optional* in both clients still behaves differently if the account's group differs. The position found above applies to `T004F` too; the comparison method is the same, one row per field status group instead of per posting key.
- **Business area financial statements per company code** (`T001-XGSBE`, `OB65`). Read at posting time as well; compare it between clients before blaming the posting key for a business area that is demanded in one and not the other.
- **Document splitting characteristics** for the profit center — mandatory or not, zero-balance or not, and the default (constant) that fills an underivable line. A profit center that is *optional* on both key and account can still be non-blank on every line, and one that is *required* can still be inherited rather than entered.
- **Derivation.** The profit center usually arrives from the cost center, order, WBS element or material rather than from the keyboard. *Optional on the posting key* says nothing about whether it will be blank.

If the question behind the comparison is *"which client is right?"*, the transport log is the tie-breaker: a Customizing change in `OB41` is recorded in a request, and a client that lacks the change either never received it or was refreshed from a source that lacked it.

## How to verify all of this in your own system

| Claim | Where to prove it |
| :-- | :-- |
| `TBSL` is per client | `SE11`, table `TBSL`: the first key field is the client |
| The fields the report reads exist under these names | `SE11`, `TBSL` field list; `SE16` on `TBSL` for posting key `40` |
| `-`, `+`, `.` are the three statuses | `SE16` on `TBSL` for one key, beside its *Maintain Field Status* screen in `OB41` |
| The position is the same for every posting key | Run the position trick on two keys; both name the same number |
| `T004F` uses the same layout | `SE11`: compare the data elements of `TBSL-FAUS1` and `T004F-FAUS1`; then the position trick in `OBC4` on one group |
| Key and account group combine as described | `FB01`: a key with the profit center optional against an account whose group requires it, and the reverse |
| `USING CLIENT` reads another client's rows | `SE16` on `TBSL` in the other client, one key, against the report's *there* columns for that key |
| `RFC_READ_TABLE` returns offsets and lengths | `SE37`, test run with `QUERY_TABLE` = `TBSL` and one field in `FIELDS`: the table comes back with offset and length filled |
| `SCMP` compares a table across a destination | `SCMP` with `TBSL` and the destination: rows and differing fields, with `FAUS1` shown whole |
| A trailing blank in `FAUS1` is a position the screen does not use | `SE16` on `TBSL` with the string shown in full: the used positions end before the field does |

## Provenance and caveats

- Written **24 September 2026** from experience with the module. **Nothing on this page is confirmed against a named system.** Field and table names are given because they are the stable core; message texts, menu paths and the columns of the `TMOD*` tables are deliberately not quoted.
- The report was parsed and syntax-checked with `abaplint` (release 7.58 syntax) before every version. **It activated without correction on 24 September 2026** on an S/4HANA system (ID withheld — public page), and its first run terminated in the text read with the duplicate key described above. The corrected version has been parsed but, as of this writing, **not yet re-run**; the comparison itself and the RFC read are therefore still unconfirmed against a system. This page will say so when they have run.
- The three status characters and the combination rule are as remembered; the verification table names the check for each. If your system shows a fourth character, the report prints it in quotes rather than guessing.
- `RFC_READ_TABLE` is a standard function and in some landscapes its use is restricted by policy rather than by authorization. If it is, the download-and-decode route needs no function at all — and a comparison inside one system never touches it.
- The client-number option was added after the first run, on request, so that a comparison with the golden client needs no destination. It has been parsed, not yet run.

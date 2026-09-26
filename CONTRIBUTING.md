# Contributing — how pages here are written

House conventions, and the reasoning behind them. They exist because the failure mode for notes like these is not being wrong on day one — it is being confidently, unverifiably wrong three years later, after a release upgrade nobody re-read the page against.

## 1. Mechanism over verdict

A page whose payload is *"F110 won't do that"* has to be believed. A page whose payload is *"it can't — the customer's items are never in the selection set, and here is the flag that keeps them out"* can be **checked**, and it survives the reader who was not in the original conversation.

Write the mechanism. The verdict falls out of it for free.

## 2. Every claim gets a verification path

Each page ends with a table pairing its claims to the transaction, table or field where the reader confirms them. If a claim cannot be given one, that is worth knowing about the claim.

## 3. State provenance honestly

Two very different kinds of page live here, and they must never be dressed as each other:

- **Written from experience** — knowledge of how the module behaves, unverified against a named system for this page. Say so in a *Provenance* section.
- **Confirmed against a system** — name the system ID and the date, beside the specific claim it covers.

A single confirmed claim does not upgrade the rest of the page.

## 4. No message numbers or screen text from memory

Message IDs, proposal-log wording and menu paths move between releases and support packs. Quoting one from memory is precisely how a page that is 95% right becomes a page nobody trusts. Describe what the message *says*, and tell the reader to read it in their own system.

Field and table names are the stable core and are safe to name directly.

## 5. Say when S/4 differs

Where classic master-data transactions have been replaced by business partner maintenance, note it — and note that the underlying tables F110 reads (`LFB1`, `KNB1`) did not change. Readers arrive from both worlds.

## Structure

- Folders are numbered for reading order (`01_FI`), with a `README.md` as the section landing page — MkDocs' `navigation.indexes` turns it into the section's front page, and GitHub renders it when you open the folder.
- Sidebar order is set in `mkdocs_hooks.py` (`NAV_ORDER`), **never** by renumbering files. A filename is a permanent URL; inserting a lesson should not move every page after it.
- Link a folder by naming its README (`[FI](01_FI/README.md)`), not with a bare folder path — MkDocs leaves a bare folder link untouched and it 404s on the published site.

## Program output is generated, never typed

Some pages (the currency chapter) back their arithmetic with a small Python program in an `examples/` folder beside the page: stdlib only, deterministic, written to be read aloud. The page marks the spot and `tools/run_examples.py` pastes what the program actually printed, with a provenance line above the fence:

```markdown
<!-- output:xsalh_clearing -->
<!-- /output -->
```

Inside the markers is generated; outside is yours. The recorded output (`<stem>.out`) is the answer key, and CI fails if the program, the key and the page drift apart. Stems are named bare in the markers, so they must be unique across the repo.

```bash
python3 tools/run_examples.py            # verify + refill the pages
python3 tools/run_examples.py --update   # record current output as the answer key
python3 tools/run_examples.py --check    # write nothing, fail on drift (CI)
```

## Building the site locally

```bash
uv run --group docs mkdocs serve
```

Before committing, run both checks CI runs:

```bash
python3 tools/run_examples.py --check
uv run --group docs mkdocs build --strict
```

The docs root is the repo root (`mkdocs-same-dir`), so there is no `docs/` copy step: the Markdown GitHub renders is exactly what the site serves. `site/` is generated output — never commit it.

#!/usr/bin/env python3
"""Run every example, and hold its output to a recorded answer key.

This is the spine of the library. A lesson page never hand-types what a program
prints; it marks the spot and this tool fills it from a real run:

    <!-- output:significant_figures -->
    <!-- /output -->

Inside the markers is generated, outside is yours. There is a second kind,
`source:`, which pastes the program itself — for the pages where the code *is*
the lesson and a hand-copied fence could quietly drift from the file CI runs.

Four modes
----------
    python3 tools/run_examples.py             verify + refill the .md blocks
    python3 tools/run_examples.py --update    accept current output as the key
    python3 tools/run_examples.py --check     write nothing; fail on any drift  (CI)
    python3 tools/run_examples.py --only X    touch example X and nothing else

``--only`` narrows both the running and the refilling to the stems you name.
A full ``--update`` re-records *every* answer key and refills *every* page, which
in a checkout open in two sessions means adopting whatever a colleague's
half-finished example happens to print. It is never right in CI: a partial run
cannot see repo-wide drift, which is the whole job there.

An example is any ``*.py`` under a folder named ``examples/``. Its answer key is
the sibling ``<stem>.out``. Stems must be unique repo-wide, because a Markdown
block names a bare stem with no path.

Why the examples are stdlib-only, and this tool with them: a reader should be
able to run any page in this library with the ``python3`` their machine already
has. A library about how much of a number is real should not open with a
dependency resolution failure.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# <!-- output:stem -->  ...generated...  <!-- /output -->
# <!-- source:stem -->  ...generated...  <!-- /source -->
BLOCK = re.compile(
    r"(?P<open><!--\s*(?P<kind>output|source):(?P<stem>[A-Za-z0-9_\-]+)\s*-->)"
    r"(?P<body>.*?)"
    r"(?P<close><!--\s*/(?P=kind)\s*-->)",
    re.DOTALL,
)

SKIP_DIRS = {".git", "site", ".venv", "__pycache__", ".github"}

# A fenced code block, opened or closed. The pages that DOCUMENT this mechanism
# (README.md, CONTRIBUTING.md) show the markers inside a fence — those are
# documentation, not blocks to fill.
FENCE = re.compile(r"^[ \t]*(?P<f>`{3,}|~{3,})", re.MULTILINE)


def fenced_spans(text: str) -> list[tuple[int, int]]:
    """Character ranges covered by fenced code blocks."""
    spans: list[tuple[int, int]] = []
    open_at: int | None = None
    open_fence = ""
    for m in FENCE.finditer(text):
        fence = m.group("f")
        if open_at is None:
            open_at, open_fence = m.start(), fence
        elif fence[0] == open_fence[0] and len(fence) >= len(open_fence):
            spans.append((open_at, m.end()))
            open_at = None
    if open_at is not None:
        spans.append((open_at, len(text)))
    return spans


def walk(root: Path):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            yield Path(dirpath) / name


def find_examples() -> dict[str, Path]:
    """Map stem -> path for every .py under an examples/ folder. Stems are unique."""
    found: dict[str, Path] = {}
    for path in sorted(walk(REPO)):
        if path.suffix != ".py" or path.parent.name != "examples":
            continue
        if path.stem in found:
            sys.exit(
                f"ERROR: duplicate example stem {path.stem!r}\n"
                f"  {found[path.stem].relative_to(REPO)}\n  {path.relative_to(REPO)}\n"
                "Stems are named bare in Markdown blocks, so they must be unique."
            )
        found[path.stem] = path
    return found


def run_example(src: Path) -> str:
    """Run one example; return its stdout. Exits on failure.

    Run from the example's own folder so a page can tell the reader to `cd` there
    and type the same command, and with -I so a stray module beside it or on
    PYTHONPATH cannot change what the page claims.
    """
    proc = subprocess.run(
        [sys.executable, "-I", src.name],
        cwd=src.parent,
        capture_output=True,
        text=True,
        timeout=60,
    )
    if proc.returncode != 0:
        sys.exit(f"ERROR: {src.relative_to(REPO)} exited {proc.returncode}\n{proc.stderr}")
    if proc.stderr.strip():
        print(f"  note: {src.relative_to(REPO)} wrote to stderr:\n{proc.stderr}")
    return proc.stdout


def rendered_block(kind: str, src: Path, output: str, page: Path) -> str:
    """The generated body that goes between the markers on `page`."""
    href = os.path.relpath(src, page.parent)
    if kind == "source":
        body = src.read_text(encoding="utf-8").strip("\n")
        return (
            f"\n*[`{src.name}`]({href}) in full — pasted here by "
            f"`tools/run_examples.py` from the file CI runs.*\n\n"
            f"```python\n{body}\n```\n"
        )
    return (
        f"\n*Verified output of [`{src.name}`]({href}) — regenerated by "
        f"`tools/run_examples.py`, never hand-typed.*\n\n"
        f"```text\n{output.strip(chr(10))}\n```\n"
    )


def fill_pages(
    outputs: dict[str, str],
    sources: dict[str, Path],
    write: bool,
    problems: list[str],
    only: set[str] | None = None,
) -> list[str]:
    """Refill every generated block on every Markdown page. Returns drift.

    A block naming a stem that no longer exists is recorded in `problems` and left
    untouched rather than exiting on the spot — dying on the first one would leave
    every other page unfilled.

    With `only` set, a block naming any other stem is left exactly as it is. The
    selection is checked before the kind is, so a run scoped to one stem cannot
    rewrite either half of somebody else's page.
    """
    drift: list[str] = []
    for page in sorted(walk(REPO)):
        if page.suffix != ".md":
            continue
        text = page.read_text(encoding="utf-8")
        if "<!-- output:" not in text and "<!-- source:" not in text:
            continue
        skip = fenced_spans(text)

        def replace(m: re.Match) -> str:
            if any(lo <= m.start() < hi for lo, hi in skip):
                return m.group(0)
            stem, kind = m.group("stem"), m.group("kind")
            if only is not None and stem not in only:
                return m.group(0)
            known = sources if kind == "source" else outputs
            if stem not in known:
                problems.append(
                    f"{page.relative_to(REPO)}: asks for {kind} block {stem!r}, "
                    "but no examples/*.py has that stem"
                )
                return m.group(0)
            return (
                m.group("open")
                + rendered_block(kind, sources[stem], outputs.get(stem, ""), page)
                + m.group("close")
            )

        new = BLOCK.sub(replace, text)
        if new != text:
            drift.append(str(page.relative_to(REPO)))
            if write:
                page.write_text(new, encoding="utf-8")
    return drift


def examples_under(token: Path, examples: dict[str, Path]) -> set[str]:
    """Every example stem inside `token`, if `token` names a directory."""
    for base in (token, REPO / token):
        try:
            if not base.is_dir():
                continue
            resolved = base.resolve()
        except OSError:
            continue
        held = {s for s, p in examples.items() if resolved in p.parents}
        if held:
            return held
    return set()


def resolve_selection(raw: list[str], examples: dict[str, Path]) -> set[str]:
    """Turn `--only` values into stems: a bare stem, a path to the .py, or a folder.

    A token that names nothing is an error rather than an empty selection: a typo
    that records nothing looks exactly like a successful run.
    """
    wanted: set[str] = set()
    unknown: list[str] = []
    for token in (t.strip() for value in raw for t in value.split(",")):
        if not token:
            continue
        as_path = Path(token)
        held = examples_under(as_path, examples)
        if held:
            wanted |= held
            continue
        for candidate in (token, as_path.stem, as_path.name):
            if candidate in examples:
                wanted.add(candidate)
                break
        else:
            unknown.append(token)
    if unknown:
        sys.exit(
            f"ERROR: --only names no such example: {', '.join(unknown)}\n"
            f"Known stems: {', '.join(sorted(examples))}"
        )
    return wanted


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--update", action="store_true", help="record current output as the answer key")
    ap.add_argument("--check", action="store_true", help="write nothing; fail on drift (CI)")
    ap.add_argument(
        "--only",
        action="append",
        metavar="STEM[,STEM…]",
        help="restrict to these example stems (a path or a folder works too); "
        "repeat the flag or comma-separate. Not for CI.",
    )
    args = ap.parse_args()

    examples = find_examples()
    if not examples:
        print("No examples found (looked for *.py under any examples/ folder).")
        return 0

    selected = resolve_selection(args.only, examples) if args.only else None

    outputs: dict[str, str] = {}
    failures: list[str] = []

    for stem, src in sorted(examples.items()):
        key = src.with_suffix(".out")

        # Outside the selection: not ours. Not run, and deliberately not even
        # read — an output in hand is one `fill_pages` could write into someone
        # else's page.
        if selected is not None and stem not in selected:
            continue

        actual = run_example(src)
        outputs[stem] = actual

        if args.update:
            key.write_text(actual, encoding="utf-8")
            print(f"  recorded  {key.relative_to(REPO)}")
            continue
        if not key.exists():
            failures.append(f"{src.relative_to(REPO)}: no answer key — run with --update")
            continue
        if key.read_text(encoding="utf-8") != actual:
            failures.append(f"{src.relative_to(REPO)}: output differs from {key.name}")
        else:
            print(f"  ok        {src.relative_to(REPO)}")

    drift = fill_pages(outputs, examples, write=not args.check, problems=failures, only=selected)

    if args.check and drift:
        failures.append(
            "Markdown output blocks are stale: " + ", ".join(drift)
            + " — run tools/run_examples.py"
        )
    elif drift:
        for page in drift:
            print(f"  filled    {page}")

    if failures:
        print("\nFAILED:")
        for f in failures:
            print(f"  - {f}")
        return 1

    if selected is not None:
        print(
            f"\n{len(selected)} of {len(examples)} example(s) verified. --only was in "
            f"effect: the other {len(examples) - len(selected)} were left untouched. "
            "Do a full run before committing."
        )
        return 0

    print(f"\n{len(examples)} example(s) verified against their recorded output.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

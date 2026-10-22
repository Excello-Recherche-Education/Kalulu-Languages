#!/usr/bin/env python3
"""Check every language pack's database against the schema and the data rules.

SCHEMA.md is the contract; this is what checks it. For each <locale>/language.db:

  errors    - the pack does not follow the schema, or is damaged:
              user_version is not the latest schema/v<n>.sql (rule 5), its
              tables, columns, defaults, keys or indexes differ from that file,
              SQLite's integrity_check fails, foreign_key_check finds rows
              pointing at nothing, or the data breaks rules 2, 3, 4 or 6 of
              SCHEMA.md: a GP no lesson teaches, a lesson without minigames,
              a minigame list that is not the game's, a lesson ID that is not
              its lesson number.
  warnings  - the data breaks rule 1 of SCHEMA.md (a word or syllable with a
              missing or broken decomposition). Reported, not fatal, while a
              known case waits for a decision (payons in fr_FR). --strict makes
              it fatal.
  notices   - a rule that could not be checked, and why.

Exits 1 when there is an error (or, with --strict, a warning), 0 otherwise.
Python standard library only, so CI needs nothing installed.

Rule 4 compares ExerciseTypes with the game's MinigameTypes.NAMES, read from a
Kalulu-Frontend checkout: --frontend, or the Kalulu-Frontend folder beside this
repository in a Kalulu-Main working copy. Without one -- in CI -- the packs are
compared with each other instead, and the run says so.

    python3 .github/scripts/validate_packs.py                 # every pack
    python3 .github/scripts/validate_packs.py fr_FR/language.db
    python3 .github/scripts/validate_packs.py --frontend ../Kalulu-Frontend
"""

from __future__ import annotations

import argparse
import os
import re
import sqlite3
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_DIR = ROOT / "schema"
MINIGAME_TYPES = Path("sources/utils/minigame_types.gd")

# How many examples an annotation or a console line lists before "... and N more".
SHOWN = 10


@dataclass
class Finding:
    level: str  # "error", "warning" or "notice"
    rule: str
    title: str
    details: list[str] = field(default_factory=list)


@dataclass
class PackReport:
    name: str
    version: int | None = None
    findings: list[Finding] = field(default_factory=list)
    exercise_types: list[tuple[int, str]] | None = None

    def add(self, level: str, rule: str, title: str, details: list[str] | None = None) -> None:
        self.findings.append(Finding(level, rule, title, details or []))

    def count(self, level: str) -> int:
        return sum(1 for finding in self.findings if finding.level == level)


# --- Structure ---------------------------------------------------------------


def latest_schema() -> tuple[int, Path]:
    versions = []
    for path in SCHEMA_DIR.glob("v*.sql"):
        match = re.fullmatch(r"v(\d+)\.sql", path.name)
        if match:
            versions.append((int(match.group(1)), path))
    if not versions:
        sys.exit(f"No schema/v<n>.sql found in {SCHEMA_DIR}")
    return max(versions)


def describe(conn: sqlite3.Connection) -> dict:
    """The structure of a database, as SQLite reports it rather than as its SQL
    text reads: the packs mix quoted and unquoted column definitions written by
    different tools, which mean the same thing."""
    tables = {}
    rows = conn.execute(
        "SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
    ).fetchall()
    for name, sql in rows:
        columns = [
            (column[1], (column[2] or "").upper(), column[3], default_value(column[4]), column[5])
            for column in conn.execute(f'PRAGMA table_info("{name}")')
        ]
        foreign_keys = sorted(
            (fk[2], fk[3], fk[4] or "", fk[5].upper(), fk[6].upper())
            for fk in conn.execute(f'PRAGMA foreign_key_list("{name}")')
        )
        indexes = []
        for index in conn.execute(f'PRAGMA index_list("{name}")'):
            index_columns = tuple(info[2] for info in conn.execute(f'PRAGMA index_info("{index[1]}")'))
            indexes.append((index[2], index[3], index[4], index_columns))
        tables[name] = {
            "columns": columns,
            "foreign_keys": foreign_keys,
            "indexes": sorted(indexes),
            "autoincrement": "AUTOINCREMENT" in (sql or "").upper(),
        }
    others = set(
        conn.execute(
            "SELECT type, name FROM sqlite_master WHERE type IN ('view', 'trigger') "
            "OR (type = 'index' AND sql IS NOT NULL)"
        ).fetchall()
    )
    return {"tables": tables, "others": others}


def default_value(text: str | None) -> str | None:
    """A default as SQLite would store it: a double-quoted one, such as the
    packs' DEFAULT "" on LettersTracingData, is SQLite's legacy spelling of a
    string literal and means the same as DEFAULT ''."""
    if text is not None and len(text) >= 2 and text[0] == text[-1] == '"':
        return "'" + text[1:-1].replace('""', '"').replace("'", "''") + "'"
    return text


def describe_column(column: tuple) -> str:
    name, kind, notnull, default, pk = column
    text = f"{name} {kind or '(no type)'}"
    if notnull:
        text += " NOT NULL"
    if default is not None:
        text += f" DEFAULT {default}"
    if pk:
        text += " PRIMARY KEY"
    return text


def describe_foreign_key(fk: tuple) -> str:
    table, source, target, on_update, on_delete = fk
    return f"{source} -> {table}({target or 'its key'}) ON UPDATE {on_update} ON DELETE {on_delete}"


def compare_structure(found: dict, expected: dict) -> list[str]:
    differences = []
    found_tables, expected_tables = found["tables"], expected["tables"]
    for name in sorted(expected_tables.keys() - found_tables.keys()):
        differences.append(f"table {name} is missing")
    for name in sorted(found_tables.keys() - expected_tables.keys()):
        differences.append(f"table {name} is not in the schema")
    for name in sorted(found_tables.keys() & expected_tables.keys()):
        have, want = found_tables[name], expected_tables[name]
        have_columns = {column[0]: column for column in have["columns"]}
        want_columns = {column[0]: column for column in want["columns"]}
        for column in want["columns"]:
            if column[0] not in have_columns:
                differences.append(f"{name}: column {column[0]} is missing")
            elif have_columns[column[0]] != column:
                differences.append(
                    f"{name}: column is {describe_column(have_columns[column[0]])}, "
                    f"schema says {describe_column(column)}"
                )
        for column in have["columns"]:
            if column[0] not in want_columns:
                differences.append(f"{name}: column {column[0]} is not in the schema")
        if [c[0] for c in have["columns"] if c[0] in want_columns] != [
            c[0] for c in want["columns"] if c[0] in have_columns
        ]:
            differences.append(f"{name}: columns are in a different order than in the schema")
        for fk in sorted(set(want["foreign_keys"]) - set(have["foreign_keys"])):
            differences.append(f"{name}: foreign key {describe_foreign_key(fk)} is missing")
        for fk in sorted(set(have["foreign_keys"]) - set(want["foreign_keys"])):
            differences.append(f"{name}: foreign key {describe_foreign_key(fk)} is not in the schema")
        if have["indexes"] != want["indexes"]:
            differences.append(f"{name}: UNIQUE constraints or indexes differ from the schema")
        if have["autoincrement"] != want["autoincrement"]:
            state = "has" if have["autoincrement"] else "lacks"
            differences.append(f"{name}: {state} AUTOINCREMENT, unlike the schema")
    for kind, name in sorted(found["others"] - expected["others"]):
        differences.append(f"{kind} {name} is not in the schema")
    for kind, name in sorted(expected["others"] - found["others"]):
        differences.append(f"{kind} {name} is missing")
    return differences


# --- Data rules (SCHEMA.md, "Rules the data must follow") ---------------------


def check_decompositions(conn: sqlite3.Connection, report: PackReport) -> None:
    """Rule 1: every word and syllable is decomposed, positions 0, 1, 2... with no gap."""
    for table, text_column, relation, key, label in (
        ("Words", "Word", "GPsInWords", "WordID", "word"),
        ("Syllables", "Syllable", "GPsInSyllables", "SyllableID", "syllable"),
    ):
        rows = conn.execute(
            f"""SELECT t.{text_column}, COUNT(r.ID), MIN(r.Position), MAX(r.Position),
                       COUNT(DISTINCT r.Position)
                FROM {table} t LEFT JOIN {relation} r ON r.{key} = t.ID
                GROUP BY t.ID ORDER BY t.{text_column}"""
        ).fetchall()
        empty = [row[0] for row in rows if row[1] == 0]
        gaps = [
            f"{row[0]} (positions {positions(conn, relation, key, table, text_column, row[0])})"
            for row in rows
            if row[1] > 0 and (row[2] != 0 or row[3] != row[1] - 1 or row[4] != row[1])
        ]
        if empty:
            report.add("warning", "rule 1", f"{len(empty)} {label}(s) have no decomposition", empty)
        if gaps:
            report.add(
                "warning", "rule 1",
                f"{len(gaps)} {label}(s) have a gap or a duplicate in their GP positions", gaps,
            )


def positions(conn, relation, key, table, text_column, text) -> str:
    values = conn.execute(
        f"""SELECT r.Position FROM {relation} r JOIN {table} t ON t.ID = r.{key}
            WHERE t.{text_column} = ? ORDER BY r.Position""",
        (text,),
    ).fetchall()
    return " ".join(str(value[0]) for value in values)


def check_gps_taught(conn: sqlite3.Connection, report: PackReport) -> None:
    """Rule 2: every GP used in a decomposition is introduced by some lesson."""
    rows = conn.execute(
        """SELECT gp.Grapheme, gp.Phoneme,
                  (SELECT COUNT(DISTINCT WordID) FROM GPsInWords WHERE GPID = gp.ID),
                  (SELECT COUNT(DISTINCT SyllableID) FROM GPsInSyllables WHERE GPID = gp.ID)
           FROM GPs gp
           WHERE gp.ID NOT IN (SELECT GPID FROM GPsInLessons)
             AND (gp.ID IN (SELECT GPID FROM GPsInWords) OR gp.ID IN (SELECT GPID FROM GPsInSyllables))
           ORDER BY gp.Grapheme, gp.Phoneme"""
    ).fetchall()
    if rows:
        report.add(
            "error", "rule 2",
            f"{len(rows)} GP(s) are used in words or syllables but taught by no lesson",
            [f"{g}-{p} (in {w} word(s), {s} syllable(s))" for g, p, w, s in rows],
        )


def check_lesson_exercises(conn: sqlite3.Connection, report: PackReport) -> None:
    """Rule 3: LessonsExercises values are 0 or an ExerciseTypes ID, and every
    lesson has exactly one row with at least one minigame."""
    invalid = []
    for column in ("Exercise1", "Exercise2", "Exercise3"):
        for lesson, value in conn.execute(
            f"""SELECT l.LessonNb, e.{column} FROM LessonsExercises e
                LEFT JOIN Lessons l ON l.ID = e.LessonID
                WHERE e.{column} != 0 AND e.{column} NOT IN (SELECT ID FROM ExerciseTypes)
                ORDER BY l.LessonNb"""
        ):
            invalid.append(f"lesson {lesson}: {column} = {value}")
    if invalid:
        report.add("error", "rule 3", f"{len(invalid)} minigame slot(s) name no ExerciseTypes row", invalid)

    missing = [
        f"lesson {row[0]}"
        for row in conn.execute(
            "SELECT LessonNb FROM Lessons WHERE ID NOT IN (SELECT LessonID FROM LessonsExercises) ORDER BY LessonNb"
        )
    ]
    if missing:
        report.add("error", "rule 3", f"{len(missing)} lesson(s) have no LessonsExercises row, so no minigame", missing)

    empty = [
        f"lesson {row[0]}"
        for row in conn.execute(
            """SELECT l.LessonNb FROM LessonsExercises e JOIN Lessons l ON l.ID = e.LessonID
               WHERE e.Exercise1 = 0 AND e.Exercise2 = 0 AND e.Exercise3 = 0 ORDER BY l.LessonNb"""
        )
    ]
    if empty:
        report.add("error", "rule 3", f"{len(empty)} lesson(s) have all three minigame slots empty", empty)

    doubled = [
        f"lesson {row[0]} ({row[1]} rows)"
        for row in conn.execute(
            """SELECT l.LessonNb, COUNT(*) FROM LessonsExercises e JOIN Lessons l ON l.ID = e.LessonID
               GROUP BY e.LessonID HAVING COUNT(*) > 1 ORDER BY l.LessonNb"""
        )
    ]
    if doubled:
        report.add(
            "error", "rule 3",
            f"{len(doubled)} lesson(s) have more than one LessonsExercises row; the game adds them all up",
            doubled,
        )


def read_exercise_types(conn: sqlite3.Connection, report: PackReport) -> None:
    report.exercise_types = [
        (row[0], row[1]) for row in conn.execute("SELECT ID, Type FROM ExerciseTypes ORDER BY ID")
    ]


def check_exercise_types(report: PackReport, names: list[str], source: str) -> None:
    """Rule 4: ExerciseTypes row n holds names[n - 1], and nothing else."""
    expected = [(index + 1, name) for index, name in enumerate(names)]
    if report.exercise_types is None or report.exercise_types == expected:
        return
    have = dict(report.exercise_types)
    want = dict(expected)
    details = []
    for exercise_id in sorted(have.keys() | want.keys()):
        if exercise_id not in have:
            details.append(f"ID {exercise_id}: missing, expected {want[exercise_id]}")
        elif exercise_id not in want:
            details.append(f"ID {exercise_id}: {have[exercise_id]}, expected no row")
        elif have[exercise_id] != want[exercise_id]:
            details.append(f"ID {exercise_id}: {have[exercise_id]}, expected {want[exercise_id]}")
    report.add("error", "rule 4", f"ExerciseTypes does not match {source}", details)


def check_lesson_ids(conn: sqlite3.Connection, report: PackReport) -> None:
    """Rule 6: every lesson's ID is its lesson number. An error, not a warning:
    the Language Lambda writes GPsInLessons.LessonID to MySQL as the lesson
    number, so a pack that breaks it puts lessons the game does not have into
    production."""
    rows = conn.execute("SELECT ID, LessonNb FROM Lessons WHERE ID != LessonNb ORDER BY LessonNb").fetchall()
    if rows:
        report.add(
            "error", "rule 6",
            f"{len(rows)} lesson(s) have an ID different from their lesson number",
            [f"lesson {number} has ID {lesson_id}" for lesson_id, number in rows],
        )


DATA_RULES = (check_decompositions, check_gps_taught, check_lesson_exercises, read_exercise_types, check_lesson_ids)


# --- Running -------------------------------------------------------------------


def validate(path: Path, latest: int, reference: dict) -> PackReport:
    report = PackReport(display_name(path))
    try:
        conn = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)
        report.version = conn.execute("PRAGMA user_version").fetchone()[0]
    except sqlite3.Error as error:
        report.add("error", "file", f"cannot be read as a SQLite database: {error}")
        return report

    with conn:
        if report.version != latest:
            report.add(
                "error", "rule 5",
                f"user_version is {report.version}, the latest schema is version {latest}",
            )
        differences = compare_structure(describe(conn), reference)
        if differences:
            report.add("error", "structure", f"structure differs from schema/v{latest}.sql", differences)

        integrity = [row[0] for row in conn.execute("PRAGMA integrity_check")]
        if integrity != ["ok"]:
            report.add("error", "integrity", "SQLite integrity_check failed", integrity)

        broken = Counter(
            (row[0], row[2]) for row in conn.execute("PRAGMA foreign_key_check")
        )
        if broken:
            report.add(
                "error", "foreign keys",
                f"{sum(broken.values())} row(s) point at rows that do not exist",
                [f"{table} -> {parent}: {count} row(s)" for (table, parent), count in sorted(broken.items())],
            )

        for rule in DATA_RULES:
            try:
                rule(conn, report)
            except sqlite3.Error as error:
                report.add("notice", rule.__name__, f"could not be checked: {error}")
    conn.close()
    return report


def display_name(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path)


def minigame_names(frontend: Path | None) -> tuple[list[str] | None, str]:
    candidates = [frontend] if frontend else [ROOT.parent / "Kalulu-Frontend"]
    for checkout in candidates:
        source = checkout / MINIGAME_TYPES
        if source.is_file():
            match = re.search(r"const NAMES[^=]*=\s*\[(.*?)\]", source.read_text(encoding="utf-8"), re.S)
            if match:
                return re.findall(r'"([^"]*)"', match.group(1)), f"MinigameTypes.NAMES ({source})"
    if frontend:
        sys.exit(f"--frontend: no MinigameTypes.NAMES in {frontend / MINIGAME_TYPES}")
    return None, ""


def check_rule_4(reports: list[PackReport], frontend: Path | None) -> str:
    names, source = minigame_names(frontend)
    if names is not None:
        for report in reports:
            check_exercise_types(report, names, "MinigameTypes.NAMES")
        return f"Rule 4 compared ExerciseTypes with {source}."
    # No game checkout: the packs must at least agree with each other.
    lists = Counter(tuple(r.exercise_types) for r in reports if r.exercise_types is not None)
    if lists:
        common = list(lists.most_common(1)[0][0])
        names = [name for _, name in common]
        for report in reports:
            check_exercise_types(report, names, "the other packs")
    return (
        "Rule 4 compared the packs' ExerciseTypes with each other only: no Kalulu-Frontend "
        "checkout was found to read MinigameTypes.NAMES from (pass --frontend)."
    )


def shorten(details: list[str]) -> list[str]:
    if len(details) <= SHOWN:
        return details
    return details[:SHOWN] + [f"... and {len(details) - SHOWN} more"]


def escape(text: str, property_value: bool = False) -> str:
    text = text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    if property_value:
        text = text.replace(":", "%3A").replace(",", "%2C")
    return text


def print_console(reports: list[PackReport], rule_4_note: str) -> None:
    for report in reports:
        print(f"{report.name}  (user_version {report.version})")
        if not report.findings:
            print("  ok")
        for finding in report.findings:
            print(f"  {finding.level.upper():8} {finding.rule}: {finding.title}")
            for detail in shorten(finding.details):
                print(f"           - {detail}")
    print(rule_4_note)


def print_annotations(reports: list[PackReport], rule_4_note: str) -> None:
    for report in reports:
        for finding in report.findings:
            message = finding.title
            if finding.details:
                message += "\n" + "\n".join(shorten(finding.details))
            print(
                f"::{finding.level} file={escape(report.name, True)},"
                f"title={escape(f'{report.name} - {finding.rule}', True)}::{escape(message)}"
            )
    print(f"::notice title=Rule 4::{escape(rule_4_note)}")


def report_markdown(reports: list[PackReport], rule_4_note: str, latest: int) -> str:
    """The whole report as Markdown: the run's summary, and the pull request comment."""
    errors = sum(report.count("error") for report in reports)
    warnings = sum(report.count("warning") for report in reports)
    if errors:
        verdict = f"❌ **{errors} error(s)** — this cannot be merged as it is."
    else:
        verdict = "✅ **No errors.**"
    if warnings:
        verdict += f" {warnings} warning(s) about decompositions (rule 1), not blocking for now."
    lines = [
        "## Language pack validation",
        "",
        verdict,
        "",
        f"Checked against `schema/v{latest}.sql` and the rules in `SCHEMA.md`.",
        "",
        "| Pack | user_version | Errors | Warnings | Notices |",
        "|---|---|---|---|---|",
    ]
    for report in reports:
        lines.append(
            f"| `{report.name}` | {report.version} | {report.count('error') or '-'} | "
            f"{report.count('warning') or '-'} | {report.count('notice') or '-'} |"
        )
    lines += ["", rule_4_note, ""]
    for report in reports:
        if not report.findings:
            continue
        lines += [f"### `{report.name}`", ""]
        for finding in report.findings:
            lines.append(f"- **{finding.level}**, {finding.rule}: {finding.title}")
            if finding.details:
                lines += ["  <details><summary>details</summary>", ""]
                lines += [f"  - {detail}" for detail in finding.details]
                lines += ["", "  </details>"]
        lines.append("")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("packs", nargs="*", type=Path, help="language.db files (default: every <locale>/language.db)")
    parser.add_argument("--frontend", type=Path, help="a Kalulu-Frontend checkout, for rule 4")
    parser.add_argument("--strict", action="store_true", help="fail on warnings too")
    parser.add_argument("--report", type=Path, help="also write the report as Markdown to this file")
    args = parser.parse_args()

    latest, schema_file = latest_schema()
    reference_db = sqlite3.connect(":memory:")
    reference_db.executescript(schema_file.read_text(encoding="utf-8"))
    reference = describe(reference_db)
    reference_db.close()

    packs = args.packs or sorted(ROOT.glob("*/language.db"))
    if not packs:
        print("No language.db found.", file=sys.stderr)
        return 1
    reports = [validate(path, latest, reference) for path in packs]
    rule_4_note = check_rule_4(reports, args.frontend)

    print_console(reports, rule_4_note)
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print_annotations(reports, rule_4_note)
    markdown = report_markdown(reports, rule_4_note, latest)
    if args.report:
        args.report.write_text(markdown, encoding="utf-8")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
            summary.write(markdown)

    errors = sum(report.count("error") for report in reports)
    warnings = sum(report.count("warning") for report in reports)
    print(f"\n{len(reports)} pack(s): {errors} error(s), {warnings} warning(s).")
    return 1 if errors or (args.strict and warnings) else 0


if __name__ == "__main__":
    sys.exit(main())

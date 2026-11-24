# note.sql

Minimal SQLite conventions for personal knowledge formats.

English | [日本語](README.ja.md)

Licensed under the [GNU General Public License v3.0](LICENSE).

## What is note.sql?

note.sql is a set of shared conventions for using SQLite as a foundation for personal knowledge.

Tasks, notes, ideas, journals — the digital notebook that holds them has no portable, durable, open common standard. Each note tool stores its data in its own format, leaving a gap.

note.sql defines a set of conventions to fill this gap. It specifies only the foundation — the minimum shape of a note table, naming rules — and leaves concrete expression to each format (a set of DDL representing a particular methodology, e.g. `zettelkasten`, `evergreen`). On this shared foundation, multiple formats can coexist in the same SQLite file, and tools work across formats.

note.sql is not a library, CLI, or application — it is the conventions themselves. Anyone can publish a format or build tooling on top of it.

## Why SQLite?

The traces of your thinking deserve a longer life than any app. Whatever app is discontinued, whatever service shuts down, they should remain in your hands.

SQL is a mature open standard with decades of history. Pulling fragments together with views, noticing patterns through aggregation, returning to the past through search — the vocabulary for flipping through your records, recalling them, and reconnecting them is all there in the standard.

SQLite implements that SQL as a single file, readable and writable in any environment — the de facto standard.

The same motivation might seem satisfied by a pile of files like Markdown. But each file is an independent document, with no shared way to bind them together. How tags and relationships are expressed is left to loose conventions — frontmatter keys, folder structures — that depend on each file and the user's discipline, and there is no way to distribute that convention itself so that another tool can apply it consistently. note.sql puts that role on the SQLite schema. A format is a DDL — a distributable artifact — that takes effect as structure the moment the database is opened, and aggregation and cross-cutting search come built in as SQL.

---

## Conventions

The conventions are divided into two parts.

- Data conventions (Conventions 1–6) apply to every note and property in a note.sql file — whether a table comes from a published format or was added by the user to their own database.
- Published-format conventions (Conventions 7–11) apply only to formats that are published.

Users may add tables to their own database freely. A table meant to hold notes should follow the data conventions; it need not follow the published-format conventions such as the prefix rule.

---

## Data Conventions

### 1. note.sql File

A SQLite database that contains at least one note table (Convention 2) is a note.sql file.

### 2. Note Table

The central concept of note.sql is the note table. Any table that has at least the following columns is a note table.

```sql
id         TEXT PRIMARY KEY  -- UUID recommended
title      TEXT              -- nullable
body       TEXT NOT NULL
created_at TEXT NOT NULL     -- UTC timestamp (Convention 5)
updated_at TEXT NOT NULL     -- UTC timestamp (Convention 5)
```

`body` is the note's content and is required. `title` is an optional heading: many notes — quick captures, journal entries, fleeting notes — are body only, and giving a note a heading is itself an act of curation that not every methodology has.

How note tables are used is up to you. For Zettelkasten, for example, a single note table with links managed in a separate table is valid, as is a separate note table for each note type (literature note, permanent note, etc.).

### 3. Property Tables

A property table holds the vocabulary of values a note can carry — tags, statuses, moods. Any table that has at least the following columns is a property table.

```sql
id    TEXT PRIMARY KEY  -- UUID recommended
label TEXT NOT NULL     -- human-readable display value
```

`label` is the row's human-readable display value — the one string that even a tool unaware of the format can always show for the row (the tag text, a status name).

A note references a property in one of two ways:

- Single-value — the note table holds a reference column to the property table (e.g. `status_id TEXT REFERENCES todo_status(id) ON DELETE SET NULL`). Each note carries at most one value. Per Convention 6, the column is nullable or has a `DEFAULT`.
- Multi-value — a junction table holds one reference column to the note table and one to the property table (e.g. `todo_task_tag(task_id, tag_id)`). Each note carries any number of values.

In both patterns, references are declared per Convention 4. This is what lets even a tool unaware of the format discover properties mechanically: find the tables shaped `id` + `label`, then follow the reference columns declared to point at them — directly from a note table, or through a junction table.

note.sql implies no uniqueness beyond the primary key. Add constraints that match your semantics — e.g. `UNIQUE` on `label` where the vocabulary should not repeat, or a primary key of `(task_id, tag_id)` on a junction table where a note carries each tag at most once.

Tables that do not match the shapes of Conventions 2 and 3 are neither note tables nor property tables. Apart from Convention 4, note.sql places no restrictions on them.

### 4. Declared References

Any column, in any table, that references a note table or a property table must declare both:

- its target, with `REFERENCES`
- what should happen when the referenced row is deleted, with `ON DELETE` (`CASCADE`, `SET NULL`, `SET DEFAULT`, `RESTRICT`, ...)

```sql
-- Junction table: when a note or a tag is deleted, so is the link between them
task_id TEXT NOT NULL REFERENCES todo_task(id) ON DELETE CASCADE,
tag_id  TEXT NOT NULL REFERENCES todo_tag(id)  ON DELETE CASCADE,

-- Single-value: when a status is deleted, the task goes back to having none
status_id TEXT REFERENCES todo_status(id) ON DELETE SET NULL
```

Anything that modifies the database must respect the declared intent: when it deletes a referenced row, the result must be what is declared. How it achieves this — through the database's foreign key enforcement or by handling it itself — is not prescribed.

### 5. Timestamps

`created_at` and `updated_at` on note tables hold UTC timestamps in the following fixed-width form.

```
YYYY-MM-DDTHH:MM:SS.sssZ   -- e.g. 2026-11-24T09:30:00.000Z
```

The width is fixed so that string order matches chronological order. In SQLite, `strftime('%Y-%m-%dT%H:%M:%fZ', 'now')` produces it.

- `created_at` is when the note was created.
- `updated_at` is when the note's content, or the properties assigned to it (single-value or multi-value), last changed. Changing a vocabulary entry itself (such as a property table's `label`) does not change `updated_at` on the notes that carry it.

### 6. Extensibility

- On note tables, property tables, and the junction tables of Convention 3, columns beyond those specified by note.sql must be nullable or carry a `DEFAULT`, so that a tool knowing only the note.sql-defined columns can still insert a valid row
- Anything not defined by note.sql is up to you

---

## Published-Format Conventions

### 7. Formats

A format is a set of DDL representing a particular methodology. A format satisfies the data conventions, and in addition:

- It must have at least one note table.
- It may include tables beyond note tables, such as tags, links, or settings. Because multiple formats can coexist in a single SQLite database, all table and view names must follow the prefix rule in Convention 8 to prevent name collisions.
- Its references must point only at tables of the same format. A reference across formats would create a dependency between them.

### 8. Prefixes and Naming

Table names and view names must be prefixed with the format name. Because SQL identifiers do not allow hyphens, the prefix uses underscores even when the format name contains hyphens (e.g. the format `cornell-notes` uses the prefix `cornell_notes`).

```
<format>_<table>      -- e.g. zettelkasten_note, evergreen_note
<format>_<view>_view  -- e.g. zettelkasten_graph_view (views are recommended, not required)
```

To keep names consistent, the following style is recommended.

- The part after the prefix uses the singular form (e.g. `..._note`, `..._task`, `..._tag` — not `..._notes`).
- A reference column is named after the table it points to: the referenced table's singular name with the format prefix removed, plus `_id` (`todo_task` → `task_id`, `todo_tag` → `tag_id`, `diary_entry` → `entry_id`).

### 9. Compatibility

To avoid breaking databases that use a format under the same name, and the user tables that reference it, the following changes are discouraged:

- Changing the type of an existing column, or dropping it
- Dropping or renaming an existing table

A breaking change that needs any of these is published under a distinct name (Convention 11).

A user who wants to extend a published format's table is recommended to create their own table that references the note's `id`, rather than adding columns to the format's table. A column added directly may collide with a column of the same name added by a later version of the format, or be lost by a migration that rebuilds the table.

```sql
-- e.g. keep your own time estimate for todo_task
CREATE TABLE my_task_estimate (
    task_id TEXT PRIMARY KEY REFERENCES todo_task(id) ON DELETE CASCADE,
    minutes INTEGER
);
```

### 10. Re-applicable format.sql

A `format.sql` is the complete, current definition of a format. It is recommended that it also be safe to re-apply to a database that already holds data — running it again converges the database on the current definition instead of failing or destroying anything.

- Tables and indexes use `CREATE ... IF NOT EXISTS`, so re-applying is a no-op for what already exists
- Views are dropped and recreated (`DROP VIEW IF EXISTS` then `CREATE VIEW`), so they always end up at the current definition

Views hold no state, so re-applying `format.sql` is itself the mechanism for updating them. This removes stale views from a format's concerns entirely, and leaves transforming existing tables as the only thing a migration has to do. How that transformation is carried out is outside note.sql.

### 11. Version Declaration

It is recommended that a format have a `<format>_meta` table: a single-row table holding at least `schema_version INTEGER NOT NULL`, which declares the format's current version.

```sql
id             INTEGER PRIMARY KEY CHECK (id = 1)  -- one row only
schema_version INTEGER NOT NULL
```

Further metadata is held as additional columns (nullable or with a `DEFAULT`, per Convention 6). The single row can be enforced with a constraint such as the `CHECK (id = 1)` above.

Because note.sql assumes multiple formats coexist in one database, a database-global marker such as `PRAGMA user_version` cannot serve this purpose: the version has to be held per format, which means a prefixed table (Conventions 7 and 8). Even a tool unaware of the format can then detect its version with a single query.

Advance `schema_version` for compatible evolution within the bounds of Conventions 6 and 9. Breaking changes are published under a distinct name.

---

## What note.sql Intentionally Leaves Out

These are excluded to keep note.sql minimal and methodology-agnostic.

- How CRUD operations should be implemented
- Migration between versions of a format (only how a version is declared is defined — Convention 11)
- Any obligation to provide views
- How a particular methodology must be expressed
- Hints about UI or presentation

---

## Publishing a Format

1. Prepare a DDL file (`format.sql`) that satisfies note.sql.
2. Prepare a `spec.md` describing the design intent.
3. Publish both in any repository.

The format name becomes the table prefix (Convention 8), so choose a name distinctive enough to avoid colliding with other formats in the same database. The same applies when a breaking change is published under a distinct name (Conventions 9 and 11). note.sql prescribes no versioning scheme beyond that.

## Examples

- [`basic`](examples/basic/format.sql) — a minimal format with only the required columns.
- [`todo`](examples/todo/format.sql) — a simple todo format with status, due date, and tags.
- [`diary`](examples/diary/format.sql) — a simple diary format with one entry per date and tags.

-- diary: a simple diary format with one entry per date and tags.
-- Safe to re-apply to an existing database (Convention 8).

CREATE TABLE IF NOT EXISTS diary_entry (
    id         TEXT PRIMARY KEY,
    title      TEXT,
    body       TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    entry_date TEXT,             -- date, YYYY-MM-DD (Convention 4)
    mood       TEXT              -- free text or rating
);

-- Multi-value property (Convention 2): entries and tags, many-to-many.
CREATE TABLE IF NOT EXISTS diary_tag (
    id    TEXT PRIMARY KEY,      -- UUID recommended
    label TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS diary_entry_tag (
    entry_id TEXT NOT NULL REFERENCES diary_entry(id) ON DELETE CASCADE,
    tag_id   TEXT NOT NULL REFERENCES diary_tag(id)   ON DELETE CASCADE,
    PRIMARY KEY (entry_id, tag_id)
);

CREATE TABLE IF NOT EXISTS diary_meta (
    id             INTEGER PRIMARY KEY CHECK (id = 1),
    schema_version INTEGER NOT NULL
);

-- Stamp the schema version this file defines (Convention 9).
INSERT INTO diary_meta (id, schema_version) VALUES (1, 1)
ON CONFLICT (id) DO UPDATE SET schema_version = excluded.schema_version;

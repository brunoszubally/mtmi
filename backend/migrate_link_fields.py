#!/usr/bin/env python3
import argparse
import os
import re
from datetime import datetime

import psycopg2
from psycopg2.extras import Json
from dotenv import load_dotenv


URL_RE = re.compile(r"https?://[^\s,;]+", re.IGNORECASE)
LINK_KEY_RE = re.compile(r"^(?P<base>.*_link)(?P<idx>\d+)?$")
MAX_LINKS = 10


def extract_urls(value):
    urls = []

    def add_from_text(text):
        if not isinstance(text, str):
            return
        found = URL_RE.findall(text)
        for u in found:
            cleaned = u.rstrip(").,;]}")
            if cleaned:
                urls.append(cleaned)

    if isinstance(value, list):
        for item in value:
            add_from_text(item)
    else:
        add_from_text(value)

    # Stabil dedupe
    deduped = []
    seen = set()
    for u in urls:
        if u not in seen:
            deduped.append(u)
            seen.add(u)
    return deduped


def normalize_link_fields(data):
    if not isinstance(data, dict):
        return data, False, []

    out = dict(data)
    groups = {}

    for key, value in data.items():
        m = LINK_KEY_RE.match(key)
        if not m:
            continue
        base = m.group("base")
        idx = int(m.group("idx")) if m.group("idx") else None
        groups.setdefault(base, {"indexed": {}, "legacy": []})
        if idx is None:
            groups[base]["legacy"].append(value)
        else:
            groups[base]["indexed"][idx] = value

    changed_bases = []
    for base, payload in groups.items():
        indexed = payload["indexed"]
        legacy = payload["legacy"]

        # Csak akkor normalizálunk, ha van legacy (_link) mező, vagy
        # valamelyik indexed mezőben több URL van egy stringben.
        indexed_multi = any(len(extract_urls(v)) > 1 for v in indexed.values())
        if not legacy and not indexed_multi:
            continue

        urls = []
        for idx in sorted(indexed.keys()):
            urls.extend(extract_urls(indexed[idx]))
        for value in legacy:
            urls.extend(extract_urls(value))

        # Dedupe + max 10
        merged = []
        seen = set()
        for u in urls:
            if u not in seen:
                merged.append(u)
                seen.add(u)
            if len(merged) >= MAX_LINKS:
                break

        # Töröljük a korábbi base kulcsokat
        for k in list(out.keys()):
            m = LINK_KEY_RE.match(k)
            if m and m.group("base") == base:
                out.pop(k, None)

        # Újraírjuk _link1..N kulcsokra
        for i, u in enumerate(merged, start=1):
            out[f"{base}{i}"] = u

        changed_bases.append(base)

    return out, bool(changed_bases), changed_bases


def run(apply_changes=False, submitted_only=True):
    load_dotenv()
    database_url = os.environ.get("DATABASE_URL", "")
    if not database_url:
        raise RuntimeError("DATABASE_URL nincs beállítva.")

    where = "WHERE submitted = 1" if submitted_only else ""
    query = f"SELECT id, data FROM forms {where} ORDER BY created_at DESC"

    scanned = 0
    changed = 0
    changed_details = []

    with psycopg2.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(query)
            rows = cur.fetchall()

            for form_id, data in rows:
                scanned += 1
                new_data, is_changed, changed_bases = normalize_link_fields(data)
                if not is_changed:
                    continue

                changed += 1
                changed_details.append((form_id, changed_bases))

                if apply_changes:
                    cur.execute(
                        "UPDATE forms SET data = %s, updated_at = %s WHERE id = %s",
                        (Json(new_data), datetime.utcnow(), form_id),
                    )

        if apply_changes:
            conn.commit()

    print(f"Scanned forms: {scanned}")
    print(f"Changed forms: {changed}")
    mode = "APPLY" if apply_changes else "DRY-RUN"
    print(f"Mode: {mode}")
    for form_id, bases in changed_details[:50]:
        print(f"- {form_id}: {', '.join(bases)}")
    if len(changed_details) > 50:
        print(f"... and {len(changed_details) - 50} more")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Normalize legacy *_link fields to *_link1..*_link10 in forms.data"
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply changes to database (default is dry-run)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Process all forms (default: only submitted=1)",
    )
    args = parser.parse_args()

    run(apply_changes=args.apply, submitted_only=not args.all)

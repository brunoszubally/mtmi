"""Atomic, version-checked writes for forms shared by several editors."""

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi import HTTPException
from psycopg2.extras import Json


def snapshot(form_id, row):
    data, updated_at, school_id, submitted = row
    return {"session_id": form_id, "data": data,
            "updated_at": updated_at.isoformat(), "school_id": school_id,
            "submitted": submitted or 0}


def require_version(expected, current):
    if expected is None:
        raise HTTPException(428, detail={
            "code": "reload_required",
            "message": "Frissítsd az oldalt a biztonságos közös szerkesztéshez. A helyi piszkozatod megmarad.",
        })
    if isinstance(expected, str):
        try:
            expected = datetime.fromisoformat(expected.replace("Z", "+00:00"))
        except ValueError:
            raise HTTPException(422, detail="Érvénytelen űrlapverzió.")
    if expected.tzinfo is not None:
        expected = expected.astimezone(timezone.utc).replace(tzinfo=None)
    actual = datetime.fromisoformat(current["updated_at"])
    if expected != actual:
        raise HTTPException(409, detail={
            "code": "version_conflict",
            "message": "Közben más is mentette ezt a pályázatot. Egyeztesd a változtatásokat.",
            "current": current,
        })


def save_school_form(conn, school_id, requested_id, data, expected_updated_at):
    # The school lock also serializes the first save from two new tabs.
    # An absent/stale form ID must never silently create a replacement form.
    with conn.cursor() as cur:
        cur.execute("SELECT form_id FROM schools WHERE id = %s FOR UPDATE", (school_id,))
        school = cur.fetchone()
        if school is None:
            raise HTTPException(404, detail="Az iskola nem található.")
        form_id = school[0]
        if form_id:
            if requested_id != form_id:
                raise HTTPException(409, detail={
                    "code": "form_link_changed", "session_id": form_id,
                    "message": "Az iskolának már van pályázata. Töltsd be a jelenlegi változatot.",
                })
            cur.execute("SELECT data, updated_at, school_id, submitted FROM forms WHERE id = %s FOR UPDATE",
                        (form_id,))
            row = cur.fetchone()
            if row is None:
                raise HTTPException(409, detail={"code": "missing_form",
                    "message": "A hozzárendelt pályázat nem található. Kérj segítséget az adminisztrátortól."})
            if row[2] and row[2] != school_id:
                raise HTTPException(403, detail="Ez az űrlap nem ehhez az iskolához tartozik.")
            current = snapshot(form_id, row)
            if row[3] == 1:
                raise HTTPException(409, detail={"code": "form_submitted",
                    "message": "A pályázatot közben véglegesítették. Szerkesztés előtt újra meg kell nyitni."})
            require_version(expected_updated_at, current)
            if row[0] == data:
                return form_id, row[1]
            now = max(datetime.utcnow(), row[1] + timedelta(microseconds=1))
            cur.execute("UPDATE forms SET data = %s, updated_at = %s, school_id = COALESCE(school_id, %s) WHERE id = %s",
                        (Json(data), now, school_id, form_id))
        else:
            if requested_id or expected_updated_at:
                raise HTTPException(409, detail={"code": "form_link_changed",
                    "message": "A pályázat hozzárendelése megváltozott. Frissítsd az oldalt."})
            form_id, now = str(uuid4()), datetime.utcnow()
            cur.execute("INSERT INTO forms (id, data, created_at, updated_at, submitted, school_id) VALUES (%s, %s, %s, %s, 0, %s)",
                        (form_id, Json(data), now, now, school_id))
        cur.execute("UPDATE schools SET form_id = %s, updated_at = %s WHERE id = %s",
                    (form_id, now, school_id))
    return form_id, now


def submit_school_form(conn, form_id, school_id, expected_updated_at):
    with conn.cursor() as cur:
        cur.execute("SELECT form_id FROM schools WHERE id = %s FOR UPDATE", (school_id,))
        school = cur.fetchone()
        if school is None or school[0] != form_id:
            raise HTTPException(403, detail="Ez nem az iskola aktuális pályázata.")
        cur.execute("SELECT data, updated_at, school_id, submitted FROM forms WHERE id = %s FOR UPDATE", (form_id,))
        row = cur.fetchone()
        if row is None:
            raise HTTPException(404, detail="Nincs ilyen űrlap.")
        if row[2] and row[2] != school_id:
            raise HTTPException(403, detail="Ez az űrlap nem ehhez az iskolához tartozik.")
        require_version(expected_updated_at, snapshot(form_id, row))
        now = max(datetime.utcnow(), row[1] + timedelta(microseconds=1))
        cur.execute("UPDATE forms SET submitted = 1, updated_at = %s WHERE id = %s", (now, form_id))
    return now

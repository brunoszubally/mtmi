"""Egyetlen iskola űrlapjának visszaállítása a napi FTP-mentésből.

Miért nem a mentés saját visszatöltése (gunzip | psql): az a teljes forms és
schools táblát törli és újratölti, vagyis minden más iskola azóta beírt munkája
elveszne. Ez az eszköz csak a megadott iskola űrlapjához nyúl.

Lépések:

  1. Ki melyik űrlap, és mi van most élesben?
       python restore_school_form.py find --school lanczos

  2. Melyik mentésben mennyi adat volt? (FTP-ről, napokra bontva)
       python restore_school_form.py scan --school lanczos

  3. Mező szintű összevetés egy mentés és az éles állapot között:
       python restore_school_form.py diff --school lanczos --backup mtmi-backup-20261013.sql.gz

  4. Visszaállítás (előtte az éles sort JSON-ba menti, egy tranzakcióban fut):
       python restore_school_form.py restore --form-id <id> \\
           --backup mtmi-backup-20261013.sql.gz --mode merge --yes

     --mode merge:   az éles állapot marad, a mentésből csak az élesben üres
                     mezők töltődnek vissza (az azóta beírt munka nem vész el)
     --mode replace: az űrlap tartalma teljesen a mentésbeli lesz

A --backup lehet helyi fájl is (.sql vagy .sql.gz); ha nincs ilyen fájl, az
FTP backups mappájából tölti le.

Env: DATABASE_URL (find/diff/restore), FTP_HOST/FTP_USER/FTP_PASS (scan, és ha
a mentést FTP-ről kell letölteni; ha nincs megadva, a main.py-ban rögzített
értékeket használja). BACKUP_FTP_DIR, BACKUP_FTP_TLS ugyanúgy működik, mint a
db_backup.py-ban. Railway alatt: railway run python ...
"""

import argparse
import ftplib
import gzip
import io
import json
import os
import re
import sys
import unicodedata
from datetime import datetime, timezone

BACKUP_FTP_DIR = os.environ.get("BACKUP_FTP_DIR", "backups")
BACKUP_FTP_TLS = os.environ.get("BACKUP_FTP_TLS", "0").strip().lower() in ("1", "true", "yes")
BACKUP_FILE_PREFIX = "mtmi-backup-"
BACKUP_FILE_SUFFIX = ".sql.gz"
SCHOOL_NAME_KEY = "palyazo_iskola_neve"


# --- Segédek --------------------------------------------------------------

def norm(text) -> str:
    """Ékezet- és kisbetűfüggetlen összehasonlításhoz."""
    text = unicodedata.normalize("NFKD", str(text or ""))
    return "".join(ch for ch in text if not unicodedata.combining(ch)).casefold()


def is_empty(value) -> bool:
    if value is None:
        return True
    if isinstance(value, str):
        return not value.strip()
    if isinstance(value, (list, tuple)):
        return all(is_empty(v) for v in value)
    if isinstance(value, dict):
        return all(is_empty(v) for v in value.values())
    return False


def size_of(value) -> int:
    if is_empty(value):
        return 0
    if isinstance(value, str):
        return len(value.strip())
    return len(json.dumps(value, ensure_ascii=False))


def summarize(data) -> str:
    data = data if isinstance(data, dict) else {}
    filled = [k for k, v in data.items() if not is_empty(v)]
    chars = sum(size_of(data[k]) for k in filled)
    return "%3d kitöltött mező, %6d karakter" % (len(filled), chars)


def preview(value, width=70) -> str:
    text = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)
    text = " ".join(str(text).split())
    return text if len(text) <= width else text[:width - 1] + "…"


def fmt_ts(value) -> str:
    if value is None:
        return "-"
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M UTC")
    return str(value)[:16].replace("T", " ") + " UTC"


# --- A mentésfájl beolvasása ------------------------------------------------

_INSERT_RE = re.compile(r'^INSERT INTO "(?P<table>[^"]+)" \((?P<cols>.*?)\) VALUES \((?P<vals>.*)\);$')


def _parse_values(text: str):
    """A db_backup.py által (psycopg2 mogrify-jal) írt VALUES lista feldolgozása."""
    values, i, n = [], 0, len(text)
    while i < n:
        while i < n and text[i] == " ":
            i += 1
        escape = False
        if text[i] in "Ee" and i + 1 < n and text[i + 1] == "'":
            escape, i = True, i + 1
        if text[i] == "'":
            i += 1
            buf = []
            while True:
                ch = text[i]
                if ch == "\\" and escape:
                    nxt = text[i + 1]
                    buf.append({"n": "\n", "t": "\t", "r": "\r", "b": "\b", "f": "\f"}.get(nxt, nxt))
                    i += 2
                    continue
                if ch == "'":
                    if i + 1 < n and text[i + 1] == "'":
                        buf.append("'")
                        i += 2
                        continue
                    i += 1
                    break
                buf.append(ch)
                i += 1
            value = "".join(buf)
        else:
            j = i
            while j < n and text[j] not in ",:":
                j += 1
            token = text[i:j].strip()
            i = j
            if token == "NULL":
                value = None
            elif token in ("true", "false"):
                value = token == "true"
            else:
                value = float(token) if "." in token else int(token)
        cast = None
        if text.startswith("::", i):
            j = i + 2
            while j < n and (text[j].isalnum() or text[j] in "_ "):
                j += 1
            cast, i = text[i + 2:j].strip(), j
        if cast in ("json", "jsonb") and isinstance(value, str):
            value = json.loads(value)
        values.append(value)
        while i < n and text[i] == " ":
            i += 1
        if i < n and text[i] == ",":
            i += 1
    return values


def parse_dump(sql_text: str):
    """{tábla: [sor dict, ...]} a mentésből, plusz a mentés időpontja."""
    tables, made_at = {}, None
    for line in sql_text.splitlines():
        if line.startswith("-- Készült:"):
            made_at = line.split(":", 1)[1].strip()
            continue
        if not line.startswith("INSERT INTO "):
            continue
        m = _INSERT_RE.match(line)
        if not m:
            raise ValueError("Nem értelmezhető sor a mentésben: %s…" % line[:120])
        cols = [c.strip().strip('"') for c in m.group("cols").split(",")]
        vals = _parse_values(m.group("vals"))
        if len(cols) != len(vals):
            raise ValueError("Oszlopszám-eltérés a(z) %s táblában: %s…" % (m.group("table"), line[:120]))
        tables.setdefault(m.group("table"), []).append(dict(zip(cols, vals)))
    return tables, made_at


# --- FTP --------------------------------------------------------------------

def ftp_settings():
    """Env-ből, ennek hiányában a mellette lévő main.py-ban rögzített értékekből."""
    keys = ("FTP_HOST", "FTP_USER", "FTP_PASS")
    values = {k: os.environ.get(k) for k in keys}
    if not all(values.values()):
        main_py = os.path.join(os.path.dirname(os.path.abspath(__file__)), "main.py")
        try:
            with open(main_py, encoding="utf-8") as fh:
                src = fh.read()
        except OSError:
            src = ""
        for key in keys:
            if not values[key]:
                m = re.search(r'^%s\s*=\s*"([^"]*)"' % key, src, re.M)
                values[key] = m.group(1) if m else None
    return tuple(values[k] for k in keys)


def ftp_connect():
    host, user, password = ftp_settings()
    if not (host and user and password):
        sys.exit("Hiányzik az FTP_HOST / FTP_USER / FTP_PASS (env-ben és a main.py-ban sincs).")
    if BACKUP_FTP_TLS:
        ftp = ftplib.FTP_TLS(host, timeout=60)
        ftp.login(user, password)
        ftp.prot_p()
    else:
        ftp = ftplib.FTP(host, timeout=60)
        ftp.login(user, password)
    ftp.cwd(BACKUP_FTP_DIR)
    return ftp


def ftp_list_backups(ftp):
    return sorted(n for n in ftp.nlst() if n.startswith(BACKUP_FILE_PREFIX) and n.endswith(BACKUP_FILE_SUFFIX))


def ftp_download(ftp, name) -> bytes:
    buf = io.BytesIO()
    ftp.retrbinary("RETR %s" % name, buf.write)
    return buf.getvalue()


def load_backup(ref: str, ftp=None):
    """Helyi fájl, vagy az FTP backups mappájában lévő fájlnév."""
    if os.path.exists(ref):
        with open(ref, "rb") as fh:
            raw = fh.read()
        name = os.path.basename(ref)
    else:
        own = ftp is None
        ftp = ftp or ftp_connect()
        try:
            raw = ftp_download(ftp, ref)
        finally:
            if own:
                ftp.quit()
        name = ref
        # Helyben is megtartjuk, hogy a visszaállítás ugyanazt a fájlt használja.
        with open(name, "wb") as fh:
            fh.write(raw)
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    tables, made_at = parse_dump(raw.decode("utf-8"))
    return name, made_at, tables


# --- Iskola és űrlap megkeresése --------------------------------------------

def match_schools(schools, query):
    q = norm(query)
    return [s for s in schools if q in norm(s.get("name")) or q in norm(s.get("email"))]


def forms_for(schools, forms, query):
    """Az iskolákhoz tartozó űrlapok: school_id, schools.form_id vagy az űrlapba írt iskolanév alapján."""
    ids = {s["id"] for s in schools}
    linked = {s.get("form_id") for s in schools if s.get("form_id")}
    q = norm(query)
    out = []
    for f in forms:
        data = f.get("data") if isinstance(f.get("data"), dict) else {}
        reasons = []
        if f["id"] in linked:
            reasons.append("az iskolához kötött űrlap")
        if f.get("school_id") in ids:
            reasons.append("school_id")
        if q in norm(data.get(SCHOOL_NAME_KEY)):
            reasons.append("iskolanév az űrlapban")
        if reasons:
            out.append((f, reasons))
    out.sort(key=lambda item: str(item[0].get("updated_at") or ""), reverse=True)
    return out


def print_matches(schools, matches):
    if not schools:
        print("  Nincs ilyen nevű iskola.")
    for s in schools:
        print("  ISKOLA  %s  | %s | felhasználónév: %s | kötött űrlap: %s"
              % (s["id"], s.get("name"), s.get("email") or "-", s.get("form_id") or "-"))
    if not matches:
        print("  Nincs hozzá tartozó űrlap.")
    for f, reasons in matches:
        data = f.get("data") if isinstance(f.get("data"), dict) else {}
        print("  ŰRLAP   %s  | %s | módosítva: %s | létrehozva: %s | %s | %s"
              % (f["id"], summarize(data), fmt_ts(f.get("updated_at")), fmt_ts(f.get("created_at")),
                 "beküldve" if f.get("submitted") == 1 else "folyamatban", ", ".join(reasons)))


# --- Adatbázis --------------------------------------------------------------

def db_connect():
    import psycopg2
    url = os.environ.get("DATABASE_URL")
    if not url:
        sys.exit("Hiányzik a DATABASE_URL környezeti változó.")
    return psycopg2.connect(url, connect_timeout=20)


def live_tables(conn):
    with conn.cursor() as c:
        c.execute("SELECT id, name, email, form_id, updated_at FROM schools")
        schools = [dict(zip(("id", "name", "email", "form_id", "updated_at"), r)) for r in c.fetchall()]
        c.execute("SELECT id, data, created_at, updated_at, submitted, pdf_file_path, school_id FROM forms")
        cols = ("id", "data", "created_at", "updated_at", "submitted", "pdf_file_path", "school_id")
        forms = [dict(zip(cols, r)) for r in c.fetchall()]
    return schools, forms


# --- Parancsok --------------------------------------------------------------

def cmd_find(args):
    with db_connect() as conn:
        schools, forms = live_tables(conn)
    hits = match_schools(schools, args.school)
    print("ÉLES ÁLLAPOT")
    print_matches(hits, forms_for(hits, forms, args.school))


def cmd_scan(args):
    ftp = ftp_connect()
    try:
        names = ftp_list_backups(ftp)
        if args.days:
            names = names[-args.days:]
        print("%d mentés az FTP-n (%s)\n" % (len(names), BACKUP_FTP_DIR))
        for name in names:
            _, made_at, tables = load_backup(name, ftp)
            hits = match_schools(tables.get("schools", []), args.school)
            print("%s  (készült: %s)" % (name, made_at))
            print_matches(hits, forms_for(hits, tables.get("forms", []), args.school))
            print()
    finally:
        ftp.quit()


def diff_fields(old, new):
    old = old if isinstance(old, dict) else {}
    new = new if isinstance(new, dict) else {}
    lost, added, changed = [], [], []
    for key in sorted(set(old) | set(new)):
        a, b = old.get(key), new.get(key)
        if is_empty(a) and is_empty(b):
            continue
        if is_empty(b):
            lost.append(key)
        elif is_empty(a):
            added.append(key)
        elif a != b:
            changed.append(key)
    return lost, added, changed


def print_diff(backup_data, live_data):
    lost, added, changed = diff_fields(backup_data, live_data)
    print("\n  A mentésben kitöltött, élesben üres mező (merge visszahozza): %d" % len(lost))
    for k in lost:
        print("    - %-45s %6d kar.  %s" % (k, size_of(backup_data[k]), preview(backup_data[k])))
    print("\n  Élesben azóta kitöltött mező (merge megtartja, replace törli): %d" % len(added))
    for k in added:
        print("    + %-45s %6d kar.  %s" % (k, size_of(live_data[k]), preview(live_data[k])))
    print("\n  Mindkettőben kitöltött, de eltérő mező (merge az élest tartja meg): %d" % len(changed))
    for k in changed:
        print("    ~ %-45s mentés %6d kar. / éles %6d kar." % (k, size_of(backup_data[k]), size_of(live_data[k])))
        print("        mentés: %s" % preview(backup_data[k]))
        print("        éles:   %s" % preview(live_data[k]))


def pick_form(tables_forms, form_id):
    for f in tables_forms:
        if f["id"] == form_id:
            return f
    return None


def cmd_diff(args):
    name, made_at, tables = load_backup(args.backup)
    with db_connect() as conn:
        schools, forms = live_tables(conn)
    b_hits = match_schools(tables.get("schools", []), args.school)
    l_hits = match_schools(schools, args.school)
    b_forms = forms_for(b_hits, tables.get("forms", []), args.school)
    l_forms = forms_for(l_hits, forms, args.school)
    print("MENTÉS: %s (készült: %s)" % (name, made_at))
    print_matches(b_hits, b_forms)
    print("\nÉLES")
    print_matches(l_hits, l_forms)

    form_ids = [args.form_id] if args.form_id else sorted({f["id"] for f, _ in b_forms})
    for form_id in form_ids:
        b = pick_form(tables.get("forms", []), form_id)
        l = pick_form(forms, form_id)
        print("\n=== ŰRLAP %s" % form_id)
        print("  mentés: %s" % (summarize(b["data"]) if b else "nincs a mentésben"))
        print("  éles:   %s" % (summarize(l["data"]) if l else "NINCS MEG ÉLESBEN (törölve)"))
        if b:
            print_diff(b["data"], l["data"] if l else {})


def cmd_restore(args):
    if args.mode not in ("merge", "replace"):
        sys.exit("--mode merge vagy replace kell.")
    name, made_at, tables = load_backup(args.backup)
    b = pick_form(tables.get("forms", []), args.form_id)
    if not b:
        sys.exit("A(z) %s űrlap nincs benne a(z) %s mentésben." % (args.form_id, name))
    backup_data = b["data"] if isinstance(b["data"], dict) else {}

    conn = db_connect()
    try:
        with conn.cursor() as c:
            c.execute("SELECT data, created_at, updated_at, submitted, pdf_file_path, school_id "
                      "FROM forms WHERE id = %s FOR UPDATE", (args.form_id,))
            row = c.fetchone()
            live_data = (row[0] if row and isinstance(row[0], dict) else {})

            if args.mode == "replace":
                new_data = dict(backup_data)
            else:
                new_data = dict(live_data)
                for key, value in backup_data.items():
                    if is_empty(new_data.get(key)) and not is_empty(value):
                        new_data[key] = value

            print("Mentés:     %s (készült: %s)" % (name, made_at))
            print("Űrlap:      %s" % args.form_id)
            print("Most élesben: %s" % (summarize(live_data) if row else "NINCS (újra létrehozzuk)"))
            print("A mentésben:  %s" % summarize(backup_data))
            print("Visszaállítás után (%s): %s" % (args.mode, summarize(new_data)))
            if row:
                print_diff(backup_data, live_data)

            school_id = (row[5] if row else None) or b.get("school_id")
            if not args.yes:
                print("\nSZÁRAZ FUTÁS - semmi nem változott. Élesítés: ugyanez --yes kapcsolóval.")
                conn.rollback()
                return

            # Az éles sor mentése még a módosítás előtt. Az app naiv UTC időt tárol.
            now = datetime.now(timezone.utc).replace(tzinfo=None)
            stamp = now.strftime("%Y%m%d-%H%M%S-%f")
            safety = "restore-safety-%s-%s.json" % (args.form_id, stamp)
            # "x": egy korábbi biztonsági mentést soha nem írunk felül.
            with open(safety, "x", encoding="utf-8") as fh:
                json.dump({
                    "form_id": args.form_id,
                    "saved_at_utc": stamp,
                    "existed": bool(row),
                    "data": live_data,
                    "created_at": row[1].isoformat() if row and row[1] else None,
                    "updated_at": row[2].isoformat() if row and row[2] else None,
                    "submitted": row[3] if row else None,
                    "pdf_file_path": row[4] if row else None,
                    "school_id": row[5] if row else None,
                }, fh, ensure_ascii=False, indent=1)
            print("\nAz éles állapot elmentve: %s" % safety)

            payload = json.dumps(new_data, ensure_ascii=False)
            if row:
                c.execute("UPDATE forms SET data = %s::jsonb, updated_at = %s WHERE id = %s",
                          (payload, now, args.form_id))
            else:
                c.execute("INSERT INTO forms (id, data, created_at, updated_at, submitted, pdf_file_path, school_id) "
                          "VALUES (%s, %s::jsonb, %s, %s, %s, %s, %s)",
                          (args.form_id, payload, b.get("created_at") or now, now,
                           b.get("submitted") or 0, b.get("pdf_file_path"), school_id))
            if args.relink:
                if not school_id:
                    sys.exit("--relink: az űrlaphoz nem tartozik iskola, nincs mihez kötni.")
                c.execute("UPDATE schools SET form_id = %s, updated_at = %s WHERE id = %s",
                          (args.form_id, now, school_id))
                print("Az iskola (%s) újra ehhez az űrlaphoz van kötve." % school_id)
        conn.commit()
        print("KÉSZ: az űrlap visszaállítva.")
    except BaseException:
        conn.rollback()
        raise
    finally:
        conn.close()


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("find", help="az iskola és űrlapjai élesben")
    s.add_argument("--school", required=True)
    s.set_defaults(func=cmd_find)

    s = sub.add_parser("scan", help="az iskola űrlapja az FTP-n lévő mentésekben, naponta")
    s.add_argument("--school", required=True)
    s.add_argument("--days", type=int, default=7, help="az utolsó hány mentést nézze (0 = mindet)")
    s.set_defaults(func=cmd_scan)

    s = sub.add_parser("diff", help="mező szintű összevetés: mentés vs. éles")
    s.add_argument("--school", required=True)
    s.add_argument("--backup", required=True)
    s.add_argument("--form-id")
    s.set_defaults(func=cmd_diff)

    s = sub.add_parser("restore", help="egy űrlap visszaállítása (--yes nélkül csak száraz futás)")
    s.add_argument("--form-id", required=True)
    s.add_argument("--backup", required=True)
    s.add_argument("--mode", required=True, choices=("merge", "replace"))
    s.add_argument("--relink", action="store_true", help="az iskola űrlapja újra ez legyen (schools.form_id)")
    s.add_argument("--yes", action="store_true")
    s.set_defaults(func=cmd_restore)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()

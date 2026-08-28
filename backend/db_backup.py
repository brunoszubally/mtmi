"""Napi adatbázis-mentés FTP-re.

Miért így: a Supabase szerver PostgreSQL 17, a legtöbb gépen és CI futtatón
viszont régebbi a pg_dump, ami ilyenkor megtagadja a mentést. Ezért a dumpot
magunk állítjuk elő SQL INSERT-ekből - ez verziófüggetlen, és sima psql-lel
visszatölthető.

A mentés saját, közvetlen adatbázis-kapcsolatot nyit, nem a kérésekhez használt
poolt: a SimpleConnectionPool nem szálbiztos, a mentés pedig háttérszálon fut.
"""

import ftplib
import gzip
import io
import os
import threading
import time
import traceback
from datetime import datetime, timezone

import psycopg2

# A mentendő táblák - a visszatöltés is ebben a sorrendben történik.
BACKUP_TABLES = ("app_settings", "schools", "forms")

BACKUP_ENABLED = (os.environ.get("BACKUP_ENABLED", "1").strip().lower()
                  not in ("0", "false", "no"))
# Hány óra (UTC) után készüljön el az aznapi mentés. Alapból éjjel 1 UTC = 3 óra
# nyáron Budapesten, amikor senki nem tölt űrlapot.
BACKUP_HOUR_UTC = int(os.environ.get("BACKUP_HOUR_UTC", "1"))
BACKUP_KEEP_DAYS = int(os.environ.get("BACKUP_KEEP_DAYS", "30"))
BACKUP_FTP_DIR = os.environ.get("BACKUP_FTP_DIR", "backups")
# Az FTP alapból titkosítatlan, ahogy a PDF-feltöltés is. BACKUP_FTP_TLS=1
# esetén FTPS-sel próbálkozunk - ha a szerver tudja, elég ennyit átállítani.
BACKUP_FTP_TLS = os.environ.get("BACKUP_FTP_TLS", "0").strip().lower() in ("1", "true", "yes")
BACKUP_CHECK_INTERVAL_SECONDS = int(os.environ.get("BACKUP_CHECK_INTERVAL_SECONDS", "600"))
# Sikertelen mentés után ennyi ideig nem próbálkozunk újra.
BACKUP_RETRY_AFTER_SECONDS = 1800

BACKUP_FILE_PREFIX = "mtmi-backup-"
BACKUP_FILE_SUFFIX = ".sql.gz"


def _log(msg):
    print("[BACKUP] %s" % msg, flush=True)


# --- A dump előállítása ---------------------------------------------------

def _quote_ident(name: str) -> str:
    return '"%s"' % str(name).replace('"', '""')


def _columns(cur, table):
    cur.execute("""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
        ORDER BY ordinal_position
    """, (table,))
    return cur.fetchall()


def _primary_key(cur, table):
    cur.execute("""
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = %s::regclass AND i.indisprimary
    """, (table,))
    return [r[0] for r in cur.fetchall()]


def _create_table_sql(cur, table, columns):
    parts = []
    for name, data_type, is_nullable, default in columns:
        piece = "  %s %s" % (_quote_ident(name), data_type)
        if default is not None:
            piece += " DEFAULT %s" % default
        if is_nullable == "NO":
            piece += " NOT NULL"
        parts.append(piece)
    pk = _primary_key(cur, table)
    if pk:
        parts.append("  PRIMARY KEY (%s)" % ", ".join(_quote_ident(c) for c in pk))
    return "CREATE TABLE IF NOT EXISTS %s (\n%s\n);" % (_quote_ident(table), ",\n".join(parts))


def build_dump_sql(conn) -> str:
    """Teljes, visszatölthető SQL dump szövegként."""
    out = io.StringIO()
    now = datetime.now(timezone.utc)
    out.write("-- MTMI Iskola Program - adatbázis mentés\n")
    out.write("-- Készült: %s UTC\n" % now.strftime("%Y-%m-%d %H:%M:%S"))
    out.write("--\n-- Visszatöltés (FIGYELEM: felülírja a meglévő tartalmat):\n")
    out.write("--   gunzip -c %s... | psql \"$DATABASE_URL\"\n--\n\n" % BACKUP_FILE_PREFIX)
    out.write("BEGIN;\n\n")

    counts = {}
    for table in BACKUP_TABLES:
        with conn.cursor() as cur:
            columns = _columns(cur, table)
            if not columns:
                _log("a(z) %s tábla nem létezik, kihagyva" % table)
                continue

            names = [c[0] for c in columns]
            types = {c[0]: c[1] for c in columns}
            # A json/jsonb mezőt szövegként olvassuk ki, és beszúráskor
            # kasztoljuk vissza - így nem kell típusadaptert regisztrálni.
            select_list = ", ".join(
                ("%s::text" % _quote_ident(n)) if types[n] in ("json", "jsonb") else _quote_ident(n)
                for n in names
            )
            placeholders = ", ".join(
                "%s::jsonb" if types[n] == "jsonb" else ("%s::json" if types[n] == "json" else "%s")
                for n in names
            )
            insert_prefix = "INSERT INTO %s (%s) VALUES (" % (
                _quote_ident(table), ", ".join(_quote_ident(n) for n in names)
            )

            cur.execute("SELECT %s FROM %s" % (select_list, _quote_ident(table)))
            rows = cur.fetchall()
            counts[table] = len(rows)

            out.write("-- ------------------------------------------------------------\n")
            out.write("-- %s (%d sor)\n" % (table, len(rows)))
            out.write("-- ------------------------------------------------------------\n")
            out.write(_create_table_sql(cur, table, columns) + "\n")
            out.write("DELETE FROM %s;\n" % _quote_ident(table))
            for row in rows:
                values = cur.mogrify(placeholders, row).decode("utf-8")
                out.write(insert_prefix + values + ");\n")
            out.write("\n")

    out.write("COMMIT;\n")
    out.write("-- sorok: %s\n" % ", ".join("%s=%d" % (t, n) for t, n in counts.items()))
    return out.getvalue()


# --- FTP ------------------------------------------------------------------

def _ftp_connect(host, user, password):
    if BACKUP_FTP_TLS:
        ftp = ftplib.FTP_TLS(host, timeout=60)
        ftp.login(user, password)
        ftp.prot_p()
        return ftp
    ftp = ftplib.FTP(host, timeout=60)
    ftp.login(user, password)
    return ftp


def _enter_backup_dir(ftp):
    """A mentések külön mappába mennek, hogy ne keveredjenek a PDF-ekkel."""
    try:
        ftp.cwd(BACKUP_FTP_DIR)
    except ftplib.error_perm:
        ftp.mkd(BACKUP_FTP_DIR)
        ftp.cwd(BACKUP_FTP_DIR)


def _prune_old_backups(ftp, keep_days):
    """A megadott számú legfrissebb mentést tartjuk meg, a többit töröljük."""
    try:
        names = sorted(n for n in ftp.nlst()
                       if n.startswith(BACKUP_FILE_PREFIX) and n.endswith(BACKUP_FILE_SUFFIX))
    except Exception as e:
        _log("a régi mentések listázása nem sikerült: %s" % e)
        return 0
    deleted = 0
    for name in names[:-keep_days] if keep_days > 0 else []:
        try:
            ftp.delete(name)
            deleted += 1
        except Exception as e:
            _log("a(z) %s törlése nem sikerült: %s" % (name, e))
    return deleted


def upload_backup(payload: bytes, filename: str, host, user, password) -> None:
    with _ftp_connect(host, user, password) as ftp:
        _enter_backup_dir(ftp)
        ftp.storbinary("STOR %s" % filename, io.BytesIO(payload))
        deleted = _prune_old_backups(ftp, BACKUP_KEEP_DAYS)
        if deleted:
            _log("%d régi mentés törölve" % deleted)


# --- Naplózás az adatbázisban --------------------------------------------

def ensure_backup_table(conn):
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS db_backups (
                day date PRIMARY KEY,
                created_at timestamp,
                filename text,
                size_bytes integer,
                ok integer DEFAULT 0,
                error text
            )
        """)
    conn.commit()


def _record_result(conn, day, filename, size_bytes, ok, error):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO db_backups (day, created_at, filename, size_bytes, ok, error)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (day) DO UPDATE SET
                created_at = EXCLUDED.created_at,
                filename = EXCLUDED.filename,
                size_bytes = EXCLUDED.size_bytes,
                ok = EXCLUDED.ok,
                error = EXCLUDED.error
        """, (day, datetime.utcnow(), filename, size_bytes, 1 if ok else 0, error))
    conn.commit()


def _todays_state(conn, day):
    """(kesz_e, utolso_probalkozas) az adott napra."""
    with conn.cursor() as cur:
        cur.execute("SELECT ok, created_at FROM db_backups WHERE day = %s", (day,))
        row = cur.fetchone()
    if not row:
        return False, None
    return row[0] == 1, row[1]


# --- A mentés futtatása ---------------------------------------------------

def run_backup(database_url, ftp_host, ftp_user, ftp_pass):
    """Egy mentés végigfuttatása. Visszaadja a naplóbejegyzés adatait."""
    day = datetime.now(timezone.utc).date()
    filename = "%s%s%s" % (BACKUP_FILE_PREFIX, day.strftime("%Y%m%d"), BACKUP_FILE_SUFFIX)
    conn = psycopg2.connect(database_url, connect_timeout=20)
    try:
        ensure_backup_table(conn)
        try:
            started = time.time()
            sql = build_dump_sql(conn)
            payload = gzip.compress(sql.encode("utf-8"), compresslevel=6)
            upload_backup(payload, filename, ftp_host, ftp_user, ftp_pass)
            _record_result(conn, day, filename, len(payload), True, None)
            _log("kész: %s (%d KB, %.1f s)" % (filename, len(payload) // 1024, time.time() - started))
            return {"ok": True, "filename": filename, "size_bytes": len(payload)}
        except Exception as e:
            error = "%s: %s" % (type(e).__name__, e)
            _log("HIBA: %s\n%s" % (error, traceback.format_exc()))
            try:
                _record_result(conn, day, filename, 0, False, error[:2000])
            except Exception:
                pass
            return {"ok": False, "filename": filename, "error": error}
    finally:
        try:
            conn.close()
        except Exception:
            pass


def _should_run_now(database_url):
    now = datetime.now(timezone.utc)
    if now.hour < BACKUP_HOUR_UTC:
        return False
    conn = psycopg2.connect(database_url, connect_timeout=20)
    try:
        ensure_backup_table(conn)
        done, last_attempt = _todays_state(conn, now.date())
        if done:
            return False
        if last_attempt is not None:
            # Sikertelen próbálkozás után várunk, hogy ne verjük az FTP-t.
            age = (datetime.utcnow() - last_attempt).total_seconds()
            if age < BACKUP_RETRY_AFTER_SECONDS:
                return False
        return True
    finally:
        try:
            conn.close()
        except Exception:
            pass


def start_backup_scheduler(database_url, ftp_host, ftp_user, ftp_pass):
    """Háttérszál, ami naponta egyszer elkészíti és feltölti a mentést.

    Nem óránként ébred és futtat: azt nézi, van-e már mai sikeres mentés. Így a
    szerver újraindulása vagy alvása után is pótolja az elmaradt mentést, és
    soha nem készít egy napra kettőt.
    """
    if not BACKUP_ENABLED:
        _log("kikapcsolva (BACKUP_ENABLED=0)")
        return None
    if not database_url:
        _log("nincs DATABASE_URL, a napi mentés nem indul")
        return None

    def loop():
        # Induláskor adunk időt az appnak, hogy kiszolgálja az első kéréseket.
        time.sleep(60)
        while True:
            try:
                if _should_run_now(database_url):
                    run_backup(database_url, ftp_host, ftp_user, ftp_pass)
            except Exception as e:
                _log("az ütemező hibája: %s: %s" % (type(e).__name__, e))
            time.sleep(BACKUP_CHECK_INTERVAL_SECONDS)

    thread = threading.Thread(target=loop, name="db-backup", daemon=True)
    thread.start()
    _log("napi mentés ütemezve (%02d:00 UTC után, %d napot tartunk meg)"
         % (BACKUP_HOUR_UTC, BACKUP_KEEP_DAYS))
    return thread

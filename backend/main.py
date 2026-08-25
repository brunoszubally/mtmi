from fastapi import FastAPI, HTTPException, Request, Form, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import HTMLResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
import os
import json
import base64
import hmac
import hashlib
import time
from email.utils import formatdate
from dotenv import load_dotenv
load_dotenv()

import psycopg2
from psycopg2.extras import Json
from psycopg2.pool import SimpleConnectionPool
import shutil
from reportlab.lib.pagesizes import letter, A4
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from io import BytesIO
import ftplib
import bcrypt
from xml.sax.saxutils import escape
import tempfile
import subprocess
from contextlib import contextmanager

# --- Adatbázis inicializálás ---
DATABASE_URL = os.environ.get("DATABASE_URL", "")
BUDAPEST_TZ = ZoneInfo("Europe/Budapest")
DB_POOL_MAX_CONN = int(os.environ.get("DB_POOL_MAX_CONN", "8"))
# FIGYELEM: a SimpleConnectionPool elengedéskor csak akkor tartja meg a
# kapcsolatot, ha a poolban minconn-nál kevesebb van (psycopg2/pool.py,
# _putconn), a többit lezárja. minconn=1 mellett tehát gyakorlatilag nem volt
# pooling: párhuzamos kérésnél szinte minden kérés új TCP+TLS kapcsolatot
# nyitott. Ezért a minconn alapból a maxconn-nal egyezik.
# Kevesebb induló kapcsolat kell? DB_POOL_MIN_CONN=1 visszaállítja a régit.
DB_POOL_MIN_CONN = int(os.environ.get("DB_POOL_MIN_CONN", str(DB_POOL_MAX_CONN)))
# Ennyi másodpercnél régebben elengedett kapcsolatot ellenőrzünk csak SELECT 1-gyel.
# A frissen visszaadott kapcsolatot nem valószínű, hogy közben eldobta a pooler,
# így a gyakori kéréseknél megspóroljuk a plusz oda-vissza utat.
DB_CONN_VALIDATE_AFTER_SECONDS = float(os.environ.get("DB_CONN_VALIDATE_AFTER_SECONDS", "30"))
DB_POOL: Optional[SimpleConnectionPool] = None
AUTH_SECRET = (os.environ.get("AUTH_SECRET") or DATABASE_URL or "mtmi-dev-auth-secret").encode("utf-8")
SCHOOL_TOKEN_TTL_SECONDS = int(os.environ.get("SCHOOL_TOKEN_TTL_SECONDS", str(60 * 60 * 24 * 14)))
ADMIN_TOKEN_TTL_SECONDS = int(os.environ.get("ADMIN_TOKEN_TTL_SECONDS", str(60 * 60 * 12)))

# --- FTP konfiguráció ---
FTP_HOST = "move-on.hu"
FTP_USER = "fileupload@mtmi-iskola.hu"
FTP_PASS = "Vilaguralom1472"
FTP_PATH = "/fileupload/"

# PDF feltöltések mappája (lokális cache)
UPLOAD_DIR = "uploads"
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR)

def upload_to_ftp(local_file_path: str, remote_filename: str) -> bool:
    """Fájl feltöltése FTP szerverre"""
    try:
        with ftplib.FTP(FTP_HOST) as ftp:
            ftp.login(FTP_USER, FTP_PASS)
            # Nem kell könyvtár váltás, mert már a /fileupload könyvtárban vagyunk
            
            with open(local_file_path, 'rb') as file:
                ftp.storbinary(f'STOR {remote_filename}', file)
            
            return True
    except Exception as e:
        print(f"FTP feltöltés hiba: {e}")
        return False

def delete_from_ftp(filename: str) -> bool:
    """Fájl törlése FTP szerverről"""
    try:
        with ftplib.FTP(FTP_HOST) as ftp:
            ftp.login(FTP_USER, FTP_PASS)
            # Nem kell könyvtár váltás, mert már a /fileupload könyvtárban vagyunk
            ftp.delete(filename)
            return True
    except Exception as e:
        print(f"FTP törlés hiba: {e}")
        return False


# TCP keepalive, hogy a pooler/tűzfal ne dobja csendben az inaktív kapcsolatokat
DB_CONNECT_KWARGS = {
    "connect_timeout": 10,
    "keepalives": 1,
    "keepalives_idle": 30,
    "keepalives_interval": 10,
    "keepalives_count": 3,
}


def init_db_pool():
    global DB_POOL
    try:
        DB_POOL = SimpleConnectionPool(
            minconn=max(1, DB_POOL_MIN_CONN),
            maxconn=max(DB_POOL_MIN_CONN, DB_POOL_MAX_CONN),
            dsn=DATABASE_URL,
            **DB_CONNECT_KWARGS
        )
        print(f"DB pool initialized (min={DB_POOL_MIN_CONN}, max={DB_POOL_MAX_CONN})")
    except Exception as e:
        DB_POOL = None
        print(f"DB pool init failed, falling back to direct connections: {e}")


# Kapcsolatonként (id szerint) az utolsó poolba visszaadás időpontja.
# A psycopg2 connection nem enged saját attribútumot, ezért külön tábla.
_CONN_LAST_RELEASED = {}


def _mark_connection_released(conn):
    if conn is not None:
        _CONN_LAST_RELEASED[id(conn)] = time.monotonic()


def _forget_connection(conn):
    if conn is not None:
        _CONN_LAST_RELEASED.pop(id(conn), None)


def _needs_liveness_check(conn) -> bool:
    """Csak a régóta álló kapcsolatot érdemes SELECT 1-gyel ellenőrizni."""
    last_released = _CONN_LAST_RELEASED.get(id(conn))
    if last_released is None:
        return True
    return (time.monotonic() - last_released) >= DB_CONN_VALIDATE_AFTER_SECONDS


def _connection_is_alive(conn) -> bool:
    """A poolban álló kapcsolatot a szerver észrevétlenül lezárhatta - ellenőrizzük."""
    if conn is None or conn.closed:
        return False
    try:
        with conn.cursor() as c:
            c.execute("SELECT 1")
        conn.rollback()
        return True
    except Exception:
        return False


def _acquire_connection():
    """Élő kapcsolatot ad vissza: (conn, poolbol_jott)."""
    if DB_POOL is None:
        return psycopg2.connect(DATABASE_URL, **DB_CONNECT_KWARGS), False

    for _ in range(max(1, DB_POOL_MAX_CONN)):
        conn = DB_POOL.getconn()
        if conn is not None and not conn.closed and not _needs_liveness_check(conn):
            return conn, True
        if _connection_is_alive(conn):
            return conn, True
        # Halott kapcsolat: eldobjuk, hogy a pool újat nyithasson helyette
        print("DB pool: halott kapcsolat eldobva, új kapcsolat nyitása")
        _forget_connection(conn)
        try:
            DB_POOL.putconn(conn, close=True)
        except Exception as e:
            print(f"DB pool putconn(close=True) hiba: {e}")

    # A pool nem tudott élő kapcsolatot adni - közvetlen kapcsolat végső esetként
    print("DB pool: nem sikerült élő kapcsolatot szerezni, közvetlen kapcsolat")
    return psycopg2.connect(DATABASE_URL, **DB_CONNECT_KWARGS), False


@contextmanager
def db_connection():
    conn = None
    from_pool = False
    broken = False
    try:
        conn, from_pool = _acquire_connection()
        yield conn
        conn.commit()
    except Exception as e:
        # Csak a tényleg sérült kapcsolatot dobjuk el (HTTPException miatt ne)
        broken = isinstance(e, (psycopg2.InterfaceError, psycopg2.OperationalError))
        if isinstance(e, psycopg2.Error):
            print(f"DB hiba: {type(e).__name__}: {e}")
        if conn is not None:
            try:
                conn.rollback()
            except Exception:
                # Ha a rollback is elhasal, a kapcsolat halott - ne fedje el az eredeti hibát
                broken = True
        raise
    finally:
        if conn is not None:
            if from_pool and DB_POOL is not None:
                discard = broken or bool(conn.closed)
                if discard:
                    _forget_connection(conn)
                else:
                    _mark_connection_released(conn)
                try:
                    DB_POOL.putconn(conn, close=discard)
                except Exception as e:
                    print(f"DB pool putconn hiba: {e}")
            else:
                _forget_connection(conn)
                try:
                    conn.close()
                except Exception:
                    pass

def init_db():
    with db_connection() as conn:
        with conn.cursor() as c:
            # Create forms table if not exists
            c.execute('''
                CREATE TABLE IF NOT EXISTS forms (
                    id TEXT PRIMARY KEY,
                    data JSONB NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    submitted INTEGER DEFAULT 0,
                    pdf_file_path TEXT,
                    school_id TEXT
                )
            ''')
            
            # Create schools table if not exists
            c.execute('''
                CREATE TABLE IF NOT EXISTS schools (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    email TEXT UNIQUE,
                    password_hash TEXT,
                    form_id TEXT,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL
                )
            ''')

            # Indexek a gyakori lekérdezésekhez (idempotens)
            c.execute("CREATE INDEX IF NOT EXISTS idx_forms_created_at ON forms (created_at DESC)")
            c.execute("CREATE INDEX IF NOT EXISTS idx_forms_school_id ON forms (school_id)")
            c.execute("CREATE INDEX IF NOT EXISTS idx_schools_form_id ON schools (form_id)")
            c.execute("CREATE INDEX IF NOT EXISTS idx_schools_lower_email ON schools (LOWER(email))")

            # App szintű pályázati időzítés és állapot
            c.execute('''
                CREATE TABLE IF NOT EXISTS app_settings (
                    id INTEGER PRIMARY KEY,
                    submission_mode TEXT NOT NULL DEFAULT 'forced_inactive',
                    submission_start_at TIMESTAMPTZ,
                    submission_end_at TIMESTAMPTZ,
                    updated_at TIMESTAMP NOT NULL
                )
            ''')
            c.execute('''
                INSERT INTO app_settings (id, submission_mode, submission_start_at, submission_end_at, updated_at)
                VALUES (1, 'forced_inactive', NULL, NULL, %s)
                ON CONFLICT (id) DO NOTHING
            ''', (datetime.utcnow(),))
            c.execute("""
                UPDATE app_settings
                SET submission_mode = 'forced_inactive', updated_at = %s
                WHERE id = 1 AND (submission_mode IS NULL OR submission_mode = 'auto')
            """, (datetime.utcnow(),))
            
            conn.commit()

init_db()
init_db_pool()

# --- FastAPI app ---
app = FastAPI()

# Tömörítés a hostingtól függetlenül. A statikus fájlokat a Railway edge már
# gzipeli, az API JSON-válaszait viszont így biztosan tömörítve küldjük:
# /admin/schools 62 KB -> 9 KB, /admin/result/{id} 65 KB -> 20 KB.
# Az 1 KB alatti válaszokon nem éri meg, azokat kihagyjuk.
app.add_middleware(GZipMiddleware, minimum_size=1024)

# CORS beállítás (frontend fejlesztéshez)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://mtmi-frontend.onrender.com",
        "https://palyazat.mtmi-iskola.hu",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health():
    """Gyors ellenőrzés: fut-e az app, és él-e az adatbázis-kapcsolat."""
    try:
        with db_connection() as conn:
            with conn.cursor() as c:
                c.execute("SELECT 1")
        return {"status": "ok", "db": "ok", "pool": DB_POOL is not None}
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={"status": "error", "db": f"{type(e).__name__}: {str(e)[:200]}"}
        )

# --- Pydantic modellek ---
class SaveRequest(BaseModel):
    data: dict
    session_id: Optional[str] = None

class SaveResponse(BaseModel):
    session_id: str
    url: str
    updated_at: Optional[str] = None

class LoadResponse(BaseModel):
    data: dict
    session_id: str
    submitted: int  # vagy bool
    pdf_file_path: Optional[str] = None
    school_id: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


def _b64url_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _b64url_decode(raw: str) -> bytes:
    padding = "=" * (-len(raw) % 4)
    return base64.urlsafe_b64decode(raw + padding)


def _sign_token_payload(payload: dict) -> str:
    body = _b64url_encode(json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8"))
    signature = hmac.new(AUTH_SECRET, body.encode("utf-8"), hashlib.sha256).digest()
    return f"{body}.{_b64url_encode(signature)}"


def issue_auth_token(role: str, ttl_seconds: int, **claims) -> str:
    payload = {
        "role": role,
        "exp": int(datetime.now(timezone.utc).timestamp()) + ttl_seconds,
        **claims
    }
    return _sign_token_payload(payload)


def verify_auth_token(token: str) -> Optional[dict]:
    try:
        body, sig = token.split(".", 1)
        expected_sig = _b64url_encode(hmac.new(AUTH_SECRET, body.encode("utf-8"), hashlib.sha256).digest())
        if not hmac.compare_digest(sig, expected_sig):
            return None
        payload = json.loads(_b64url_decode(body).decode("utf-8"))
        if int(payload.get("exp", 0)) < int(datetime.now(timezone.utc).timestamp()):
            return None
        return payload
    except Exception:
        return None


def get_auth_payload(request: Request, allowed_roles: Optional[List[str]] = None) -> dict:
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Hiányzó vagy érvénytelen hitelesítés.")
    payload = verify_auth_token(auth_header.split(" ", 1)[1].strip())
    if not payload:
        raise HTTPException(status_code=401, detail="Lejárt vagy érvénytelen hitelesítés.")
    if allowed_roles and payload.get("role") not in allowed_roles:
        raise HTTPException(status_code=403, detail="Nincs jogosultság ehhez a művelethez.")
    return payload


def require_admin_auth(request: Request) -> dict:
    return get_auth_payload(request, ["admin"])


def require_school_auth(request: Request, expected_school_id: Optional[str] = None) -> dict:
    payload = get_auth_payload(request, ["school"])
    if expected_school_id and payload.get("school_id") != expected_school_id:
        raise HTTPException(status_code=403, detail="Nincs jogosultság ehhez az iskolához.")
    return payload


def resolve_form_owner_school_id(session_id: str) -> Optional[str]:
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("""
                SELECT f.school_id, s.id
                FROM forms f
                LEFT JOIN schools s ON s.form_id = f.id
                WHERE f.id = %s
            """, (session_id,))
            row = c.fetchone()
    if not row:
        return None
    return row[0] or row[1]


def require_form_access(request: Request, session_id: str, allow_admin: bool = True) -> dict:
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Hiányzó vagy érvénytelen hitelesítés.")
    payload = verify_auth_token(auth_header.split(" ", 1)[1].strip())
    if not payload:
        raise HTTPException(status_code=401, detail="Lejárt vagy érvénytelen hitelesítés.")

    role = payload.get("role")
    if role == "admin":
        if allow_admin:
            return payload
        raise HTTPException(status_code=403, detail="Admin hozzáférés ezen a végponton nem engedélyezett.")

    if role != "school":
        raise HTTPException(status_code=403, detail="Nincs jogosultság ehhez a művelethez.")

    owner_school_id = resolve_form_owner_school_id(session_id)
    school_id = payload.get("school_id")
    if not owner_school_id:
        raise HTTPException(status_code=403, detail="Ez az űrlap nincs iskolai fiókhoz rendelve.")
    if owner_school_id and owner_school_id != school_id:
        raise HTTPException(status_code=403, detail="Ez az űrlap nem ehhez az iskolához tartozik.")
    return payload


def _to_utc_iso(dt):
    if not dt:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat()


def _format_bp(dt):
    """Időpont magyar idő szerinti, olvasható formában (pl. 2026. 08. 24. 08:00)."""
    if not dt:
        return ""
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(BUDAPEST_TZ).strftime("%Y. %m. %d. %H:%M")


def get_submission_settings():
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("""
                SELECT submission_mode, submission_start_at, submission_end_at
                FROM app_settings
                WHERE id = 1
            """)
            row = c.fetchone()
    if not row:
        return {
            "mode": "forced_inactive",
            "start_at": None,
            "end_at": None
        }
    return {
        "mode": row[0] or "forced_inactive",
        "start_at": row[1],
        "end_at": row[2]
    }


def compute_submission_status():
    cfg = get_submission_settings()
    now_utc = datetime.now(timezone.utc)
    now_budapest = now_utc.astimezone(BUDAPEST_TZ)

    mode = cfg["mode"] or "forced_inactive"
    start_at = cfg["start_at"]
    end_at = cfg["end_at"]

    status = "open"
    message = "A pályázati felület elérhető."
    countdown_days_left = None

    if mode == "forced_inactive":
        status = "inactive"
        message = "Jelenleg nincs aktív pályázati időszak."
    elif mode == "forced_review":
        status = "review"
        message = "A pályázati felület jelenleg nem elérhető, bírálat zajlik."
    elif mode != "forced_open":
        status = "inactive"
        message = "Jelenleg nincs aktív pályázati időszak."
    elif start_at and now_utc < start_at:
        # Nyitott módban a megadott kezdés előtt még nem érhető el a felület
        status = "inactive"
        message = f"A pályázati felület {_format_bp(start_at)} időponttól lesz elérhető."
    elif end_at and now_utc >= end_at:
        # Nyitott módban a megadott lezárás után zárva van a felület
        status = "inactive"
        message = f"A pályázati időszak {_format_bp(end_at)} időpontban lezárult."
    elif end_at:
        seconds_left = (end_at - now_utc).total_seconds()
        if seconds_left > 0:
            days_left = int((seconds_left + 86399) // 86400)
            if 0 < days_left <= 10:
                status = "countdown"
                countdown_days_left = days_left
                message = f"Még {days_left} napja van a beadásra."

    is_available = status in ("open", "countdown")
    return {
        "status": status,
        "is_available": is_available,
        "message": message,
        "countdown_days_left": countdown_days_left,
        "mode": mode,
        "start_at": _to_utc_iso(start_at),
        "end_at": _to_utc_iso(end_at),
        "now_at": now_budapest.isoformat(),
        "timezone": "Europe/Budapest"
    }


def ensure_submission_available():
    status = compute_submission_status()
    if not status["is_available"]:
        raise HTTPException(status_code=423, detail=status["message"])


def _format_value_for_pdf(value):
    if value is None:
        return ""
    if isinstance(value, list):
        return ", ".join(str(v) for v in value if str(v).strip())
    if isinstance(value, bool):
        return "Igen" if value else "Nem"
    return str(value)


def _humanize_key(key: str) -> str:
    return key.replace("_", " ").strip().capitalize()


def _build_submission_pdf_buffer(session_id: str, data: dict, created_at=None, updated_at=None, school_name: Optional[str] = None):
    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=32,
        rightMargin=32,
        topMargin=32,
        bottomMargin=32
    )
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "PdfTitle",
        parent=styles["Heading1"],
        fontSize=18,
        leading=22,
        spaceAfter=14,
        alignment=1
    )
    section_style = ParagraphStyle(
        "PdfSection",
        parent=styles["Heading2"],
        fontSize=12,
        leading=15,
        spaceBefore=8,
        spaceAfter=6
    )
    key_style = ParagraphStyle(
        "PdfKey",
        parent=styles["Normal"],
        fontSize=9,
        leading=12
    )
    value_style = ParagraphStyle(
        "PdfValue",
        parent=styles["Normal"],
        fontSize=9,
        leading=12
    )

    story = []
    story.append(Paragraph("MTMI Iskola Program - Pályázati összefoglaló", title_style))
    meta_rows = [
        ["Session azonosító", session_id],
        ["Generálva", datetime.now(BUDAPEST_TZ).strftime("%Y-%m-%d %H:%M:%S (Europe/Budapest)")],
    ]
    if school_name:
        meta_rows.append(["Iskola", school_name])
    if created_at:
        meta_rows.append(["Létrehozva", created_at.strftime("%Y-%m-%d %H:%M:%S")])
    if updated_at:
        meta_rows.append(["Utolsó mentés", updated_at.strftime("%Y-%m-%d %H:%M:%S")])

    meta_table = Table(meta_rows, colWidths=[160, 350])
    meta_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F7FAFC")),
        ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#CBD5E0")),
        ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
        ("FONTNAME", (1, 0), (1, -1), "Helvetica"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 14))

    section_groups = [
        ("Alapadatok", [
            "palyazo_iskola_neve", "iskola_cime", "telepulesforma", "iskolatipus",
            "iskola_tanuloi_letszama", "intezmenytipus_tanuloi_letszama",
            "programban_erintett_tanulok_szama", "iskola_mtmi_tanari_letszama"
        ]),
        ("Kapcsolattartók", [
            "mtmi_felelos_kapcsolattarto_neve", "mtmi_felelos_kapcsolattarto_beosztas",
            "mtmi_felelos_kapcsolattarto_telefonszam1", "mtmi_felelos_kapcsolattarto_telefonszam2",
            "mtmi_felelos_kapcsolattarto_email1", "mtmi_felelos_kapcsolattarto_email2",
            "intezmenyvezeto_kapcsolattarto_neve", "intezmenyvezeto_kapcsolattarto_beosztas",
            "intezmenyvezeto_kapcsolattarto_telefonszam1", "intezmenyvezeto_kapcsolattarto_telefonszam2",
            "intezmenyvezeto_kapcsolattarto_email1", "intezmenyvezeto_kapcsolattarto_email2"
        ]),
    ]

    rendered_keys = set()
    for title, keys in section_groups:
        rows = []
        for key in keys:
            if key not in data:
                continue
            value = _format_value_for_pdf(data.get(key))
            if not value:
                continue
            rendered_keys.add(key)
            rows.append([
                Paragraph(escape(_humanize_key(key)), key_style),
                Paragraph(escape(value).replace("\n", "<br/>"), value_style)
            ])
        if not rows:
            continue
        section = [Paragraph(title, section_style)]
        tbl = Table(rows, colWidths=[190, 320], repeatRows=0)
        tbl.setStyle(TableStyle([
            ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#E2E8F0")),
            ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#EDF2F7")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("LEFTPADDING", (0, 0), (-1, -1), 6),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))
        section.append(tbl)
        section.append(Spacer(1, 10))
        story.append(KeepTogether(section))

    misc_rows = []
    for key in sorted(data.keys()):
        if key in rendered_keys:
            continue
        value = _format_value_for_pdf(data.get(key))
        if not value:
            continue
        misc_rows.append([
            Paragraph(escape(_humanize_key(key)), key_style),
            Paragraph(escape(value).replace("\n", "<br/>"), value_style)
        ])

    if misc_rows:
        story.append(Paragraph("Egyéb mezők", section_style))
        misc_table = Table(misc_rows, colWidths=[190, 320], repeatRows=0)
        misc_table.setStyle(TableStyle([
            ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#E2E8F0")),
            ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#F7FAFC")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("LEFTPADDING", (0, 0), (-1, -1), 6),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))
        story.append(misc_table)

    doc.build(story)
    buffer.seek(0)
    return buffer


def _find_chrome_executable() -> Optional[str]:
    candidates = [
        os.environ.get("CHROME_BIN"),
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        "/usr/bin/google-chrome",
        "/usr/bin/google-chrome-stable",
        "/usr/bin/chromium",
        "/usr/bin/chromium-browser",
    ]
    for path in candidates:
        if path and os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return None


def _render_exact_pdf_via_chrome(url: str) -> Optional[bytes]:
    chrome_bin = _find_chrome_executable()
    if not chrome_bin:
        return None

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
        tmp_path = tmp.name

    cmd = [
        chrome_bin,
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        "--run-all-compositor-stages-before-draw",
        "--virtual-time-budget=15000",
        f"--print-to-pdf={tmp_path}",
        url
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=45)
        if proc.returncode != 0 or not os.path.exists(tmp_path):
            return None
        with open(tmp_path, "rb") as fh:
            return fh.read()
    except Exception:
        return None
    finally:
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass

# --- API végpontok ---
@app.post("/api/save", response_model=SaveResponse)
def save_form(req: SaveRequest, request: Request):
    ensure_submission_available()
    now = datetime.utcnow()
    session_id = req.session_id or str(uuid4())
    school_auth = require_school_auth(request)
    school_id = school_auth.get("school_id")
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("SELECT id, school_id FROM forms WHERE id = %s", (session_id,))
            existing_row = c.fetchone()
            if existing_row:
                existing_school_id = existing_row[1]
                if existing_school_id and existing_school_id != school_id:
                    raise HTTPException(status_code=403, detail="Ez az űrlap nem ehhez az iskolához tartozik.")
                c.execute(
                    "UPDATE forms SET data = %s, updated_at = %s, school_id = COALESCE(school_id, %s) WHERE id = %s",
                    (Json(req.data), now, school_id, session_id)
                )
            else:
                c.execute(
                    "INSERT INTO forms (id, data, created_at, updated_at, submitted, school_id) VALUES (%s, %s, %s, %s, 0, %s)",
                    (session_id, Json(req.data), now, now, school_id)
                )
            c.execute(
                "UPDATE schools SET form_id = %s, updated_at = %s WHERE id = %s",
                (session_id, now, school_id)
            )
            conn.commit()
    url = str(request.base_url) + f"kitoltes/{session_id}"
    return SaveResponse(session_id=session_id, url=url, updated_at=now.isoformat())

@app.get("/api/load/{session_id}", response_model=LoadResponse)
def load_form(session_id: str, request: Request):
    require_form_access(request, session_id, allow_admin=True)
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("SELECT data, submitted, pdf_file_path, school_id, created_at, updated_at FROM forms WHERE id = %s", (session_id,))
            row = c.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Nincs ilyen űrlap!")
    data = row[0]
    submitted = row[1] if row[1] is not None else 0
    pdf_file_path = row[2] if row[2] is not None else None
    school_id = row[3] if row[3] is not None else None
    created_at = row[4] if row[4] is not None else None
    updated_at = row[5] if row[5] is not None else None
    return LoadResponse(
        data=data,
        session_id=session_id,
        submitted=submitted,
        pdf_file_path=pdf_file_path,
        school_id=school_id,
        created_at=created_at.isoformat() if created_at else None,
        updated_at=updated_at.isoformat() if updated_at else None,
    )

# PDF feltöltés végpont
@app.post("/api/upload-pdf/{session_id}")
async def upload_pdf(session_id: str, request: Request, file: UploadFile = File(...)):
    require_form_access(request, session_id, allow_admin=False)
    # Ellenőrizzük, hogy a fájl PDF-e
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Csak PDF fájlok tölthetők fel!")
    
    # Ellenőrizzük a fájl méretét (max 10MB)
    if file.size and file.size > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="A fájl mérete nem lehet nagyobb 10MB-nál!")
    
    # Fájl mentése - tisztított fájlnév
    import re
    import urllib.parse
    
    # Tisztítjuk a fájlnevet: csak alfanumerikus karakterek, pont, kötőjel és aláhúzás
    clean_filename = re.sub(r'[^a-zA-Z0-9._-]', '_', file.filename)
    # URL decode, ha szükséges
    try:
        clean_filename = urllib.parse.unquote(clean_filename)
    except:
        pass
    # Tisztítás után is
    clean_filename = re.sub(r'[^a-zA-Z0-9._-]', '_', clean_filename)
    
    filename = f"{session_id}_{clean_filename}"
    local_file_path = os.path.join(UPLOAD_DIR, filename)
    
    try:
        # Lokális fájl mentése (cache)
        with open(local_file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # FTP feltöltés
        if upload_to_ftp(local_file_path, filename):
            # Sikeres FTP feltöltés után lokális fájl törlése
            os.remove(local_file_path)
            
            # Adatbázis frissítése
            with db_connection() as conn:
                with conn.cursor() as c:
                    c.execute("UPDATE forms SET pdf_file_path = %s, updated_at = %s WHERE id = %s", 
                             (filename, datetime.utcnow(), session_id))
                    conn.commit()
            
            return {"filename": filename, "url": f"https://mtmi-iskola.hu/fileupload/{filename}"}
        else:
            # FTP hiba esetén lokális fájl törlése és hiba
            if os.path.exists(local_file_path):
                os.remove(local_file_path)
            raise HTTPException(status_code=500, detail="Hiba az FTP feltöltés során!")
            
    except Exception as e:
        # Hiba esetén lokális fájl törlése
        if os.path.exists(local_file_path):
            os.remove(local_file_path)
        raise HTTPException(status_code=500, detail=f"Hiba a fájl mentése során: {str(e)}")

# PDF törlés végpont
@app.delete("/api/delete-pdf/{session_id}")
def delete_pdf(session_id: str, request: Request):
    require_form_access(request, session_id, allow_admin=False)
    with db_connection() as conn:
        with conn.cursor() as c:
            # Lekérjük a jelenlegi PDF fájl nevét
            c.execute("SELECT pdf_file_path FROM forms WHERE id = %s", (session_id,))
            row = c.fetchone()
            if row and row[0]:
                filename = row[0]
                
                # FTP törlés
                delete_from_ftp(filename)
                
                # Adatbázis frissítése
                c.execute("UPDATE forms SET pdf_file_path = NULL, updated_at = %s WHERE id = %s", 
                         (datetime.utcnow(), session_id))
                conn.commit()
    
    return {"status": "deleted"}



@app.post("/api/submit/{session_id}")
def submit_form(session_id: str, request: Request):
    ensure_submission_available()
    require_form_access(request, session_id, allow_admin=False)
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("UPDATE forms SET submitted = 1, updated_at = %s WHERE id = %s", (datetime.utcnow(), session_id))
            conn.commit()
    return {"status": "ok"} 


@app.post("/api/reopen/{session_id}")
def reopen_form(session_id: str, request: Request):
    ensure_submission_available()
    require_form_access(request, session_id, allow_admin=False)
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("UPDATE forms SET submitted = 0, updated_at = %s WHERE id = %s", (datetime.utcnow(), session_id))
            conn.commit()
    return {"status": "reopened"}

# Környezeti változóból (vesszővel elválasztva), hogy ne a kódban álljon a jelszó.
ADMIN_PASSWORDS = [
    p.strip() for p in (os.environ.get("ADMIN_PASSWORDS") or "admin,Suli2025!").split(",") if p.strip()
]

@app.post("/api/admin/login")
def admin_login(data: dict):
    password = data.get("password")
    if isinstance(password, str) and any(hmac.compare_digest(password, valid) for valid in ADMIN_PASSWORDS):
        return {"success": True, "access_token": issue_auth_token("admin", ADMIN_TOKEN_TTL_SECONDS)}
    return {"success": False}

@app.get("/api/admin/list")
def admin_list(request: Request):
    require_admin_auth(request)
    try:
        with db_connection() as conn:
            with conn.cursor() as c:
                # Csak az iskolanevet kérjük le a JSONB-ből, nem a teljes űrlap-adatot
                c.execute("""
                    SELECT id,
                           COALESCE(data->>'palyazo_iskola_neve', '(nincs megadva)'),
                           created_at, updated_at, submitted, pdf_file_path
                    FROM forms
                    ORDER BY created_at DESC
                """)
                rows = c.fetchall()
        result = []
        for row in rows:
            id, iskola_nev, created_at, updated_at, submitted, pdf_file_path = row
            result.append({
                "id": id,
                "iskola_nev": iskola_nev,
                "created_at": created_at.isoformat() if created_at else None,
                "updated_at": updated_at.isoformat() if updated_at else None,
                "submitted": submitted,
                "has_pdf": pdf_file_path is not None
            })
        return result
    except Exception as e:
        print(f"Database error in admin_list: {e}")
        raise HTTPException(status_code=500, detail="Nem sikerült betölteni a kitöltéseket.")

@app.get("/api/admin/result/{session_id}")
def admin_result(session_id: str, request: Request):
    require_admin_auth(request)
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("SELECT data, pdf_file_path FROM forms WHERE id = %s", (session_id,))
            row = c.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Nincs ilyen űrlap!")
    data = row[0]
    pdf_file_path = row[1]
    return {"data": data, "pdf_file_path": pdf_file_path} 

@app.delete("/api/admin/delete/{session_id}")
def admin_delete(session_id: str, request: Request):
    require_admin_auth(request)
    with db_connection() as conn:
        with conn.cursor() as c:
            # PDF fájl törlése is
            c.execute("SELECT pdf_file_path FROM forms WHERE id = %s", (session_id,))
            row = c.fetchone()
            if row and row[0]:
                filename = row[0]
                # FTP törlés
                delete_from_ftp(filename)
            
            c.execute("DELETE FROM forms WHERE id = %s", (session_id,))
            conn.commit()
    return {"status": "deleted"}


@app.post("/api/admin/forms/bulk")
def admin_bulk_forms(payload: dict, request: Request):
    require_admin_auth(request)
    action = (payload.get("action") or "").strip()
    session_ids = payload.get("session_ids") or []

    if action not in ("mark_submitted", "mark_in_progress", "delete"):
        raise HTTPException(status_code=400, detail="Érvénytelen bulk action.")
    if not isinstance(session_ids, list) or not session_ids:
        raise HTTPException(status_code=400, detail="Legalább 1 session_id kötelező.")

    session_ids = [str(sid).strip() for sid in session_ids if str(sid).strip()]
    if not session_ids:
        raise HTTPException(status_code=400, detail="Nincs érvényes session_id.")

    with db_connection() as conn:
        with conn.cursor() as c:
            if action == "mark_submitted":
                c.execute(
                    "UPDATE forms SET submitted = 1, updated_at = %s WHERE id = ANY(%s)",
                    (datetime.utcnow(), session_ids)
                )
                affected = c.rowcount
            elif action == "mark_in_progress":
                c.execute(
                    "UPDATE forms SET submitted = 0, updated_at = %s WHERE id = ANY(%s)",
                    (datetime.utcnow(), session_ids)
                )
                affected = c.rowcount
            else:
                c.execute("SELECT id, pdf_file_path FROM forms WHERE id = ANY(%s)", (session_ids,))
                rows = c.fetchall()
                for _, pdf_file_path in rows:
                    if pdf_file_path:
                        delete_from_ftp(pdf_file_path)
                c.execute("DELETE FROM forms WHERE id = ANY(%s)", (session_ids,))
                affected = c.rowcount
            conn.commit()

    return {"status": "ok", "action": action, "affected": affected}

# --- Iskolai login ---
@app.post("/api/school/login")
def school_login(data: dict):
    email = data.get("email", "").strip().lower()
    password = data.get("password", "")
    if not email or not password:
        raise HTTPException(status_code=400, detail="Felhasználónév és jelszó megadása kötelező!")
    
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("SELECT id, name, password_hash, form_id FROM schools WHERE LOWER(email) = %s", (email,))
            row = c.fetchone()
    
    if not row:
        raise HTTPException(status_code=401, detail="Hibás felhasználónév vagy jelszó!")
    
    school_id, school_name, password_hash, form_id = row
    
    if not password_hash:
        raise HTTPException(status_code=401, detail="Ehhez az iskolához még nincs jelszó beállítva. Kérd az adminisztrátort!")
    
    if not bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8')):
        raise HTTPException(status_code=401, detail="Hibás felhasználónév vagy jelszó!")
    
    # Get form status if form exists
    form_status = None
    form_updated_at = None
    form_created_at = None
    form_submitted = None
    if form_id:
        with db_connection() as conn:
            with conn.cursor() as c:
                c.execute("SELECT submitted, created_at, updated_at FROM forms WHERE id = %s", (form_id,))
                form_row = c.fetchone()
                if form_row:
                    form_submitted = form_row[0]
                    form_created_at = form_row[1]
                    form_updated_at = form_row[2]
                    form_status = "submitted" if form_row[0] == 1 else "in_progress"
    
    return {
        "school_id": school_id,
        "school_name": school_name,
        "access_token": issue_auth_token("school", SCHOOL_TOKEN_TTL_SECONDS, school_id=school_id),
        "form_id": form_id,
        "form_status": form_status,  # None, "in_progress", or "submitted"
        "form_submitted": form_submitted,
        "form_created_at": form_created_at.isoformat() if form_created_at else None,
        "form_updated_at": form_updated_at.isoformat() if form_updated_at else None,
    }


@app.get("/api/school/dashboard/{school_id}")
def school_dashboard(school_id: str, request: Request):
    require_school_auth(request, school_id)
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("SELECT id, name, email, form_id FROM schools WHERE id = %s", (school_id,))
            school_row = c.fetchone()
            if not school_row:
                raise HTTPException(status_code=404, detail="Iskola nem található!")

            form_id = school_row[3]
            form_row = None
            if form_id:
                c.execute("SELECT submitted, created_at, updated_at, data FROM forms WHERE id = %s", (form_id,))
                form_row = c.fetchone()

    response = {
        "school_id": school_row[0],
        "school_name": school_row[1],
        "school_email": school_row[2],
        "form_id": form_id,
        "form_status": None,
        "submitted": None,
        "created_at": None,
        "updated_at": None,
        "filled_fields_count": 0,
    }

    if form_row:
        submitted = 1 if form_row[0] == 1 else 0
        form_data = form_row[3] if isinstance(form_row[3], dict) else {}
        response.update({
            "form_status": "submitted" if submitted else "in_progress",
            "submitted": submitted,
            "created_at": form_row[1].isoformat() if form_row[1] else None,
            "updated_at": form_row[2].isoformat() if form_row[2] else None,
            "filled_fields_count": len([k for k, v in form_data.items() if _format_value_for_pdf(v)]),
        })

    return response


@app.get("/api/public/submission-status")
def public_submission_status():
    return compute_submission_status()

# --- Admin: Iskolák kezelése ---
@app.get("/api/admin/schools")
def admin_list_schools(request: Request):
    require_admin_auth(request)
    with db_connection() as conn:
        with conn.cursor() as c:
            # A teljes f.data helyett csak az első kitöltött kapcsolattartói e-mailt
            # kérjük le - így nem húzzuk át iskolánként a teljes űrlap-JSON-t.
            c.execute("""
                SELECT s.id, s.name, s.email, s.password_hash IS NOT NULL as has_password,
                       s.form_id, f.submitted, s.created_at, s.updated_at,
                       f.created_at, f.updated_at,
                       COALESCE(
                           NULLIF(f.data->>'mtmi_felelos_kapcsolattarto_email1', ''),
                           NULLIF(f.data->>'mtmi_felelos_kapcsolattarto_email2', ''),
                           NULLIF(f.data->>'intezmenyvezeto_kapcsolattarto_email1', ''),
                           NULLIF(f.data->>'intezmenyvezeto_kapcsolattarto_email2', '')
                       ) AS form_email
                FROM schools s
                LEFT JOIN forms f ON s.form_id = f.id
                ORDER BY s.name ASC
            """)
            rows = c.fetchall()
    result = []
    for row in rows:
        form_email = row[10]
        effective_email = row[2] or form_email
        result.append({
            "id": row[0],
            "name": row[1],
            "email": row[2],
            "effective_email": effective_email,
            "email_source": "school" if row[2] else ("form" if form_email else None),
            "has_password": row[3],
            "form_id": row[4],
            "submitted": row[5],
            "created_at": row[6].isoformat() if row[6] else None,
            "updated_at": row[7].isoformat() if row[7] else None,
            "form_created_at": row[8].isoformat() if row[8] else None,
            "form_updated_at": row[9].isoformat() if row[9] else None
        })
    return result


@app.get("/api/admin/submission-window")
def admin_get_submission_window(request: Request):
    require_admin_auth(request)
    return compute_submission_status()


def _parse_admin_datetime(value):
    if value in (None, ""):
        return None
    try:
        dt = datetime.fromisoformat(value)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=BUDAPEST_TZ)
        return dt.astimezone(timezone.utc)
    except Exception:
        raise HTTPException(status_code=400, detail="Érvénytelen dátum formátum!")


@app.put("/api/admin/submission-window")
def admin_update_submission_window(payload: dict, request: Request):
    require_admin_auth(request)
    mode = (payload.get("mode") or "forced_inactive").strip()
    if mode not in ("forced_open", "forced_inactive", "forced_review"):
        raise HTTPException(status_code=400, detail="Érvénytelen mód! (forced_open/forced_inactive/forced_review)")

    start_at = _parse_admin_datetime(payload.get("start_at"))
    end_at = _parse_admin_datetime(payload.get("end_at"))
    if start_at and end_at and start_at >= end_at:
        raise HTTPException(status_code=400, detail="A kezdő időpontnak korábbinak kell lennie, mint a záró időpontnak.")

    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("""
                UPDATE app_settings
                SET submission_mode = %s,
                    submission_start_at = %s,
                    submission_end_at = %s,
                    updated_at = %s
                WHERE id = 1
            """, (mode, start_at, end_at, datetime.utcnow()))
            conn.commit()

    return compute_submission_status()

@app.post("/api/admin/schools")
def admin_create_school(data: dict, request: Request):
    require_admin_auth(request)
    name = data.get("name", "").strip()
    email = data.get("email", "").strip().lower() if data.get("email") else None
    password = data.get("password", "")
    
    if not name:
        raise HTTPException(status_code=400, detail="Az iskola neve kötelező!")
    
    school_id = str(uuid4())
    now = datetime.utcnow()
    password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8') if password else None
    
    with db_connection() as conn:
        with conn.cursor() as c:
            # Check for duplicate email
            if email:
                c.execute("SELECT id FROM schools WHERE LOWER(email) = %s", (email,))
                if c.fetchone():
                    raise HTTPException(status_code=400, detail="Ez a felhasználónév már használatban van!")
            
            c.execute(
                "INSERT INTO schools (id, name, email, password_hash, form_id, created_at, updated_at) VALUES (%s, %s, %s, %s, NULL, %s, %s)",
                (school_id, name, email, password_hash, now, now)
            )
            conn.commit()
    
    return {"id": school_id, "name": name, "email": email}

@app.put("/api/admin/schools/{school_id}")
def admin_update_school(school_id: str, data: dict, request: Request):
    require_admin_auth(request)
    name = data.get("name", "").strip()
    email = data.get("email", "").strip().lower() if data.get("email") else None
    password = data.get("password", "")
    
    now = datetime.utcnow()
    
    with db_connection() as conn:
        with conn.cursor() as c:
            # Check school exists
            c.execute("SELECT id FROM schools WHERE id = %s", (school_id,))
            if not c.fetchone():
                raise HTTPException(status_code=404, detail="Iskola nem található!")
            
            # Check for duplicate email (excluding this school)
            if email:
                c.execute("SELECT id FROM schools WHERE LOWER(email) = %s AND id != %s", (email, school_id))
                if c.fetchone():
                    raise HTTPException(status_code=400, detail="Ez a felhasználónév már használatban van!")
            
            # Build update query
            if password:
                password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
                c.execute(
                    "UPDATE schools SET name = %s, email = %s, password_hash = %s, updated_at = %s WHERE id = %s",
                    (name, email, password_hash, now, school_id)
                )
            else:
                # Don't update password if not provided
                c.execute(
                    "UPDATE schools SET name = %s, email = %s, updated_at = %s WHERE id = %s",
                    (name, email, now, school_id)
                )
            conn.commit()
    
    return {"status": "updated"}

@app.delete("/api/admin/schools/{school_id}")
def admin_delete_school(school_id: str, request: Request):
    require_admin_auth(request)
    with db_connection() as conn:
        with conn.cursor() as c:
            # Unlink form if any
            c.execute("UPDATE forms SET school_id = NULL WHERE school_id = %s", (school_id,))
            c.execute("DELETE FROM schools WHERE id = %s", (school_id,))
            conn.commit()
    return {"status": "deleted"}

# --- Iskolai save: form_id hozzárendelése az iskolához ---
@app.post("/api/school/link-form")
def school_link_form(data: dict, request: Request):
    school_id = data.get("school_id")
    form_id = data.get("form_id")
    if not school_id or not form_id:
        raise HTTPException(status_code=400, detail="school_id és form_id megadása kötelező!")
    require_school_auth(request, school_id)
    require_form_access(request, form_id, allow_admin=False)

    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("UPDATE schools SET form_id = %s, updated_at = %s WHERE id = %s", (form_id, datetime.utcnow(), school_id))
            c.execute("UPDATE forms SET school_id = %s WHERE id = %s", (school_id, form_id))
            conn.commit()
    return {"status": "linked"}

@app.post("/api/admin/generate-pdf")
def generate_pdf(payload: dict, request: Request):
    require_admin_auth(request)
    session_id = payload.get("session_id")
    data = payload.get("data", {})
    buffer = _build_submission_pdf_buffer(session_id=session_id, data=data or {})
    
    return Response(
        content=buffer.getvalue(),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=MTMI_kitoltes_{session_id}.pdf"}
    )


@app.get("/api/export/pdf/{session_id}")
def export_submission_pdf(session_id: str, request: Request):
    require_form_access(request, session_id, allow_admin=True)
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("""
                SELECT f.data, f.created_at, f.updated_at, s.name
                FROM forms f
                LEFT JOIN schools s ON s.id = f.school_id
                WHERE f.id = %s
            """, (session_id,))
            row = c.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Nincs ilyen űrlap.")

    data, created_at, updated_at, school_name = row
    exact_view_url = f"{str(request.base_url).rstrip('/')}/kitoltes/{session_id}?adminview=1&pdfview=1"
    exact_pdf = _render_exact_pdf_via_chrome(exact_view_url)
    if exact_pdf:
        return Response(
            content=exact_pdf,
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename=MTMI_kitoltes_{session_id}.pdf"}
        )

    buffer = _build_submission_pdf_buffer(
        session_id=session_id,
        data=data if isinstance(data, dict) else {},
        created_at=created_at,
        updated_at=updated_at,
        school_name=school_name
    )
    return Response(
        content=buffer.getvalue(),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=MTMI_kitoltes_{session_id}.pdf"}
    )

from fastapi.responses import FileResponse

FRONTEND_DIR = os.path.realpath(os.path.join(os.path.dirname(__file__), "..", "frontend"))


def _resolve_frontend_file(relative_path: str) -> Optional[str]:
    """A frontend mappán belüli fájl feloldása.

    Bármilyen kiszökési kísérlet (../, %2e%2e%2f, symlink) None-t ad vissza,
    így nem lehet a frontend mappán kívüli fájlt (pl. backend/.env) letölteni.
    """
    if not relative_path:
        return None
    candidate = os.path.realpath(os.path.join(FRONTEND_DIR, relative_path))
    if candidate != FRONTEND_DIR and not candidate.startswith(FRONTEND_DIR + os.sep):
        return None
    return candidate if os.path.isfile(candidate) else None


def _static_etag(stat_result) -> str:
    """Ugyanaz az ETag, amit a Starlette FileResponse is számol."""
    etag_base = f"{stat_result.st_mtime}-{stat_result.st_size}"
    return f'"{hashlib.md5(etag_base.encode()).hexdigest()}"'


def _if_none_match_matches(header_value: str, etag: str) -> bool:
    """If-None-Match egyeztetés gyenge összehasonlítással (RFC 9110)."""
    if not header_value:
        return False
    if header_value.strip() == "*":
        return True
    for candidate in header_value.split(","):
        candidate = candidate.strip()
        if candidate.startswith("W/"):
            candidate = candidate[2:]
        if candidate == etag:
            return True
    return False


def _static_response(request: Request, path: str, headers=None):
    """Statikus fájl kiszolgálása feltételes kérés (304) kezelésével.

    A FileResponse kirakja az ETag-et és a Last-Modified-ot, de - a
    StaticFiles-szal ellentétben - nem nézi az If-None-Match-et, ezért
    magától sosem ad 304-et. A "no-cache, must-revalidate" mellett így minden
    oldalbetöltés újratöltötte a teljes fájlt ahelyett, hogy revalidált volna.
    """
    try:
        stat_result = os.stat(path)
    except OSError:
        return FileResponse(path, headers=headers)

    etag = _static_etag(stat_result)
    if _if_none_match_matches(request.headers.get("if-none-match"), etag):
        not_modified_headers = dict(headers or {})
        not_modified_headers["ETag"] = etag
        not_modified_headers["Last-Modified"] = formatdate(stat_result.st_mtime, usegmt=True)
        return Response(status_code=304, headers=not_modified_headers)

    return FileResponse(path, stat_result=stat_result, headers=headers)


# Kiszolgálni a kért fájlt, ha létezik, különben index.html (SPA routing)
@app.get("/{full_path:path}")
async def serve_static_or_spa(request: Request, full_path: str):
    def html_headers():
        # no-store helyett no-cache: a böngésző eltárolhatja, de mindig
        # revalidál (304), így a deploy azonnal látszik, de nem tölt újra mindent.
        return {"Cache-Control": "no-cache, must-revalidate"}

    index_html = os.path.join(FRONTEND_DIR, "index.html")

    # 1. Ha üres az útvonal, az index.html-t adjuk
    if not full_path or full_path == "/":
        return _static_response(request, index_html, html_headers())

    file_path = _resolve_frontend_file(full_path)

    # 2. Ha az admin alá próbál navigálni:
    if full_path.startswith("admin"):
        if file_path:
            if file_path.lower().endswith((".js", ".css", ".html")):
                return _static_response(request, file_path, html_headers())
            return _static_response(request, file_path)
        # SPA routing az admin részre
        return _static_response(request, os.path.join(FRONTEND_DIR, "admin", "index.html"), html_headers())

    # 3. Keresés a frontend gyökerében lévő fájlokként (pl. style.css)
    if file_path:
        if file_path.lower().endswith((".js", ".css", ".html")):
            return _static_response(request, file_path, html_headers())
        return _static_response(request, file_path)

    # 4. Fallback: index.html (SPA routing a public részre)
    return _static_response(request, index_html, html_headers())

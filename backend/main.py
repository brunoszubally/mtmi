from fastapi import FastAPI, HTTPException, Request, Form, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
import os
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
DB_POOL_MIN_CONN = int(os.environ.get("DB_POOL_MIN_CONN", "1"))
DB_POOL_MAX_CONN = int(os.environ.get("DB_POOL_MAX_CONN", "8"))
DB_POOL: Optional[SimpleConnectionPool] = None

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


def init_db_pool():
    global DB_POOL
    try:
        DB_POOL = SimpleConnectionPool(
            minconn=max(1, DB_POOL_MIN_CONN),
            maxconn=max(DB_POOL_MIN_CONN, DB_POOL_MAX_CONN),
            dsn=DATABASE_URL
        )
        print(f"DB pool initialized (min={DB_POOL_MIN_CONN}, max={DB_POOL_MAX_CONN})")
    except Exception as e:
        DB_POOL = None
        print(f"DB pool init failed, falling back to direct connections: {e}")


@contextmanager
def db_connection():
    conn = None
    try:
        if DB_POOL is not None:
            conn = DB_POOL.getconn()
        else:
            conn = psycopg2.connect(DATABASE_URL)
        yield conn
        conn.commit()
    except Exception:
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            if DB_POOL is not None:
                DB_POOL.putconn(conn)
            else:
                conn.close()

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


def _to_utc_iso(dt):
    if not dt:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat()


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
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("SELECT id FROM forms WHERE id = %s", (session_id,))
            if c.fetchone():
                c.execute(
                    "UPDATE forms SET data = %s, updated_at = %s WHERE id = %s",
                    (Json(req.data), now, session_id)
                )
            else:
                c.execute(
                    "INSERT INTO forms (id, data, created_at, updated_at, submitted) VALUES (%s, %s, %s, %s, 0)",
                    (session_id, Json(req.data), now, now)
                )
            conn.commit()
    url = str(request.base_url) + f"kitoltes/{session_id}"
    return SaveResponse(session_id=session_id, url=url, updated_at=now.isoformat())

@app.get("/api/load/{session_id}", response_model=LoadResponse)
def load_form(session_id: str):
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
async def upload_pdf(session_id: str, file: UploadFile = File(...)):
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
def delete_pdf(session_id: str):
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
def submit_form(session_id: str):
    ensure_submission_available()
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("UPDATE forms SET submitted = 1, updated_at = %s WHERE id = %s", (datetime.utcnow(), session_id))
            conn.commit()
    return {"status": "ok"} 


@app.post("/api/reopen/{session_id}")
def reopen_form(session_id: str):
    ensure_submission_available()
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("UPDATE forms SET submitted = 0, updated_at = %s WHERE id = %s", (datetime.utcnow(), session_id))
            conn.commit()
    return {"status": "reopened"}

ADMIN_PASSWORDS = ["admin", "Suli2025!"]

@app.post("/api/admin/login")
def admin_login(data: dict):
    password = data.get("password")
    if password in ADMIN_PASSWORDS:
        return {"success": True}
    return {"success": False}

@app.get("/api/admin/list")
def admin_list():
    import json as _json
    try:
        with db_connection() as conn:
            with conn.cursor() as c:
                c.execute("SELECT id, data, created_at, submitted, pdf_file_path FROM forms ORDER BY created_at DESC")
                rows = c.fetchall()
        result = []
        for row in rows:
            id, data_json, created_at, submitted, pdf_file_path = row
            if isinstance(data_json, dict):
                data = data_json
            elif isinstance(data_json, str):
                try:
                    data = _json.loads(data_json)
                except Exception:
                    data = {}
            else:
                data = {}
            iskola_nev = data.get("palyazo_iskola_neve", "(nincs megadva)")
            result.append({
                "id": id,
                "iskola_nev": iskola_nev,
                "created_at": created_at,
                "submitted": submitted,
                "has_pdf": pdf_file_path is not None
            })
        return result
    except Exception as e:
        print(f"Database error in admin_list: {e}")
        raise HTTPException(status_code=500, detail="Nem sikerült betölteni a kitöltéseket.")

@app.get("/api/admin/result/{session_id}")
def admin_result(session_id: str):
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
def admin_delete(session_id: str):
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
def admin_bulk_forms(payload: dict):
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
        raise HTTPException(status_code=400, detail="Email és jelszó megadása kötelező!")
    
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("SELECT id, name, password_hash, form_id FROM schools WHERE LOWER(email) = %s", (email,))
            row = c.fetchone()
    
    if not row:
        raise HTTPException(status_code=401, detail="Hibás email vagy jelszó!")
    
    school_id, school_name, password_hash, form_id = row
    
    if not password_hash:
        raise HTTPException(status_code=401, detail="Ehhez az iskolához még nincs jelszó beállítva. Kérd az adminisztrátort!")
    
    if not bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8')):
        raise HTTPException(status_code=401, detail="Hibás email vagy jelszó!")
    
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
        "form_id": form_id,
        "form_status": form_status,  # None, "in_progress", or "submitted"
        "form_submitted": form_submitted,
        "form_created_at": form_created_at.isoformat() if form_created_at else None,
        "form_updated_at": form_updated_at.isoformat() if form_updated_at else None,
    }


@app.get("/api/school/dashboard/{school_id}")
def school_dashboard(school_id: str):
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
def admin_list_schools():
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("""
                SELECT s.id, s.name, s.email, s.password_hash IS NOT NULL as has_password, 
                       s.form_id, f.submitted, s.created_at, f.data
                FROM schools s
                LEFT JOIN forms f ON s.form_id = f.id
                ORDER BY s.name ASC
            """)
            rows = c.fetchall()
    result = []
    for row in rows:
        form_data = row[7] if len(row) > 7 and row[7] else {}
        form_email = None
        if isinstance(form_data, dict):
            form_email = (
                form_data.get("mtmi_felelos_kapcsolattarto_email1")
                or form_data.get("mtmi_felelos_kapcsolattarto_email2")
                or form_data.get("intezmenyvezeto_kapcsolattarto_email1")
                or form_data.get("intezmenyvezeto_kapcsolattarto_email2")
            )

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
            "created_at": row[6]
        })
    return result


@app.get("/api/admin/submission-window")
def admin_get_submission_window():
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
def admin_update_submission_window(payload: dict):
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
def admin_create_school(data: dict):
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
                    raise HTTPException(status_code=400, detail="Ez az email cím már használatban van!")
            
            c.execute(
                "INSERT INTO schools (id, name, email, password_hash, form_id, created_at, updated_at) VALUES (%s, %s, %s, %s, NULL, %s, %s)",
                (school_id, name, email, password_hash, now, now)
            )
            conn.commit()
    
    return {"id": school_id, "name": name, "email": email}

@app.put("/api/admin/schools/{school_id}")
def admin_update_school(school_id: str, data: dict):
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
                    raise HTTPException(status_code=400, detail="Ez az email cím már használatban van!")
            
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
def admin_delete_school(school_id: str):
    with db_connection() as conn:
        with conn.cursor() as c:
            # Unlink form if any
            c.execute("UPDATE forms SET school_id = NULL WHERE school_id = %s", (school_id,))
            c.execute("DELETE FROM schools WHERE id = %s", (school_id,))
            conn.commit()
    return {"status": "deleted"}

# --- Iskolai save: form_id hozzárendelése az iskolához ---
@app.post("/api/school/link-form")
def school_link_form(data: dict):
    school_id = data.get("school_id")
    form_id = data.get("form_id")
    if not school_id or not form_id:
        raise HTTPException(status_code=400, detail="school_id és form_id megadása kötelező!")
    
    with db_connection() as conn:
        with conn.cursor() as c:
            c.execute("UPDATE schools SET form_id = %s, updated_at = %s WHERE id = %s", (form_id, datetime.utcnow(), school_id))
            c.execute("UPDATE forms SET school_id = %s WHERE id = %s", (school_id, form_id))
            conn.commit()
    return {"status": "linked"}

@app.post("/api/admin/generate-pdf")
def generate_pdf(request: dict):
    session_id = request.get("session_id")
    data = request.get("data", {})
    buffer = _build_submission_pdf_buffer(session_id=session_id, data=data or {})
    
    return Response(
        content=buffer.getvalue(),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=MTMI_kitoltes_{session_id}.pdf"}
    )


@app.get("/api/export/pdf/{session_id}")
def export_submission_pdf(session_id: str, request: Request):
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

# Kiszolgálni a kért fájlt, ha létezik, különben index.html (SPA routing)
@app.get("/{full_path:path}")
async def serve_static_or_spa(full_path: str):
    frontend_dir = os.path.join(os.path.dirname(__file__), "..", "frontend")

    def no_cache_headers():
        return {"Cache-Control": "no-store, no-cache, must-revalidate, max-age=0"}
    
    # 1. Ha üres az útvonal, az index.html-t adjuk
    if not full_path or full_path == "/":
        return FileResponse(os.path.join(frontend_dir, "index.html"), headers=no_cache_headers())
        
    # 2. Ha az admin alá próbál navigálni:
    if full_path.startswith("admin"):
        # Ha fájlt kér az admin mappából:
        file_path = os.path.join(frontend_dir, full_path)
        if os.path.isfile(file_path):
            file_name = os.path.basename(file_path).lower()
            if file_name.endswith((".js", ".css", ".html")):
                return FileResponse(file_path, headers=no_cache_headers())
            return FileResponse(file_path)
        # SPA routing az admin részre
        return FileResponse(os.path.join(frontend_dir, "admin", "index.html"), headers=no_cache_headers())
        
    # 3. Keresés a frontend gyökerében lévő fájlokként (pl. style.css)
    file_path = os.path.join(frontend_dir, full_path)
    if os.path.isfile(file_path):
        file_name = os.path.basename(file_path).lower()
        if file_name.endswith((".js", ".css", ".html")):
            return FileResponse(file_path, headers=no_cache_headers())
        return FileResponse(file_path)
    
    # 4. Fallback: index.html (SPA routing a public részre)
    return FileResponse(os.path.join(frontend_dir, "index.html"), headers=no_cache_headers())

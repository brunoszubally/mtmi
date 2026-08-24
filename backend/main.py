from fastapi import FastAPI, HTTPException, Request, Form, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime, timezone, timedelta
import os
import psycopg2
from psycopg2.extras import Json
import shutil
import json
from reportlab.lib.pagesizes import letter, A4
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from io import BytesIO
import ftplib

# --- Adatbázis inicializálás ---
DATABASE_URL = os.environ.get("DATABASE_URL", "")

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

def init_db():
    with psycopg2.connect(DATABASE_URL) as conn:
        with conn.cursor() as c:
            # Create table if not exists
            c.execute('''
                CREATE TABLE IF NOT EXISTS forms (
                    id TEXT PRIMARY KEY,
                    data JSONB NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    submitted INTEGER DEFAULT 0
                )
            ''')

            c.execute('''
                CREATE TABLE IF NOT EXISTS schools (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    email TEXT,
                    password_hash TEXT,
                    form_id TEXT,
                    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
                    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
                )
            ''')
            
            c.execute('''
                CREATE TABLE IF NOT EXISTS app_settings (
                    key TEXT PRIMARY KEY,
                    value JSONB NOT NULL,
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
            ''')

            # Add pdf_file_path column if it doesn't exist
            try:
                c.execute('ALTER TABLE forms ADD COLUMN pdf_file_path TEXT')
                print("Added pdf_file_path column")
            except Exception as e:
                print(f"Column might already exist: {e}")
            
            conn.commit()

init_db()

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

# --- Pályázati időszak (a felület nyitása/zárása) ---
PERIOD_SETTING_KEY = "application_period"

try:
    from zoneinfo import ZoneInfo
    LOCAL_TZ = ZoneInfo("Europe/Budapest")
except Exception:  # ha nincs tzdata a konténerben, fix közép-európai eltolás
    LOCAL_TZ = timezone(timedelta(hours=1))


def parse_datetime_input(value):
    """ISO 8601 szöveget időzóna-tudatos datetime-má alakít. Üres érték -> None."""
    if value is None:
        return None
    if isinstance(value, datetime):
        dt = value
    else:
        text = str(value).strip()
        if not text:
            return None
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        try:
            dt = datetime.fromisoformat(text)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Érvénytelen dátumformátum: {value}")
    if dt.tzinfo is None:
        # Időzóna nélküli érték esetén magyar helyi időként értelmezzük
        dt = dt.replace(tzinfo=LOCAL_TZ)
    return dt


def format_local(dt: Optional[datetime]) -> Optional[str]:
    """Magyar olvasható formátum a visszajelzésekhez (pl. 2026. 08. 24. 08:00)."""
    if not dt:
        return None
    return dt.astimezone(LOCAL_TZ).strftime("%Y. %m. %d. %H:%M")


def read_period_setting():
    """A DB-ben tárolt időszak-beállítás kiolvasása (érték, mentés ideje)."""
    with psycopg2.connect(DATABASE_URL) as conn:
        with conn.cursor() as c:
            c.execute("SELECT value, updated_at FROM app_settings WHERE key = %s", (PERIOD_SETTING_KEY,))
            row = c.fetchone()
    if not row:
        return {}, None
    value = row[0]
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except Exception:
            value = {}
    if not isinstance(value, dict):
        value = {}
    return value, row[1]


def build_period_state(value: dict, updated_at):
    """A tárolt beállításból felépíti a teljes állapotot (nyitva/zárva + szövegek)."""
    start = parse_datetime_input(value.get("start"))
    end = parse_datetime_input(value.get("end"))
    now = datetime.now(timezone.utc)

    if start and now < start:
        status = "before"
    elif end and now > end:
        status = "after"
    else:
        status = "open"

    custom_message = (value.get("message") or "").strip() or None
    if status == "before":
        default_message = f"A pályázati felület {format_local(start)} időponttól lesz elérhető."
    elif status == "after":
        default_message = f"A pályázati időszak {format_local(end)} időpontban lezárult."
    else:
        default_message = None

    return {
        "start": start.astimezone(LOCAL_TZ).isoformat() if start else None,
        "end": end.astimezone(LOCAL_TZ).isoformat() if end else None,
        "start_label": format_local(start),
        "end_label": format_local(end),
        "configured": bool(start or end),
        "is_open": status == "open",
        "status": status,
        "message": custom_message or default_message,
        "custom_message": custom_message,
        "server_time": now.astimezone(LOCAL_TZ).isoformat(),
        "updated_at": updated_at.isoformat() if updated_at else None,
        "updated_by": value.get("updated_by") or None,
    }


def get_period_state():
    value, updated_at = read_period_setting()
    return build_period_state(value, updated_at)


def ensure_period_open():
    """403-mal elutasítja a beküldést/mentést, ha a felület éppen zárva van."""
    state = get_period_state()
    if not state["is_open"]:
        raise HTTPException(
            status_code=403,
            detail=state["message"] or "A pályázati felület jelenleg zárva van."
        )


# --- Pydantic modellek ---
class SaveRequest(BaseModel):
    data: dict
    session_id: Optional[str] = None

class SaveResponse(BaseModel):
    session_id: str
    url: str

class LoadResponse(BaseModel):
    data: dict
    session_id: str
    submitted: int  # vagy bool
    pdf_file_path: Optional[str] = None

# --- API végpontok ---
@app.post("/api/save", response_model=SaveResponse)
def save_form(req: SaveRequest, request: Request):
    ensure_period_open()
    now = datetime.utcnow()
    session_id = req.session_id or str(uuid4())
    with psycopg2.connect(DATABASE_URL) as conn:
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
    return SaveResponse(session_id=session_id, url=url)

@app.get("/api/load/{session_id}", response_model=LoadResponse)
def load_form(session_id: str):
    with psycopg2.connect(DATABASE_URL) as conn:
        with conn.cursor() as c:
            c.execute("SELECT data, submitted, pdf_file_path FROM forms WHERE id = %s", (session_id,))
            row = c.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Nincs ilyen űrlap!")
    data = row[0]
    submitted = row[1] if row[1] is not None else 0
    pdf_file_path = row[2] if row[2] is not None else None
    return LoadResponse(data=data, session_id=session_id, submitted=submitted, pdf_file_path=pdf_file_path)

# PDF feltöltés végpont
@app.post("/api/upload-pdf/{session_id}")
async def upload_pdf(session_id: str, file: UploadFile = File(...)):
    ensure_period_open()
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
            with psycopg2.connect(DATABASE_URL) as conn:
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
    ensure_period_open()
    with psycopg2.connect(DATABASE_URL) as conn:
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

# Egyszerű root végpont
@app.get("/")
def root():
    return {"msg": "MTMI űrlap backend fut!"} 

@app.post("/api/submit/{session_id}")
def submit_form(session_id: str):
    ensure_period_open()
    with psycopg2.connect(DATABASE_URL) as conn:
        with conn.cursor() as c:
            c.execute("UPDATE forms SET submitted = 1, updated_at = %s WHERE id = %s", (datetime.utcnow(), session_id))
            conn.commit()
    return {"status": "ok"} 

ADMIN_PASSWORDS = ["admin", "Suli2025!"]

@app.post("/api/admin/login")
def admin_login(data: dict):
    password = data.get("password")
    if password in ADMIN_PASSWORDS:
        return {"success": True}
    return {"success": False}

# --- Pályázati időszak végpontok ---

class PeriodUpdate(BaseModel):
    start: Optional[str] = None
    end: Optional[str] = None
    message: Optional[str] = None
    updated_by: Optional[str] = None


@app.get("/api/period")
def public_period():
    """Publikus végpont: nyitva van-e a felület, és meddig."""
    return get_period_state()


@app.get("/api/admin/period")
def admin_get_period():
    """Az admin felület mindig a ténylegesen elmentett beállítást kapja vissza."""
    return get_period_state()


@app.post("/api/admin/period")
def admin_set_period(req: PeriodUpdate):
    start = parse_datetime_input(req.start)
    end = parse_datetime_input(req.end)
    if start and end and end <= start:
        raise HTTPException(status_code=400, detail="A záró időpont nem lehet korábbi a kezdő időpontnál!")

    value = {
        "start": start.astimezone(LOCAL_TZ).isoformat() if start else None,
        "end": end.astimezone(LOCAL_TZ).isoformat() if end else None,
        "message": (req.message or "").strip() or None,
        "updated_by": (req.updated_by or "").strip() or None,
    }

    with psycopg2.connect(DATABASE_URL) as conn:
        with conn.cursor() as c:
            c.execute(
                """
                INSERT INTO app_settings (key, value, updated_at)
                VALUES (%s, %s, NOW())
                ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
                """,
                (PERIOD_SETTING_KEY, Json(value))
            )
            conn.commit()

    # Visszaolvasás az adatbázisból, hogy az admin tényleg a mentett állapotot lássa
    return get_period_state()


@app.delete("/api/admin/period")
def admin_clear_period():
    """Időkorlát törlése: a felület korlátlanul nyitva marad."""
    with psycopg2.connect(DATABASE_URL) as conn:
        with conn.cursor() as c:
            c.execute("DELETE FROM app_settings WHERE key = %s", (PERIOD_SETTING_KEY,))
            conn.commit()
    return get_period_state()


@app.get("/api/admin/list")
def admin_list():
    try:
        with psycopg2.connect(DATABASE_URL) as conn:
            with conn.cursor() as c:
                c.execute("""
                    SELECT id, data, created_at, updated_at, submitted, pdf_file_path
                    FROM forms
                    ORDER BY LOWER(COALESCE(data->>'palyazo_iskola_neve', '')), created_at DESC
                """)
                rows = c.fetchall()
        result = []
        for row in rows:
            id, data_json, created_at, updated_at, submitted, pdf_file_path = row
            data = {}
            if isinstance(data_json, dict):
                data = data_json
            elif isinstance(data_json, str):
                try:
                    parsed = json.loads(data_json)
                    if isinstance(parsed, dict):
                        data = parsed
                except Exception:
                    data = {}
            iskola_nev = data.get("palyazo_iskola_neve", "(nincs megadva)")
            result.append({
                "id": id,
                "iskola_nev": iskola_nev,
                "created_at": created_at,
                "updated_at": updated_at,
                "submitted": submitted,
                "has_pdf": pdf_file_path is not None
            })
        return result
    except Exception as e:
        print(f"Database error: {e}")
        return {"error": str(e), "database_url": DATABASE_URL}

@app.get("/api/admin/schools")
def admin_schools():
    try:
        with psycopg2.connect(DATABASE_URL) as conn:
            with conn.cursor() as c:
                c.execute("""
                    SELECT
                        s.id,
                        s.name,
                        s.email,
                        s.form_id,
                        s.created_at,
                        s.updated_at,
                        f.created_at AS form_created_at,
                        f.updated_at AS form_updated_at,
                        f.submitted
                    FROM schools s
                    LEFT JOIN forms f ON f.id = s.form_id
                    ORDER BY LOWER(s.name), s.created_at DESC
                """)
                rows = c.fetchall()

        result = []
        for row in rows:
            school_id, name, email, form_id, created_at, updated_at, form_created_at, form_updated_at, submitted = row
            result.append({
                "id": school_id,
                "name": name,
                "email": email,
                "form_id": form_id,
                "created_at": created_at,
                "updated_at": updated_at,
                "form_created_at": form_created_at,
                "form_updated_at": form_updated_at,
                "submitted": submitted if submitted is not None else 0
            })
        return result
    except Exception as e:
        print(f"Schools database error: {e}")
        return {"error": str(e), "database_url": DATABASE_URL}

@app.get("/api/admin/result/{session_id}")
def admin_result(session_id: str):
    with psycopg2.connect(DATABASE_URL) as conn:
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
    with psycopg2.connect(DATABASE_URL) as conn:
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

@app.post("/api/admin/generate-pdf")
def generate_pdf(request: dict):
    session_id = request.get("session_id")
    data = request.get("data", {})
    
    # PDF generálása
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4)
    story = []
    
    # Stílusok
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=16,
        spaceAfter=20,
        alignment=1  # középre igazítás
    )
    heading_style = ParagraphStyle(
        'CustomHeading',
        parent=styles['Heading2'],
        fontSize=14,
        spaceAfter=12,
        spaceBefore=12
    )
    normal_style = styles['Normal']
    
    # Cím
    story.append(Paragraph("MTMI Iskola Program<br/>Pályázati űrlap (összefoglaló)", title_style))
    story.append(Spacer(1, 20))
    
    # Alapadatok
    story.append(Paragraph("0. Alapadatok", heading_style))
    if data.get("palyazo_iskola_neve"):
        story.append(Paragraph(f"<b>Pályázó iskola neve:</b> {data['palyazo_iskola_neve']}", normal_style))
    if data.get("iskola_cime"):
        story.append(Paragraph(f"<b>Iskola címe:</b> {data['iskola_cime']}", normal_style))
    if data.get("telepulesforma"):
        story.append(Paragraph(f"<b>Településforma:</b> {data['telepulesforma']}", normal_style))
    if data.get("iskolatipus"):
        story.append(Paragraph(f"<b>Iskolatípus:</b> {', '.join(data['iskolatipus']) if isinstance(data['iskolatipus'], list) else data['iskolatipus']}", normal_style))
    if data.get("iskola_tanuloi_letszama"):
        story.append(Paragraph(f"<b>Iskola tanulói létszáma:</b> {data['iskola_tanuloi_letszama']}", normal_style))
    story.append(Spacer(1, 12))
    
    # MTMI működés iskolai személyi feltételei
    story.append(Paragraph("1. MTMI működés iskolai személyi feltételei", heading_style))
    if data.get("mtmi_csapat_letszam"):
        story.append(Paragraph(f"<b>MTMI csapat létszáma:</b> {data['mtmi_csapat_letszam']}", normal_style))
    if data.get("mtmi_csapat_kozos_tevekenyseg"):
        story.append(Paragraph(f"<b>MTMI csapat közös tevékenységei:</b>", normal_style))
        story.append(Paragraph(data['mtmi_csapat_kozos_tevekenyseg'], normal_style))
    story.append(Spacer(1, 12))
    
    # MTMI tantárgyak
    story.append(Paragraph("2. MTMI tantárgyak, elemek a pedagógiai programban", heading_style))
    if data.get("pedprog_mtmi_tartalom"):
        story.append(Paragraph(f"<b>Pedagógiai program MTMI tartalmak:</b> {data['pedprog_mtmi_tartalom']}", normal_style))
    if data.get("pedprog_mtmi_leiras"):
        story.append(Paragraph(f"<b>Pedagógiai program leírás:</b>", normal_style))
        story.append(Paragraph(data['pedprog_mtmi_leiras'], normal_style))
    story.append(Spacer(1, 12))
    
    # Saját MTMI programkínálat
    story.append(Paragraph("3. Saját MTMI programkínálat", heading_style))
    if data.get("mtmi_szakkorok_szama"):
        story.append(Paragraph(f"<b>MTMI-fókuszú szakkörek száma:</b> {data['mtmi_szakkorok_szama']}", normal_style))
    if data.get("mtmi_nyilt_napok"):
        story.append(Paragraph(f"<b>MTMI nyílt napok:</b>", normal_style))
        story.append(Paragraph(data['mtmi_nyilt_napok'], normal_style))
    if data.get("mtmi_projektnapok"):
        story.append(Paragraph(f"<b>MTMI projektnapok:</b>", normal_style))
        story.append(Paragraph(data['mtmi_projektnapok'], normal_style))
    if data.get("mtmi_szakmai_gyakorlatok"):
        story.append(Paragraph(f"<b>MTMI szakmai gyakorlatok:</b>", normal_style))
        story.append(Paragraph(data['mtmi_szakmai_gyakorlatok'], normal_style))
    story.append(Spacer(1, 12))
    
    # MTMI versenyek
    story.append(Paragraph("4. MTMI versenyek, pályázatok, kutatások", heading_style))
    if data.get("mtmi_versenyek_szervezese"):
        story.append(Paragraph(f"<b>MTMI versenyek szervezése:</b> {data['mtmi_versenyek_szervezese']}", normal_style))
    if data.get("mtmi_versenyek_bemutatasa"):
        story.append(Paragraph(f"<b>MTMI versenyek bemutatása:</b>", normal_style))
        story.append(Paragraph(data['mtmi_versenyek_bemutatasa'], normal_style))
    story.append(Spacer(1, 12))
    
    # Lányok érdeklődése
    story.append(Paragraph("5. A lányok érdeklődésének felkeltése", heading_style))
    if data.get("mtmi_lanyok_programok"):
        story.append(Paragraph(f"<b>Lányok programok:</b> {data['mtmi_lanyok_programok']}", normal_style))
    story.append(Spacer(1, 12))
    
    # MTMI kapcsolatrendszer
    story.append(Paragraph("6. MTMI kapcsolatrendszer működtetése", heading_style))
    if data.get("mtmi_egyuttmukodes_felsooktatas"):
        story.append(Paragraph(f"<b>Felsőoktatási együttműködés:</b> {data['mtmi_egyuttmukodes_felsooktatas']}", normal_style))
    if data.get("mtmi_egyuttmukodes_vallalatok"):
        story.append(Paragraph(f"<b>Vállalati együttműködés:</b> {data['mtmi_egyuttmukodes_vallalatok']}", normal_style))
    story.append(Spacer(1, 12))
    
    # Pedagógusok ösztönzése
    story.append(Paragraph("7. Pedagógusok ösztönzése", heading_style))
    if data.get("mtmi_pedagogusok_osztonezes"):
        story.append(Paragraph(f"<b>Pedagógusok ösztönzése:</b> {data['mtmi_pedagogusok_osztonezes']}", normal_style))
    story.append(Spacer(1, 12))
    
    # PDF generálása
    doc.build(story)
    buffer.seek(0)
    
    return Response(
        content=buffer.getvalue(),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=MTMI_kitoltes_{session_id}.pdf"}
    ) 

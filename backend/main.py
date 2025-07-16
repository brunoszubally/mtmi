from fastapi import FastAPI, HTTPException, Request, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime
import sqlite3
import json
import os

# --- Adatbázis inicializálás ---
DB_PATH = os.path.join(os.environ.get("DISK_PATH", os.path.dirname(__file__)), 'mtmi_forms.db')


def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS forms (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            submitted INTEGER DEFAULT 0
        )
    ''')
    # Ha a submitted mező hiányzik, hozzáadjuk (régi DB-k esetén)
    try:
        c.execute('ALTER TABLE forms ADD COLUMN submitted INTEGER DEFAULT 0')
    except sqlite3.OperationalError:
        pass
    conn.commit()
    conn.close()

init_db()

# --- FastAPI app ---
app = FastAPI()

# CORS beállítás (frontend fejlesztéshez)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://mtmi-frontend.onrender.com",
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

class LoadResponse(BaseModel):
    data: dict
    session_id: str
    submitted: int  # vagy bool

# --- API végpontok ---
@app.post("/api/save", response_model=SaveResponse)
def save_form(req: SaveRequest, request: Request):
    now = datetime.utcnow().isoformat()
    session_id = req.session_id or str(uuid4())
    with sqlite3.connect(DB_PATH, timeout=30) as conn:
        c = conn.cursor()
        c.execute("SELECT id FROM forms WHERE id = ?", (session_id,))
        if c.fetchone():
            c.execute(
                "UPDATE forms SET data = ?, updated_at = ? WHERE id = ?",
                (json.dumps(req.data), now, session_id)
            )
        else:
            c.execute(
                "INSERT INTO forms (id, data, created_at, updated_at, submitted) VALUES (?, ?, ?, ?, 0)",
                (session_id, json.dumps(req.data), now, now)
            )
        conn.commit()
    url = str(request.base_url) + f"kitoltes/{session_id}"
    return SaveResponse(session_id=session_id, url=url)

@app.get("/api/load/{session_id}", response_model=LoadResponse)
def load_form(session_id: str):
    with sqlite3.connect(DB_PATH, timeout=30) as conn:
        c = conn.cursor()
        c.execute("SELECT data, submitted FROM forms WHERE id = ?", (session_id,))
        row = c.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Nincs ilyen űrlap!")
    data = json.loads(row[0])
    submitted = row[1] if row[1] is not None else 0
    return LoadResponse(data=data, session_id=session_id, submitted=submitted)

# Egyszerű root végpont
@app.get("/")
def root():
    return {"msg": "MTMI űrlap backend fut!"} 

@app.post("/api/submit/{session_id}")
def submit_form(session_id: str):
    with sqlite3.connect(DB_PATH, timeout=30) as conn:
        c = conn.cursor()
        c.execute("UPDATE forms SET submitted = 1, updated_at = ? WHERE id = ?", (datetime.utcnow().isoformat(), session_id))
        conn.commit()
    return {"status": "ok"} 

ADMIN_PASSWORDS = ["admin", "Sanyika1472"]

@app.post("/api/admin/login")
def admin_login(data: dict):
    password = data.get("password")
    if password in ADMIN_PASSWORDS:
        return {"success": True}
    return {"success": False}

@app.get("/api/admin/list")
def admin_list():
    with sqlite3.connect(DB_PATH, timeout=30) as conn:
        c = conn.cursor()
        c.execute("SELECT id, data, created_at, submitted FROM forms ORDER BY created_at DESC")
        rows = c.fetchall()
    result = []
    for row in rows:
        id, data_json, created_at, submitted = row
        try:
            data = json.loads(data_json)
        except Exception:
            data = {}
        iskola_nev = data.get("palyazo_iskola_neve", "(nincs megadva)")
        result.append({
            "id": id,
            "iskola_nev": iskola_nev,
            "created_at": created_at,
            "submitted": submitted
        })
    return result

@app.get("/api/admin/result/{session_id}")
def admin_result(session_id: str):
    with sqlite3.connect(DB_PATH, timeout=30) as conn:
        c = conn.cursor()
        c.execute("SELECT data FROM forms WHERE id = ?", (session_id,))
        row = c.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Nincs ilyen űrlap!")
    data = json.loads(row[0])
    return {"data": data} 
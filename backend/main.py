from fastapi import FastAPI, HTTPException, Request, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime
import os
import psycopg2
from psycopg2.extras import Json

# --- Adatbázis inicializálás ---
DATABASE_URL = os.environ.get("DATABASE_URL", "")


def init_db():
    with psycopg2.connect(DATABASE_URL) as conn:
        with conn.cursor() as c:
            c.execute('''
                CREATE TABLE IF NOT EXISTS forms (
                    id TEXT PRIMARY KEY,
                    data JSONB NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    submitted INTEGER DEFAULT 0
                )
            ''')
            conn.commit()

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
            c.execute("SELECT data, submitted FROM forms WHERE id = %s", (session_id,))
            row = c.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Nincs ilyen űrlap!")
    data = row[0]
    submitted = row[1] if row[1] is not None else 0
    return LoadResponse(data=data, session_id=session_id, submitted=submitted)

# Egyszerű root végpont
@app.get("/")
def root():
    return {"msg": "MTMI űrlap backend fut!"} 

@app.post("/api/submit/{session_id}")
def submit_form(session_id: str):
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

@app.get("/api/admin/list")
def admin_list():
    with psycopg2.connect(DATABASE_URL) as conn:
        with conn.cursor() as c:
            c.execute("SELECT id, data, created_at, submitted FROM forms ORDER BY created_at DESC")
            rows = c.fetchall()
    result = []
    for row in rows:
        id, data_json, created_at, submitted = row
        data = data_json
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
    with psycopg2.connect(DATABASE_URL) as conn:
        with conn.cursor() as c:
            c.execute("SELECT data FROM forms WHERE id = %s", (session_id,))
            row = c.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Nincs ilyen űrlap!")
    data = row[0]
    return {"data": data} 

@app.delete("/api/admin/delete/{session_id}")
def admin_delete(session_id: str):
    with psycopg2.connect(DATABASE_URL) as conn:
        with conn.cursor() as c:
            c.execute("DELETE FROM forms WHERE id = %s", (session_id,))
            conn.commit()
    return {"status": "deleted"} 
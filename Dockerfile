FROM python:3.11-slim

WORKDIR /app

# Függőségek telepítése
COPY backend/requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Backend kód másolása
COPY backend /app/backend/

# Frontend kód másolása a containerbe, egy szinttel a backend fölé,
# ahogy a main.py elvárja: os.path.join(os.path.dirname(__file__), "..", "frontend")
COPY frontend /app/frontend/

# Feltöltések mappa létrehozása a backendben
RUN mkdir -p /app/backend/uploads

WORKDIR /app/backend

# Alapértelmezett port (a Render állítja be, de lokálisan jó a 8000)
ENV PORT=10000
EXPOSE $PORT

# Elindítjuk az uvicornt a Render által megadott (vagy alapértelmezett) porton
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT}"]
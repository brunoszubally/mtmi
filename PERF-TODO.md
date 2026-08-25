# Teljesítmény: mért állapot és teendők

> Ez a jegyzet azért készült, hogy terminálból (Claude Code) folytatható legyen a munka.
> Minden szám **mérés**, nem becslés – a mérés módja alább reprodukálható.

## Kiindulás

- **Az éles kód a `codex/admin-ui-and-flow-updates` ágon van** (utolsó commit: 2026-08-18),
  nem a `master`-en (az júniusi). Ez az ág ennek a leszármazottja.
- Ez az ág tartalmazza a beadási időzítés hibajavítását is
  (commit `ecbdcf8`), lásd lentebb a "Kapcsolódó" részt.
- Az itt leírt teljesítmény-teendőkből **még semmi nincs megcsinálva**, ez csak a felmérés.

## Amit NEM kell javítani (megmérve, rendben van)

150 iskola / 150 űrlap (átlag 24 KB JSONB űrlaponként, a `backups/` valódi adataiból):

| végpont | idő | válasz mérete |
|---|---|---|
| `GET /api/admin/list` | 29–38 ms | 28,1 KB |
| `GET /api/admin/schools` | 33–41 ms | 62,4 KB |
| `GET /api/admin/result/{id}` | 10–16 ms | 65,1 KB |

- Nincs N+1 a backendben, az admin lista és az iskolák lekérdezés nem húzza át a teljes
  űrlap-JSON-t, és az indexek megvannak (`init_db`).
- A kitöltő oldal saját JS/DOM költsége rendben: `load` 104 ms, 1888 DOM elem, 261 űrlapmező.

## Teendők fontossági sorrendben

### 1. Nincs tömörítés (gzip/brotli) – a legnagyobb és legolcsóbb nyereség

Sem az `nginx.conf`-ban nincs `gzip` direktíva, sem a FastAPI-ban `GZipMiddleware`
(`backend/main.py:239` – az `app = FastAPI()` után nincs ilyen middleware).

| | most | gzip-pel |
|---|---|---|
| `index.html` + `script.js` + `style.css` | **353 KB** | **55 KB** (6,5×) |
| `index.html` | 211,6 KB | 22,6 KB |
| `script.js` | 112,5 KB | 26,0 KB |
| `style.css` | 29,1 KB | 6,6 KB |
| `admin/admin.js` | 60,0 KB | 15,0 KB |
| `/api/admin/list` | 28,1 KB | 4,6 KB |
| `/api/admin/schools` | 62,4 KB | 9,3 KB |
| `/api/admin/result/{id}` | 65,1 KB | 19,7 KB |

**Teendő:**
- Backend: `from fastapi.middleware.gzip import GZipMiddleware` +
  `app.add_middleware(GZipMiddleware, minimum_size=1024)` – ez a hostingtól függetlenül hat.
- Frontend kiszolgálás: `gzip on; gzip_types text/html text/css application/javascript application/json; gzip_min_length 1024;`

**Előbb ellenőrizni:** lehet, hogy a hosting már tömörít. Ez dönti el:
```bash
curl -sI -H 'Accept-Encoding: gzip' https://palyazat.mtmi-iskola.hu/script.js | grep -i content-encoding
curl -sI -H 'Accept-Encoding: gzip' https://palyazat.mtmi-iskola.hu/api/health | grep -i content-encoding
```

### 2. A statikus fájlok cache-elése ki van kapcsolva

`nginx.conf:33-40` – a fejlesztői ág aktív:
```
expires -1;
add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
# Production: uncomment these lines and comment out the above
# expires 1y;
# add_header Cache-Control "public, immutable";
```
Így minden oldalbetöltésnél újratöltődik a teljes 353 KB.

**Teendő:** a production ág bekapcsolása. Fontos: az `expires 1y; immutable` **csak
verziózott fájlnévvel** biztonságos (`script.js?v=2026-08-25` vagy tartalom-hash),
különben a felhasználók régi JS-t kapnak deploy után. Verziózás nélkül `expires 1h`
a biztonságos kompromisszum.

**Nyitott kérdés:** ez az `nginx.conf` egyáltalán az éles frontendet szolgálja ki?
Gyanús, hogy nincs benne `/api` proxy, pedig a frontend `API_BASE = "/api"`-t használ
(`frontend/admin/admin.js:2`). Tisztázni deploy előtt.

### 3. Excel export: 150 külön, sorosan megvárt kérés

`frontend/admin/admin.js:1009` (`exportToExcel`) – a ciklus az `1028.` sorban minden
űrlapra külön `/admin/result/{id}`-t hív `await`-tel. Ugyanez a minta:
`exportSelectedToExcel` (`:1240`, ciklus `:1245`).

Mérve 150 rekordnál: **7,4 MB** letöltés. Lokálisan (hálózati késleltetés nélkül) 0,9 s,
de ez 150 külön oda-vissza út – éles hálózaton ~100 ms RTT-vel önmagában +15 s.

**Teendő (bármelyik):**
- gyors: 8-as párhuzamosítás (`Promise.all` batch-ekben) – a kliensoldali kód marad,
- jobb: bulk végpont a backendben (egy kérés, minden űrlap adata), gzip-pel ~1 MB.

### 4. Autosave: mindig a teljes űrlapot küldi, akkor is, ha nem változott

- `frontend/script.js:19` – `AUTO_SAVE_DEBOUNCE_MS = 1000`
- `frontend/script.js:1539` – `scheduleAutoSave()`
- `frontend/script.js:1458` – `saveForm()`: nincs összehasonlítás az utoljára elküldött
  adattal, minden hívás elküldi a teljes JSON-t.

Az éles adatok alapján ez **24–87 KB POST** gépelési szünetenként, és a szerveren
minden alkalommal teljes JSONB sor-újraírás.

**Teendő:** debounce 3000 ms + az elküldött JSON eltárolása (`lastSavedPayload`), és ha
megegyezik, kihagyni a kérést. A "Mentés" gomb továbbra is küldjön mindig.

### 5. Kérésenként egy fölösleges `SELECT 1`

`backend/main.py:122` (`_acquire_connection`) minden kapcsolatkivételkor meghívja a
`_connection_is_alive()`-ot (`backend/main.py:109`), ami egy `SELECT 1`-et futtat.
Supabase pooleren keresztül ez minden API híváshoz hozzáad egy plusz oda-vissza utat.

**Teendő:** csak a régóta álló kapcsolatot validálni (pl. ha >60 s-e nem volt használva),
vagy elhagyni az ellenőrzést és `InterfaceError`/`OperationalError` esetén egyszer újrapróbálni.

### 6. Az admin oldal mindig letölti az xlsx könyvtárat

`frontend/admin/index.html:320` – `xlsx.full.min.js` (nagyságrendileg ~900 KB) minden
admin oldalbetöltésnél betöltődik, akkor is, ha sosem exportálsz.

**Teendő:** dinamikus betöltés az első export-kattintáskor (script tag injektálás + Promise).

### 7. A kitöltő oldal négy külső CDN-től függ

`frontend/index.html:9-18` és `:2892` – Google Fonts (2 család, 7 súly), Bootstrap CSS,
Bootstrap Icons, animate.css, Bootstrap JS. Ezek render-blokkolók.

Mérés: amikor a CDN-ek nem elérhetők, a betöltés **13,4 s**-ig lóg (104 ms helyett).
Ez egy pályázati határidő napján valós kockázat.

**Teendő:** a ténylegesen használt fájlok kiszolgálása saját helyről (self-host), vagy
legalább a nem kritikusak (animate.css, Bootstrap Icons) leválasztása / lusta betöltése.

## Javasolt commit-bontás

1. `perf: gzip middleware a backendben` (1. pont, backend rész) – kockázatmentes
2. `perf: Excel export párhuzamosítása` (3. pont)
3. `perf: autosave csak változás esetén, 3s debounce` (4. pont)
4. `perf: xlsx könyvtár lusta betöltése` (6. pont)
5. `perf: nginx gzip + cache` (1-2. pont) – **csak** miután tisztázódott, hogy az
   `nginx.conf` az éles kiszolgáló
6. `perf: CDN függőségek self-hostolása` (7. pont) – ez a legnagyobb munka

## A mérés reprodukálása

```bash
# 1. Lokális Postgres (a konténerben nincs docker daemon, ezért közvetlenül)
initdb -D /tmp/pgdata -U user --auth=trust
pg_ctl -D /tmp/pgdata -o '-p 55432 -k /tmp' start
createdb -h localhost -p 55432 -U user mtmi_perf

# 2. Backend (FIGYELEM: a backend/.env élő DATABASE_URL-t tartalmaz,
#    ezért másolatból futtasd, .env nélkül, és add meg kézzel a DATABASE_URL-t)
cp -r backend /tmp/testapp && rm -f /tmp/testapp/.env
cd /tmp/testapp && DATABASE_URL="postgresql://user@localhost:55432/mtmi_perf" \
  python3 -m uvicorn main:app --port 8000

# 3. Adatok: a backups/live_api_snapshot_20260605/results/*.json fájlokból
#    150 űrlap + 150 iskola beszúrása (átlag 24 KB/űrlap)

# 4. Frontend + /api proxy egy porton (mint élesben az nginx), majd Playwright
#    (a konténerben: /opt/pw-browsers, PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1)
```

Tömörítési arány méréséhez elég:
```bash
for f in frontend/index.html frontend/script.js frontend/style.css frontend/admin/admin.js; do
  echo "$f: $(stat -c%s $f) B -> $(gzip -9 -c $f | wc -c) B"
done
```

## Kapcsolódó, de NEM teljesítmény: biztonság

Ezek külön, sürgős teendők (a repo **publikus**):

- `backend/.env` be van commitolva, `DATABASE_URL`-lel együtt.
- FTP jelszó a `backend/main.py`-ban, kódba égetve.
- Mindkettőt rotálni kell, és kivenni a verziókövetésből (`.gitignore` + a
  történetből is, ha a kulcsok nem cserélhetők azonnal).

## Kapcsolódó munka ezen az ágon

`ecbdcf8` – "Az admin beadási időzítés valóban működjön": belépés után nem töltődött be a
mentett időszak, a Mentés emiatt NULL-ra írta a dátumokat, és a dátumok nem is
nyitották/zárták a felületet. Deploy előtt ellenőrizni:

```sql
SELECT submission_mode, submission_start_at, submission_end_at FROM app_settings;
```

Ha régi záró dátum van benne, a deploy azonnal lezárja a kitöltő felületet – előtte
állítsátok át az adminban vagy töröljétek a dátumokat.

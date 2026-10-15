# Lánczos – eltűnt pályázati adatok (2026-10-15)

A Lánczos napokig dolgozott a pályázatán, és eltűntek az adatai. Azt kérték,
hogy legalább a két nappal ezelőtti állapotot kapják vissza.

**Állapot:** az élesben semmi nem változott. Az adatukat még senki nem látta,
mert a felhős munkakörnyezetből az FTP nem érhető el (csak HTTPS megy ki). A
mentések elemzését és a visszaállítást gépről kell folytatni, lásd lent.

## Amit tudunk

### Railway: melyik branchből megy az éles

A Railway szinte biztosan a **`codex/admin-ui-and-flow-updates`** branchből
deployol. Biztosan a Railway felületén látszik: Service → Settings → Source →
Branch.

- Csak ezen a branchen van rajta a `66b9a9f` revert („élesben 500-akat
  okozott”).
- Az élesben mért perf-commitok, és az FTP-mentés is („az első éles mentés fel
  is került”) itt vannak.
- A `master` júniusi, és még a Renderre mutat.

Ez a jegyzet és a szkript a `claude/restore-school-form` branchen van, ami az
éles branchből ágazik le. Az éles branchet nem érinti, így a Railway nem
deployol tőle.

### Van napi mentés

- **Hol és mikor:** a `backend/db_backup.py` minden éjjel kb. 01:00 UTC-kor
  (03:00 budapesti idő) teljes mentést tölt fel az FTP `backups/` mappájába
  `mtmi-backup-ÉÉÉÉHHNN.sql.gz` néven.
- **Mit tartalmaz:** az `app_settings`, `schools` és `forms` táblát.
- **Megőrzés:** 30 napig, tehát az október eleji mentések is megvannak.
- **Melyik nap mit őriz:** a `mtmi-backup-20261013.sql.gz` az okt. 12-e esti
  állapotot tartalmazza. Ha az adat csak okt. 14-én tűnt el, a `20261014`
  mentés még frissebb.

> **TILOS a mentés saját visszatöltése (`gunzip -c … | psql`).** Az törli és
> újratölti a teljes `forms` és `schools` táblát, így minden más iskola azóta
> beírt munkája elveszne. Csak a lenti szkripttel, egyetlen űrlapra szabad
> visszaállítani.

## Teendő gépről

```
git fetch && git checkout claude/restore-school-form
cd backend
pip install psycopg2-binary   # csak a find/diff/restore parancsokhoz kell
```

### 1. Mi történt? (csak olvas)

```
python restore_school_form.py scan --school lanczos --days 0
```

- **Mit csinál:** letölti az FTP-ről az összes mentést, és napokra bontva
  kiírja a Lánczos iskolát és az űrlapjait. Minden űrlapnál megadja a
  kitöltött mezők és karakterek számát, és a módosítás idejét.
- **FTP-adatok:** ha nincs `FTP_HOST`/`FTP_USER`/`FTP_PASS` env, a `main.py`-ban
  rögzített értékeket használja.
- **Letöltött fájlok:** az aktuális mappába kerülnek.

Utána az éles állapot. Ehhez kell a `DATABASE_URL`, ami Railway alatt
automatikusan megvan:

```
railway run python restore_school_form.py find --school lanczos
railway run python restore_school_form.py diff --school lanczos --backup mtmi-backup-20261013.sql.gz
```

### 2. Visszaállítás

```
# száraz futás: kiírja, mi lenne, nem ír semmit
railway run python restore_school_form.py restore --form-id <ID> --backup mtmi-backup-20261013.sql.gz --mode merge
# élesítés
railway run python restore_school_form.py restore --form-id <ID> --backup mtmi-backup-20261013.sql.gz --mode merge --yes
```

- **`--mode merge`:** az éles állapot marad, a mentésből csak az élesben üres
  mezők töltődnek vissza. Az azóta beírt munka nem vész el. Ha valamelyik mező
  mindkét helyen ki van töltve, de eltér, a szkript kilistázza, és az élest
  tartja meg.
- **`--mode replace`:** az űrlap tartalma teljesen a mentésbeli lesz.
- **`--relink`:** az iskolát újra ehhez az űrlaphoz köti. Akkor kell, ha a
  `find` szerint az iskola egy új, szinte üres űrlapra mutat.
- **Biztonsági mentés és tranzakció:** írás előtt a jelenlegi éles sort
  `restore-safety-<id>-<idő>.json` fájlba menti, és mindent egy tranzakcióban
  csinál.
- **Törölt űrlap:** ha az űrlapot közben törölték, a mentésből újra létrehozza.

Tesztelve helyben, PostgreSQL 16-tal, a `db_backup.build_dump_sql` által
készített mentésekkel és helyi FTP-vel:

- az ékezetek, idézőjelek, backslashek, sortörések és emojik bitre pontosan
  visszajönnek;
- a többi iskola érintetlen marad.

### 3. Visszaállítás előtt és után

- **Előtte:** a Lánczosnál mindenki zárja be az összes lapot, ahol az űrlap
  nyitva van. Egy nyitva felejtett régi lapon egyetlen leütés felülírja a
  visszaállított adatot.
- **Ha a lenti 1. ok történt:** a régi böngészős másolat még ott lehet
  valamelyik gépükön, és újra felülírhat. Ilyenkor azokon a gépeken törölni kell
  az oldal tárolt adatait. A kijelentkezés nem elég, mert a másolatot nem törli.
  Biztosabb, ha előbb a javítás megy ki (lásd lent).

## Lehetséges okok

Hogy melyik történt, az a `scan` és a `find` kimenetéből derül ki. A
sorszámok az éles branchre vonatkoznak.

### 1. Régi böngészős másolat felülírja az űrlapot (a legvalószínűbb)

Ez az aug. 28-i `6b4efa2` commit óta van élesben.

- **A másolat keletkezése:** a böngésző minden gépeléskor elmenti a teljes
  űrlap másolatát (`frontend/script.js:2202`). Ezt csak sikeres
  szerver-mentés után törli.
- **Mikor marad meg:** ha valaki az utolsó leütés után 3 másodpercen belül
  bezárja a lapot, vagy a mentés hibát kap (terhelés alatt a pool miatt még
  mindig jöhet 500-as), a másolat azon a gépen marad.
- **Mi történik később:** ha napokkal később valaki azon a gépen nyitja meg az
  űrlapot, a szerverről betöltött adatot a program lecseréli a régi másolatra
  (`script.js:2074` → `restoreLocalDraftIntoForm`, `script.js:1904`).
  Sehol nem ellenőrzi, hogy a másolat régebbi-e a szerveren lévőnél
  (`getRestorableLocalDraft`, `script.js:118`).
- **A felülírás:** a felület kiírja: „Visszatöltöttük a nem mentett
  módosításaidat… Kattints a Mentés gombra” (`script.js:1928`). Erre a
  kattintásra vagy az első leütésre a régi állapot felülírja a kollégák azóta
  végzett munkáját.

**Ismertetőjel:** a mostani tartalom egy korábbi napi mentéssel egyezik, és
nem üres.

### 2. Két nyitott lap vagy két kolléga egyszerre

A mentés mindig a teljes űrlapot küldi, a szerver pedig ellenőrzés nélkül
felülírja (`backend/main.py:729`). Ha egy régi lap napok óta nyitva van,
egyetlen leütés is elég.

**Ismertetőjel:** ugyanaz, mint az 1. esetnél. Az iskolától kell megkérdezni,
látták-e a „Visszatöltöttük…” sávot.

### 3. Az iskola egy új, üres űrlapra lett átkötve

- **Mikor történik:** ha valaki egy régi vagy idegen linken
  (`/kitoltes/<azonosító>`) nyitja meg az űrlapot, és a betöltés 403-at vagy
  404-et ad (`script.js:2088`). Ilyenkor a program új űrlapot kezd, és az első
  mentés az iskolát erre köti át (`main.py:738`).
- **Következmény:** a régi űrlap érintetlenül megvan az adatbázisban, csak
  lecsatolódott. Mentés nem kell hozzá, elég visszakötni:
  `restore … --relink`, vagy közvetlenül a `schools.form_id` átírásával.

**Ismertetőjel:** a `find` két űrlapot mutat, és a hozzá kötött az új, szinte
üres.

## Kérdések az iskolának

- Hány gépen vagy böngészőben, hányan dolgoztak rajta?
- Látták-e a „Visszatöltöttük a nem mentett módosításaidat” sávot, vagy azt,
  hogy „A hozzád rendelt űrlap … nem létezik / másik iskolához tartozik”?
- Most üres az űrlap, vagy egy régebbi változata látszik?
- Mikor látták utoljára jónak, és milyen linken nyitották meg?

## Javítandó (még nincs megcsinálva)

1. **Böngészős másolat:** csak akkor töltődjön vissza, ha frissebb, mint a
   szerver `updated_at`-je. Ez az 1. okot zárja ki.
2. **Ütközésfigyelés:** a kliens küldje el, melyik `updated_at`-re épül a
   mentés. A szerver utasítsa el (409), ha közben újabb mentés történt, a
   felület pedig figyelmeztessen. Ez a 2. okot zárja ki.
3. **Kapcsolat-pool:** a `SimpleConnectionPool` terhelés alatt nem vár, hanem
   500-at ad (lásd `40fcdb5`). A sikertelen mentések miatt maradnak meg a régi
   böngészős másolatok.
4. **Biztonság, FTP-jelszó:** az FTP-jelszó nyílt szövegként benne van a
   `backend/main.py`-ban és a git-történetben. Env-be kell tenni és le kell
   cserélni.
5. **Biztonság, mentések helye:** meg kell nézni, hol van az FTP `backups`
   mappája. Ha a weboldal nyilvános könyvtárán (pl. `public_html`) belül van,
   a teljes adatbázis-mentés böngészőből letölthető lehet.

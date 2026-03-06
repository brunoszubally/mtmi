# MTMI Iskolai Login - Fejlesztési Állapot és Debug Infó

Ezt a dokumentumot azért hoztuk létre, hogy egy másik AI asszisztens (pl. Copilot, Cursor, Codex) könnyen felvehesse a fonalat.

## 1. Mit fejlesztettünk le idáig?

### Adatbázis & Backend (`backend/main.py`)
- Létrehoztunk egy új `schools` táblát, ami összeköti az iskolákat a `forms` táblával.
- Megírtuk a `POST /api/school/login` végpontot. Ez fogadja az `email` és `password` paramétereket, és bcrypt algoritmussal ellenőrzi a hashelt jelszót.
- Sikeres login esetén visszaadja: `school_id`, `school_name`, `form_id` és `form_status` (`null`, `"in_progress"` vagy `"submitted"`).
- **Backend státusz: TÖKÉLETESEN MŰKÖDIK.** (curl-lel tesztelve a helyes email/jelszó párossal sikeres választ ad).

### Frontend HTML (`frontend/index.html`)
- Bekerült egy új `login-screen` div a `welcome-screen` elé.
- A `welcome-screen` alapértelmezetten el lett rejtve (`style="display:none;"`).

### Frontend JS (`frontend/script.js`)
- A fájl elején definiáltuk a `handleSchoolLogin(email, password)` függvényt.
- Ez meghívja a backendet, majd a válasz alapján:
  - Elrejti a `login-screen`-t.
  - Ha nincs kitöltés (`form_status === null`), megjeleníti a `welcome-screen`-t.
  - Ha folyamatban van (`form_status === 'in_progress'`), betölti az űrlapot (meghívja a `loadForm()`-ot) és megjeleníti a `main-form-content`-et.
  - Ha be van küldve (`form_status === 'submitted'`), a `thankyou-fullscreen`-t mutatja.
- A HTML document betöltésekor (`DOMContentLoaded`):
  - Rákötöttük a `submit` event listenert a `school-login-form` formra.
  - Lefutom a session checket (hogy be van-e már lépve a user).

## 2. Hol akadtunk el? (A Probléma)

Amikor a böngészőben a felhasználó beírja a helyes emailt és jelszót, majd rákattint a "Belépés" gombra (vagy nyom egy Entert a formon), **semmi sem történik a UI-on a felhasználó elmondása szerint**. 

**Amit már próbáltunk:**
- Kezdetben a `loadForm()` egy scope-on (egy belső `DOMContentLoaded`) belül volt definiálva, ezért a globális névtérbe kitettük (`window.loadForm = loadForm;`), hogy a `handleSchoolLogin` is elérje.
- Volt egy probléma, hogy a belső `DOMContentLoaded` hook (a fájl vége felé) rögtön elrejtette a `welcome-screen`-t, ha futott egy initial `loadForm()` és talált (készített) egy `session_id`-t. Ezt feltételhez kötöttük (`if (loginScreen && loginScreen.style.display === 'none') { ... }`).

**Lehetséges hibaokok, amit a másik AI-nak érdemes megnéznie a `script.js`-ben:**
1. **Event listener kötés:** Lehet, hogy a `DOMContentLoaded`-be tett event listener nem kötődik rá a gombra megfelelően, vagy valami preventeli alapból?
2. **Külön fájl/Script betöltés:**  Az `index.html`-ben a `script.js` cache-elve van a böngészőben? (Kértem hard refresht, de lehet, hogy a szerver még a régit szolgálja ki / statikus fájl cache probléma FastAPInál?). Érdemes ellenőrizni, hogy a FastAPI a statikus fájlokat (`StaticFiles`) cache-eli-e.
3. **Konfliktus:** A fájlban van több `DOMContentLoaded` event listener és egy `setTimeout(..., 100)` is, amely manipulálja a DOM-ot. Lehet, hogy ezek írják felül egymás state-jét, ahogy betölt a DOM.
4. **Console log hiánya:** Érdemes lenne néhány `console.log()`-ot betenni a `handleSchoolLogin`-ba és a form `.addEventListener('submit', ...)` blokkba, hogy kiderüljön, eljut-e odáig a vezérlés.

## 3. Merre tovább?

Kérd meg a Codexet/Copilotot, hogy:
1. Adjon hozzá debug `console.log()`-okat a `script.js` elején lévő login szekcióhoz.
2. Nézze át a `DOMContentLoaded` blokkokat (különösen a `script.js` 204. és 939. sora környékén lévőket), hogy nincs-e scope/futási sorrend probléma.
3. Erősítse meg a FastAPI statikus fájl kiszolgálását (hogy biztosan nem kap-e valami agresszív cache fejlécet a `script.js`).

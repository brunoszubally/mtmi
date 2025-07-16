// --- Globális segédfüggvény ---
function getSessionIdFromUrl() {
    const m = window.location.pathname.match(/kitoltes\/(\w[\w-]*)/);
    return m ? m[1] : null;
}

const API_BASE = "https://mtmi.onrender.com/api"; // Állítsd át, ha máshol fut a backend!
const FORM_ID = "mtmi-form";
const SESSION_KEY = "mtmi_session_id";
const LINK_BOX_ID = "mtmi-link-box";

document.addEventListener('DOMContentLoaded', function() {
  var startBtn = document.getElementById('start-form-btn');
  if (startBtn) {
    startBtn.addEventListener('click', function() {
      var welcome = document.getElementById('welcome-screen');
      if (welcome) welcome.style.display = "none";
      document.getElementById('main-form-content').style.display = 'block';
      document.body.style.overflow = 'auto';
      window.scrollTo(0,0);
    });
  } else {
    document.body.style.overflow = 'hidden';
  }
  // Wizard léptetés
  const steps = Array.from(document.querySelectorAll('.form-step'));
  let currentStep = 0;
  const progressBar = document.getElementById('form-progress');
  const progressPercent = document.getElementById('progress-percent');
  const stepperLinks = Array.from(document.querySelectorAll('.stepper-link'));

  function showStep(idx, direction = 1) {
    steps.forEach((step, i) => {
      if (i === idx) {
        step.style.display = '';
        step.classList.remove('animate__fadeOutLeft', 'animate__fadeOutRight', 'animate__fadeInRight', 'animate__fadeInLeft');
        step.classList.add(direction > 0 ? 'animate__fadeInRight' : 'animate__fadeInLeft');
      } else {
        if (step.style.display !== 'none') {
          step.classList.remove('animate__fadeInRight', 'animate__fadeInLeft');
          step.classList.add(direction > 0 ? 'animate__fadeOutLeft' : 'animate__fadeOutRight');
          setTimeout(() => { step.style.display = 'none'; }, 400);
        } else {
          step.style.display = 'none';
        }
      }
    });
    // Progress bar és százalék frissítés
    const percent = Math.round(((idx+1)/steps.length)*100);
    progressBar.style.width = percent + '%';
    progressPercent.textContent = percent + '%';
    // Stepper linkek frissítése
    stepperLinks.forEach((link, i) => {
      link.classList.remove('active');
      if (i === idx) {
        link.classList.add('active');
      }
    });
  }

  document.querySelectorAll('.next-step').forEach(btn => {
    btn.addEventListener('click', function() {
      if (currentStep < steps.length - 1) {
        showStep(currentStep + 1, 1);
        currentStep++;
      }
    });
  });
  document.querySelectorAll('.prev-step').forEach(btn => {
    btn.addEventListener('click', function() {
      if (currentStep > 0) {
        showStep(currentStep - 1, -1);
        currentStep--;
      }
    });
  });

  // Stepper navigáció kattintás - mostantól bármikor lehet kattintani
  stepperLinks.forEach((link, i) => {
    link.addEventListener('click', function() {
      if (i !== currentStep) {
        const direction = i > currentStep ? 1 : -1;
        showStep(i, direction);
        currentStep = i;
      }
    });
  });

  // Feltételes alapítvány mező
  const alapitvanySelect = document.getElementById('alapitvany-select');
  const alapitvanyLinkDiv = document.getElementById('alapitvany-link');
  if (alapitvanySelect) {
    alapitvanySelect.addEventListener('change', function() {
      if (this.value === 'igen') {
        alapitvanyLinkDiv.style.display = '';
        alapitvanyLinkDiv.classList.add('animate__fadeIn');
      } else {
        alapitvanyLinkDiv.classList.remove('animate__fadeIn');
        alapitvanyLinkDiv.style.display = 'none';
      }
    });
  }

  // 2. blokk: szülői képviselő feltételes logika
  const szuloKepviseloSelect = document.getElementById('mtmi-szulo-kepviselo-select');
  const szuloEgyeztetesBlock = document.getElementById('szulo-egyeztetes-block');
  if (szuloKepviseloSelect && szuloEgyeztetesBlock) {
    szuloKepviseloSelect.addEventListener('change', function() {
      if (this.value === 'igen') {
        szuloEgyeztetesBlock.style.display = '';
        szuloEgyeztetesBlock.classList.add('animate__fadeIn');
      } else {
        szuloEgyeztetesBlock.classList.remove('animate__fadeIn');
        szuloEgyeztetesBlock.style.display = 'none';
      }
    });
  }

  // MTMI csapat tagok dinamikus mezői (2. blokk)
  const csapatLetszamInput = document.getElementById('mtmi-csapat-letszam');
  const csapatTagokDiv = document.getElementById('mtmi-csapat-tagok');
  const szakok = [
    { value: 'matematika', label: 'Matematika' },
    { value: 'fizika', label: 'Fizika' },
    { value: 'kemia', label: 'Kémia' },
    { value: 'biologia', label: 'Biológia' },
    { value: 'foldrajz', label: 'Földrajz' },
    { value: 'digitalis_kultura', label: 'Digitális kultúra' },
    { value: 'kornyezetismeret', label: 'Környezetismeret' },
    { value: 'termeszettudomany', label: 'Természettudomány' },
    { value: 'integralt_termeszettudomany', label: 'Integrált természettudomány' },
    { value: 'technika', label: 'Technika és tervezés' },
    { value: 'egyeb', label: 'Egyéb' }
  ];
  if (csapatLetszamInput && csapatTagokDiv) {
    csapatLetszamInput.addEventListener('input', function() {
      let n = parseInt(this.value, 10);
      if (isNaN(n) || n < 1) n = 1;
      if (n > 8) n = 8;
      csapatTagokDiv.innerHTML = '';
      for (let i = 1; i <= n; i++) {
        // Név
        const label = document.createElement('label');
        label.className = 'form-label mt-2';
        label.textContent = `Név ${i}`;
        const input = document.createElement('input');
        input.type = 'text';
        input.className = 'form-control mb-2';
        input.name = `mtmi_csapat_tag${i}_nev`;
        input.placeholder = `Név ${i}`;
        csapatTagokDiv.appendChild(label);
        csapatTagokDiv.appendChild(input);
        // Szak/szakpár (checkboxok)
        const szakLabel = document.createElement('label');
        szakLabel.className = 'form-label';
        szakLabel.textContent = 'Tanított szak/szakpár';
        csapatTagokDiv.appendChild(szakLabel);
        const szakRow = document.createElement('div');
        szakRow.className = 'row';
        szakok.forEach((szak, idx) => {
          const col = document.createElement('div');
          col.className = 'col-6 col-md-4';
          const formCheck = document.createElement('div');
          formCheck.className = 'form-check';
          const checkbox = document.createElement('input');
          checkbox.type = 'checkbox';
          checkbox.className = 'form-check-input';
          checkbox.name = `mtmi_csapat_tag${i}_szak`;
          checkbox.value = szak.value;
          checkbox.id = `csapat${i}-szak-${szak.value}`;
          const checkboxLabel = document.createElement('label');
          checkboxLabel.className = 'form-check-label';
          checkboxLabel.setAttribute('for', `csapat${i}-szak-${szak.value}`);
          checkboxLabel.textContent = szak.label;
          formCheck.appendChild(checkbox);
          formCheck.appendChild(checkboxLabel);
          col.appendChild(formCheck);
          szakRow.appendChild(col);
        });
        csapatTagokDiv.appendChild(szakRow);
        // Tevékenységek
        const tevLabel = document.createElement('label');
        tevLabel.className = 'form-label mt-1';
        tevLabel.textContent = 'Tevékenységek';
        const tevInput = document.createElement('textarea');
        tevInput.className = 'form-control mb-2';
        tevInput.name = `mtmi_csapat_tag${i}_tevekenyseg`;
        tevInput.placeholder = 'Tevékenységek';
        csapatTagokDiv.appendChild(tevLabel);
        csapatTagokDiv.appendChild(tevInput);
      }
    });
  }

  // 3. blokk: pedagógiai program és MTMI koncepció feltételes logika
  const pedprogSelect = document.getElementById('pedprog-mtmi-tartalom-select');
  const pedprogLeiras = document.getElementById('pedprog-mtmi-tartalom-leiras');
  if (pedprogSelect && pedprogLeiras) {
    pedprogSelect.addEventListener('change', function() {
      if (this.value === 'igen' || this.value === 'reszben') {
        pedprogLeiras.style.display = '';
        pedprogLeiras.classList.add('animate__fadeIn');
      } else {
        pedprogLeiras.classList.remove('animate__fadeIn');
        pedprogLeiras.style.display = 'none';
      }
    });
  }
  const koncepcioSelect = document.getElementById('mtmi-koncepcio-select');
  const koncepcioLeiras = document.getElementById('mtmi-koncepcio-leiras');
  if (koncepcioSelect && koncepcioLeiras) {
    koncepcioSelect.addEventListener('change', function() {
      if (this.value === 'igen' || this.value === 'reszben') {
        koncepcioLeiras.style.display = '';
        koncepcioLeiras.classList.add('animate__fadeIn');
      } else {
        koncepcioLeiras.classList.remove('animate__fadeIn');
        koncepcioLeiras.style.display = 'none';
      }
    });
  }

  // Kezdő lépés megjelenítése
  showStep(0);

  // --- MTMI űrlap automatikus mentés és betöltés ---

  // Segédfüggvény: űrlap adatainak kiolvasása objektumba
  function getFormData(form) {
      const data = {};
      const formData = new FormData(form);
      for (const [key, value] of formData.entries()) {
          // Többszörös checkboxok kezelése tömbként
          if (data[key]) {
              if (Array.isArray(data[key])) {
                  data[key].push(value);
              } else {
                  data[key] = [data[key], value];
              }
          } else {
              data[key] = value;
          }
      }
      return data;
  }

  // Segédfüggvény: űrlap feltöltése objektumból
  function setFormData(form, data) {
      for (const [key, value] of Object.entries(data)) {
          const el = form.elements[key];
          if (!el) continue;
          if (el.type === "checkbox" || el.type === "radio") {
              if (Array.isArray(value)) {
                  for (const v of value) {
                      const box = form.querySelector(`[name='${key}'][value='${v}']`);
                      if (box) box.checked = true;
                  }
              } else {
                  const box = form.querySelector(`[name='${key}'][value='${value}']`);
                  if (box) box.checked = true;
              }
          } else {
              el.value = value;
          }
      }
      // --- ÚJ: minden select, checkbox, radio mezőre triggereljük a change/input eseményt ---
      ["change", "input"].forEach(eventType => {
          form.querySelectorAll("select, input[type=checkbox], input[type=radio]").forEach(el => {
              el.dispatchEvent(new Event(eventType, { bubbles: true }));
          });
      });
  }

  // Generált link megjelenítése
  function showLink(session_id) {
      let box = document.getElementById(LINK_BOX_ID);
      if (!box) {
          box = document.createElement("div");
          box.id = LINK_BOX_ID;
          box.className = "alert alert-info mt-3";
          const form = document.getElementById(FORM_ID);
          form.parentNode.insertBefore(box, form);
      }
      const url = window.location.origin + `/kitoltes/${session_id}`;
      box.innerHTML = `<b>Az űrlapod elérhető ezen a linken 30 napig (vagy amíg nem törlöd):</b><br><a href='${url}' target='_blank'>${url}</a>`;
  }

  // Mentés a backendre
  async function saveForm(auto=false) {
      const form = document.getElementById(FORM_ID);
      if (!form) return;
      const data = getFormData(form);
      let session_id = localStorage.getItem(SESSION_KEY);
      // Ha az URL-ben van session_id, azt is elfogadjuk
      const urlSession = getSessionIdFromUrl();
      if (urlSession) session_id = urlSession;
      try {
          const resp = await fetch(`${API_BASE}/save`, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ data, session_id })
          });
          if (resp.ok) {
              const res = await resp.json();
              localStorage.setItem(SESSION_KEY, res.session_id);
              showLink(res.session_id);
              // Ha nincs session_id az URL-ben, írjuk bele (csak első mentésnél)
              if (!getSessionIdFromUrl()) {
                  history.replaceState({}, "", `/kitoltes/${res.session_id}`);
              }
              if (!auto) {
                  // Manuális mentésnél visszajelzés
                  showToast("Sikeres mentés!", "success");
              }
          } else {
              if (!auto) showToast("Hiba a mentés során!", "danger");
          }
      } catch (e) {
          if (!auto) showToast("Hálózati hiba a mentés során!", "danger");
      }
  }

  // Betöltés a backendről
  async function loadForm() {
      let session_id = localStorage.getItem(SESSION_KEY);
      const urlSession = getSessionIdFromUrl();
      if (urlSession) session_id = urlSession;
      if (!session_id) return;
      try {
          const resp = await fetch(`${API_BASE}/load/${session_id}`);
          if (resp.ok) {
              const res = await resp.json();
              // --- ADMINVIEW workaround ---
              const urlParams = new URLSearchParams(window.location.search);
              const adminView = urlParams.get('adminview');
              if (res.submitted && parseInt(res.submitted) === 1 && !adminView) {
                // Ugyanaz a thank you screen, mint véglegesítéskor!
                document.getElementById("main-form-content").style.display = "none";
                document.getElementById("welcome-screen").style.display = "none";
                document.getElementById("thankyou-fullscreen").style.display = "flex";
                window.scrollTo(0,0);
                // Főoldalra vissza gomb SPA élmény
                const backBtn = document.querySelector("#thankyou-fullscreen a.btn");
                if (backBtn) {
                  backBtn.addEventListener("click", function(ev) {
                    ev.preventDefault();
                    document.getElementById("thankyou-fullscreen").style.display = "none";
                    document.getElementById("welcome-screen").style.display = "";
                    document.body.style.overflow = "auto";
                    window.scrollTo(0,0);
                  });
                }
                return;
              }
              const form = document.getElementById(FORM_ID);
              setFormData(form, res.data);
              showLink(session_id);
              // --- ADMINVIEW: minden mező readonly/disabled, mentés/véglegesítés gombok elrejtése ---
              if (adminView) {
                form.querySelectorAll('input, select, textarea, button').forEach(el => {
                  if (el.type === "checkbox" || el.type === "radio") {
                    el.disabled = true;
                  } else if (el.tagName === "SELECT" || el.tagName === "TEXTAREA") {
                    el.disabled = true;
                  } else if (["text","number","email","url","tel"].includes(el.type)) {
                    el.readOnly = true;
                  } else if (el.type === "submit" || el.type === "button") {
                    el.style.display = "none";
                  }
                });
                // Manuális mentés gomb elrejtése
                const saveBtn = document.getElementById("mtmi-save-btn");
                if (saveBtn) saveBtn.style.display = "none";
                // Véglegesítés gomb elrejtése
                const submitBtn = form.querySelector("button[type='submit']");
                if (submitBtn) submitBtn.style.display = "none";
              }
          }
      } catch (e) {
          // Nincs adat vagy hiba
      }
  }

  // Toast üzenet (Bootstrap 5)
  function showToast(msg, type="info") {
      let toast = document.getElementById("mtmi-toast");
      if (!toast) {
          toast = document.createElement("div");
          toast.id = "mtmi-toast";
          toast.className = "toast align-items-center text-bg-"+type+" border-0 position-fixed bottom-0 end-0 m-4";
          toast.style.zIndex = 9999;
          toast.innerHTML = `<div class="d-flex"><div class="toast-body"></div><button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button></div>`;
          document.body.appendChild(toast);
      }
      toast.querySelector(".toast-body").textContent = msg;
      const bsToast = new bootstrap.Toast(toast, { delay: 2500 });
      bsToast.show();
  }

  // Események bekötése
  window.addEventListener("DOMContentLoaded", () => {
      const form = document.getElementById(FORM_ID);
      if (!form) return;
      // Betöltés session_id alapján
      loadForm();
      const session_id = getSessionIdFromUrl() || localStorage.getItem("mtmi_session_id");
      if (session_id) {
        const welcome = document.getElementById("welcome-screen");
        const mainForm = document.getElementById("main-form-content");
        if (welcome) welcome.style.display = "none";
        if (mainForm) mainForm.style.display = "";
      }
      // Automatikus mentés minden mező változásakor
      form.addEventListener("input", () => saveForm(true));
      form.addEventListener("change", () => saveForm(true));
      // Manuális mentés gomb hozzáadása
      let saveBtn = document.getElementById("mtmi-save-btn");
      if (!saveBtn) {
          saveBtn = document.createElement("button");
          saveBtn.id = "mtmi-save-btn";
          saveBtn.type = "button";
          saveBtn.className = "btn btn-warning mb-3 me-2";
          saveBtn.textContent = "Mentés";
          form.parentNode.insertBefore(saveBtn, form);
      }
      saveBtn.addEventListener("click", () => saveForm(false));
  });

  document.getElementById("mtmi-form").addEventListener("submit", async function(e) {
    console.log("[SUBMIT] Esemény indult");
    e.preventDefault(); // Mindig az első sor!
    // Gyors fix: minden nem látható mezőről levesszük a required attribútumot
    document.querySelectorAll(".form-step[style*='display: none'] input, .form-step[style*='display: none'] select, .form-step[style*='display: none'] textarea").forEach(el => {
      el.required = false;
    });

    // --- VÉGLEGESÍTÉS: backend submit meghívása ---
    let session_id = localStorage.getItem("mtmi_session_id");
    const urlSession = getSessionIdFromUrl();
    if (urlSession) session_id = urlSession;
    console.log("[SUBMIT] session_id:", session_id);
    if (session_id) {
      try {
        const resp = await fetch(`${API_BASE}/submit/${session_id}`, { method: "POST" });
        console.log("[SUBMIT] Backend válasz status:", resp.status);
        const respText = await resp.text();
        console.log("[SUBMIT] Backend válasz body:", respText);
      } catch (err) {
        console.error("[SUBMIT] Backend submit hiba:", err);
      }
    } else {
      console.warn("[SUBMIT] Nincs session_id!");
    }

    // --- Köszönőképernyő mutatása ---
    // Elrejtem minden fő tartalmat
    document.getElementById("main-form-content").style.display = "none";
    document.getElementById("welcome-screen").style.display = "none";
    if(document.getElementById("step-final")) document.getElementById("step-final").style.display = "block";
    document.getElementById("thankyou-fullscreen").style.display = "flex";
    document.body.style.overflow = "auto";
    window.scrollTo(0,0);

    // DOM állapot logolása
    console.log("[SUBMIT] main-form-content display:", document.getElementById("main-form-content").style.display);
    console.log("[SUBMIT] welcome-screen display:", document.getElementById("welcome-screen").style.display);
    console.log("[SUBMIT] step-final display:", document.getElementById("step-final") ? document.getElementById("step-final").style.display : "nincs");
    console.log("[SUBMIT] thankyou-fullscreen display:", document.getElementById("thankyou-fullscreen").style.display);

    // Főoldalra vissza gomb SPA élmény
    const backBtn = document.querySelector("#thankyou-fullscreen a.btn");
    if (backBtn) {
      backBtn.addEventListener("click", function(ev) {
        ev.preventDefault();
        document.getElementById("thankyou-fullscreen").style.display = "none";
        document.getElementById("welcome-screen").style.display = "";
        document.body.style.overflow = "auto";
        window.scrollTo(0,0);
      });
    }
  });
}); 

function updateRequiredAttributes() {
  document.querySelectorAll(".form-step").forEach(step => {
    const visible = step.style.display !== "none";
    step.querySelectorAll("input, select, textarea").forEach(el => {
      if (visible) {
        // Csak akkor legyen required, ha eredetileg is az volt (opcionális finomítás)
        if (el.dataset.originalRequired === "true") el.required = true;
      } else {
        el.required = false;
      }
    });
  });
}

// Eredeti required attribútumok mentése (egyszer, DOMContentLoaded-nál)
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("input, select, textarea").forEach(el => {
    el.dataset.originalRequired = el.required ? "true" : "false";
  });
  updateRequiredAttributes();
}); 

document.querySelector("button[type='submit']").addEventListener("click", updateRequiredAttributes); 

// --- Vissza a főoldalra gomb mindenhol ---
function setupBackToWelcome(selector) {
  const backBtn = document.querySelector(selector);
  if (backBtn) {
    backBtn.addEventListener("click", function(ev) {
      ev.preventDefault();
      if(document.getElementById("main-form-content")) document.getElementById("main-form-content").style.display = "none";
      if(document.getElementById("thankyou-fullscreen")) document.getElementById("thankyou-fullscreen").style.display = "none";
      // Welcome screen mutatása
      document.getElementById("welcome-screen").style.display = "";
      if(document.getElementById("main-form-content")) document.getElementById("main-form-content").style.display = "none"; // <-- ÚJ: mindig elrejtjük
      document.body.style.overflow = "auto";
      window.scrollTo(0,0);
    });
  }
}

// Események bekötése a vissza gombokra (DOMContentLoaded után)
document.addEventListener("DOMContentLoaded", () => {
  setupBackToWelcome("#thankyou-fullscreen a.btn");
  // Üdvözlőképernyőnél mindig elrejtjük a formot
  if(document.getElementById("welcome-screen") && document.getElementById("main-form-content")) {
    if(document.getElementById("welcome-screen").style.display !== "none") {
      document.getElementById("main-form-content").style.display = "none";
    }
  }
  // Welcome screen induláskor: body scroll engedélyezése
  if(document.getElementById("welcome-screen") && document.getElementById("welcome-screen").style.display !== "none") {
    document.body.style.overflow = "auto";
  }
}); 

document.addEventListener("click", function(ev) {
  if (ev.target.matches("#thankyou-fullscreen a.btn")) {
    ev.preventDefault();
    if(document.getElementById("main-form-content")) document.getElementById("main-form-content").style.display = "none";
    if(document.getElementById("thankyou-fullscreen")) document.getElementById("thankyou-fullscreen").style.display = "none";
    document.getElementById("welcome-screen").style.display = "";
    if(document.getElementById("main-form-content")) document.getElementById("main-form-content").style.display = "none"; // <-- ÚJ: mindig elrejtjük
    document.body.style.overflow = "auto";
    window.scrollTo(0,0);
  }
}); 

// --- Eredmények letöltése gomb a köszönőképernyőn ---
document.addEventListener("DOMContentLoaded", () => {
  const downloadBtn = document.getElementById("download-results-btn");
  if (downloadBtn) {
    downloadBtn.addEventListener("click", async function() {
      let session_id = localStorage.getItem("mtmi_session_id");
      const urlSession = getSessionIdFromUrl();
      if (urlSession) session_id = urlSession;
      if (!session_id) {
        alert("Nincs session_id, nem tudom letölteni az eredményeket.");
        return;
      }
      // Lekérjük a backendről az összes választ
      const resp = await fetch(`${API_BASE}/load/${session_id}`);
      if (!resp.ok) {
        alert("Nem sikerült letölteni az eredményeket a szerverről.");
        return;
      }
      const res = await resp.json();
      const data = res.data;
      // Lemásoljuk az eredeti űrlap HTML-t
      const form = document.getElementById("mtmi-form");
      if (!form) {
        alert("Nem található az űrlap a DOM-ban.");
        return;
      }
      // Klónozzuk a form tartalmát
      const formClone = form.cloneNode(true);
      // Kitöltjük a mezőket a válaszokkal (minden input/select/textarea)
      formClone.querySelectorAll('input, select, textarea').forEach(el => {
        const key = el.name;
        if (!key) return;
        const value = data[key];
        console.log('[Összefoglaló kitöltés]', {name: key, type: el.type, tag: el.tagName, backendValue: value});
        if (typeof value === 'undefined') return;
        if (el.type === "checkbox") {
          if (Array.isArray(value)) {
            el.checked = value.includes(el.value);
          } else {
            el.checked = (el.value == value);
          }
          el.disabled = true;
        } else if (el.type === "radio") {
          el.checked = (el.value == value);
          el.disabled = true;
        } else if (el.tagName === "SELECT") {
          el.value = value;
          el.disabled = true;
        } else if (el.tagName === "TEXTAREA") {
          el.value = value;
          el.readOnly = true;
        } else if (el.type === "text" || el.type === "number" || el.type === "email" || el.type === "url" || el.type === "tel") {
          el.value = value;
          el.readOnly = true;
        }
      });
      // Minden feltételes/dinamikus blokkot láthatóvá teszünk
      formClone.querySelectorAll('[style*="display: none"]').forEach(el => { el.style.display = ''; });
      // Eltávolítjuk a steppereket, navigációt, gombokat
      formClone.querySelectorAll('.stepper-sidebar, .stepper, .stepper-vertical, .stepper-link, .prev-step, .next-step, button[type="submit"], #thankyou-placeholder, #thankyou-fullscreen, #mtmi-save-btn, .progress, #form-progress, #progress-percent').forEach(el => el.remove());
      // Minden .form-step-et láthatóvá teszünk
      formClone.querySelectorAll('.form-step').forEach(el => { el.style.display = ''; el.classList.remove('animate__animated', 'animate__fadeIn', 'animate__fadeInRight', 'animate__fadeInLeft', 'animate__fadeOutLeft', 'animate__fadeOutRight'); });
      // Teljes HTML oldal generálása
      let html = `<html><head><meta charset='utf-8'><title>MTMI űrlap eredmények</title>`;
      // Bootstrap és saját CSS beillesztése
      html += `<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css' rel='stylesheet'>`;
      html += `<link rel='stylesheet' href='/style.css'>`;
      html += `</head><body class='bg-light'><div class='container py-5'>`;
      html += `<h1 class='mb-4 text-center fw-bold'>MTMI Iskola Program<br><span class='text-primary'>Pályázati űrlap (összefoglaló)</span></h1>`;
      html += formClone.innerHTML;
      html += `</div><script>window.addEventListener('DOMContentLoaded', function() {\n  const data = ${JSON.stringify(data)};\n  document.querySelectorAll('input, select, textarea').forEach(function(el) {\n    const key = el.name;\n    if (!key) return;\n    const value = data[key];\n    if (typeof value === 'undefined') return;\n    if (el.type === "checkbox") {\n      if (Array.isArray(value)) {\n        el.checked = value.includes(el.value);\n      } else {\n        el.checked = (el.value == value);\n      }\n      el.disabled = true;\n    } else if (el.type === "radio") {\n      el.checked = (el.value == value);\n      el.disabled = true;\n    } else if (el.tagName === "SELECT") {\n      el.value = value;\n      el.disabled = true;\n    } else if (el.tagName === "TEXTAREA") {\n      el.value = value;\n      el.readOnly = true;\n    } else if (["text","number","email","url","tel"].includes(el.type)) {\n      el.value = value;\n      el.readOnly = true;\n    }\n  });\n});<\/script></body></html>`;
      // Új ablakban nyitjuk meg a nyomtatható nézetet
      const printWindow = window.open("", "_blank");
      printWindow.document.write(html);
      printWindow.document.close();
    });
  }
}); 
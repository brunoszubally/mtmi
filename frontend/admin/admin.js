// API_BASE dinamikus meghatározása
const API_BASE = "/api";

// --- Admin session kezelés ---
function setAdminSession(loggedIn) {
  if (loggedIn) {
    localStorage.setItem("mtmi_admin_logged_in", "1");
  } else {
    localStorage.removeItem("mtmi_admin_logged_in");
  }
}
function isAdminLoggedIn() {
  return localStorage.getItem("mtmi_admin_logged_in") === "1";
}

function utcIsoToDatetimeLocalBp(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  const parts = new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Europe/Budapest",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  }).formatToParts(d);
  const map = Object.fromEntries(parts.map(p => [p.type, p.value]));
  return `${map.year}-${map.month}-${map.day}T${map.hour}:${map.minute}`;
}

function renderSubmissionStatusText(status) {
  const map = {
    open: "Nyitott",
    countdown: "Nyitott (visszaszámláló)",
    review: "Bírálat zajlik / lezárva",
    preopen: "Még nem nyílt meg"
  };
  const label = map[status.status] || status.status;
  const countdown = status.countdown_days_left ? ` | Hátralévő napok: ${status.countdown_days_left}` : "";
  return `Állapot: ${label} | Mód: ${status.mode}${countdown} | Üzenet: ${status.message}`;
}

async function loadSubmissionWindowSettings() {
  try {
    const resp = await fetch(`${API_BASE}/admin/submission-window`);
    if (!resp.ok) return;
    const status = await resp.json();

    const modeEl = document.getElementById("submission-mode");
    const startEl = document.getElementById("submission-start-at");
    const endEl = document.getElementById("submission-end-at");
    const statusEl = document.getElementById("submission-window-status");
    if (!modeEl || !startEl || !endEl || !statusEl) return;

    modeEl.value = status.mode || "auto";
    startEl.value = utcIsoToDatetimeLocalBp(status.start_at);
    endEl.value = utcIsoToDatetimeLocalBp(status.end_at);
    statusEl.textContent = renderSubmissionStatusText(status);
  } catch (e) {
    console.error("Submission window load error:", e);
  }
}

async function saveSubmissionWindowSettings() {
  const modeEl = document.getElementById("submission-mode");
  const startEl = document.getElementById("submission-start-at");
  const endEl = document.getElementById("submission-end-at");
  const errorEl = document.getElementById("submission-window-error");
  const statusEl = document.getElementById("submission-window-status");
  if (!modeEl || !startEl || !endEl || !errorEl || !statusEl) return;

  errorEl.style.display = "none";
  const body = {
    mode: modeEl.value,
    start_at: startEl.value || null,
    end_at: endEl.value || null
  };

  try {
    const resp = await fetch(`${API_BASE}/admin/submission-window`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
    const json = await resp.json();
    if (!resp.ok) {
      errorEl.textContent = json.detail || "Mentési hiba.";
      errorEl.style.display = "block";
      return;
    }

    statusEl.textContent = renderSubmissionStatusText(json);
    await loadSubmissionWindowSettings();
  } catch (e) {
    errorEl.textContent = "Hálózati hiba.";
    errorEl.style.display = "block";
  }
}

function showAdminListBlock() {
  document.getElementById("admin-login-block").style.display = "none";
  const listBlock = document.getElementById("admin-list-block");
  listBlock.style.display = "";
  listBlock.classList.add("wide-admin");
  const listCard = document.querySelector(".admin-list-card");
  if (listCard) listCard.classList.add("wide-admin");
  loadAdminList();
  loadSchoolsList();
  console.log("Lista nézet: osztályok", listBlock, listCard);
}
function showAdminLoginBlock() {
  const listBlock = document.getElementById("admin-list-block");
  listBlock.style.display = "none";
  listBlock.classList.remove("wide-admin");
  const listCol = document.querySelector(".admin-list-col");
  if (listCol) listCol.classList.remove("wide-admin");
  const listCard = document.querySelector(".admin-list-card");
  if (listCard) listCard.classList.remove("wide-admin");
  document.getElementById("admin-login-block").style.display = "";
  document.getElementById("admin-login-form").reset();
  console.log("Login nézet: osztályok", listBlock, listCol, listCard);
}

// --- Oldal betöltéskor: ha már be van lépve, automatikusan a listát mutatjuk ---
document.addEventListener("DOMContentLoaded", function () {
  if (isAdminLoggedIn()) {
    showAdminListBlock();
  } else {
    showAdminLoginBlock();
  }
});

// --- Admin login ---
document.getElementById("admin-login-form").addEventListener("submit", async function (e) {
  e.preventDefault();
  const user = document.getElementById("admin-username").value.trim();
  const pw = document.getElementById("admin-password").value;
  // Csak "admin" felhasználónév engedélyezett
  if (user !== "admin") {
    document.getElementById("admin-login-error").textContent = "Hibás felhasználónév vagy jelszó!";
    document.getElementById("admin-login-error").style.display = "block";
    return;
  }
  const resp = await fetch(`${API_BASE}/admin/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ password: pw })
  });
  const res = await resp.json();
  if (res.success) {
    setAdminSession(true);
    showAdminListBlock();
  } else {
    setAdminSession(false);
    document.getElementById("admin-login-error").textContent = "Hibás felhasználónév vagy jelszó!";
    document.getElementById("admin-login-error").style.display = "block";
  }
});

// --- Kilépés gomb ---
document.addEventListener("DOMContentLoaded", function () {
  const logoutBtn = document.getElementById("admin-logout-btn");
  if (logoutBtn) {
    logoutBtn.addEventListener("click", function () {
      setAdminSession(false);
      showAdminLoginBlock();
    });
  }


});

let deleteSessionId = null;
let adminFormRows = [];
const selectedFormIds = new Set();
const ADMIN_LINK_KEY_RE = /^(.*_link)(\d+)$/;
let adminSchoolsRows = [];

function getFormsFilterState() {
  const q = (document.getElementById("forms-search-input")?.value || "").trim().toLowerCase();
  const status = document.getElementById("forms-status-filter")?.value || "all";
  return { q, status };
}

function getSchoolsFilterState() {
  const q = (document.getElementById("schools-search-input")?.value || "").trim().toLowerCase();
  const status = document.getElementById("schools-status-filter")?.value || "all";
  return { q, status };
}

function setStatValue(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = String(value);
}

function refreshAdminStats() {
  const formsTotal = adminFormRows.length;
  const formsSubmitted = adminFormRows.filter((r) => Number(r.submitted) === 1).length;
  const formsProgress = formsTotal - formsSubmitted;
  const schoolsTotal = adminSchoolsRows.length;

  setStatValue("admin-stat-forms-total", formsTotal);
  setStatValue("admin-stat-forms-submitted", formsSubmitted);
  setStatValue("admin-stat-forms-progress", formsProgress);
  setStatValue("admin-stat-schools-total", schoolsTotal);
}

function getSelectedFormIds() {
  return Array.from(selectedFormIds);
}

function updateBulkToolbarState() {
  const selectedCount = selectedFormIds.size;
  const selectedCountEl = document.getElementById("bulk-selected-count");
  if (selectedCountEl) selectedCountEl.textContent = String(selectedCount);
  [
    "bulk-export-selected-btn",
    "bulk-mark-submitted-btn",
    "bulk-mark-inprogress-btn",
    "bulk-delete-selected-btn"
  ].forEach((id) => {
    const btn = document.getElementById(id);
    if (btn) btn.disabled = selectedCount === 0;
  });
}

function setFormSelected(formId, checked) {
  if (checked) selectedFormIds.add(formId);
  else selectedFormIds.delete(formId);
  const checkboxes = Array.from(document.querySelectorAll('#admin-list-tbody input[type="checkbox"][data-session-id]'));
  const selectAll = document.getElementById("admin-select-all-forms");
  if (selectAll && checkboxes.length) {
    selectAll.checked = checkboxes.every((cb) => selectedFormIds.has(cb.dataset.sessionId));
  }
  updateBulkToolbarState();
}

function resetFormSelections() {
  selectedFormIds.clear();
  const selectAll = document.getElementById("admin-select-all-forms");
  if (selectAll) selectAll.checked = false;
  updateBulkToolbarState();
}

function collectIndexedLinkGroups(data) {
  const groups = {};
  Object.entries(data || {}).forEach(([key, value]) => {
    const m = key.match(ADMIN_LINK_KEY_RE);
    if (!m) return;
    const base = m[1];
    const idx = parseInt(m[2], 10);
    if (!groups[base]) groups[base] = [];
    if (typeof value === "string" && value.trim() !== "") {
      groups[base].push({ idx, url: value.trim() });
    }
  });
  Object.keys(groups).forEach(base => {
    groups[base].sort((a, b) => a.idx - b.idx);
  });
  return groups;
}

function addIndexedLinksToSummary(formClone, data) {
  const groups = collectIndexedLinkGroups(data);
  Object.entries(groups).forEach(([base, links]) => {
    const firstInput = formClone.querySelector(`input[type="url"][name="${base}"]`);
    if (!firstInput || links.length === 0) return;

    // Az első link marad az eredeti mezőben
    firstInput.value = links[0].url;

    // A többi linket listázzuk alatta kattinthatóan
    if (links.length > 1) {
      const list = document.createElement("div");
      list.className = "admin-indexed-links mt-2";
      links.forEach((item, i) => {
        const row = document.createElement("div");
        const a = document.createElement("a");
        a.href = item.url;
        a.target = "_blank";
        a.rel = "noopener noreferrer";
        a.textContent = `${base}${i + 1}: ${item.url}`;
        row.appendChild(a);
        list.appendChild(row);
      });
      firstInput.insertAdjacentElement("afterend", list);
    } else {
      const single = document.createElement("div");
      single.className = "admin-indexed-links mt-2";
      const a = document.createElement("a");
      a.href = links[0].url;
      a.target = "_blank";
      a.rel = "noopener noreferrer";
      a.textContent = links[0].url;
      single.appendChild(a);
      firstInput.insertAdjacentElement("afterend", single);
    }
  });
}

// --- Kitöltések listázása ---
function renderAdminFormsTable(rows) {
  const tbody = document.getElementById("admin-list-tbody");
  tbody.innerHTML = "";
  for (const row of rows) {
    const tr = document.createElement("tr");
    const tdSelect = document.createElement("td");
    const selectBox = document.createElement("input");
    selectBox.type = "checkbox";
    selectBox.className = "form-check-input";
    selectBox.dataset.sessionId = row.id;
    selectBox.addEventListener("change", () => setFormSelected(row.id, selectBox.checked));
    tdSelect.appendChild(selectBox);
    tr.appendChild(tdSelect);

    // Iskola neve kattintható
    const tdNev = document.createElement("td");
    const link = document.createElement("a");
    link.href = "#";
    link.textContent = row.iskola_nev;
    link.addEventListener("click", function (ev) {
      ev.preventDefault();
      showSummary(row.id);
    });
    tdNev.appendChild(link);
    tr.appendChild(tdNev);
    // Dátum
    const tdDatum = document.createElement("td");
    tdDatum.textContent = row.created_at ? new Date(row.created_at).toLocaleString("hu-HU") : "";
    tr.appendChild(tdDatum);
    // Státusz
    const tdStatus = document.createElement("td");
    tdStatus.innerHTML = renderStatusIcon(row.submitted);
    tr.appendChild(tdStatus);
    // PDF ikon
    const tdPdf = document.createElement("td");
    if (row.has_pdf) {
      const pdfLink = document.createElement("a");
      pdfLink.href = `${API_BASE.replace('/api', '')}/uploads/${row.id}_*.pdf`;
      pdfLink.target = "_blank";
      pdfLink.innerHTML = '<i class="bi bi-file-earmark-pdf text-danger"></i>';
      pdfLink.title = "PDF megtekintése";
      pdfLink.style.cursor = "pointer";
      pdfLink.addEventListener("click", function (e) {
        e.preventDefault();
        // Lekérjük a pontos PDF fájl nevét
        fetch(`${API_BASE}/admin/result/${row.id}`)
          .then(resp => resp.json())
          .then(data => {
            if (data.pdf_file_path) {
              // FTP szerver URL használata
              const pdfUrl = `https://mtmi-iskola.hu/fileupload/${data.pdf_file_path}`;
              console.log("PDF URL:", pdfUrl);
              window.open(pdfUrl, '_blank');
            } else {
              alert("PDF fájl nem található!");
            }
          })
          .catch(err => {
            console.error("Hiba a PDF lekérdezése során:", err);
            alert("Hiba a PDF megnyitása során!");
          });
      });
      tdPdf.appendChild(pdfLink);
    } else {
      tdPdf.innerHTML = '<i class="bi bi-file-earmark-pdf text-muted"></i>';
      tdPdf.title = "Nincs PDF";
    }
    tr.appendChild(tdPdf);

    // Export gombok
    const tdExcel = document.createElement("td");
    tdExcel.className = "text-nowrap";
    const excelBtn = document.createElement("button");
    excelBtn.className = "btn btn-outline-success btn-sm";
    excelBtn.innerHTML = '<i class="bi bi-file-earmark-excel"></i>';
    excelBtn.title = "Excel export";
    excelBtn.addEventListener("click", function () {
      exportSingleToExcel(row.id);
    });
    tdExcel.appendChild(excelBtn);
    tr.appendChild(tdExcel);

    // ÚJ: Megtekintés gomb
    const tdView = document.createElement("td");
    const viewBtn = document.createElement("a");
    viewBtn.href = `/kitoltes/${row.id}?adminview=1`;
    viewBtn.target = "_blank";
    viewBtn.className = "btn btn-outline-primary btn-sm";
    viewBtn.textContent = "Megnyitás";
    tdView.appendChild(viewBtn);
    tr.appendChild(tdView);
    // ÚJ: Törlés gomb
    const tdDelete = document.createElement("td");
    const deleteBtn = document.createElement("button");
    deleteBtn.className = "btn btn-outline-danger btn-sm";
    deleteBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-trash" viewBox="0 0 16 16"><path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5.5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6zm3 .5a.5.5 0 0 1 .5-.5.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6zm-7-1A1.5 1.5 0 0 1 5.5 4h5A1.5 1.5 0 0 1 12 5.5V6h1a.5.5 0 0 1 0 1h-1v6A2.5 2.5 0 0 1 8.5 15h-3A2.5 2.5 0 0 1 3 13V7H2a.5.5 0 0 1 0-1h1v-.5zM5.5 5a.5.5 0 0 0-.5.5V6h6v-.5a.5.5 0 0 0-.5-.5h-5z"/></svg>';
    deleteBtn.title = "Törlés";
    deleteBtn.addEventListener("click", function () {
      deleteSessionId = row.id;
      const modal = new bootstrap.Modal(document.getElementById('deleteConfirmModal'));
      modal.show();
    });
    tdDelete.appendChild(deleteBtn);
    tr.appendChild(tdDelete);
    tbody.appendChild(tr);
  }
}

function applyFormsFilters() {
  const { q, status } = getFormsFilterState();
  const filtered = adminFormRows.filter((row) => {
    const matchesText = !q || String(row.iskola_nev || "").toLowerCase().includes(q);
    const isSubmitted = Number(row.submitted) === 1;
    const matchesStatus =
      status === "all" ||
      (status === "submitted" && isSubmitted) ||
      (status === "in_progress" && !isSubmitted);
    return matchesText && matchesStatus;
  });
  resetFormSelections();
  renderAdminFormsTable(filtered);
}

async function loadAdminList() {
  const resp = await fetch(`${API_BASE}/admin/list`);
  const list = await resp.json();
  adminFormRows = Array.isArray(list) ? list : [];
  if (!Array.isArray(list)) {
    alert("Nem sikerült betölteni a kitöltéseket.");
  }
  refreshAdminStats();
  applyFormsFilters();
}

// Modal megerősítés gomb esemény
if (document.getElementById('confirmDeleteBtn')) {
  document.getElementById('confirmDeleteBtn').addEventListener('click', async function () {
    if (deleteSessionId) {
      const resp = await fetch(`${API_BASE}/admin/delete/${deleteSessionId}`, { method: "DELETE" });
      if (resp.ok) {
        // Modal bezárása
        const modal = bootstrap.Modal.getInstance(document.getElementById('deleteConfirmModal'));
        modal.hide();
        loadAdminList();
      } else {
        alert("Hiba történt a törlés során!");
      }
      deleteSessionId = null;
    }
  });
}

// --- Státusz ikon renderelése ---
function renderStatusIcon(submitted) {
  if (submitted) {
    return `<span class="status-badge submitted">
      <svg width="18" height="18" fill="none"><circle cx="9" cy="9" r="9" fill="#d1e7dd"/><path d="M5 9.5l3 3 5-6" stroke="#198754" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
      Véglegesítve
    </span>`;
  } else {
    return `<span class="status-badge inprogress">
      <svg width="18" height="18" fill="none"><circle cx="9" cy="9" r="9" fill="#eee"/><path d="M9 5v4l2.5 2.5" stroke="#888" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
      Folyamatban
    </span>`;
  }
}

// --- Összefoglaló nézet megjelenítése ---
async function showSummary(session_id) {
  const resp = await fetch(`${API_BASE}/admin/result/${session_id}`);
  if (!resp.ok) {
    alert("Nem sikerült letölteni az eredményeket a szerverről.");
    return;
  }
  const res = await resp.json();
  const data = res.data;
  // Lemásoljuk az eredeti űrlap HTML-t (feltételezzük, hogy az index.html elérhető)
  const formHtmlResp = await fetch("/index.html");
  const formHtmlText = await formHtmlResp.text();
  // Kinyerjük a <form id="mtmi-form">...</form> tartalmát
  const formMatch = formHtmlText.match(/<form[^>]*id=["']mtmi-form["'][^>]*>([\s\S]*?)<\/form>/);
  if (!formMatch) {
    alert("Nem található az űrlap HTML a forrásban.");
    return;
  }
  const formInner = formMatch[1];
  // Létrehozunk egy dummy formot a DOM-ban, hogy ki tudjuk tölteni
  const dummyDiv = document.createElement("div");
  dummyDiv.innerHTML = `<form id='mtmi-form'>${formInner}</form>`;
  const formClone = dummyDiv.querySelector("#mtmi-form");
  // Az indexed link mezők (_link1.._link10) megjelenítése az összefoglalóban
  addIndexedLinksToSummary(formClone, data);

  // Kitöltjük a mezőket a válaszokkal (ugyanaz a logika, mint a letöltésnél)
  formClone.querySelectorAll('input, select, textarea').forEach(el => {
    const key = el.name;
    if (!key) return;
    const value = data[key];
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
    } else if (["text", "number", "email", "url", "tel"].includes(el.type)) {
      el.value = value;
      el.readOnly = true;
    }
  });
  // Minden feltételes/dinamikus blokkot láthatóvá teszünk
  formClone.querySelectorAll('[style*="display: none"]').forEach(el => { el.style.display = ''; });
  // Eltávolítjuk a steppereket, navigációt, gombokat és PDF feltöltési szekciót
  formClone.querySelectorAll('.stepper-sidebar, .stepper, .stepper-vertical, .stepper-link, .prev-step, .next-step, button[type="submit"], #thankyou-placeholder, #thankyou-fullscreen, #mtmi-save-btn, .progress, #form-progress, #progress-percent, #pdf-upload, #pdf-upload-btn, #pdf-filename, #pdf-preview, #pdf-remove-btn, #pdf-upload-progress, #pdf-upload-status, #finalize-btn').forEach(el => el.remove());
  // Minden .form-step-et láthatóvá teszünk
  formClone.querySelectorAll('.form-step').forEach(el => { el.style.display = ''; el.classList.remove('animate__animated', 'animate__fadeIn', 'animate__fadeInRight', 'animate__fadeInLeft', 'animate__fadeOutLeft', 'animate__fadeOutRight'); });
  // Teljes HTML oldal generálása
  let html = `<html><head><meta charset='utf-8'><title>MTMI űrlap eredmények</title>`;
  html += `<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css' rel='stylesheet'>`;
  html += `<link href='https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css' rel='stylesheet'>`;
  html += `<link rel='stylesheet' href='/style.css'>`;
  html += `<style>
    #print-wrapper {
      width: 21cm;
      margin: 0 auto;
      background: white;
      padding: 1cm;
    }
    body {
      display: flex;
      justify-content: center;
      align-items: flex-start;
      background: #e0e0e0;
    }
    .container {
      max-width: 800px !important;
      width: 100%;
    }
    /* Az összefoglaló nézetben eltávolítjuk a min-height-ot és a felesleges térközöket */
    .form-step {
      min-height: auto !important;
    }
    #step-final {
      padding-bottom: 0 !important;
      margin-bottom: 0 !important;
    }
    #step-final .mb-4, #step-final .mb-5 {
      margin-bottom: 1rem !important;
    }
    /* Textarea automatikus méretezése a tartalomhoz */
    textarea {
      resize: none !important;
      min-height: 100px !important;
      overflow: visible !important;
      width: 100%;
      box-sizing: border-box;
    }
    /* Hosszú szövegek esetén automatikus magasság beállítása */
    textarea[readonly] {
      height: auto !important;
      min-height: 100px;
      overflow: visible !important;
    }
    /* JavaScript által beállított magasság felülírja a CSS-t */
    textarea[style*="height"] {
      height: inherit !important;
    }
    /* Inline height felülírja minden mást */
    textarea[style*="height:"] {
      height: inherit !important;
      min-height: inherit !important;
    }
    @media print {
      @page {
        margin: 0;
        size: A4;
      }
      body {
        background: white;
        margin: 0;
        padding: 0;
      }
      #print-wrapper {
        width: 21cm;
        margin: 0;
        padding: 1cm;
      }
      .btn, button, a.btn {
        display: none !important;
      }
      .text-center.mb-3, .text-center.mb-4 {
        display: none !important;
      }
      .container {
        max-width: 100% !important;
        width: 100%;
        padding: 0 !important;
        margin: 0 !important;
      }
      textarea {
        overflow: visible !important;
        white-space: pre-wrap !important;
        word-wrap: break-word !important;
        page-break-inside: auto !important;
        border: 1px solid #dee2e6 !important;
        padding: 0.375rem 0.75rem !important;
      }
      .form-control:not(textarea), .form-select, .form-check {
        page-break-inside: avoid;
      }
      .stepper, .stepper-sidebar, .progress, .next-step, .prev-step {
        display: none !important;
      }
    }
  </style>`;
  html += `</head><body class='bg-light'><div id="print-wrapper"><div class='container py-5'>`;
  // PDF link hozzáadása, ha van
  let pdfLinkHtml = '';
  if (res.pdf_file_path) {
    const pdfUrl = `https://mtmi-iskola.hu/fileupload/${res.pdf_file_path}`;
    pdfLinkHtml = `
      <div class="text-center mb-4">
        <a href="${pdfUrl}" target="_blank" class="btn btn-outline-danger">
          <i class="bi bi-file-earmark-pdf"></i> PDF megtekintése
        </a>
      </div>
    `;
  }

  html += `<h1 class='mb-4 text-center fw-bold'>MTMI Iskola Program<br><span class='text-primary'>Pályázati űrlap (összefoglaló)</span></h1>`;

  // Print gomb hozzáadása
  html += `
    <div class="text-center mb-3">
      <button onclick="window.print()" class="btn btn-primary btn-lg">
        <i class="bi bi-printer"></i> Nyomtatás
      </button>
    </div>
  `;

  html += formClone.innerHTML;
  // PDF link a form után, de még a container-en belül
  if (res.pdf_file_path) {
    const pdfUrl = `https://mtmi-iskola.hu/fileupload/${res.pdf_file_path}`;
    html += `
      <div class="text-center mt-4 mb-4">
        <a href="${pdfUrl}" target="_blank" class="btn btn-outline-danger btn-lg">
          <i class="bi bi-file-earmark-pdf"></i> PDF megtekintése
        </a>
      </div>
    `;
  }
  html += `</div></div><script>
    // Azonnal alkalmazzuk a readonly beállításokat
    const data = ${JSON.stringify(data)};
    document.querySelectorAll('input, select, textarea').forEach(function(el) {
      const key = el.name;
      if (!key) return;
      const value = data[key];
      if (typeof value === 'undefined') return;
      if (el.type === "checkbox") {
        if (Array.isArray(value)) {
          el.checked = value.includes(el.value);
        } else {
          el.checked = (el.value == value);
        }
        el.disabled = true;
        el.style.pointerEvents = "none";
      } else if (el.type === "radio") {
        el.checked = (el.value == value);
        el.disabled = true;
        el.style.pointerEvents = "none";
      } else if (el.tagName === "SELECT") {
        el.value = value;
        el.disabled = true;
        el.style.pointerEvents = "none";
      } else if (el.tagName === "TEXTAREA") {
        el.value = value;
        el.readOnly = true;
        el.style.backgroundColor = "#f8f9fa";
        el.style.pointerEvents = "none";
      } else if (["text","number","email","url","tel"].includes(el.type)) {
        el.value = value;
        el.readOnly = true;
        el.style.backgroundColor = "#f8f9fa";
        el.style.pointerEvents = "none";
      }
    });
    // Extra biztonság: minden mező readonly
    setTimeout(function() {
      document.querySelectorAll('input, select, textarea').forEach(function(el) {
        if (el.type === "checkbox" || el.type === "radio") {
          el.disabled = true;
          el.style.pointerEvents = "none";
        } else if (el.tagName === "SELECT") {
          el.disabled = true;
          el.style.pointerEvents = "none";
        } else {
          el.readOnly = true;
          el.style.backgroundColor = "#f8f9fa";
          el.style.pointerEvents = "none";
        }
      });
      
      // Textarea magasság automatikus beállítása a teljes tartalomhoz
      document.querySelectorAll('textarea').forEach(function(textarea) {
        console.log('Textarea:', textarea.name, 'Value length:', textarea.value.length, 'Value:', textarea.value.substring(0, 50) + '...');
        if (textarea.value && textarea.value.trim() !== '') {
          // Ideiglenesen eltávolítjuk a readonly-ot és a height-ot a magasság számításához
          const wasReadonly = textarea.readOnly;
          textarea.readOnly = false;
          
          // Közvetlenül felülírjuk a height-et, nem távolítjuk el
          textarea.style.height = 'auto';
          
          // Dinamikusan számítjuk ki a szükséges magasságot
          const lineHeight = parseInt(window.getComputedStyle(textarea).lineHeight) || 20;
          const textWidth = textarea.offsetWidth - parseInt(window.getComputedStyle(textarea).paddingLeft) - parseInt(window.getComputedStyle(textarea).paddingRight);
          const charWidth = 8; // Becsült karakter szélesség
          const charsPerLine = Math.floor(textWidth / charWidth);
          
          // Sorok számolása a szöveg alapján
          let lines = 1;
          const textLines = textarea.value.split('\\n');
          for (let line of textLines) {
            if (line.length > charsPerLine) {
              lines += Math.ceil(line.length / charsPerLine);
            } else {
              lines += 1;
            }
          }
          
          const padding = parseInt(window.getComputedStyle(textarea).paddingTop) + parseInt(window.getComputedStyle(textarea).paddingBottom) || 16;
          const border = parseInt(window.getComputedStyle(textarea).borderTopWidth) + parseInt(window.getComputedStyle(textarea).borderBottomWidth) || 2;
          
          const calculatedHeight = (lines * lineHeight) + padding + border;
          
          // Beállítjuk a magasságot a számított értékre - erős felülírás
          textarea.style.setProperty('height', calculatedHeight + 'px', 'important');
          console.log('Textarea height set to:', calculatedHeight + 'px', 'for', textarea.name);
          
          // Ellenőrizzük, hogy a magasság ténylegesen beállításra került-e
          setTimeout(() => {
            const actualHeight = textarea.style.height;
            console.log('Actual height after setting:', actualHeight, 'for', textarea.name);
          }, 10);
          
          // Visszaállítjuk a readonly-ot
          textarea.readOnly = wasReadonly;
        }
      });

      // ResizeObserver hozzáadása a textarea-khoz a dinamikus méretezéshez
      const resizeObserver = new ResizeObserver(function(entries) {
        entries.forEach(function(entry) {
          if (entry.target.tagName === 'TEXTAREA') {
            // Újraszámoljuk a magasságot, ha változik a szélesség
            const textarea = entry.target;
            textarea.style.height = 'auto';
            const lineHeight = parseInt(window.getComputedStyle(textarea).lineHeight) || 20;
            const textWidth = textarea.offsetWidth - parseInt(window.getComputedStyle(textarea).paddingLeft) - parseInt(window.getComputedStyle(textarea).paddingRight);
            const charWidth = 8;
            const charsPerLine = Math.floor(textWidth / charWidth);

            let lines = 1;
            const textLines = textarea.value.split('\\n');
            for (let line of textLines) {
              if (line.length > charsPerLine) {
                lines += Math.ceil(line.length / charsPerLine);
              } else {
                lines += 1;
              }
            }

            const padding = parseInt(window.getComputedStyle(textarea).paddingTop) + parseInt(window.getComputedStyle(textarea).paddingBottom) || 16;
            const border = parseInt(window.getComputedStyle(textarea).borderTopWidth) + parseInt(window.getComputedStyle(textarea).borderBottomWidth) || 2;
            const calculatedHeight = (lines * lineHeight) + padding + border;

            textarea.style.setProperty('height', calculatedHeight + 'px', 'important');
          }
        });
      });

      document.querySelectorAll('textarea').forEach(function(textarea) {
        resizeObserver.observe(textarea);
      });
    }, 100);
  </script></body></html>`;
  // Új ablakban nyitjuk meg a nyomtatható nézetet
  const printWindow = window.open("", "_blank");
  printWindow.document.write(html);
  printWindow.document.close();
}

// --- Excel export funkció ---
async function exportToExcel() {
  try {
    // Lekérjük az összes kitöltést
    const resp = await fetch(`${API_BASE}/admin/list`);
    const submissions = await resp.json();

    if (submissions.length === 0) {
      alert('Nincsenek kitöltések az exportáláshoz!');
      return;
    }

    // Excel fájl generálása
    const workbook = XLSX.utils.book_new();

    // Minden kitöltéshez lekérjük a részletes adatokat
    const allData = [];
    const headers = new Set();

    for (const submission of submissions) {
      const detailResp = await fetch(`${API_BASE}/admin/result/${submission.id}`);
      const detail = await detailResp.json();

      // A 'data' objektumból vesszük az űrlap adatokat
      if (detail.data) {
        // Meta adatok hozzáadása
        const fullData = {
          session_id: submission.id,
          iskola_nev: submission.iskola_nev,
          created_at: submission.created_at,
          submitted: submission.submitted,
          has_pdf: submission.has_pdf,
          ...detail.data
        };

        // Minden mezőt hozzáadunk a headers-hez
        Object.keys(fullData).forEach(key => headers.add(key));

        allData.push(fullData);
      }
    }

    // Headers rendezése
    const sortedHeaders = Array.from(headers).sort();

    // Excel adatok előkészítése
    const excelData = [
      sortedHeaders // Fejléc sor
    ];

    // Adatok hozzáadása
    allData.forEach(row => {
      const excelRow = [];
      sortedHeaders.forEach(header => {
        let value = row[header];

        // Array értékek kezelése (pl. checkbox csoportok)
        if (Array.isArray(value)) {
          value = value.join(', ');
        }

        // Undefined értékek kezelése
        if (value === undefined || value === null) {
          value = '';
        }

        excelRow.push(value);
      });
      excelData.push(excelRow);
    });

    // Worksheet létrehozása
    const worksheet = XLSX.utils.aoa_to_sheet(excelData);

    // Oszlop szélességek automatikus beállítása
    const columnWidths = sortedHeaders.map(header => ({
      wch: Math.max(header.length, 15) // Minimum 15 karakter szélesség
    }));
    worksheet['!cols'] = columnWidths;

    // Worksheet hozzáadása a workbook-hoz
    XLSX.utils.book_append_sheet(workbook, worksheet, 'MTMI Kitöltések');

    // Excel fájl letöltése
    const fileName = `mtmi_kitoltesek_${new Date().toISOString().split('T')[0]}.xlsx`;
    XLSX.writeFile(workbook, fileName);

  } catch (error) {
    console.error('Excel export hiba:', error);
    alert('Hiba történt az Excel export során!');
  }
}

// --- Egyetlen kitöltés Excel exportja ---
async function exportSingleToExcel(sessionId) {
  try {
    // Lekérjük a kitöltés részletes adatait
    const resp = await fetch(`${API_BASE}/admin/result/${sessionId}`);
    if (!resp.ok) {
      alert('Nem sikerült letölteni a kitöltés adatait!');
      return;
    }

    const result = await resp.json();
    const data = result.data;

    // Excel fájl generálása
    const workbook = XLSX.utils.book_new();

    // Adatok előkészítése - minden mező külön sorban
    const excelData = [
      ['Mező neve', 'Érték'] // Fejléc
    ];

    // Minden mezőt hozzáadunk (rendezett sorrendben)
    const allFields = [
      // Alapadatok
      'palyazo_iskola_neve', 'iskola_cime', 'telepulesforma', 'iskolatipus',
      'iskola_tanuloi_letszama', 'intezmenytipus_tanuloi_letszama', 'programban_erintett_tanulok_szama',
      'iskola_mtmi_tanari_letszama', 'mtmi_felelos_kapcsolattarto_neve', 'mtmi_felelos_kapcsolattarto_beosztas',
      'mtmi_felelos_kapcsolattarto_telefonszam1', 'mtmi_felelos_kapcsolattarto_telefonszam2',
      'mtmi_felelos_kapcsolattarto_email',

      // MTMI csapat
      'mtmi_csapat_letszam', 'mtmi_csapat_kozos_tevekenyseg', 'mtmi_csapat_kozos_tevekenyseg_link',
      'mtmi_csapat_tag1_nev', 'mtmi_csapat_tag1_szak', 'mtmi_csapat_tag2_nev', 'mtmi_csapat_tag2_szak',
      'mtmi_csapat_tag3_nev', 'mtmi_csapat_tag3_szak', 'mtmi_csapat_tag4_nev', 'mtmi_csapat_tag4_szak',

      // Pedagógiai program
      'pedprog_mtmi_tartalom', 'pedprog_mtmi_leiras', 'pedprog_mtmi_link',
      'mtmi_koncepcio_leiras', 'mtmi_koncepcio_link',

      // MTMI programkínálat
      'mtmi_szakkorok_szama', 'mtmi_szakkor_diakok_szama', 'mtmi_szakkor_tanarok_szama',
      'mtmi_szakkorok_bemutatasa', 'mtmi_szakkorok_link', 'mtmi_fakultaciok_szama',
      'mtmi_fakultaciok_diakok_szama', 'mtmi_egyeb_tevekenysegek_szama',
      'mtmi_egyeb_tevekenysegek_bemutatasa', 'mtmi_egyeb_tevekenysegek_link',
      'mtmi_egyuttmukodes_palyaorientacio', 'mtmi_egyuttmukodes_palyaorientacio_leiras',
      'mtmi_egyeb_palyaorientacios_programok', 'mtmi_egyeb_palyaorientacios_programok_link',

      // MTMI versenyek
      'mtmi_tanulmányi_verseny_reszvetel', 'mtmi_tanulmányi_versenyek_szama',
      'mtmi_tanulmányi_verseny_diakok_szama', 'mtmi_tanulmányi_verseny_tanarok_szama',
      'mtmi_tanulmányi_versenyek_bemutatasa', 'mtmi_tanulmányi_versenyek_link',
      'mtmi_kutatási_verseny_reszvetel', 'mtmi_kutatási_versenyek_szama',
      'mtmi_kutatási_verseny_diakok_szama', 'mtmi_kutatási_verseny_tanarok_szama',
      'mtmi_kutatási_versenyek_bemutatasa', 'mtmi_kutatási_versenyek_link',
      'mtmi_otlet_esszepalyazat_reszvetel', 'mtmi_otlet_esszepalyazat_szama',
      'mtmi_otlet_esszepalyazat_diakok_szama', 'mtmi_otlet_esszepalyazat_tanarok_szama',
      'mtmi_otlet_esszepalyazat_bemutatasa', 'mtmi_otlet_esszepalyazat_link',
      'mtmi_faliujsag_vitrin_reszvetel', 'mtmi_faliujsag_vitrin_bemutatasa',

      // Lányok
      'lanyok_mtmi_kiemelt_figyelem', 'lanyok_mtmi_reszvetel_bemutatasa', 'lanyok_mtmi_reszvetel_link',
      'lanyoknak_szolo_mtmi_programok', 'lanyoknak_szolo_mtmi_programok_bemutatasa', 'lanyoknak_szolo_mtmi_programok_link',
      'lanyok_mtmi_nepszerusito', 'lanyok_mtmi_nepszerusito_bemutatasa', 'lanyok_mtmi_nepszerusito_link',

      // Kapcsolatrendszer
      'mtmi_cegkapcsolat', 'mtmi_cegkapcsolat_bemutatasa', 'mtmi_cegkapcsolat_link',
      'mtmi_egyetem_kapcsolat', 'mtmi_egyetem_kapcsolat_bemutatasa', 'mtmi_egyetem_kapcsolat_link',
      'mtmi_kutatointezet_kapcsolat', 'mtmi_kutatointezet_kapcsolat_bemutatasa', 'mtmi_kutatointezet_kapcsolat_link',
      'mtmi_egyeb_kapcsolat', 'mtmi_egyeb_kapcsolat_bemutatasa', 'mtmi_egyeb_kapcsolat_link',

      // Pedagógusok
      'mtmi_pedagogusok_tovabbkepzes', 'mtmi_pedagogusok_tovabbkepzes_bemutatasa', 'mtmi_pedagogusok_tovabbkepzes_link',
      'mtmi_pedagogusok_teljesitmenyertekeles', 'mtmi_pedagogusok_teljesitmenyertekeles_bemutatasa',
      'mtmi_pedagogusok_teljesitmenyertekeles_link', 'mtmi_egyeb_tovabbkepzesi_programok',

      // GDPR
      'gdpr_consent'
    ];

    // Minden mezőt hozzáadunk a definiált sorrendben
    allFields.forEach(key => {
      let value = data[key];

      // Array értékek kezelése (pl. checkbox csoportok)
      if (Array.isArray(value)) {
        value = value.join(', ');
      }

      // Undefined értékek kezelése
      if (value === undefined || value === null) {
        value = '';
      }

      excelData.push([key, value]);
    });

    // Hozzáadunk minden egyéb mezőt is, ami nem szerepel a listában
    Object.keys(data).forEach(key => {
      if (!allFields.includes(key)) {
        let value = data[key];

        if (Array.isArray(value)) {
          value = value.join(', ');
        }

        if (value === undefined || value === null) {
          value = '';
        }

        excelData.push([key, value]);
      }
    });

    // Worksheet létrehozása
    const worksheet = XLSX.utils.aoa_to_sheet(excelData);

    // Oszlop szélességek beállítása
    worksheet['!cols'] = [
      { wch: 40 }, // Mező neve oszlop
      { wch: 60 }  // Érték oszlop
    ];

    // Worksheet hozzáadása a workbook-hoz
    const iskolaNev = data.palyazo_iskola_neve || 'Ismeretlen';
    const bekuldesDatuma = data.created_at ? new Date(data.created_at).toISOString().split('T')[0] : 'Ismeretlen';
    const sheetName = `${iskolaNev}_${bekuldesDatuma}`.substring(0, 31); // Excel sheet neve max 31 karakter

    XLSX.utils.book_append_sheet(workbook, worksheet, sheetName);

    // Excel fájl letöltése
    const fileName = `${iskolaNev}_${bekuldesDatuma}.xlsx`;
    XLSX.writeFile(workbook, fileName);

  } catch (error) {
    console.error('Egyetlen Excel export hiba:', error);
    alert('Hiba történt az Excel export során!');
  }
}

async function exportSelectedToExcel() {
  const ids = getSelectedFormIds();
  if (!ids.length) return;
  try {
    const workbook = XLSX.utils.book_new();
    for (const sessionId of ids) {
      const resp = await fetch(`${API_BASE}/admin/result/${sessionId}`);
      if (!resp.ok) continue;
      const result = await resp.json();
      const data = result.data || {};
      const rows = [["Mező", "Érték"]];
      Object.keys(data).sort().forEach((key) => {
        let value = data[key];
        if (Array.isArray(value)) value = value.join(", ");
        rows.push([key, value ?? ""]);
      });
      const sheet = XLSX.utils.aoa_to_sheet(rows);
      XLSX.utils.book_append_sheet(workbook, sheet, sessionId.substring(0, 31));
    }
    XLSX.writeFile(workbook, `mtmi_kijelolt_kitoltesek_${new Date().toISOString().slice(0, 10)}.xlsx`);
  } catch (e) {
    console.error("Kijelölt export hiba:", e);
    alert("Hiba történt a kijelölt export során.");
  }
}

async function runBulkAction(action) {
  const ids = getSelectedFormIds();
  if (!ids.length) return;
  const labels = {
    mark_submitted: "beküldöttre állítás",
    mark_in_progress: "folyamatbanra állítás",
    delete: "törlés"
  };
  if (action === "delete" && !confirm(`Biztosan törlöd a kijelölt ${ids.length} kitöltést?`)) return;

  try {
    const resp = await fetch(`${API_BASE}/admin/forms/bulk`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action, session_ids: ids })
    });
    const json = await resp.json().catch(() => ({}));
    if (!resp.ok) {
      alert(json.detail || `Sikertelen ${labels[action]}.`);
      return;
    }
    await loadAdminList();
  } catch (e) {
    console.error("Bulk action hiba:", e);
    alert(`Hiba történt a ${labels[action]} közben.`);
  }
}

// --- Tab váltás kezelése ---
document.addEventListener("DOMContentLoaded", function () {
  const tabs = document.querySelectorAll('#admin-tabs .nav-link');
  tabs.forEach(tab => {
    tab.addEventListener('click', function () {
      // Aktív tab beállítása
      tabs.forEach(t => t.classList.remove('active'));
      this.classList.add('active');
      // Tab tartalom váltás
      const targetId = this.getAttribute('data-tab');
      document.getElementById('forms-tab').style.display = targetId === 'forms-tab' ? '' : 'none';
      document.getElementById('schools-tab').style.display = targetId === 'schools-tab' ? '' : 'none';
      // Iskolák betöltése ha arra a tabra váltunk
      if (targetId === 'schools-tab') {
        loadSchoolsList();
      }
    });
  });

  // "Új iskola" gomb
  const addSchoolBtn = document.getElementById('add-school-btn');
  if (addSchoolBtn) {
    addSchoolBtn.addEventListener('click', function () {
      openSchoolModal(null);
    });
  }

  // School edit save gomb
  const schoolSaveBtn = document.getElementById('school-edit-save-btn');
  if (schoolSaveBtn) {
    schoolSaveBtn.addEventListener('click', saveSchool);
  }

  const submissionSaveBtn = document.getElementById("submission-save-btn");
  if (submissionSaveBtn) {
    submissionSaveBtn.addEventListener("click", saveSubmissionWindowSettings);
  }

  const formsSearchInput = document.getElementById("forms-search-input");
  if (formsSearchInput) formsSearchInput.addEventListener("input", applyFormsFilters);
  const formsStatusFilter = document.getElementById("forms-status-filter");
  if (formsStatusFilter) formsStatusFilter.addEventListener("change", applyFormsFilters);
  const formsClearBtn = document.getElementById("forms-clear-filters-btn");
  if (formsClearBtn) {
    formsClearBtn.addEventListener("click", () => {
      if (formsSearchInput) formsSearchInput.value = "";
      if (formsStatusFilter) formsStatusFilter.value = "all";
      applyFormsFilters();
    });
  }

  const schoolsSearchInput = document.getElementById("schools-search-input");
  if (schoolsSearchInput) schoolsSearchInput.addEventListener("input", applySchoolsFilters);
  const schoolsStatusFilter = document.getElementById("schools-status-filter");
  if (schoolsStatusFilter) schoolsStatusFilter.addEventListener("change", applySchoolsFilters);
  const schoolsClearBtn = document.getElementById("schools-clear-filters-btn");
  if (schoolsClearBtn) {
    schoolsClearBtn.addEventListener("click", () => {
      if (schoolsSearchInput) schoolsSearchInput.value = "";
      if (schoolsStatusFilter) schoolsStatusFilter.value = "all";
      applySchoolsFilters();
    });
  }

  const selectAll = document.getElementById("admin-select-all-forms");
  if (selectAll) {
    selectAll.addEventListener("change", function () {
      document.querySelectorAll('#admin-list-tbody input[type="checkbox"]').forEach((cb) => {
        cb.checked = this.checked;
        const sid = cb.dataset.sessionId;
        if (sid) setFormSelected(sid, this.checked);
      });
      updateBulkToolbarState();
    });
  }

  const bulkExportBtn = document.getElementById("bulk-export-selected-btn");
  if (bulkExportBtn) bulkExportBtn.addEventListener("click", exportSelectedToExcel);
  const bulkSubmittedBtn = document.getElementById("bulk-mark-submitted-btn");
  if (bulkSubmittedBtn) bulkSubmittedBtn.addEventListener("click", () => runBulkAction("mark_submitted"));
  const bulkInprogressBtn = document.getElementById("bulk-mark-inprogress-btn");
  if (bulkInprogressBtn) bulkInprogressBtn.addEventListener("click", () => runBulkAction("mark_in_progress"));
  const bulkDeleteBtn = document.getElementById("bulk-delete-selected-btn");
  if (bulkDeleteBtn) bulkDeleteBtn.addEventListener("click", () => runBulkAction("delete"));

  updateBulkToolbarState();
  loadSubmissionWindowSettings();
});

// --- Iskolák listázása ---
async function loadSchoolsList() {
  try {
    const resp = await fetch(`${API_BASE}/admin/schools`);
    const schools = await resp.json();
    adminSchoolsRows = Array.isArray(schools) ? schools : [];
    refreshAdminStats();
    applySchoolsFilters();
  } catch (e) {
    console.error('Iskolák betöltési hiba:', e);
  }
}

function renderSchoolsTable(schools) {
  const tbody = document.getElementById('schools-list-tbody');
  tbody.innerHTML = '';
  if (schools.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted">Nincs találat a szűrés alapján.</td></tr>';
    return;
  }

  schools.forEach(s => {
      let statusHtml = '<span class="text-muted">Nincs űrlap</span>';
      if (s.form_id) {
        if (s.submitted === 1) {
          statusHtml = '<span class="badge bg-success">Beküldve</span>';
        } else {
          statusHtml = '<span class="badge bg-warning text-dark">Folyamatban</span>';
        }
      }

      let passwordHtml = s.has_password
        ? '<span class="badge bg-success">Beállítva</span>'
        : '<span class="badge bg-secondary">Nincs</span>';

      let emailHtml = s.email || '<span class="text-muted">-</span>';

      tbody.innerHTML += `
        <tr>
          <td>${s.name}</td>
          <td>${emailHtml}</td>
          <td>${passwordHtml}</td>
          <td>${statusHtml}</td>
          <td>
            <button class="btn btn-sm btn-outline-primary me-1" onclick="openSchoolModal('${s.id}', '${s.name.replace(/'/g, "\\'")}', '${(s.email || '').replace(/'/g, "\\'")}')">
              <i class="bi bi-pencil"></i> Szerkesztés
            </button>
            <button class="btn btn-sm btn-outline-danger" onclick="deleteSchool('${s.id}', '${s.name.replace(/'/g, "\\'")}')">
              <i class="bi bi-trash"></i>
            </button>
          </td>
        </tr>
      `;
    });
}

function applySchoolsFilters() {
  const { q, status } = getSchoolsFilterState();
  const filtered = adminSchoolsRows.filter((s) => {
    const text = `${s.name || ""} ${s.email || ""}`.toLowerCase();
    const matchesText = !q || text.includes(q);
    const state = !s.form_id ? "no_form" : (Number(s.submitted) === 1 ? "submitted" : "in_progress");
    const matchesStatus = status === "all" || status === state;
    return matchesText && matchesStatus;
  });
  renderSchoolsTable(filtered);
}

// --- Iskola modal megnyitása ---
function openSchoolModal(id, name, email) {
  const modal = new bootstrap.Modal(document.getElementById('schoolEditModal'));
  const titleEl = document.getElementById('schoolEditModalTitle');
  document.getElementById('school-edit-error').style.display = 'none';

  document.getElementById('school-edit-id').value = id || '';
  document.getElementById('school-edit-name').value = name || '';
  document.getElementById('school-edit-email').value = email || '';
  document.getElementById('school-edit-password').value = '';

  titleEl.textContent = id ? 'Iskola szerkesztése' : 'Új iskola hozzáadása';
  modal.show();
}

// --- Iskola mentése (létrehozás vagy szerkesztés) ---
async function saveSchool() {
  const id = document.getElementById('school-edit-id').value;
  const name = document.getElementById('school-edit-name').value.trim();
  const email = document.getElementById('school-edit-email').value.trim();
  const password = document.getElementById('school-edit-password').value;
  const errorEl = document.getElementById('school-edit-error');
  errorEl.style.display = 'none';

  if (!name) {
    errorEl.textContent = 'Az iskola neve kötelező!';
    errorEl.style.display = 'block';
    return;
  }

  const body = { name, email: email || null, password };

  try {
    let resp;
    if (id) {
      // Szerkesztés
      resp = await fetch(`${API_BASE}/admin/schools/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      });
    } else {
      // Létrehozás
      resp = await fetch(`${API_BASE}/admin/schools`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      });
    }

    if (!resp.ok) {
      const err = await resp.json();
      errorEl.textContent = err.detail || 'Hiba történt!';
      errorEl.style.display = 'block';
      return;
    }

    // Bezárjuk a modalt és frissítjük a listát
    const modal = bootstrap.Modal.getInstance(document.getElementById('schoolEditModal'));
    modal.hide();
    loadSchoolsList();
  } catch (e) {
    errorEl.textContent = 'Hálózati hiba!';
    errorEl.style.display = 'block';
  }
}

// --- Iskola törlése ---
async function deleteSchool(id, name) {
  if (!confirm(`Biztosan törli a(z) "${name}" iskolát?`)) return;

  try {
    const resp = await fetch(`${API_BASE}/admin/schools/${id}`, { method: 'DELETE' });
    if (resp.ok) {
      loadSchoolsList();
    } else {
      alert('Hiba történt a törlés során!');
    }
  } catch (e) {
    alert('Hálózati hiba!');
  }
}

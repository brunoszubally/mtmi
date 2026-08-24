// API_BASE dinamikus meghatározása
const API_BASE = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' 
  ? "http://localhost:8000/api" 
  : "https://mtmi.onrender.com/api";

// --- Admin session kezelés ---
const ADMIN_LOGIN_STATE_KEY = "mtmi_admin_logged_in";

function setAdminSession(loggedIn) {
  if (loggedIn) {
    localStorage.setItem(ADMIN_LOGIN_STATE_KEY, "1");
  } else {
    localStorage.removeItem(ADMIN_LOGIN_STATE_KEY);
  }
}

function isAdminLoggedIn() {
  return localStorage.getItem(ADMIN_LOGIN_STATE_KEY) === "1";
}

function setAdminLoginError(message = "") {
  const errorEl = document.getElementById("admin-login-error");
  if (!errorEl) return;
  if (message) {
    errorEl.textContent = message;
    errorEl.style.display = "block";
  } else {
    errorEl.textContent = "";
    errorEl.style.display = "none";
  }
}

function handleAdminUnauthorized(message = "A munkamenet lejárt. Kérjük, jelentkezz be újra.") {
  setAdminSession(false);
  showAdminLoginBlock();
  setAdminLoginError(message);
}

async function adminFetch(url, options = {}) {
  const response = await fetch(url, {
    credentials: "include",
    ...options
  });
  if (response.status === 401 || response.status === 403) {
    handleAdminUnauthorized();
    return null;
  }
  return response;
}

async function restoreAdminSession() {
  if (!isAdminLoggedIn()) {
    showAdminLoginBlock();
    return;
  }

  const response = await adminFetch(`${API_BASE}/admin/list`);
  if (!response) return;

  if (!response.ok) {
    setAdminSession(false);
    showAdminLoginBlock();
    return;
  }

  showAdminListBlock();
}

function showAdminListBlock() {
  document.getElementById("admin-login-block").style.display = "none";
  const listBlock = document.getElementById("admin-list-block");
  listBlock.style.display = "";
  listBlock.classList.add("wide-admin");
  const listCard = document.querySelector(".admin-list-card");
  if (listCard) listCard.classList.add("wide-admin");
  loadAdminList();
  loadAdminSchools();
  loadAdminPeriod();
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
  setAdminLoginError("");
  console.log("Login nézet: osztályok", listBlock, listCol, listCard);
}

// --- Oldal betöltéskor: csak érvényes sessionnel mutatjuk a listát ---
document.addEventListener("DOMContentLoaded", function() {
  restoreAdminSession();
});

// --- Admin login ---
document.getElementById("admin-login-form").addEventListener("submit", async function(e) {
  e.preventDefault();
  const user = document.getElementById("admin-username").value.trim();
  const pw = document.getElementById("admin-password").value;
  // Csak "admin" felhasználónév engedélyezett
  if (user !== "admin") {
    setAdminLoginError("Hibás felhasználónév vagy jelszó!");
    return;
  }
  const resp = await fetch(`${API_BASE}/admin/login`, {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ password: pw })
  });
  const res = await resp.json();
  if (res.success) {
    setAdminSession(true);
    setAdminLoginError("");
    showAdminListBlock();
  } else {
    setAdminSession(false);
    setAdminLoginError("Hibás felhasználónév vagy jelszó!");
  }
});

// --- Kilépés gomb ---
document.addEventListener("DOMContentLoaded", function() {
  const logoutBtn = document.getElementById("admin-logout-btn");
  if (logoutBtn) {
    logoutBtn.addEventListener("click", function() {
      setAdminSession(false);
      showAdminLoginBlock();
    });
  }

  document.querySelectorAll(".admin-tab-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      setAdminView(btn.dataset.adminView);
    });
  });

  const submissionsSearch = document.getElementById("admin-submissions-search");
  const submissionsStatus = document.getElementById("admin-submissions-status-filter");
  const submissionsSort = document.getElementById("admin-submissions-sort");
  const schoolsSearch = document.getElementById("admin-schools-search");
  const schoolsStatus = document.getElementById("admin-schools-status-filter");
  const schoolsSort = document.getElementById("admin-schools-sort");

  if (submissionsSearch) {
    submissionsSearch.addEventListener("input", () => {
      adminSubmissionFilters.search = submissionsSearch.value;
      renderAdminList();
    });
  }
  if (submissionsStatus) {
    submissionsStatus.addEventListener("change", () => {
      adminSubmissionFilters.status = submissionsStatus.value;
      renderAdminList();
    });
  }
  if (submissionsSort) {
    submissionsSort.addEventListener("change", () => {
      adminSubmissionFilters.sort = submissionsSort.value;
      renderAdminList();
    });
  }

  if (schoolsSearch) {
    schoolsSearch.addEventListener("input", () => {
      adminSchoolFilters.search = schoolsSearch.value;
      renderAdminSchools();
    });
  }
  if (schoolsStatus) {
    schoolsStatus.addEventListener("change", () => {
      adminSchoolFilters.status = schoolsStatus.value;
      renderAdminSchools();
    });
  }
  if (schoolsSort) {
    schoolsSort.addEventListener("change", () => {
      adminSchoolFilters.sort = schoolsSort.value;
      renderAdminSchools();
    });
  }

  const periodForm = document.getElementById("admin-period-form");
  if (periodForm) {
    periodForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      await saveAdminPeriod();
    });
  }

  ["admin-period-mode", "admin-period-start", "admin-period-end"].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener("change", () => renderPeriodModeWarning(adminPeriodState));
  });

  const periodReloadBtn = document.getElementById("admin-period-reload-btn");
  if (periodReloadBtn) {
    periodReloadBtn.addEventListener("click", () => loadAdminPeriod());
  }

  const periodClearBtn = document.getElementById("admin-period-clear-btn");
  if (periodClearBtn) {
    periodClearBtn.addEventListener("click", async () => {
      if (!confirm("Biztosan törlöd a beállított dátumokat? A működési mód nem változik.")) return;
      await clearAdminPeriod();
    });
  }

  const periodBannerBtn = document.getElementById("admin-period-banner-btn");
  if (periodBannerBtn) {
    periodBannerBtn.addEventListener("click", () => setAdminView("settings"));
  }

  setAdminView("submissions");
});

let deleteSessionId = null;
let adminCurrentView = "submissions";
let adminSubmissions = [];
let adminSchools = [];

const adminSubmissionFilters = {
  search: "",
  status: "all",
  sort: "name_asc"
};

const adminSchoolFilters = {
  search: "",
  status: "all",
  sort: "name_asc"
};

function formatAdminDate(value, { dateOnly = false } = {}) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat("hu-HU", {
    timeZone: "Europe/Budapest",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    ...(dateOnly ? {} : { hour: "2-digit", minute: "2-digit" })
  }).format(date);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function sortByDate(a, b, key, direction = "desc") {
  const aTime = a[key] ? new Date(a[key]).getTime() : 0;
  const bTime = b[key] ? new Date(b[key]).getTime() : 0;
  return direction === "asc" ? aTime - bTime : bTime - aTime;
}

function sortByName(a, b, key, direction = "asc") {
  const multiplier = direction === "asc" ? 1 : -1;
  return multiplier * String(a[key] || "").localeCompare(String(b[key] || ""), "hu", { sensitivity: "base" });
}

function updateAdminCounters() {
  const submissionsCount = document.getElementById("admin-submissions-count");
  const schoolsCount = document.getElementById("admin-schools-count");
  if (submissionsCount) submissionsCount.textContent = adminSubmissions.length;
  if (schoolsCount) schoolsCount.textContent = adminSchools.length;
}

function setAdminView(viewName) {
  adminCurrentView = viewName;
  if (viewName === "settings") loadAdminPeriod();
  document.querySelectorAll(".admin-tab-btn").forEach(btn => {
    btn.classList.toggle("active", btn.dataset.adminView === viewName);
  });
  document.querySelectorAll(".admin-view").forEach(view => {
    view.classList.toggle("active", view.id === `admin-view-${viewName}`);
  });
}

function normalizeAdminListResponse(payload) {
  if (Array.isArray(payload)) return payload;
  if (payload && Array.isArray(payload.items)) return payload.items;
  if (payload && Array.isArray(payload.data)) return payload.data;
  if (payload && Array.isArray(payload.results)) return payload.results;
  return null;
}

function getSubmissionStatusValue(row) {
  return row.submitted ? "submitted" : "in_progress";
}

function getSchoolStatusValue(row) {
  if (!row.form_id) return "no_form";
  return row.submitted ? "submitted" : "in_progress";
}

function renderSchoolStatusBadge(row) {
  if (!row.form_id) {
    return `<span class="status-badge neutral"><i class="bi bi-dash-circle"></i> Nincs űrlap</span>`;
  }
  return renderStatusIcon(row.submitted);
}

function getFilteredAndSortedSubmissions() {
  const search = adminSubmissionFilters.search.trim().toLowerCase();
  let rows = [...adminSubmissions];

  if (search) {
    rows = rows.filter(row => (row.iskola_nev || "").toLowerCase().includes(search));
  }

  if (adminSubmissionFilters.status !== "all") {
    rows = rows.filter(row => getSubmissionStatusValue(row) === adminSubmissionFilters.status);
  }

  switch (adminSubmissionFilters.sort) {
    case "name_desc":
      rows.sort((a, b) => sortByName(a, b, "iskola_nev", "desc"));
      break;
    case "created_desc":
      rows.sort((a, b) => sortByDate(a, b, "created_at", "desc"));
      break;
    case "created_asc":
      rows.sort((a, b) => sortByDate(a, b, "created_at", "asc"));
      break;
    case "updated_desc":
      rows.sort((a, b) => sortByDate(a, b, "updated_at", "desc"));
      break;
    case "name_asc":
    default:
      rows.sort((a, b) => sortByName(a, b, "iskola_nev", "asc"));
      break;
  }

  return rows;
}

function getFilteredAndSortedSchools() {
  const search = adminSchoolFilters.search.trim().toLowerCase();
  let rows = [...adminSchools];

  if (search) {
    rows = rows.filter(row =>
      (row.name || "").toLowerCase().includes(search) ||
      (row.email || "").toLowerCase().includes(search)
    );
  }

  if (adminSchoolFilters.status !== "all") {
    rows = rows.filter(row => getSchoolStatusValue(row) === adminSchoolFilters.status);
  }

  switch (adminSchoolFilters.sort) {
    case "name_desc":
      rows.sort((a, b) => sortByName(a, b, "name", "desc"));
      break;
    case "school_created_desc":
      rows.sort((a, b) => sortByDate(a, b, "created_at", "desc"));
      break;
    case "school_created_asc":
      rows.sort((a, b) => sortByDate(a, b, "created_at", "asc"));
      break;
    case "form_created_desc":
      rows.sort((a, b) => sortByDate(a, b, "form_created_at", "desc"));
      break;
    case "name_asc":
    default:
      rows.sort((a, b) => sortByName(a, b, "name", "asc"));
      break;
  }

  return rows;
}

function renderAdminList() {
  const tbody = document.getElementById("admin-list-tbody");
  if (!tbody) return;
  tbody.innerHTML = "";

  const rows = getFilteredAndSortedSubmissions();
  if (rows.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8" class="text-center text-muted py-4">Nincs találat a jelenlegi szűrőkre.</td></tr>`;
    return;
  }

  for (const row of rows) {
    const tr = document.createElement("tr");
    const tdNev = document.createElement("td");
    const link = document.createElement("a");
    link.href = "#";
    link.textContent = row.iskola_nev;
    link.addEventListener("click", function(ev) {
      ev.preventDefault();
      showSummary(row.id);
    });
    tdNev.appendChild(link);
    tr.appendChild(tdNev);

    const tdCreated = document.createElement("td");
    tdCreated.textContent = formatAdminDate(row.created_at);
    tr.appendChild(tdCreated);

    const tdUpdated = document.createElement("td");
    tdUpdated.textContent = formatAdminDate(row.updated_at);
    tr.appendChild(tdUpdated);

    const tdStatus = document.createElement("td");
    tdStatus.innerHTML = renderStatusIcon(row.submitted);
    tr.appendChild(tdStatus);

    const tdPdf = document.createElement("td");
    if (row.has_pdf) {
      const pdfLink = document.createElement("a");
      pdfLink.href = `${API_BASE.replace('/api', '')}/uploads/${row.id}_*.pdf`;
      pdfLink.target = "_blank";
      pdfLink.innerHTML = '<i class="bi bi-file-earmark-pdf text-danger"></i>';
      pdfLink.title = "PDF megtekintése";
      pdfLink.style.cursor = "pointer";
      pdfLink.addEventListener("click", function(e) {
        e.preventDefault();
        adminFetch(`${API_BASE}/admin/result/${row.id}`)
          .then(resp => {
            if (!resp) return null;
            return resp.json();
          })
          .then(data => {
            if (!data) return;
            if (data.pdf_file_path) {
              const pdfUrl = `https://mtmi-iskola.hu/fileupload/${data.pdf_file_path}`;
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

    const tdExcel = document.createElement("td");
    const excelBtn = document.createElement("button");
    excelBtn.className = "btn btn-outline-success btn-sm";
    excelBtn.innerHTML = '<i class="bi bi-file-earmark-excel"></i>';
    excelBtn.title = "Excel export";
    excelBtn.addEventListener("click", function() {
      exportSingleToExcel(row.id);
    });
    tdExcel.appendChild(excelBtn);
    tr.appendChild(tdExcel);

    const tdView = document.createElement("td");
    const viewBtn = document.createElement("a");
    viewBtn.href = `/kitoltes/${row.id}?adminview=1`;
    viewBtn.target = "_blank";
    viewBtn.className = "btn btn-outline-primary btn-sm";
    viewBtn.textContent = "Megnyitás";
    tdView.appendChild(viewBtn);
    tr.appendChild(tdView);

    const tdDelete = document.createElement("td");
    const deleteBtn = document.createElement("button");
    deleteBtn.className = "btn btn-outline-danger btn-sm";
    deleteBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-trash" viewBox="0 0 16 16"><path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5.5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6zm3 .5a.5.5 0 0 1 .5-.5.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6zm-7-1A1.5 1.5 0 0 1 5.5 4h5A1.5 1.5 0 0 1 12 5.5V6h1a.5.5 0 0 1 0 1h-1v6A2.5 2.5 0 0 1 8.5 15h-3A2.5 2.5 0 0 1 3 13V7H2a.5.5 0 0 1 0-1h1v-.5zM5.5 5a.5.5 0 0 0-.5.5V6h6v-.5a.5.5 0 0 0-.5-.5h-5z"/></svg>';
    deleteBtn.title = "Törlés";
    deleteBtn.addEventListener("click", function() {
      deleteSessionId = row.id;
      const modal = new bootstrap.Modal(document.getElementById('deleteConfirmModal'));
      modal.show();
    });
    tdDelete.appendChild(deleteBtn);
    tr.appendChild(tdDelete);
    tbody.appendChild(tr);
  }
}

function renderAdminSchools() {
  const tbody = document.getElementById("admin-schools-tbody");
  if (!tbody) return;
  tbody.innerHTML = "";

  const rows = getFilteredAndSortedSchools();
  if (rows.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7" class="text-center text-muted py-4">Nincs találat a jelenlegi szűrőkre.</td></tr>`;
    return;
  }

  for (const row of rows) {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${escapeHtml(row.name)}</td>
      <td>${row.email ? escapeHtml(row.email) : '<span class="text-muted">—</span>'}</td>
      <td>${formatAdminDate(row.created_at)}</td>
      <td>${row.form_id ? `<code>${escapeHtml(row.form_id)}</code>` : '<span class="text-muted">Nincs kapcsolva</span>'}</td>
      <td>${row.form_created_at ? formatAdminDate(row.form_created_at) : '<span class="text-muted">—</span>'}</td>
      <td>${renderSchoolStatusBadge(row)}</td>
      <td>${row.form_id ? `<a href="/kitoltes/${encodeURIComponent(row.form_id)}?adminview=1" target="_blank" class="btn btn-outline-primary btn-sm">Megnyitás</a>` : '<span class="text-muted">—</span>'}</td>
    `;
    tbody.appendChild(tr);
  }
}

// --- Kitöltések listázása ---
async function loadAdminList() {
  const resp = await adminFetch(`${API_BASE}/admin/list`);
  if (!resp) return;
  if (!resp.ok) {
    alert("Nem sikerült betölteni a kitöltéseket.");
    return;
  }
  const listRaw = await resp.json();
  const list = normalizeAdminListResponse(listRaw);
  if (!list) {
    alert("Nem sikerült betölteni a kitöltéseket.");
    return;
  }
  adminSubmissions = list;
  updateAdminCounters();
  renderAdminList();
}

async function loadAdminSchools() {
  const resp = await adminFetch(`${API_BASE}/admin/schools`);
  if (!resp) return;
  if (!resp.ok) {
    alert("Nem sikerült betölteni az iskolákat.");
    return;
  }
  const list = await resp.json();
  if (!Array.isArray(list)) {
    alert("Nem sikerült betölteni az iskolákat.");
    return;
  }
  adminSchools = list;
  updateAdminCounters();
  renderAdminSchools();
}

// --- Pályázati időszak (nyitás/zárás) kezelése ---
let adminPeriodState = null;

// A szerver magyar idő szerinti ISO stringet ad vissza (pl. 2026-09-01T08:00:00+02:00),
// ezért szövegesen vágjuk le a datetime-local mezőnek, hogy böngésző-időzónától
// függetlenül pontosan azt lássa az admin, ami el van mentve.
function isoToDatetimeLocalValue(isoString) {
  if (!isoString || typeof isoString !== "string") return "";
  return isoString.slice(0, 16);
}

function setPeriodFeedback(message, type = "info") {
  const box = document.getElementById("admin-period-feedback");
  if (!box) return;
  if (!message) {
    box.style.display = "none";
    box.textContent = "";
    return;
  }
  box.className = `alert alert-${type} mb-0`;
  box.textContent = message;
  box.style.display = "block";
}

const PERIOD_MODE_LABELS = {
  auto: "Időszak szerint",
  forced_open: "Mindig nyitva (dátumtól függetlenül)",
  forced_closed: "Mindig zárva"
};

function periodRangeText(state) {
  if (!state.configured) return "nincs megadva dátum";
  return `${state.start_label || "nincs megadva"} – ${state.end_label || "nincs megadva"}`;
}

function describePeriod(state) {
  if (!state) return { text: "Az időszak beállítása nem elérhető.", type: "secondary" };
  const range = periodRangeText(state);

  if (state.status === "forced_open") {
    const extra = state.dates_ignored
      ? ` FIGYELEM: a beállított dátumok (${range}) most NEM érvényesülnek!`
      : "";
    return { text: `A felület NYITVA – „Mindig nyitva” módban.${extra}`, type: state.dates_ignored ? "warning" : "success" };
  }
  if (state.status === "forced_closed") {
    const extra = state.dates_ignored
      ? ` A beállított dátumok (${range}) most nem érvényesülnek.`
      : "";
    return { text: `A felület ZÁRVA – „Mindig zárva” módban.${extra}`, type: "danger" };
  }
  if (!state.configured) {
    return { text: "Időszak szerinti mód, de nincs megadva dátum – a felület korlátlanul nyitva van.", type: "secondary" };
  }
  if (state.status === "before") {
    return { text: `A felület ZÁRVA. Nyitás: ${state.start_label}. Beállított időszak: ${range}`, type: "warning" };
  }
  if (state.status === "after") {
    return { text: `A felület ZÁRVA, az időszak lezárult. Beállított időszak: ${range}`, type: "danger" };
  }
  return { text: `A felület NYITVA. Beállított időszak: ${range}`, type: "success" };
}

function renderAdminPeriod(state, { fillInputs = true } = {}) {
  adminPeriodState = state;

  const banner = document.getElementById("admin-period-banner");
  const bannerText = document.getElementById("admin-period-banner-text");
  const info = describePeriod(state);
  if (banner && bannerText) {
    banner.className = `alert alert-${info.type} d-flex flex-wrap align-items-center gap-2 mb-4`;
    bannerText.textContent = info.text;
  }

  if (fillInputs) {
    const modeInput = document.getElementById("admin-period-mode");
    const startInput = document.getElementById("admin-period-start");
    const endInput = document.getElementById("admin-period-end");
    const messageInput = document.getElementById("admin-period-message");
    if (modeInput) modeInput.value = (state && state.mode) || "auto";
    if (startInput) startInput.value = isoToDatetimeLocalValue(state && state.start);
    if (endInput) endInput.value = isoToDatetimeLocalValue(state && state.end);
    if (messageInput) messageInput.value = (state && state.custom_message) || "";
  }

  renderPeriodModeWarning(state);

  const stateEl = document.getElementById("admin-period-state");
  const modeLabelEl = document.getElementById("admin-period-mode-label");
  if (modeLabelEl) modeLabelEl.textContent = (state && PERIOD_MODE_LABELS[state.mode]) || "—";
  const startLabelEl = document.getElementById("admin-period-start-label");
  const endLabelEl = document.getElementById("admin-period-end-label");
  const updatedEl = document.getElementById("admin-period-updated");
  if (stateEl) stateEl.textContent = state ? (state.is_open ? "Nyitva" : "Zárva") : "—";
  if (startLabelEl) startLabelEl.textContent = (state && state.start_label) || "—";
  if (endLabelEl) endLabelEl.textContent = (state && state.end_label) || "—";
  if (updatedEl) {
    if (state && state.updated_at) {
      updatedEl.textContent = formatAdminDate(state.updated_at);
    } else {
      updatedEl.textContent = "—";
    }
  }
}

function renderPeriodModeWarning(state) {
  const warning = document.getElementById("admin-period-mode-warning");
  if (!warning) return;
  const modeInput = document.getElementById("admin-period-mode");
  const startInput = document.getElementById("admin-period-start");
  const endInput = document.getElementById("admin-period-end");
  const mode = modeInput ? modeInput.value : ((state && state.mode) || "auto");
  const hasDates = Boolean((startInput && startInput.value) || (endInput && endInput.value));

  if (mode === "forced_open" && hasDates) {
    warning.className = "alert alert-warning mt-3 mb-0";
    warning.textContent = "„Mindig nyitva” módban a megadott dátumok elmentődnek, de NEM zárják le a felületet. Ha azt szeretnéd, hogy a dátumok érvényesüljenek, válaszd az „Időszak szerint” módot.";
    warning.style.display = "block";
    return;
  }
  if (mode === "forced_closed") {
    warning.className = "alert alert-danger mt-3 mb-0";
    warning.textContent = "„Mindig zárva” módban a kitöltő felület senkinek nem érhető el, a megadott dátumoktól függetlenül.";
    warning.style.display = "block";
    return;
  }
  warning.style.display = "none";
  warning.textContent = "";
}

async function loadAdminPeriod() {
  const resp = await adminFetch(`${API_BASE}/admin/period`);
  if (!resp) return;
  if (!resp.ok) {
    renderAdminPeriod(null, { fillInputs: false });
    setPeriodFeedback("Nem sikerült betölteni a pályázati időszak beállítását.", "danger");
    return;
  }
  const state = await resp.json();
  renderAdminPeriod(state);
  setPeriodFeedback("");
}

async function saveAdminPeriod() {
  const startInput = document.getElementById("admin-period-start");
  const endInput = document.getElementById("admin-period-end");
  const messageInput = document.getElementById("admin-period-message");
  const saveBtn = document.getElementById("admin-period-save-btn");

  const modeInput = document.getElementById("admin-period-mode");
  const mode = modeInput ? modeInput.value : "auto";
  const start = startInput ? startInput.value : "";
  const end = endInput ? endInput.value : "";
  if (start && end && end <= start) {
    setPeriodFeedback("A záró időpont nem lehet korábbi a kezdő időpontnál!", "danger");
    return;
  }

  if (saveBtn) saveBtn.disabled = true;
  try {
    const resp = await adminFetch(`${API_BASE}/admin/period`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        mode: mode,
        start: start || null,
        end: end || null,
        message: messageInput ? messageInput.value : null
      })
    });
    if (!resp) return;
    if (!resp.ok) {
      let detail = "Nem sikerült menteni a pályázati időszakot.";
      try {
        const err = await resp.json();
        if (err && err.detail) detail = err.detail;
      } catch (e) { /* marad az alapértelmezett szöveg */ }
      setPeriodFeedback(detail, "danger");
      return;
    }
    // A backend a ténylegesen elmentett állapotot olvassa vissza az adatbázisból
    const state = await resp.json();
    renderAdminPeriod(state);
    setPeriodFeedback(`Mentve. ${describePeriod(state).text}`, "success");
  } catch (e) {
    setPeriodFeedback("Hálózati hiba a mentés során!", "danger");
  } finally {
    if (saveBtn) saveBtn.disabled = false;
  }
}

async function clearAdminPeriod() {
  const resp = await adminFetch(`${API_BASE}/admin/period`, { method: "DELETE" });
  if (!resp) return;
  if (!resp.ok) {
    setPeriodFeedback("Nem sikerült törölni a beállított dátumokat.", "danger");
    return;
  }
  const state = await resp.json();
  renderAdminPeriod(state);
  setPeriodFeedback(`A dátumok törölve. ${describePeriod(state).text}`, "success");
}

// Modal megerősítés gomb esemény
if (document.getElementById('confirmDeleteBtn')) {
  document.getElementById('confirmDeleteBtn').addEventListener('click', async function() {
    if (deleteSessionId) {
      const resp = await adminFetch(`${API_BASE}/admin/delete/${deleteSessionId}`, { method: "DELETE" });
      if (!resp) return;
      if (resp.ok) {
        // Modal bezárása
        const modal = bootstrap.Modal.getInstance(document.getElementById('deleteConfirmModal'));
        modal.hide();
        loadAdminList();
        loadAdminSchools();
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
  const resp = await adminFetch(`${API_BASE}/admin/result/${session_id}`);
  if (!resp) return;
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
    } else if (["text","number","email","url","tel"].includes(el.type)) {
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
    const resp = await adminFetch(`${API_BASE}/admin/list`);
    if (!resp) return;
    if (!resp.ok) {
      alert("Nem sikerült betölteni a kitöltéseket.");
      return;
    }
    const submissionsRaw = await resp.json();
    const submissions = normalizeAdminListResponse(submissionsRaw);
    if (!submissions) {
      alert("Nem sikerült betölteni a kitöltéseket.");
      return;
    }
    
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
      const detailResp = await adminFetch(`${API_BASE}/admin/result/${submission.id}`);
      if (!detailResp) return;
      if (!detailResp.ok) {
        alert("Nem sikerült betölteni az egyik kitöltés részleteit.");
        return;
      }
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
    const resp = await adminFetch(`${API_BASE}/admin/result/${sessionId}`);
    if (!resp) return;
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


 

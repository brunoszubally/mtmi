function getSessionIdFromUrl() {
  const m = window.location.pathname.match(/kitoltes\/(\w[\w-]*)/);
  return m ? m[1] : null;
}

// API_BASE dinamikus meghatározása
const API_BASE = "/api";
const FORM_ID = "mtmi-form";
const SESSION_KEY = "mtmi_session_id";
const LINK_BOX_ID = "mtmi-link-box";
const SCHOOL_ID_KEY = "mtmi_school_id";
const SCHOOL_NAME_KEY = "mtmi_school_name";
const SCHOOL_TOKEN_KEY = "mtmi_school_token";
const ADMIN_TOKEN_KEY = "mtmi_admin_token";
const LINKED_FORM_ID_KEY = "mtmi_linked_form_id";
const GUIDE_PAGE_PATH = "/kitoltesi-utmutato.html";
const GUIDE_RETURN_KEY = "mtmi_guide_return_to";
const MAX_LINK_FIELDS_PER_GROUP = 10;
const AUTO_SAVE_DEBOUNCE_MS = 1000;
window.currentLoadedFormSchoolId = null;
window.mtmiPublicGateLocked = false;
window.submissionStatusData = null;
window.forceReadonlyView = false;
window.mtmiDashboardData = null;
let requiredQuickfixRaf = null;
let autoSaveTimer = null;
let saveInFlight = false;
let pendingAutoSave = false;

// --- Iskolai login kezelés ---
function getSchoolSession() {
  const schoolId = localStorage.getItem(SCHOOL_ID_KEY);
  const schoolName = localStorage.getItem(SCHOOL_NAME_KEY);
  return schoolId ? { school_id: schoolId, school_name: schoolName } : null;
}

function getSchoolAccessToken() {
  return localStorage.getItem(SCHOOL_TOKEN_KEY);
}

function getAdminAccessToken() {
  return localStorage.getItem(ADMIN_TOKEN_KEY);
}

function isAdminViewActive() {
  const urlParams = new URLSearchParams(window.location.search);
  return Boolean(urlParams.get("adminview"));
}

function getCurrentAccessToken() {
  if (isAdminViewActive()) {
    return getAdminAccessToken() || getSchoolAccessToken();
  }
  return getSchoolAccessToken();
}

function buildAuthorizedHeaders({ json = false, adminOnly = false } = {}) {
  const headers = {};
  if (json) headers["Content-Type"] = "application/json";
  const token = adminOnly ? getAdminAccessToken() : getCurrentAccessToken();
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return headers;
}

function setSchoolSession(schoolId, schoolName, accessToken) {
  localStorage.setItem(SCHOOL_ID_KEY, schoolId);
  localStorage.setItem(SCHOOL_NAME_KEY, schoolName);
  if (accessToken) {
    localStorage.setItem(SCHOOL_TOKEN_KEY, accessToken);
  }
  updateSchoolLogoutButtonVisibility();
}

function clearSchoolSession() {
  localStorage.removeItem(SCHOOL_ID_KEY);
  localStorage.removeItem(SCHOOL_NAME_KEY);
  localStorage.removeItem(SCHOOL_TOKEN_KEY);
  localStorage.removeItem(SESSION_KEY);
  localStorage.removeItem(LINKED_FORM_ID_KEY);
  window.mtmiDashboardData = null;
  const card = document.getElementById("school-dashboard-card");
  if (card) card.style.display = "none";
  updateSchoolLogoutButtonVisibility();
}

function updateSchoolLogoutButtonVisibility() {
  const logoutBtn = document.getElementById("school-logout-btn");
  if (!logoutBtn) return;
  const urlParams = new URLSearchParams(window.location.search);
  const adminView = urlParams.get("adminview");
  logoutBtn.style.display = getSchoolSession() && !adminView ? "" : "none";
}

function setSchoolLoginUiState(isLoading) {
  const submitBtn = document.getElementById("school-login-submit-btn");
  const loginCard = document.getElementById("school-login-card");
  const emailInput = document.getElementById("school-login-email");
  const passwordInput = document.getElementById("school-login-password");

  if (submitBtn) {
    if (!submitBtn.dataset.originalHtml) submitBtn.dataset.originalHtml = submitBtn.innerHTML;
    submitBtn.disabled = isLoading;
    submitBtn.classList.toggle("is-loading", isLoading);
    submitBtn.setAttribute("aria-busy", isLoading ? "true" : "false");
    submitBtn.innerHTML = isLoading
      ? '<span class="login-btn-spinner" aria-hidden="true"></span><span>Belépés...</span>'
      : submitBtn.dataset.originalHtml;
  }

  if (loginCard) loginCard.classList.toggle("is-loading", isLoading);
  if (emailInput) emailInput.disabled = isLoading;
  if (passwordInput) passwordInput.disabled = isLoading;
}

function performSchoolLogout() {
  if (autoSaveTimer) {
    clearTimeout(autoSaveTimer);
    autoSaveTimer = null;
  }
  pendingAutoSave = false;
  saveInFlight = false;
  clearSchoolSession();
  window.forceReadonlyView = false;
  window.currentLoadedFormSchoolId = null;
  window.mtmiDashboardData = null;

  const form = document.getElementById(FORM_ID);
  if (form) form.reset();

  const loginEmail = document.getElementById("school-login-email");
  const loginPassword = document.getElementById("school-login-password");
  const loginError = document.getElementById("school-login-error");
  if (loginEmail) loginEmail.value = "";
  if (loginPassword) loginPassword.value = "";
  if (loginError) {
    loginError.textContent = "";
    loginError.style.display = "none";
  }
  setSchoolLoginUiState(false);

  hideSubmissionClosedScreen();
  updateThankyouEditButton();
  syncSchoolNameField("logout");
  history.replaceState({}, "", "/");
  window.scrollTo(0, 0);

  if (window.submissionStatusData && !window.submissionStatusData.is_available) {
    showSubmissionClosedScreen(window.submissionStatusData);
  } else {
    setPrimaryScreen("login");
  }
}

function getGuideReturnTarget() {
  const path = `${window.location.pathname || "/"}${window.location.search || ""}${window.location.hash || ""}`;
  return path || "/";
}

function setupGuideReturnLinks() {
  const guideLinks = Array.from(document.querySelectorAll("[data-guide-link='true']"));
  if (!guideLinks.length) return;
  const returnTo = getGuideReturnTarget();
  const guideUrl = `${GUIDE_PAGE_PATH}?return_to=${encodeURIComponent(returnTo)}`;

  guideLinks.forEach((link) => {
    link.setAttribute("href", guideUrl);
    if (link.dataset.bound === "1") return;
    link.dataset.bound = "1";
    link.addEventListener("click", () => {
      localStorage.setItem(GUIDE_RETURN_KEY, returnTo);
    });
  });
}

function formatHuDateTime(isoValue) {
  if (!isoValue) return "-";
  try {
    return new Date(isoValue).toLocaleString("hu-HU");
  } catch (e) {
    return isoValue;
  }
}

function setGuidePanelOpen(isOpen) {
  const panel = document.getElementById("guide-panel");
  const backdrop = document.getElementById("guide-panel-backdrop");
  if (!panel || !backdrop) return;

  if (isOpen) {
    backdrop.style.display = "block";
    panel.classList.add("is-open");
    panel.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
    return;
  }

  panel.classList.remove("is-open");
  panel.setAttribute("aria-hidden", "true");
  backdrop.style.display = "none";
  const loginScreen = document.getElementById("login-screen");
  const isLoginVisible = loginScreen && loginScreen.style.display !== "none";
  document.body.style.overflow = isLoginVisible ? "hidden" : "auto";
}

function setupGuidePanel() {
  const openBtn = document.getElementById("open-guide-panel-btn");
  const closeBtn = document.getElementById("close-guide-panel-btn");
  const backdrop = document.getElementById("guide-panel-backdrop");
  const panel = document.getElementById("guide-panel");

  if (openBtn && !openBtn.dataset.bound) {
    openBtn.dataset.bound = "1";
    openBtn.addEventListener("click", () => setGuidePanelOpen(true));
  }
  if (closeBtn && !closeBtn.dataset.bound) {
    closeBtn.dataset.bound = "1";
    closeBtn.addEventListener("click", () => setGuidePanelOpen(false));
  }
  if (backdrop && !backdrop.dataset.bound) {
    backdrop.dataset.bound = "1";
    backdrop.addEventListener("click", () => setGuidePanelOpen(false));
  }
  if (!document.body.dataset.guideEscBound) {
    document.body.dataset.guideEscBound = "1";
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") setGuidePanelOpen(false);
    });
  }
  if (panel && !panel.dataset.jumpBound) {
    panel.dataset.jumpBound = "1";
    panel.addEventListener("click", (event) => {
      const trigger = event.target.closest(".guide-panel-jump-pill");
      if (!trigger) return;
      const targetId = trigger.getAttribute("href");
      if (!targetId || !targetId.startsWith("#")) return;
      const target = panel.querySelector(targetId);
      if (!target) return;
      event.preventDefault();
      target.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  }
}

function updateSchoolDashboardCard(partial = {}) {
  const card = document.getElementById("school-dashboard-card");
  if (!card) return;

  const existing = window.mtmiDashboardData || {};
  window.mtmiDashboardData = { ...existing, ...partial };
  const data = window.mtmiDashboardData;

  const statusEl = document.getElementById("dashboard-status-label");
  const countEl = document.getElementById("dashboard-filled-count");
  const updatedEl = document.getElementById("dashboard-updated-at");

  const statusMap = {
    submitted: "Beküldve",
    in_progress: "Folyamatban",
    none: "Még nincs megkezdve"
  };
  const status = data.form_status || (data.form_id ? "in_progress" : "none");

  if (statusEl) statusEl.textContent = statusMap[status] || status;
  if (countEl) countEl.textContent = String(data.filled_fields_count || 0);
  if (updatedEl) updatedEl.textContent = formatHuDateTime(data.updated_at);
  card.style.display = getSchoolSession() ? "" : "none";
}

async function loadSchoolDashboard() {
  const schoolSession = getSchoolSession();
  if (!schoolSession?.school_id) return;
  try {
    const resp = await fetch(`${API_BASE}/school/dashboard/${schoolSession.school_id}`, {
      headers: buildAuthorizedHeaders()
    });
    if (!resp.ok) return;
    const dashboard = await resp.json();
    updateSchoolDashboardCard(dashboard);
  } catch (e) {
    console.warn("[DASHBOARD] load failed", e);
  }
}

function canApplySchoolSessionToCurrentForm() {
  const schoolSession = getSchoolSession();
  if (!schoolSession) return false;
  const loadedSchoolId = window.currentLoadedFormSchoolId;
  if (!loadedSchoolId) return true;
  return loadedSchoolId === schoolSession.school_id;
}

function parseLinkFieldName(name) {
  const m = String(name || '').match(/^(.*_link)(\d+)?$/);
  if (!m) return null;
  return {
    base: m[1],
    index: m[2] ? parseInt(m[2], 10) : 1
  };
}

function updateLinkGroupControls(baseName) {
  const group = document.querySelector(`.multi-link-group[data-link-base="${baseName}"]`);
  if (!group) return;
  const addBtn = group.querySelector('.multi-link-add-btn');
  if (!addBtn) return;
  const count = group.querySelectorAll('input[type="url"][data-link-base]').length;
  addBtn.disabled = count >= MAX_LINK_FIELDS_PER_GROUP;
  addBtn.textContent = `+ Link hozzáadása (${count}/${MAX_LINK_FIELDS_PER_GROUP})`;
}

function addLinkField(baseName, shouldFocus = true) {
  const group = document.querySelector(`.multi-link-group[data-link-base="${baseName}"]`);
  if (!group) return null;

  const linkInputs = Array.from(group.querySelectorAll('input[type="url"][data-link-base]'));
  if (linkInputs.length >= MAX_LINK_FIELDS_PER_GROUP) return null;
  const template = linkInputs[0];
  if (!template) return null;

  const nextIndex = linkInputs.length + 1;
  const newInput = template.cloneNode(true);
  newInput.name = `${baseName}${nextIndex}`;
  newInput.value = '';
  newInput.required = false;
  newInput.dataset.linkBase = baseName;
  newInput.dataset.linkIndex = String(nextIndex);

  const controls = group.querySelector('.multi-link-controls');
  if (controls) {
    group.insertBefore(newInput, controls);
  } else {
    group.appendChild(newInput);
  }

  updateLinkGroupControls(baseName);
  if (shouldFocus) newInput.focus();
  return newInput;
}

function ensureLinkFieldCount(baseName, targetCount) {
  const safeTarget = Math.max(1, Math.min(MAX_LINK_FIELDS_PER_GROUP, targetCount));
  let group = document.querySelector(`.multi-link-group[data-link-base="${baseName}"]`);
  if (!group) return;

  while (group.querySelectorAll('input[type="url"][data-link-base]').length < safeTarget) {
    addLinkField(baseName, false);
    group = document.querySelector(`.multi-link-group[data-link-base="${baseName}"]`);
    if (!group) break;
  }
}

function setupMultiLinkFields() {
  const urlInputs = Array.from(document.querySelectorAll('input[type="url"][name]'))
    .filter(input => parseLinkFieldName(input.name));
  if (urlInputs.length === 0) return;

  const groups = new Map();
  urlInputs.forEach(input => {
    const parsed = parseLinkFieldName(input.name);
    if (!parsed) return;
    if (!groups.has(parsed.base)) groups.set(parsed.base, []);
    groups.get(parsed.base).push(input);
  });

  groups.forEach((inputs, baseName) => {
    if (document.querySelector(`.multi-link-group[data-link-base="${baseName}"]`)) return;
    if (!inputs[0] || !inputs[0].parentNode) return;

    const firstInput = inputs[0];
    const parent = firstInput.parentNode;
    const group = document.createElement('div');
    group.className = 'multi-link-group';
    group.dataset.linkBase = baseName;
    parent.insertBefore(group, firstInput);

    inputs.forEach((input, idx) => {
      const index = idx + 1;
      input.name = `${baseName}${index}`;
      input.dataset.linkBase = baseName;
      input.dataset.linkIndex = String(index);
      if (index > 1) input.required = false;
      group.appendChild(input);
    });

    const controls = document.createElement('div');
    controls.className = 'multi-link-controls mb-2';

    const addBtn = document.createElement('button');
    addBtn.type = 'button';
    addBtn.className = 'btn btn-outline-primary btn-sm multi-link-add-btn';
    addBtn.addEventListener('click', () => addLinkField(baseName, true));
    controls.appendChild(addBtn);

    group.appendChild(controls);
    updateLinkGroupControls(baseName);
  });

  console.log('[LINKS] multi-link setup done', {
    groups: Array.from(groups.keys()).length
  });
}

function syncSchoolNameField(reason = 'unknown') {
  const schoolSession = getSchoolSession();
  const schoolNameInput = document.querySelector("input[name='palyazo_iskola_neve']");
  if (!schoolNameInput) return;

  if (schoolSession && schoolSession.school_name && canApplySchoolSessionToCurrentForm()) {
    if (schoolNameInput.value !== schoolSession.school_name) {
      schoolNameInput.value = schoolSession.school_name;
    }
    schoolNameInput.readOnly = true;
    schoolNameInput.style.backgroundColor = '#f8f9fa';
    schoolNameInput.style.cursor = 'not-allowed';

    let note = document.getElementById('school-name-autofill-note');
    if (!note) {
      note = document.createElement('small');
      note.id = 'school-name-autofill-note';
      note.className = 'form-text text-muted';
      note.textContent = 'Automatikusan kitöltve a bejelentkezett iskolai fiók alapján.';
      schoolNameInput.insertAdjacentElement('afterend', note);
    }
  } else {
    schoolNameInput.readOnly = false;
    schoolNameInput.style.backgroundColor = '';
    schoolNameInput.style.cursor = '';
    const note = document.getElementById('school-name-autofill-note');
    if (note) note.remove();
  }

  console.log('[SCHOOL_NAME] syncSchoolNameField', {
    reason,
    hasSchoolSession: Boolean(schoolSession),
    currentLoadedFormSchoolId: window.currentLoadedFormSchoolId,
    schoolName: schoolSession ? schoolSession.school_name : null,
    fieldValue: schoolNameInput.value,
    readOnly: schoolNameInput.readOnly
  });
}

function setPrimaryScreen(screen) {
  const loginScreen = document.getElementById('login-screen');
  const welcomeScreen = document.getElementById('welcome-screen');
  const mainForm = document.getElementById('main-form-content');
  const thankyouScreen = document.getElementById('thankyou-fullscreen');

  if (loginScreen) loginScreen.style.setProperty('display', 'none', 'important');
  if (welcomeScreen) welcomeScreen.style.setProperty('display', 'none', 'important');
  if (mainForm) mainForm.style.setProperty('display', 'none', 'important');
  if (thankyouScreen) thankyouScreen.style.setProperty('display', 'none', 'important');
  setGuidePanelOpen(false);

  if (screen === 'login' && loginScreen) {
    loginScreen.style.setProperty('display', 'flex', 'important');
    document.body.style.overflow = 'hidden';
  } else if (screen === 'welcome' && welcomeScreen) {
    welcomeScreen.style.setProperty('display', 'flex', 'important');
    document.body.style.overflow = 'auto';
  } else if (screen === 'form' && mainForm) {
    mainForm.style.setProperty('display', 'block', 'important');
    document.body.style.overflow = 'auto';
  } else if (screen === 'thankyou' && thankyouScreen) {
    thankyouScreen.style.setProperty('display', 'flex', 'important');
    document.body.style.overflow = 'auto';
  }

  console.log('[UI] setPrimaryScreen', screen, {
    login: loginScreen ? loginScreen.style.display : '(missing)',
    welcome: welcomeScreen ? welcomeScreen.style.display : '(missing)',
    form: mainForm ? mainForm.style.display : '(missing)',
    thankyou: thankyouScreen ? thankyouScreen.style.display : '(missing)'
  });
}

function ensureSubmissionStatusUi() {
  let banner = document.getElementById("submission-countdown-banner");
  if (!banner) {
    banner = document.createElement("div");
    banner.id = "submission-countdown-banner";
    banner.style.display = "none";
    banner.style.position = "sticky";
    banner.style.top = "0";
    banner.style.zIndex = "20000";
    banner.style.padding = "12px 16px";
    banner.style.textAlign = "center";
    banner.style.fontWeight = "600";
    banner.style.background = "#fff3cd";
    banner.style.color = "#856404";
    banner.style.borderBottom = "1px solid #ffe69c";
    document.body.prepend(banner);
  }

  let closedScreen = document.getElementById("submission-closed-screen");
  if (!closedScreen) {
    closedScreen = document.createElement("div");
    closedScreen.id = "submission-closed-screen";
    closedScreen.className = "submission-closed-screen status-review";
    closedScreen.style.display = "none";
    closedScreen.style.position = "fixed";
    closedScreen.style.inset = "0";
    closedScreen.style.zIndex = "30000";
    closedScreen.style.alignItems = "center";
    closedScreen.style.justifyContent = "center";
    closedScreen.innerHTML = `
      <div class="submission-closed-backdrop"></div>
      <div class="submission-closed-card card shadow-lg border-0">
        <div class="card-body p-4 p-md-5 text-center">
          <img src="/logo.png" alt="MTMI Iskola Program logó" class="submission-closed-logo">
          <span id="submission-closed-badge" class="submission-closed-badge">Bírálat zajlik</span>
          <h1 class="fw-bold mb-2 submission-closed-title-main">MTMI Iskola Program</h1>
          <h2 id="submission-closed-title" class="submission-closed-title">Pályázati felület lezárva</h2>
          <p id="submission-closed-message" class="submission-closed-message">A pályázati felület jelenleg nem elérhető, bírálat zajlik.</p>
          <div id="submission-closed-help" class="submission-closed-help" style="display: none;"></div>
          <button id="submission-logout-btn" type="button" class="btn btn-outline-secondary btn-lg mt-3">Kilépés</button>
        </div>
      </div>
    `;
    document.body.appendChild(closedScreen);

    const logoutBtn = document.getElementById("submission-logout-btn");
    if (logoutBtn) {
      logoutBtn.addEventListener("click", () => performSchoolLogout());
    }
  }
}

function getSubmissionClosedUiConfig(statusData) {
  const status = statusData?.status || "review";
  if (status === "inactive") {
    return {
      rootClass: "status-inactive",
      badge: "Nincs aktív időszak",
      title: "Jelenleg nincs aktív pályázati időszak",
      message: "",
      help: "Köszönjük az érdeklődést. Az új pályázati időszak megnyitásáról ezen a felületen adunk majd tájékoztatást."
    };
  }
  return {
    rootClass: "status-review",
    badge: "Bírálat zajlik",
    title: "Pályázati felület lezárva",
    message: statusData?.message || "A pályázati felület jelenleg nem elérhető, bírálat zajlik.",
    help: ""
  };
}

function hidePrimaryScreensForClosedState() {
  const loginScreen = document.getElementById("login-screen");
  const welcomeScreen = document.getElementById("welcome-screen");
  const mainForm = document.getElementById("main-form-content");
  const thankyouScreen = document.getElementById("thankyou-fullscreen");
  if (loginScreen) loginScreen.style.setProperty("display", "none", "important");
  if (welcomeScreen) welcomeScreen.style.setProperty("display", "none", "important");
  if (mainForm) mainForm.style.setProperty("display", "none", "important");
  if (thankyouScreen) thankyouScreen.style.setProperty("display", "none", "important");
}

function showSubmissionClosedScreen(statusOrMessage) {
  ensureSubmissionStatusUi();
  const closedScreen = document.getElementById("submission-closed-screen");
  const closedBadge = document.getElementById("submission-closed-badge");
  const closedTitle = document.getElementById("submission-closed-title");
  const closedMessage = document.getElementById("submission-closed-message");
  const closedHelp = document.getElementById("submission-closed-help");
  const logoutBtn = document.getElementById("submission-logout-btn");
  const statusData = typeof statusOrMessage === "string"
    ? { status: window.submissionStatusData?.status || "review", message: statusOrMessage }
    : (statusOrMessage || window.submissionStatusData || { status: "review" });
  const ui = getSubmissionClosedUiConfig(statusData);

  if (closedScreen) {
    closedScreen.classList.remove("status-review", "status-inactive");
    closedScreen.classList.add(ui.rootClass);
  }
  if (closedBadge) closedBadge.textContent = ui.badge;
  if (closedTitle) closedTitle.textContent = ui.title;
  if (closedMessage) {
    closedMessage.textContent = ui.message || "";
    closedMessage.style.display = ui.message ? "" : "none";
  }
  if (closedHelp) {
    closedHelp.textContent = ui.help || "";
    closedHelp.style.display = ui.help ? "" : "none";
  }
  if (logoutBtn) logoutBtn.style.display = getSchoolSession() ? "" : "none";
  hidePrimaryScreensForClosedState();
  if (closedScreen) closedScreen.style.display = "flex";
}

function hideSubmissionClosedScreen() {
  const closedScreen = document.getElementById("submission-closed-screen");
  if (closedScreen) closedScreen.style.display = "none";
}

function updateThankyouEditButton() {
  const editBtn = document.getElementById("edit-submission-btn");
  if (!editBtn) return;
  const status = window.submissionStatusData;
  const canEdit = Boolean(status && status.is_available && getSchoolSession() && (localStorage.getItem(SESSION_KEY) || getSessionIdFromUrl()));
  editBtn.style.display = canEdit ? "" : "none";
}

async function applyPublicSubmissionStatus() {
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get("adminview")) return true;

  ensureSubmissionStatusUi();
  const banner = document.getElementById("submission-countdown-banner");
  try {
    const resp = await fetch(`${API_BASE}/public/submission-status`);
    if (!resp.ok) return true;
    const status = await resp.json();
    window.submissionStatusData = status;
    updateThankyouEditButton();

    if (status.status === "countdown" && status.message) {
      banner.textContent = status.message;
      banner.style.background = "#fff3cd";
      banner.style.color = "#856404";
      banner.style.display = "block";
    } else if (!status.is_available && status.message) {
      banner.textContent = status.message;
      if (status.status === "inactive") {
        banner.style.background = "#e8f1ff";
        banner.style.color = "#154a92";
      } else {
        banner.style.background = "#f8d7da";
        banner.style.color = "#842029";
      }
      banner.style.display = "block";
    } else {
      banner.style.display = "none";
    }
    window.mtmiPublicGateLocked = !status.is_available;
    return true;
  } catch (e) {
    console.warn("[STATUS] public submission-status fetch failed", e);
    return true;
  }
}

async function handleSchoolLogin(email, password) {
  const errorEl = document.getElementById('school-login-error');
  console.log('[LOGIN] handleSchoolLogin start', {
    email,
    hasPassword: Boolean(password),
    ts: new Date().toISOString()
  });
  if (!errorEl) {
    console.error('[LOGIN] school-login-error element not found');
    return;
  }
  errorEl.style.display = 'none';
  setSchoolLoginUiState(true);

  try {
    console.log('[LOGIN] sending POST /api/school/login');
    const resp = await fetch(`${API_BASE}/school/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    console.log('[LOGIN] response received', { ok: resp.ok, status: resp.status });

    if (!resp.ok) {
      const err = await resp.json();
      console.warn('[LOGIN] backend rejected login', err);
      errorEl.textContent = err.detail || 'Hib\u00e1s felhaszn\u00e1l\u00f3n\u00e9v vagy jelsz\u00f3!';
      errorEl.style.display = 'block';
      setSchoolLoginUiState(false);
      return;
    }

    const res = await resp.json();
    console.log('[LOGIN] login success payload', res);
    setSchoolSession(res.school_id, res.school_name, res.access_token);
    if (res.form_id) {
      localStorage.setItem(LINKED_FORM_ID_KEY, res.form_id);
    }
    syncSchoolNameField('after-login-success');
    updateSchoolDashboardCard({
      form_id: res.form_id || null,
      form_status: res.form_status || null,
      updated_at: res.form_updated_at || null
    });
    await loadSchoolDashboard();
    await applyPublicSubmissionStatus();
    const submissionStatus = window.submissionStatusData;

    if (submissionStatus && !submissionStatus.is_available) {
      if (res.form_status === 'submitted' && res.form_id) {
        localStorage.setItem(SESSION_KEY, res.form_id);
        history.replaceState({}, '', `/kitoltes/${res.form_id}`);
        window.forceReadonlyView = true;
        hideSubmissionClosedScreen();
        setPrimaryScreen('form');
        window.scrollTo(0, 0);
        if (typeof loadForm === 'function') loadForm();
        if (typeof window.loadForm === 'function') window.loadForm();
      } else {
        window.forceReadonlyView = false;
        showSubmissionClosedScreen(submissionStatus);
      }
      return;
    }
    window.forceReadonlyView = false;

    if (res.form_status === 'submitted') {
      // Már beküldték → "köszönjük" képernyő
      if (res.form_id) {
        localStorage.setItem(SESSION_KEY, res.form_id);
        history.replaceState({}, '', `/kitoltes/${res.form_id}`);
      }
      setPrimaryScreen('thankyou');
      updateThankyouEditButton();
      window.scrollTo(0, 0);
      console.log('[LOGIN] switched to submitted screen');
    } else if (res.form_status === 'in_progress' && res.form_id) {
      // Folyamatban lévő kitöltés → betöltés és tovább
      localStorage.setItem(SESSION_KEY, res.form_id);
      history.replaceState({}, '', `/kitoltes/${res.form_id}`);
      setPrimaryScreen('form');
      window.scrollTo(0, 0);
      // A loadForm fog lefutni a DOMContentLoaded-ben
      if (typeof loadForm === 'function') loadForm();
      if (typeof window.loadForm === 'function') window.loadForm();
      console.log('[LOGIN] switched to in_progress form', {
        hasLoadForm: typeof loadForm === 'function',
        hasWindowLoadForm: typeof window.loadForm === 'function'
      });
    } else {
      // Nincs kitöltés → welcome screen → űrlap indul
      setPrimaryScreen('welcome');
      console.log('[LOGIN] switched to welcome screen (new form)');
    }
  } catch (e) {
    console.error('[LOGIN] network/runtime error', e);
    errorEl.textContent = 'H\u00e1l\u00f3zati hiba! Pr\u00f3b\u00e1lja \u00fajra k\u00e9s\u0151bb.';
    errorEl.style.display = 'block';
    setSchoolLoginUiState(false);
  }
}

// Formátumellenőrzési függvények
function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

function validatePhoneNumber(phone) {
  // Magyar telefonszám formátum: +36 20 123 4567 vagy 06 20 123 4567 vagy 20 123 4567
  const phoneRegex = /^(\+36\s?|06\s?)?(\d{1,2}\s?\d{3}\s?\d{3,4})$/;
  return phoneRegex.test(phone.replace(/\s/g, ''));
}

function formatPhoneNumber(phone) {
  // Eltávolítjuk a szóközöket és speciális karaktereket
  let cleaned = phone.replace(/\s+/g, '').replace(/[^\d+]/g, '');

  // Ha +36-val kezdődik
  if (cleaned.startsWith('+36')) {
    cleaned = cleaned.substring(3);
  }

  // Ha 06-val kezdődik
  if (cleaned.startsWith('06')) {
    cleaned = cleaned.substring(2);
  }

  // Ha 36-val kezdődik
  if (cleaned.startsWith('36')) {
    cleaned = cleaned.substring(2);
  }

  // Formázás: +36 20 123 4567
  if (cleaned.length === 9) {
    return `+36 ${cleaned.substring(0, 2)} ${cleaned.substring(2, 5)} ${cleaned.substring(5)}`;
  }

  return phone; // Ha nem sikerül formázni, visszaadjuk az eredetit
}

// Globális változók a wizard-hoz
let currentStep = 0;
let steps = [];

function syncFinalizeConsentState() {
  const gdprCheckbox = document.getElementById('gdpr-checkbox');
  const finalizeBtn = document.getElementById('finalize-btn');
  const consentCard = document.getElementById('gdpr-consent-card');
  const checked = Boolean(gdprCheckbox?.checked);

  if (finalizeBtn) finalizeBtn.disabled = !checked;
  if (consentCard) consentCard.classList.toggle('is-checked', checked);
}

// GDPR checkbox kezelése
document.addEventListener('DOMContentLoaded', function () {
  const gdprCheckbox = document.getElementById('gdpr-checkbox');

  if (gdprCheckbox) {
    gdprCheckbox.addEventListener('change', syncFinalizeConsentState);
    syncFinalizeConsentState();
  }
});

// Globális showStep függvény
function showStep(idx, direction = 1) {
  console.log('showStep called with idx:', idx, 'direction:', direction);
  console.log('steps length:', steps.length);
  console.log('currentStep before:', currentStep);

  currentStep = idx; // Frissítjük a currentStep változót

  console.log('currentStep after:', currentStep);

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
  const progressBar = document.getElementById('form-progress');
  const progressPercent = document.getElementById('progress-percent');
  const stepperLinks = Array.from(document.querySelectorAll('.stepper- link'));
  if (progressBar && progressPercent) {
    const percent = Math.round(((idx + 1) / steps.length) * 100);
    progressBar.style.width = percent + '%';
    progressPercent.textContent = percent + '%';
  }

  // Stepper linkek frissítése
  if (stepperLinks.length > 0) {
    stepperLinks.forEach((link, i) => {
      link.classList.remove('active');
      if (i === idx) {
        link.classList.add('active');
      }
    });
  }

  // Required attribútumok frissítése
  updateRequiredAttributes();
  scheduleRequiredQuickfixRender();

  // Beállítjuk a data-original-required attribútumokat minden lépésben
  const currentStepElement = document.querySelector(`#step-${idx}`);
  if (currentStepElement) {
    currentStepElement.querySelectorAll("input, select, textarea").forEach(el => {
      if (el.hasAttribute('required') && !el.dataset.originalRequired) {
        el.dataset.originalRequired = "true";
      }
    });
  }

  // Közvetlenül beállítjuk a required attribútumokat az aktuális lépésben
  if (currentStepElement) {
    currentStepElement.querySelectorAll("input, select, textarea").forEach(el => {
      if (el.dataset.originalRequired === "true") {
        el.required = true;
      }
    });
  }

  // Ha az 1. blokkra váltunk, csak akkor generáljuk újra a csapattagokat, ha még nincsenek
  if (idx === 1) {
    const csapatLetszamInput = document.getElementById('mtmi-csapat-letszam');
    const csapatTagokDiv = document.getElementById('mtmi-csapat-tagok');
    if (csapatLetszamInput && csapatTagokDiv && csapatLetszamInput.value) {
      // Csak akkor generáljuk újra, ha még nincsenek csapattagok
      if (csapatTagokDiv.children.length === 0) {
        const event = new Event('input');
        csapatLetszamInput.dispatchEvent(event);
      }
    }
  }

  // GDPR checkbox kezelése - ha a 8-as lépésre váltunk
  if (idx === 7) { // 8-as lépés (0-tól számolva)
    const gdprCheckbox = document.getElementById('gdpr-checkbox');
    const finalizeBtn = document.getElementById('finalize-btn');

    if (gdprCheckbox && finalizeBtn) {
      // Eltávolítjuk a korábbi event listener-t, ha van
      gdprCheckbox.removeEventListener('change', gdprChangeHandler);

      // Hozzáadjuk az új event listener-t
      gdprCheckbox.addEventListener('change', gdprChangeHandler);

      // Véglegesítés gomb click event listener
      finalizeBtn.removeEventListener('click', finalizeBtnClickHandler);
      finalizeBtn.addEventListener('click', finalizeBtnClickHandler);

      // Kezdeti állapot beállítása
      syncFinalizeConsentState();
    }
  }
}

// GDPR checkbox change handler függvény
function gdprChangeHandler() {
  syncFinalizeConsentState();
}

// GDPR checkbox felvillantása, ha a véglegesítés gombra kattintanak
function highlightGdprCheckbox() {
  const gdprCheckbox = document.getElementById('gdpr-checkbox');
  const consentCard = document.getElementById('gdpr-consent-card');
  const target = consentCard || gdprCheckbox;
  if (target) {
    target.classList.add('consent-card-attention');
    target.scrollIntoView({ behavior: 'smooth', block: 'center' });

    setTimeout(() => {
      target.classList.remove('consent-card-attention');
    }, 1000);
  }
}

// Véglegesítés gomb click handler
function finalizeBtnClickHandler() {
  const gdprCheckbox = document.getElementById('gdpr-checkbox');
  if (gdprCheckbox && !gdprCheckbox.checked) {
    // Ha a GDPR checkbox nincs pipálva, felvillantjuk
    highlightGdprCheckbox();
    return false; // Megakadályozzuk a további műveleteket
  }
  // Ha pipálva van, folytatjuk a normál véglegesítést
  return true;
}

document.addEventListener('DOMContentLoaded', async function () {
  await applyPublicSubmissionStatus();
  await loadSchoolDashboard();

  // --- School login form kezelése ---
  console.log('[LOGIN] DOMContentLoaded (login init)');
  setupGuidePanel();
  setupGuideReturnLinks();
  setupMultiLinkFields();
  syncSchoolNameField('dom-content-loaded');
  const schoolLoginForm = document.getElementById('school-login-form');
  console.log('[LOGIN] school-login-form found?', Boolean(schoolLoginForm));
  if (schoolLoginForm) {
    schoolLoginForm.addEventListener('submit', async function (e) {
      console.log('[LOGIN] submit event fired');
      e.preventDefault();
      const email = document.getElementById('school-login-email').value;
      const password = document.getElementById('school-login-password').value;
      console.log('[LOGIN] submit payload prepared', { email, hasPassword: Boolean(password) });
      await handleSchoolLogin(email, password);
    });
    console.log('[LOGIN] submit listener attached');
  }

  const schoolLogoutBtn = document.getElementById('school-logout-btn');
  if (schoolLogoutBtn) {
    schoolLogoutBtn.addEventListener('click', () => performSchoolLogout());
  }
  updateSchoolLogoutButtonVisibility();

  const quickfixRefreshBtn = document.getElementById("required-quickfix-refresh-btn");
  if (quickfixRefreshBtn) {
    quickfixRefreshBtn.addEventListener("click", () => renderRequiredQuickfixPanel());
  }

  // --- Adminview bypass: ha adminview=1 paraméter van, kihagyjuk a logint ---
  const urlParams = new URLSearchParams(window.location.search);
  const adminView = urlParams.get('adminview');
  if (adminView) {
    setPrimaryScreen('form');
  }
  // --- Ha már be van lépve, nem mutatjuk a logint ---
  else if (getSchoolSession()) {
    console.log('[LOGIN] existing school session found');
    const sessionId = localStorage.getItem(SESSION_KEY) || getSessionIdFromUrl();
    console.log('[LOGIN] existing session id?', sessionId);
    if (sessionId) {
      // Van session → betöltjük az űrlapot (a loadForm kezeli a submitted státuszt)
      if (window.mtmiPublicGateLocked) {
        window.forceReadonlyView = true;
        showSubmissionClosedScreen(window.submissionStatusData);
        console.log('[LOGIN] session found during closed gate, waiting for loadForm decision');
      } else {
        setPrimaryScreen('form');
        console.log('[LOGIN] session + form id found, form screen prepared');
      }
    } else {
      // Be van lépve de nincs session → welcome screen
      if (window.mtmiPublicGateLocked) {
        showSubmissionClosedScreen(window.submissionStatusData);
        console.log('[LOGIN] school session found, no form session, but public gate closed');
      } else {
        hideSubmissionClosedScreen();
        setPrimaryScreen('welcome');
        console.log('[LOGIN] school session found, no form session, welcome shown');
      }
    }
  } else if (window.mtmiPublicGateLocked) {
    showSubmissionClosedScreen(window.submissionStatusData);
  }
  // Ha nincs belépve → login screen (alapértelmezett)

  var startBtn = document.getElementById('start-form-btn');
  if (startBtn) {
    startBtn.addEventListener('click', function () {
      setPrimaryScreen('form');
      window.scrollTo(0, 0);
    });
  } else {
    document.body.style.overflow = 'hidden';
  }
  // Wizard léptetés - késleltetett inicializálás
  setTimeout(() => {
    steps = Array.from(document.querySelectorAll('.form-step'));
    console.log('Steps found:', steps.length);
    steps.forEach((step, index) => {
      console.log(`Step ${index}:`, step.id);
    });
    currentStep = 0;
    const progressBar = document.getElementById('form-progress');
    const progressPercent = document.getElementById('progress-percent');
    const stepperLinks = Array.from(document.querySelectorAll('.stepper-link'));

    document.querySelectorAll('.next-step').forEach(btn => {
      btn.addEventListener('click', function () {
        // Késleltetés, hogy a DOM teljesen betöltődjön
        setTimeout(() => {
          // Validáció az aktuális lépésben
          const currentStepElement = steps[currentStep];

          // Ellenőrizzük, hogy a currentStepElement létezik
          if (!currentStepElement) {
            console.error('currentStepElement nem található:', currentStep, steps.length);
            return;
          }

          console.log('Validáció futtatása:', currentStep, currentStepElement.id);

          const requiredFields = currentStepElement.querySelectorAll('[required]');
          const emptyRequiredFields = [];

          console.log('Required mezők száma:', requiredFields.length);

          requiredFields.forEach(field => {
            let isEmpty = false;

            if (field.type === 'checkbox') {
              // Checkbox esetén ellenőrizzük, hogy van-e kiválasztott opció
              const checkboxGroup = field.name;
              const checkboxes = currentStepElement.querySelectorAll(`input[name="${checkboxGroup}"]:checked`);
              isEmpty = checkboxes.length === 0;
            } else if (field.type === 'select-one') {
              // Select esetén ellenőrizzük, hogy van-e kiválasztott érték
              isEmpty = !field.value || field.value === '';
            } else {
              // Input mezők esetén ellenőrizzük, hogy van-e érték
              isEmpty = !field.value.trim();
            }

            if (isEmpty) {
              emptyRequiredFields.push(field);
              console.log('Üres mező találva:', field.name, field.type);
            }
          });

          // Checkbox validáció a data-required attribútummal rendelkező elemekre
          const dataRequiredCheckboxes = currentStepElement.querySelectorAll('input[data-required="true"]');
          const checkedGroups = new Set();
          dataRequiredCheckboxes.forEach(checkbox => {
            const checkboxGroup = checkbox.name;
            if (!checkedGroups.has(checkboxGroup)) {
              const checkboxes = currentStepElement.querySelectorAll(`input[name="${checkboxGroup}"]:checked`);
              if (checkboxes.length === 0) {
                emptyRequiredFields.push(checkbox);
                console.log('Üres checkbox csoport:', checkboxGroup);
              }
              checkedGroups.add(checkboxGroup);
            }
          });

          console.log('Üres kötelező mezők száma:', emptyRequiredFields.length);

          if (emptyRequiredFields.length > 0) {
            // Popup megjelenítése
            console.log('Validációs popup megjelenítése');
            showValidationPopup(emptyRequiredFields);
            return;
          }

          // Ha nincs hiányzó kötelező mező, folytatjuk
          if (currentStep < steps.length - 1) {
            // Automatikus mentés a következő lépésre lépés előtt
            saveForm(true);
            showStep(currentStep + 1, 1);
            // Az oldal tetejére ugrunk
            window.scrollTo(0, 0);
          }
        }, 100); // 100ms késleltetés
      });
    });
    document.querySelectorAll('.prev-step').forEach(btn => {
      btn.addEventListener('click', function () {
        if (currentStep > 0) {
          // Automatikus mentés a visszalépés előtt
          saveForm(true);
          showStep(currentStep - 1, -1);
          // Az oldal tetejére ugrunk
          window.scrollTo(0, 0);
        }
      });
    });

    // Stepper navigáció kattintás - mostantól bármikor lehet kattintani
    stepperLinks.forEach((link, i) => {
      link.addEventListener('click', function () {
        if (i !== currentStep) {
          // Automatikus mentés a stepper navigáció előtt
          saveForm(true);
          const direction = i > currentStep ? 1 : -1;
          showStep(i, direction);
        }
      });
    });




    // 2. blokk: szülői képviselő feltételes logika
    // MTMI csapat tagok megjelenítése a létszám alapján
    const csapatLetszamInput = document.getElementById('mtmi-csapat-letszam');
    if (csapatLetszamInput) {
      csapatLetszamInput.addEventListener('input', function () {
        let n = parseInt(this.value, 10);
        if (isNaN(n) || n < 1) n = 1;
        if (n > 8) {
          n = 8;
          this.value = 8; // Automatikusan visszaállítjuk 8-ra
        }

        // Minden csapattag blokkot elrejtünk
        for (let i = 1; i <= 8; i++) {
          const block = document.getElementById(`csapat-tag-${i}`);
          if (block) {
            block.style.display = 'none';
          }
        }

        // Csak az első n blokkot jelenítjük meg
        for (let i = 1; i <= n; i++) {
          const block = document.getElementById(`csapat-tag-${i}`);
          if (block) {
            block.style.display = 'block';
          }
        }
      });
    }

    // 3. blokk: pedagógiai program és MTMI koncepció feltételes logika
    const pedprogSelect = document.getElementById('pedprog-mtmi-tartalom-select');
    const pedprogLeiras = document.getElementById('pedprog-mtmi-tartalom-leiras');
    if (pedprogSelect && pedprogLeiras) {
      pedprogSelect.addEventListener('change', function () {
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
      koncepcioSelect.addEventListener('change', function () {
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
  }, 100); // setTimeout blokk vége

  // --- MTMI űrlap automatikus mentés és betöltés ---

  // Segédfüggvény: űrlap adatainak kiolvasása objektumba
  function getFormData(form) {
    const data = {};

    // Összes mező összegyűjtése a teljes dokumentumból
    const allInputs = document.querySelectorAll('input, select, textarea');
    console.log('getFormData: Found', allInputs.length, 'inputs');

    allInputs.forEach(el => {
      if (!el.name) return;

      if (el.type === 'checkbox') {
        // Checkbox-ok esetében mindig tömböt hozunk létre
        if (!data[el.name]) {
          data[el.name] = [];
        }
        if (el.checked && el.value && el.value.trim() !== '') {
          data[el.name].push(el.value);
          console.log('getFormData: Added checkbox', el.name, 'value', el.value);
        }
      } else if (el.type === 'radio') {
        if (el.checked) {
          data[el.name] = el.value;
        }
      } else {
        if (el.value && el.value.trim() !== '') {
          data[el.name] = el.value;
        }
      }
    });

    console.log('getFormData: Final data:', data);
    return data;
  }

  // Segédfüggvény: űrlap feltöltése objektumból
  function setFormData(form, data) {
    try {
      console.log('setFormData: Kezdem a betöltést, adatok:', data);
      for (const [key, value] of Object.entries(data)) {
        if (Array.isArray(value)) {
          // Checkbox-ok esetében minden checkbox-ot alapértelmezetten false-ra állítunk
          // De csak a statikus checkbox-okat kezeljük itt (nem a dinamikusakat)
          const checkboxes = form.querySelectorAll(`[name='${key}']`);
          checkboxes.forEach(checkbox => {
            checkbox.checked = value.includes(checkbox.value);
          });
        } else {
          let el = form.elements[key];
          if (!el) {
            const indexedLink = String(key).match(/^(.*_link)(\d+)$/);
            if (indexedLink) {
              ensureLinkFieldCount(indexedLink[1], parseInt(indexedLink[2], 10));
              el = form.elements[key];
            } else if (String(key).endsWith('_link')) {
              ensureLinkFieldCount(String(key), 1);
              el = form.elements[`${key}1`];
            }
          }
          if (!el) continue;
          if (el.type === "radio") {
            const radio = form.querySelector(`[name='${key}'][value='${value}']`);
            if (radio) radio.checked = true;
          } else {
            el.value = value;
          }
        }
      }

      // Dinamikusan generált mezők betöltése
      const csapatTagokDiv = document.getElementById('mtmi-csapat-tagok');
      if (csapatTagokDiv) {
        csapatTagokDiv.querySelectorAll('input, textarea').forEach(el => {
          if (el.name && data[el.name] && typeof data[el.name] === 'string' && data[el.name].trim() !== '') {
            el.value = data[el.name];
          }
        });

        // Checkbox-ok betöltése
        csapatTagokDiv.querySelectorAll('input[type="checkbox"]').forEach(el => {
          if (el.name && data[el.name] && Array.isArray(data[el.name])) {
            // Csak akkor pipáljuk ki, ha az érték nem üres
            if (el.value && el.value.trim() !== '') {
              el.checked = data[el.name].includes(el.value);
            } else {
              el.checked = false;
            }
          } else {
            // Ha nincs adat, akkor ne legyen kipipálva
            el.checked = false;
          }
        });
      }

      // --- ÚJ: minden select, checkbox, radio mezőre triggereljük a change/input eseményt ---
      // De csak akkor, ha nem automatikus betöltés közben vagyunk
      if (!window.isLoadingForm) {
        ["change", "input"].forEach(eventType => {
          form.querySelectorAll("select, input[type=checkbox], input[type=radio]").forEach(el => {
            el.dispatchEvent(new Event(eventType, { bubbles: true }));
          });
        });
      }
      setTimeout(syncFinalizeConsentState, 120);

      // --- ÚJ: Ha van csapat létszám adat, megjelenítjük a csapattagokat ---
      console.log('setFormData: Ellenőrzöm a csapat létszámot:', data.mtmi_csapat_letszam, typeof data.mtmi_csapat_letszam);
      if (data.mtmi_csapat_letszam && data.mtmi_csapat_letszam !== '') {
        console.log('setFormData: Van csapat létszám adat:', data.mtmi_csapat_letszam);
        try {
          // Azonnal megjelenítjük a csapattagokat
          let n = parseInt(data.mtmi_csapat_letszam, 10);
          if (isNaN(n) || n < 1) n = 1;
          if (n > 8) n = 8;

          console.log('Megjelenítjük a csapattagokat:', n);
          console.log('DOM elemek keresése...');

          // Minden csapattag blokkot elrejtünk
          console.log('Elrejtés kezdete...');
          for (let i = 1; i <= 8; i++) {
            const block = document.getElementById(`csapat-tag-${i}`);
            if (block) {
              block.style.display = 'none';
              console.log(`Elrejtettük: csapat-tag-${i}`);
            } else {
              console.log(`Nem találtuk: csapat-tag-${i}`);
            }
          }

          // Csak az első n blokkot jelenítjük meg
          for (let i = 1; i <= n; i++) {
            const block = document.getElementById(`csapat-tag-${i}`);
            if (block) {
              block.style.display = 'block';
              console.log(`Megjelenítettük: csapat-tag-${i}`);
            } else {
              console.log(`Nem találtuk: csapat-tag-${i}`);
            }
          }
          console.log('Csapattagok megjelenítése befejezve');
        } catch (error) {
          console.error('Hiba a csapattagok megjelenítése közben:', error);
        }
      } else {
        console.log('setFormData: Nincs csapat létszám adat');
      }

      // --- ÚJ: Feltételes mezők megjelenítésének triggerelése ---
      const conditionalSelects = [
        'mtmi-szulo-kepviselo-select',
        'mtmi-palyaorientacio-megvalosul-select',
        'mtmi-diakok-kapcsolattartas-select',
        'mtmi-alumni-programok-select',
        'mtmi-online-palyaorientacio-select',
        'mtmi-egyuttmukodes-palyaorientacio-select',
        'mtmi-versenyek-szervezese-select',
        'mtmi-versenyeken-reszvetel-select',
        'mtmi-orszagos-nemzetkozi-reszvetel-select',
        'mtmi-eredmenyek-eleresek-select',
        'lanyok-mtmi-kiemelt-figyelem-select',
        'lanyoknak-szolo-mtmi-programok-select',
        'mtmi-kapcsolatok-egyuttmukodes-select',
        'mtmi-kozos-programok-select',
        'mtmi-szakmai-halozat-select',
        'mtmi-nemzetkozi-egyuttmukodes-select',
        'pedagogusok-osztonzese-select',
        'pedagogusok-tovabbkepzese-select',
        'pedagogusok-digitalis-eszkozok-select'
      ];

      conditionalSelects.forEach(selectId => {
        const select = document.getElementById(selectId);
        if (select && data[select.name]) {
          setTimeout(() => {
            const event = new Event('change');
            select.dispatchEvent(event);
          }, 150);
        }
      });

      // Pedagógiai program feltételes megjelenítés
      const pedprogSelect = document.getElementById('pedprog-mtmi-tartalom-select');
      const pedprogLeiras = document.getElementById('pedprog-mtmi-tartalom-leiras');
      if (pedprogSelect && pedprogLeiras && data.pedprog_mtmi_tartalom) {
        setTimeout(() => {
          const event = new Event('change');
          pedprogSelect.dispatchEvent(event);
        }, 200);
      }

      // MTMI koncepció feltételes megjelenítés
      const koncepcioSelect = document.getElementById('mtmi-koncepcio-select');
      const koncepcioLeiras = document.getElementById('mtmi-koncepcio-leiras');
      if (koncepcioSelect && koncepcioLeiras && data.mtmi_koncepcio) {
        setTimeout(() => {
          const event = new Event('change');
          koncepcioSelect.dispatchEvent(event);
        }, 250);
      }

      // Interdiszciplináris projekt feltételes megjelenítés
      const interdiszciplinarisSelect = document.getElementById('mtmi-interdiszciplinaris-projekt-select');
      const interdiszciplinarisBlock = document.getElementById('mtmi-interdiszciplinaris-projekt-block');
      if (interdiszciplinarisSelect && interdiszciplinarisBlock && data.mtmi_interdiszciplinaris_projekt) {
        setTimeout(() => {
          const event = new Event('change');
          interdiszciplinarisSelect.dispatchEvent(event);
        }, 300);
      }

      // Textarea automatikus méretezés az adatok betöltése után
      setTimeout(() => {
        document.querySelectorAll('textarea').forEach(textarea => {
          if (textarea.value && textarea.value.trim() !== '') {
            autoResizeTextarea(textarea);
          }
        });
      }, 100);

      console.log('setFormData: Függvény befejezve');
    } catch (error) {
      console.error('setFormData: Hiba történt:', error);
    }
  }

  // Generált link megjelenítése
  function showLink(session_id) {
    let box = document.getElementById(LINK_BOX_ID);
    if (!box) {
      box = document.createElement("div");
      box.id = LINK_BOX_ID;
      box.className = "alert alert-success mt-3";
      const form = document.getElementById(FORM_ID);
      form.parentNode.insertBefore(box, form);
    }
    const url = window.location.origin + `/kitoltes/${session_id}`;
    box.innerHTML = `<b>Az űrlapod elérhető ezen a linken:</b><br><a href='${url}' target='_blank'>${url}</a>`;
  }

  // Mentés a backendre
  async function saveForm(auto = false) {
    if (window.forceReadonlyView) return true;
    if (saveInFlight) {
      if (auto) {
        pendingAutoSave = true;
        return false;
      }
      showToast("Mentés folyamatban, kérlek várj...", "info");
      return false;
    }
    saveInFlight = true;
    let saveSucceeded = false;
    const form = document.getElementById(FORM_ID);
    if (!form) {
      saveInFlight = false;
      return false;
    }
    const data = getFormData(form);
    let session_id = localStorage.getItem(SESSION_KEY);
    // Ha az URL-ben van session_id, azt is elfogadjuk
    const urlSession = getSessionIdFromUrl();
    if (urlSession) session_id = urlSession;
    try {
      const resp = await fetch(`${API_BASE}/save`, {
        method: "POST",
        headers: buildAuthorizedHeaders({ json: true }),
        body: JSON.stringify({ data, session_id })
      });
      if (resp.ok) {
        const res = await resp.json();
        localStorage.setItem(SESSION_KEY, res.session_id);
        showLink(res.session_id);
        updateSchoolDashboardCard({
          form_id: res.session_id,
          form_status: "in_progress",
          updated_at: res.updated_at || new Date().toISOString(),
          filled_fields_count: Object.keys(data || {}).length
        });
        scheduleRequiredQuickfixRender();
        saveSucceeded = true;
        // Ha nincs session_id az URL-ben, írjuk bele (csak első mentésnél)
        if (!getSessionIdFromUrl()) {
          history.replaceState({}, "", `/kitoltes/${res.session_id}`);
        }

        // Ha be van lépve iskolaként, hozzárendeljük az űrlapot az iskolához
        const schoolSession = getSchoolSession();
        const alreadyLinkedFormId = localStorage.getItem(LINKED_FORM_ID_KEY);
        if (schoolSession && alreadyLinkedFormId !== res.session_id) {
          try {
            await fetch(`${API_BASE}/school/link-form`, {
              method: "POST",
              headers: buildAuthorizedHeaders({ json: true }),
              body: JSON.stringify({ school_id: schoolSession.school_id, form_id: res.session_id })
            });
            localStorage.setItem(LINKED_FORM_ID_KEY, res.session_id);
          } catch (linkErr) {
            console.error('Form-school link error:', linkErr);
          }
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
    } finally {
      saveInFlight = false;
      if (pendingAutoSave) {
        pendingAutoSave = false;
        saveForm(true);
      }
    }
    return saveSucceeded;
  }

  function scheduleAutoSave() {
    if (autoSaveTimer) clearTimeout(autoSaveTimer);
    autoSaveTimer = setTimeout(() => {
      autoSaveTimer = null;
      if (!window.isLoadingForm) saveForm(true);
    }, AUTO_SAVE_DEBOUNCE_MS);
  }

  function applyReadOnlyMode(form) {
    if (!form) return;
    form.querySelectorAll('input, select, textarea, button').forEach(el => {
      if (el.type === "checkbox" || el.type === "radio") {
        el.disabled = true;
        el.style.pointerEvents = "none";
      } else if (el.tagName === "SELECT" || el.tagName === "TEXTAREA") {
        el.disabled = true;
        el.style.pointerEvents = "none";
      } else if (["text", "number", "email", "url", "tel"].includes(el.type)) {
        el.readOnly = true;
        el.style.backgroundColor = "#f8f9fa";
        el.style.pointerEvents = "none";
      } else if (el.type === "submit" || el.type === "button") {
        el.style.display = "none";
      }
    });
    const saveBtn = document.getElementById("mtmi-save-btn");
    const pdfUploadBtn = document.getElementById("pdf-upload-btn");
    const pdfRemoveBtn = document.getElementById("pdf-remove-btn");
    if (saveBtn) saveBtn.style.display = "none";
    if (pdfUploadBtn) pdfUploadBtn.style.display = "none";
    if (pdfRemoveBtn) pdfRemoveBtn.style.display = "none";
    document.querySelectorAll('.next-step, .prev-step').forEach(btn => {
      btn.style.display = "none";
    });
  }

  // Betöltés a backendről
  async function loadForm() {
    console.log('loadForm: Kezdem a betöltést');
    let session_id = localStorage.getItem(SESSION_KEY);
    const urlSession = getSessionIdFromUrl();
    if (urlSession) session_id = urlSession;
    if (!session_id) {
      console.log('loadForm: Nincs session_id');
      window.currentLoadedFormSchoolId = null;
      return;
    }
    console.log('loadForm: Session_id:', session_id);
    try {
      const resp = await fetch(`${API_BASE}/load/${session_id}`, {
        headers: buildAuthorizedHeaders()
      });
      if (resp.ok) {
        const res = await resp.json();
        console.log('loadForm: Adatok betöltve:', res.data);
        console.log('loadForm: PDF fájl:', res.pdf_file_path);
        window.currentLoadedFormSchoolId = res.school_id || null;
        if (res.session_id) {
          localStorage.setItem(LINKED_FORM_ID_KEY, res.session_id);
        }
        console.log('loadForm: Form school_id:', window.currentLoadedFormSchoolId);
        updateSchoolDashboardCard({
          form_id: res.session_id || session_id,
          form_status: parseInt(res.submitted) === 1 ? "submitted" : "in_progress",
          updated_at: res.updated_at || null,
          filled_fields_count: Object.keys(res.data || {}).length
        });

        // PDF betöltése, ha van
        if (res.pdf_file_path) {
          loadPdfFromData(res.pdf_file_path);
        }

        // --- ADMINVIEW workaround ---
        const urlParams = new URLSearchParams(window.location.search);
        const adminView = urlParams.get('adminview');
        if (window.mtmiPublicGateLocked && !adminView) {
          const isSubmitted = parseInt(res.submitted) === 1;
          if (!isSubmitted) {
            window.forceReadonlyView = false;
            showSubmissionClosedScreen(window.submissionStatusData);
            console.log('loadForm: Closed gate + non-submitted form -> hidden');
            return;
          }
          window.forceReadonlyView = true;
          hideSubmissionClosedScreen();
          setPrimaryScreen('form');
          console.log('loadForm: Closed gate + submitted form -> readonly view allowed');
        }
        updateThankyouEditButton();
        if (res.submitted && parseInt(res.submitted) === 1 && !adminView && !window.forceReadonlyView) {
          // Ugyanaz a thank you screen, mint véglegesítéskor!
          document.getElementById("main-form-content").style.display = "none";
          document.getElementById("welcome-screen").style.display = "none";
          document.getElementById("thankyou-fullscreen").style.display = "flex";
          updateThankyouEditButton();
          window.scrollTo(0, 0);
          // Főoldalra vissza gomb SPA élmény
          const backBtn = document.querySelector("#thankyou-fullscreen a.btn");
          if (backBtn) {
            backBtn.addEventListener("click", function (ev) {
              ev.preventDefault();
              document.getElementById("thankyou-fullscreen").style.display = "none";
              document.getElementById("welcome-screen").style.display = "";
              document.body.style.overflow = "auto";
              window.scrollTo(0, 0);
            });
          }
          return;
        }
        const form = document.getElementById(FORM_ID);
        console.log('loadForm: Meghívom a setFormData-t');
        window.isLoadingForm = true;
        setFormData(form, res.data);
        window.isLoadingForm = false;
        syncSchoolNameField('after-load-form-data');
        scheduleRequiredQuickfixRender();
        console.log('loadForm: setFormData befejezve');

        // Dinamikusan generált mezők adatainak betöltése késleltetéssel
        setTimeout(() => {
          const csapatTagokDiv = document.getElementById('mtmi-csapat-tagok');
          if (csapatTagokDiv) {
            window.isLoadingForm = true;
            // Csak a dinamikus mezők adatait töltjük be
            csapatTagokDiv.querySelectorAll('input, textarea').forEach(el => {
              if (el.name && res.data[el.name] && typeof res.data[el.name] === 'string' && res.data[el.name].trim() !== '') {
                el.value = res.data[el.name];
                // Ha textarea, automatikusan méretezzük
                if (el.tagName === 'TEXTAREA') {
                  autoResizeTextarea(el);
                }
              }
            });

            // Checkbox-ok betöltése
            csapatTagokDiv.querySelectorAll('input[type="checkbox"]').forEach(el => {
              if (el.name && res.data[el.name] && Array.isArray(res.data[el.name])) {
                // Csak akkor pipáljuk ki, ha az érték nem üres
                if (el.value && el.value.trim() !== '') {
                  el.checked = res.data[el.name].includes(el.value);
                } else {
                  el.checked = false;
                }
              } else {
                el.checked = false;
              }
            });
            window.isLoadingForm = false;
          }

          // Végső textarea méretezés minden textarea-ra
          setTimeout(() => {
            document.querySelectorAll('textarea').forEach(textarea => {
              if (textarea.value && textarea.value.trim() !== '') {
                autoResizeTextarea(textarea);
              }
            });
          }, 100);
        }, 200);

        showLink(session_id);
        // --- ADMINVIEW: minden mező readonly/disabled, mentés/véglegesítés gombok elrejtése ---
        if (adminView || window.forceReadonlyView) {
          console.log("Readonly view detected - making all fields readonly");
          applyReadOnlyMode(form);
        }
      }
    } catch (e) {
      // Nincs adat vagy hiba
    }
  }

  // Expose loadForm globally so login handler can call it
  window.loadForm = loadForm;
  window.saveForm = saveForm;
  window.showToast = showToast;

  // Toast üzenet (Bootstrap 5)
  function showToast(msg, type = "info") {
    let toast = document.getElementById("mtmi-toast");
    if (!toast) {
      toast = document.createElement("div");
      toast.id = "mtmi-toast";
      toast.className = "toast align-items-center text-bg-" + type + " border-0 position-fixed bottom-0 end-0 m-4";
      toast.style.zIndex = 9999;
      toast.innerHTML = `<div class="d-flex"><div class="toast-body"></div><button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button></div>`;
      document.body.appendChild(toast);
    }
    toast.querySelector(".toast-body").textContent = msg;
    const bsToast = new bootstrap.Toast(toast, { delay: 2500 });
    bsToast.show();
  }

  // Események bekötése
  const initFormRuntime = () => {
    console.log('[FORM_INIT] initFormRuntime start');
    const form = document.getElementById(FORM_ID);
    if (!form) {
      console.warn('[FORM_INIT] form not found, init skipped');
      return;
    }

    // Admin view ellenőrzés és alkalmazása
    const urlParams = new URLSearchParams(window.location.search);
    const adminView = urlParams.get('adminview');
    if (adminView) {
      console.log("Admin view detected on page load");
      // Késleltetett alkalmazás, hogy a form betöltődjön
      setTimeout(() => {
        form.querySelectorAll('input, select, textarea, button').forEach(el => {
          if (el.type === "checkbox" || el.type === "radio") {
            el.disabled = true;
            el.style.pointerEvents = "none";
          } else if (el.tagName === "SELECT" || el.tagName === "TEXTAREA") {
            el.disabled = true;
            el.style.pointerEvents = "none";
          } else if (["text", "number", "email", "url", "tel"].includes(el.type)) {
            el.readOnly = true;
            el.style.backgroundColor = "#f8f9fa";
            el.style.pointerEvents = "none";
          } else if (el.type === "submit" || el.type === "button") {
            el.style.display = "none";
          }
        });
        // Gombok elrejtése
        const saveBtn = document.getElementById("mtmi-save-btn");
        const pdfUploadBtn = document.getElementById("pdf-upload-btn");
        const pdfRemoveBtn = document.getElementById("pdf-remove-btn");
        if (saveBtn) saveBtn.style.display = "none";
        if (pdfUploadBtn) pdfUploadBtn.style.display = "none";
        if (pdfRemoveBtn) pdfRemoveBtn.style.display = "none";
        document.querySelectorAll('.next-step, .prev-step').forEach(btn => {
          btn.style.display = "none";
        });
        console.log("Admin view applied on page load");
      }, 1000);
    }

    // Betöltés session_id alapján
    console.log('[FORM_INIT] calling loadForm');
    loadForm();
    const session_id = getSessionIdFromUrl() || localStorage.getItem("mtmi_session_id");
    console.log('[FORM_INIT] session candidate', session_id);
    if (session_id) {
      const welcome = document.getElementById("welcome-screen");
      const loginScreen = document.getElementById("login-screen");
      const mainForm = document.getElementById("main-form-content");
      // Csak akkor rejtsük el a welcome-t és mutassuk a formot,
      // ha a login screen már el van rejtve (vagyis a user belépett vagy adminview)
      if (loginScreen && loginScreen.style.display === 'none') {
        if (welcome) welcome.style.display = "none";
        if (mainForm) mainForm.style.display = "";
        console.log('[FORM_INIT] login hidden + session found -> main form visible');
      }
    }
    // Automatikus mentés minden mező változásakor
    form.addEventListener("input", () => {
      if (!window.isLoadingForm) {
        scheduleAutoSave();
        scheduleRequiredQuickfixRender();
      }
    });
    form.addEventListener("change", () => {
      if (!window.isLoadingForm) {
        scheduleAutoSave();
        scheduleRequiredQuickfixRender();
      }
    });
    // Manuális mentés gomb hozzáadása
    let saveBtn = document.getElementById("mtmi-save-btn");
    if (!saveBtn) {
      saveBtn = document.createElement("button");
      saveBtn.id = "mtmi-save-btn";
      saveBtn.type = "button";
      saveBtn.className = "btn btn-warning mb-3 me-2";
      saveBtn.textContent = "Mentés";
      // A progress bar fölé helyezzük a mentés gombot
      const progressContainer = document.querySelector('.d-flex.align-items-center.mb-4');
      if (progressContainer) {
        progressContainer.parentNode.insertBefore(saveBtn, progressContainer);
      } else {
        form.parentNode.insertBefore(saveBtn, form);
      }
    }
    saveBtn.addEventListener("click", () => {
      if (autoSaveTimer) {
        clearTimeout(autoSaveTimer);
        autoSaveTimer = null;
      }
      saveForm(false);
    });
    scheduleRequiredQuickfixRender();

    // PDF feltöltés kezelése
    setupPdfUpload();

    // Formátumellenőrzési eseménykezelők
    setupFormatValidation();

    // Textarea automatikus méretezés beállítása
    setupTextareaAutoResize();

    // Textarea-k méretezése betöltés után (késleltetéssel)
    setTimeout(() => {
      document.querySelectorAll('textarea').forEach(textarea => {
        autoResizeTextarea(textarea);
      });
    }, 500);
    console.log('[FORM_INIT] initFormRuntime done');
  };
  initFormRuntime();
});

// Véglegesítés gomb eseménykezelő
function isFieldVisibleForValidation(el) {
  if (!el) return false;
  const step = el.closest(".form-step");
  if (step && step.style.display === "none") return false;
  return true;
}

function getFieldLabelText(el) {
  if (!el) return el?.name || "Ismeretlen mező";
  const wrapped = el.closest(".mb-2, .mb-3, .mb-4, .row");
  const label = wrapped?.querySelector("label");
  if (label && label.textContent?.trim()) return label.textContent.trim();
  if (el.id) {
    const forLabel = document.querySelector(`label[for="${el.id}"]`);
    if (forLabel && forLabel.textContent?.trim()) return forLabel.textContent.trim();
  }
  return el.name || "Ismeretlen mező";
}

function getStepIndexFromField(el) {
  const step = el?.closest(".form-step");
  if (!step?.id) return 0;
  if (step.id === "step-final") return 8;
  const m = step.id.match(/^step-(\d+)$/);
  return m ? parseInt(m[1], 10) : 0;
}

function getMissingOriginalRequiredFields(form) {
  const missing = [];
  const requiredEls = Array.from(form.querySelectorAll("input, select, textarea"))
    .filter(el => el.dataset.originalRequired === "true");

  const seenRadio = new Set();
  const seenCheckbox = new Set();

  requiredEls.forEach(el => {
    if (el.type === "radio") {
      if (seenRadio.has(el.name)) return;
      seenRadio.add(el.name);
      const checked = form.querySelector(`input[type="radio"][name="${el.name}"]:checked`);
      if (!checked && isFieldVisibleForValidation(el)) missing.push(el);
      return;
    }

    if (el.type === "checkbox") {
      if (seenCheckbox.has(el.name)) return;
      seenCheckbox.add(el.name);
      const checked = form.querySelector(`input[type="checkbox"][name="${el.name}"]:checked`);
      if (!checked && isFieldVisibleForValidation(el)) missing.push(el);
      return;
    }

    if (isFieldVisibleForValidation(el) && (!el.value || !String(el.value).trim())) {
      missing.push(el);
    }
  });

  return missing;
}

function renderRequiredQuickfixPanel() {
  const panel = document.getElementById("required-quickfix-panel");
  const listEl = document.getElementById("required-quickfix-list");
  const countEl = document.getElementById("required-quickfix-count");
  const form = document.getElementById(FORM_ID);
  if (!panel || !listEl || !countEl || !form) return;
  if (window.forceReadonlyView) {
    panel.style.display = "none";
    return;
  }

  const missing = getMissingOriginalRequiredFields(form);
  countEl.textContent = String(missing.length);
  if (missing.length === 0) {
    panel.style.display = "none";
    listEl.textContent = "";
    return;
  }

  panel.style.display = "";
  listEl.innerHTML = "";
  missing.slice(0, 25).forEach((field) => {
    const item = document.createElement("span");
    item.className = "required-quickfix-item";
    const jump = document.createElement("button");
    jump.type = "button";
    jump.className = "required-quickfix-jump";
    jump.textContent = `${getStepIndexFromField(field)}. ${getFieldLabelText(field)}`;
    jump.addEventListener("click", () => {
      const stepIdx = getStepIndexFromField(field);
      if (typeof showStep === "function" && Number.isInteger(stepIdx) && stepIdx >= 0 && stepIdx <= 8) {
        showStep(stepIdx);
      }
      field.scrollIntoView({ behavior: "smooth", block: "center" });
      if (typeof field.focus === "function") field.focus();
    });
    item.appendChild(jump);
    listEl.appendChild(item);
  });
}

function scheduleRequiredQuickfixRender() {
  if (requiredQuickfixRaf) cancelAnimationFrame(requiredQuickfixRaf);
  requiredQuickfixRaf = requestAnimationFrame(() => {
    renderRequiredQuickfixPanel();
    requiredQuickfixRaf = null;
  });
}

document.addEventListener("DOMContentLoaded", () => {
  const finalizeBtn = document.getElementById("finalize-btn");
  if (finalizeBtn) {
    finalizeBtn.addEventListener("click", async function (e) {
      console.log("[FINALIZE] Esemény indult");
      e.preventDefault();

      const form = document.getElementById(FORM_ID);
      if (form) {
        const missingRequired = getMissingOriginalRequiredFields(form);
        if (missingRequired.length > 0) {
          const first = missingRequired[0];
          const label = first.closest('.mb-2, .mb-3, .mb-4, .row')?.querySelector('label')?.textContent?.trim() || first.name || 'ismeretlen mező';
          alert(`Hiányzó kötelező mező: ${label}`);
          first.scrollIntoView({ behavior: 'smooth', block: 'center' });
          if (typeof first.focus === 'function') first.focus();
          console.warn("[FINALIZE] missing required fields:", missingRequired.map(f => f.name));
          return;
        }
      }

      const gdprCheckbox = document.getElementById("gdpr-checkbox");
      if (gdprCheckbox && !gdprCheckbox.checked) {
        syncFinalizeConsentState();
        highlightGdprCheckbox();
        return;
      }

      if (typeof window.saveForm === "function") {
        const savedBeforeSubmit = await window.saveForm(true);
        if (!savedBeforeSubmit) {
          if (typeof window.showToast === "function") {
            window.showToast("A véglegesítés előtt nem sikerült menteni az aktuális adatokat.", "danger");
          } else {
            alert("A véglegesítés előtt nem sikerült menteni az aktuális adatokat.");
          }
          return;
        }
      }

      // --- VÉGLEGESÍTÉS: backend submit meghívása ---
      let session_id = localStorage.getItem("mtmi_session_id");
      const urlSession = getSessionIdFromUrl();
      if (urlSession) session_id = urlSession;
      console.log("[FINALIZE] session_id:", session_id);
      if (session_id) {
        try {
          const resp = await fetch(`${API_BASE}/submit/${session_id}`, {
            method: "POST",
            headers: buildAuthorizedHeaders()
          });
          console.log("[FINALIZE] Backend válasz status:", resp.status);
          const respText = await resp.text();
          console.log("[FINALIZE] Backend válasz body:", respText);
          if (resp.ok) {
            updateSchoolDashboardCard({
              form_id: session_id,
              form_status: "submitted",
              updated_at: new Date().toISOString()
            });
          }
        } catch (err) {
          console.error("[FINALIZE] Backend submit hiba:", err);
        }
      } else {
        console.warn("[FINALIZE] Nincs session_id!");
      }

      // --- Köszönőképernyő mutatása ---
      // Elrejtem minden fő tartalmat
      document.getElementById("main-form-content").style.display = "none";
      document.getElementById("welcome-screen").style.display = "none";
      if (document.getElementById("step-final")) document.getElementById("step-final").style.display = "block";
      document.getElementById("thankyou-fullscreen").style.display = "flex";
      updateThankyouEditButton();
      document.body.style.overflow = "auto";
      window.scrollTo(0, 0);

      // DOM állapot logolása
      console.log("[FINALIZE] main-form-content display:", document.getElementById("main-form-content").style.display);
      console.log("[FINALIZE] welcome-screen display:", document.getElementById("welcome-screen").style.display);
      console.log("[FINALIZE] step-final display:", document.getElementById("step-final") ? document.getElementById("step-final").style.display : "nincs");
      console.log("[FINALIZE] thankyou-fullscreen display:", document.getElementById("thankyou-fullscreen").style.display);

      // Főoldalra vissza gomb SPA élmény
      const backBtn = document.querySelector("#thankyou-fullscreen a.btn");
      if (backBtn) {
        backBtn.addEventListener("click", function (ev) {
          ev.preventDefault();
          document.getElementById("thankyou-fullscreen").style.display = "none";
          document.getElementById("welcome-screen").style.display = "";
          document.body.style.overflow = "auto";
          window.scrollTo(0, 0);
        });
      }
    });
  }
});

function updateRequiredAttributes() {
  document.querySelectorAll(".form-step").forEach(step => {
    const visible = step.style.display !== "none";
    step.querySelectorAll("input, select, textarea").forEach(el => {
      if (visible) {
        // Látható lépésekben visszaállítjuk az eredeti required attribútumokat
        if (el.dataset.originalRequired === "true") {
          el.required = true;
        }
      } else {
        // Nem látható lépésekben eltávolítjuk a required attribútumot
        el.required = false;
      }
    });
  });
}

// Eredeti required attribútumok mentése (azonnal, amikor a script betöltődik)
(function () {
  // Minden mezőt ellenőrizzünk, függetlenül attól, hogy látható-e
  document.querySelectorAll("input, select, textarea").forEach(el => {
    // Ha van required attribútum az HTML-ben, akkor beállítjuk
    if (el.hasAttribute('required')) {
      el.dataset.originalRequired = "true";
    } else {
      el.dataset.originalRequired = "false";
    }
  });
})();

// DOMContentLoaded eseményben csak frissítjük a required attribútumokat
document.addEventListener("DOMContentLoaded", () => {
  updateRequiredAttributes();
});

// Régi submit gomb eseménykezelő eltávolítva, mert most a véglegesítés gombot használjuk 

// --- Vissza a főoldalra gomb mindenhol ---
function setupBackToWelcome(selector) {
  const backBtn = document.querySelector(selector);
  if (backBtn) {
    backBtn.addEventListener("click", function (ev) {
      ev.preventDefault();
      if (document.getElementById("main-form-content")) document.getElementById("main-form-content").style.display = "none";
      if (document.getElementById("thankyou-fullscreen")) document.getElementById("thankyou-fullscreen").style.display = "none";
      // Welcome screen mutatása
      document.getElementById("welcome-screen").style.display = "";
      if (document.getElementById("main-form-content")) document.getElementById("main-form-content").style.display = "none"; // <-- ÚJ: mindig elrejtjük
      document.body.style.overflow = "auto";
      window.scrollTo(0, 0);
    });
  }
}

// Események bekötése a vissza gombokra (DOMContentLoaded után)
document.addEventListener("DOMContentLoaded", () => {
  setupBackToWelcome("#thankyou-fullscreen a.btn");
  // Üdvözlőképernyőnél mindig elrejtjük a formot
  if (document.getElementById("welcome-screen") && document.getElementById("main-form-content")) {
    if (document.getElementById("welcome-screen").style.display !== "none") {
      document.getElementById("main-form-content").style.display = "none";
    }
  }
  // Welcome screen induláskor: body scroll engedélyezése
  if (document.getElementById("welcome-screen") && document.getElementById("welcome-screen").style.display !== "none") {
    document.body.style.overflow = "auto";
  }
});

document.addEventListener("click", function (ev) {
  if (ev.target.matches("#thankyou-fullscreen a.btn")) {
    ev.preventDefault();
    if (document.getElementById("main-form-content")) document.getElementById("main-form-content").style.display = "none";
    if (document.getElementById("thankyou-fullscreen")) document.getElementById("thankyou-fullscreen").style.display = "none";
    document.getElementById("welcome-screen").style.display = "";
    if (document.getElementById("main-form-content")) document.getElementById("main-form-content").style.display = "none"; // <-- ÚJ: mindig elrejtjük
    document.body.style.overflow = "auto";
    window.scrollTo(0, 0);
  }
});

// --- Eredmények letöltése gomb a köszönőképernyőn ---
document.addEventListener("DOMContentLoaded", () => {
  const downloadBtn = document.getElementById("download-results-btn");
  const editBtn = document.getElementById("edit-submission-btn");
  if (downloadBtn) {
    downloadBtn.addEventListener("click", async function () {
      let session_id = localStorage.getItem("mtmi_session_id");
      const urlSession = getSessionIdFromUrl();
      if (urlSession) session_id = urlSession;
      if (!session_id) {
        alert("Nincs session_id, nem tudom letölteni az eredményeket.");
        return;
      }
      // Lekérjük a backendről az összes választ
      const resp = await fetch(`${API_BASE}/load/${session_id}`, {
        headers: buildAuthorizedHeaders()
      });
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
        console.log('[Összefoglaló kitöltés]', { name: key, type: el.type, tag: el.tagName, backendValue: value });
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
        textarea.form-control {
          min-height: 80px;
          resize: none;
          overflow-y: hidden;
          overflow-x: hidden;
          box-sizing: border-box;
          width: 100%;
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
          .btn, button {
            display: none !important;
          }
          .text-center.mb-3 {
            display: none !important;
          }
          .container {
            max-width: 100% !important;
            width: 100%;
            padding: 0 !important;
            margin: 0 !important;
          }
          textarea.form-control {
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
      html += `</div></div><script>
// Textarea automatikus méretezés függvény
function autoResizeTextarea(textarea) {
  textarea.style.height = 'auto';
  const scrollHeight = textarea.scrollHeight;
  const minHeight = 80;
  const newHeight = Math.max(scrollHeight, minHeight);
  textarea.style.height = newHeight + 'px';
}

window.addEventListener('DOMContentLoaded', function() {
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
    } else if (el.type === "radio") {
      el.checked = (el.value == value);
      el.disabled = true;
    } else if (el.tagName === "SELECT") {
      el.value = value;
      el.disabled = true;
    } else if (el.tagName === "TEXTAREA") {
      el.value = value;
      el.readOnly = true;
      // Automatikus méretezés
      setTimeout(function() {
        autoResizeTextarea(el);
      }, 50);
    } else if (["text","number","email","url","tel"].includes(el.type)) {
      el.value = value;
      el.readOnly = true;
    }
  });

  // Végső textarea méretezés
  setTimeout(function() {
    document.querySelectorAll('textarea').forEach(function(textarea) {
      if (textarea.value && textarea.value.trim() !== '') {
        autoResizeTextarea(textarea);
      }
    });
  }, 100);

  // ResizeObserver hozzáadása a textarea-khoz
  const resizeObserver = new ResizeObserver(function(entries) {
    entries.forEach(function(entry) {
      if (entry.target.tagName === 'TEXTAREA') {
        autoResizeTextarea(entry.target);
      }
    });
  });

  document.querySelectorAll('textarea').forEach(function(textarea) {
    resizeObserver.observe(textarea);
  });
});
<\/script></body></html>`;
      // Új ablakban nyitjuk meg a nyomtatható nézetet
      const printWindow = window.open("", "_blank");
      printWindow.document.write(html);
      printWindow.document.close();
    });
  }

  if (editBtn) {
    editBtn.addEventListener("click", async function () {
      let session_id = localStorage.getItem(SESSION_KEY);
      const urlSession = getSessionIdFromUrl();
      if (urlSession) session_id = urlSession;
      if (!session_id) {
        alert("Nincs session azonosító.");
        return;
      }

      await applyPublicSubmissionStatus();
      const status = window.submissionStatusData;
      if (!status || !status.is_available) {
        alert(status?.message || "A szerkesztés jelenleg nem elérhető.");
        return;
      }

      const resp = await fetch(`${API_BASE}/reopen/${session_id}`, {
        method: "POST",
        headers: buildAuthorizedHeaders()
      });
      if (!resp.ok) {
        const err = await resp.json().catch(() => ({}));
        alert(err.detail || "Nem sikerült megnyitni szerkesztésre a pályázatot.");
        return;
      }

      window.forceReadonlyView = false;
      setPrimaryScreen("form");
      if (typeof window.loadForm === "function") {
        await window.loadForm();
      }
      window.scrollTo(0, 0);
    });
  }
});

// Validációs popup megjelenítése
function showValidationPopup(emptyFields) {
  console.log('showValidationPopup hívva, emptyFields:', emptyFields.length);

  // Mezőnév leképezés
  const fieldNameMapping = {
    'iskolatipus': 'Iskolatípus',
    'mtmi_felelos_kapcsolattarto_neve': 'MTMI felelős kapcsolattartó neve',
    'mtmi_felelos_kapcsolattarto_beosztas': 'MTMI felelős kapcsolattartó beosztása',
    'mtmi_felelos_kapcsolattarto_telefonszam1': 'MTMI felelős kapcsolattartó telefonszáma',
    'mtmi_felelos_kapcsolattarto_email1': 'MTMI felelős kapcsolattartó e-mail címe',
    'intezmenyvezeto_kapcsolattarto_neve': 'Intézményvezető kapcsolattartó neve',
    'intezmenyvezeto_kapcsolattarto_beosztas': 'Intézményvezető kapcsolattartó beosztása',
    'intezmenyvezeto_kapcsolattarto_email1': 'Intézményvezető kapcsolattartó e-mail címe',
    'iskola_honlap_link': 'Iskolai honlap linkje',
    'iskola_mukodo_alapitvany': 'Iskola működő alapítványa',
    'iskola_mtmi_tanari_letszama': 'MTMI tanári létszám',
    'mtmi_csapat_letszam': 'MTMI csapat létszáma',
    'mtmi_csapat_kozos_tevekenyseg': 'MTMI csapat közös tevékenységei',
    'mtmi_szulo_kepviselo': 'MTMI szülői képviselő',
    'mtmi_csapat_tag1_nev': 'Név 1 - az iskola MTMI felelőse',
    'mtmi_csapat_tag1_tevekenyseg': 'Tevékenységek (1. csapattag)',
    'mtmi_csapat_tag1_szak': 'Tanított szak/szakpár (1. csapattag)'
  };

  // Mezők sorrendje a formon (0. blokk)
  const fieldOrder = [
    'iskolatipus',
    'iskola_tanuloi_letszama',
    'intezmenytipus_tanuloi_letszama',
    'programban_erintett_tanulok_szama',
    'iskola_mtmi_tanari_letszama',
    'mtmi_felelos_kapcsolattarto_neve',
    'mtmi_felelos_kapcsolattarto_beosztas',
    'mtmi_felelos_kapcsolattarto_telefonszam1',
    'mtmi_felelos_kapcsolattarto_email1',
    'intezmenyvezeto_kapcsolattarto_neve',
    'intezmenyvezeto_kapcsolattarto_beosztas',
    'intezmenyvezeto_kapcsolattarto_telefonszam1',
    'intezmenyvezeto_kapcsolattarto_email1',
    'iskola_honlap_link',
    'iskola_mukodo_alapitvany'
  ];

  // Mezők összegyűjtése és címkékkel ellátása
  const fieldInfo = [];

  emptyFields.forEach(field => {
    let label = '';

    // Label keresése különböző helyeken
    const labelElement = field.closest('.mb-3')?.querySelector('label') ||
      field.closest('.row')?.querySelector('label') ||
      field.closest('.form-check')?.querySelector('label') ||
      field.previousElementSibling?.tagName === 'LABEL' ? field.previousElementSibling : null;

    if (labelElement) {
      label = labelElement.textContent.trim();
    } else {
      // Ha nincs label, akkor a mezőnév leképezést használjuk
      label = fieldNameMapping[field.name] || field.name.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
    }

    fieldInfo.push({
      name: field.name,
      label: label,
      order: fieldOrder.indexOf(field.name)
    });
  });

  // Duplikációk elkerülése és sorrend szerint rendezés
  const uniqueFields = [];
  const seenLabels = new Set();

  fieldInfo.forEach(field => {
    if (!seenLabels.has(field.label)) {
      seenLabels.add(field.label);
      uniqueFields.push(field);
    }
  });

  // Sorrend szerint rendezés (a fieldOrder alapján)
  uniqueFields.sort((a, b) => {
    const orderA = a.order === -1 ? 999 : a.order; // Ha nincs a listában, a végére kerül
    const orderB = b.order === -1 ? 999 : b.order;
    return orderA - orderB;
  });

  const fieldLabels = uniqueFields.map(field => field.label);

  // Popup HTML létrehozása
  const popupHTML = `
    <div id="validation-popup" class="modal fade show" style="display: block; background-color: rgba(0,0,0,0.5);">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Kötelező mezők kitöltése</h5>
            <button type="button" class="btn-close" onclick="closeValidationPopup()"></button>
          </div>
          <div class="modal-body">
            <p>A következő kötelező mezők nincsenek kitöltve:</p>
            <ul>
              ${fieldLabels.map(label => `<li>${label}</li>`).join('')}
            </ul>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" onclick="skipToNextStep()">
              Még visszatérek ide
            </button>
            <button type="button" class="btn btn-primary" onclick="fillRequiredFields()">
              Kitöltöm a kötelező mezőket
            </button>
          </div>
        </div>
      </div>
    </div>
  `;

  // Popup hozzáadása a body-hoz
  document.body.insertAdjacentHTML('beforeend', popupHTML);

  // Popup megjelenítése
  const popup = document.getElementById('validation-popup');
  console.log('Popup létrehozva:', popup);

  if (popup) {
    popup.style.display = 'block';
    console.log('Popup megjelenítve');
  } else {
    console.error('Popup nem található a DOM-ban');
  }
  popup.style.display = 'block';
}

// Popup bezárása
function closeValidationPopup() {
  const popup = document.getElementById('validation-popup');
  if (popup) {
    popup.remove();
  }
  // NE folytassuk a következő lépésre, csak zárjuk be a popup-ot
}

// "Még visszatérek ide" gomb kezelése
function skipToNextStep() {
  const popup = document.getElementById('validation-popup');
  if (popup) {
    popup.remove();
  }
  // Folytassuk a következő lépésre
  if (currentStep < steps.length - 1) {
    showStep(currentStep + 1, 1);
    // Scroll az oldal tetejére
    window.scrollTo(0, 0);
  }
}

// Kötelező mezők kitöltése gomb kezelése
function fillRequiredFields() {
  closeValidationPopup();

  // Az első üres kötelező mezőre fókuszálás
  const currentStepElement = steps[currentStep];
  const requiredFields = currentStepElement.querySelectorAll('[required]');
  let firstEmptyField = null;

  // Keressük meg az első üres kötelező mezőt
  for (let field of requiredFields) {
    let isEmpty = false;

    if (field.type === 'checkbox') {
      // Checkbox esetén ellenőrizzük, hogy van-e kiválasztott opció
      const checkboxGroup = field.name;
      const checkboxes = currentStepElement.querySelectorAll(`input[name="${checkboxGroup}"]:checked`);
      isEmpty = checkboxes.length === 0;
    } else if (field.type === 'select-one') {
      // Select esetén ellenőrizzük, hogy van-e kiválasztott érték
      isEmpty = !field.value || field.value === '';
    } else {
      // Input mezők esetén ellenőrizzük, hogy van-e érték
      isEmpty = !field.value.trim();
    }

    if (isEmpty) {
      firstEmptyField = field;
      break;
    }
  }

  if (firstEmptyField) {
    // Scroll a mezőhöz
    firstEmptyField.scrollIntoView({ behavior: 'smooth', block: 'center' });

    // Kis késleltetés után fókuszálás
    setTimeout(() => {
      if (firstEmptyField.type === 'checkbox') {
        // Checkbox esetén az első checkbox-ra fókuszálunk
        const firstCheckbox = currentStepElement.querySelector(`input[name="${firstEmptyField.name}"]`);
        if (firstCheckbox) {
          firstCheckbox.focus();
        }
      } else {
        firstEmptyField.focus();
      }
    }, 300);
  }
}

// --- PDF feltöltés kezelése ---
function setupPdfUpload() {
  const pdfUpload = document.getElementById('pdf-upload');
  const pdfUploadBtn = document.getElementById('pdf-upload-btn');
  const pdfFilename = document.getElementById('pdf-filename');
  const pdfPreview = document.getElementById('pdf-preview');
  const pdfPreviewName = document.getElementById('pdf-preview-name');
  const pdfPreviewSize = document.getElementById('pdf-preview-size');
  const pdfRemoveBtn = document.getElementById('pdf-remove-btn');
  const pdfUploadProgress = document.getElementById('pdf-upload-progress');
  const pdfUploadStatus = document.getElementById('pdf-upload-status');

  if (!pdfUpload || !pdfUploadBtn) return;

  // PDF kiválasztás gomb
  pdfUploadBtn.addEventListener('click', () => {
    pdfUpload.click();
  });

  // PDF fájl kiválasztása
  pdfUpload.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (!file) return;

    // Ellenőrizzük a fájl típusát
    if (!file.type.includes('pdf')) {
      showPdfStatus('Csak PDF fájlok tölthetők fel!', 'danger');
      return;
    }

    // Ellenőrizzük a fájl méretét (10MB)
    if (file.size > 10 * 1024 * 1024) {
      showPdfStatus('A fájl mérete nem lehet nagyobb 10MB-nál!', 'danger');
      return;
    }

    // Fájl adatok megjelenítése
    pdfFilename.textContent = file.name;
    pdfPreviewName.textContent = file.name;
    pdfPreviewSize.textContent = `(${formatFileSize(file.size)})`;
    pdfPreview.style.display = 'block';
    pdfUploadStatus.style.display = 'none';

    // Automatikus feltöltés
    uploadPdfFile(file);
  });

  // PDF törlés
  pdfRemoveBtn.addEventListener('click', () => {
    pdfUpload.value = '';
    pdfFilename.textContent = 'Nincs kiválasztott fájl';
    pdfPreview.style.display = 'none';
    pdfUploadStatus.style.display = 'none';
    deletePdfFile();
  });
}

// PDF fájl feltöltése
async function uploadPdfFile(file) {
  const pdfUploadProgress = document.getElementById('pdf-upload-progress');
  const progressBar = pdfUploadProgress.querySelector('.progress-bar');

  pdfUploadProgress.style.display = 'block';
  progressBar.style.width = '0%';
  progressBar.textContent = '0%';

  const formData = new FormData();
  formData.append('file', file);

  let session_id = localStorage.getItem(SESSION_KEY);
  const urlSession = getSessionIdFromUrl();
  if (urlSession) session_id = urlSession;

  if (!session_id) {
    showPdfStatus('Nincs session_id, nem tudom feltölteni a fájlt!', 'danger');
    return;
  }

  try {
    const xhr = new XMLHttpRequest();

    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable) {
        const percentComplete = Math.round((e.loaded / e.total) * 100);
        progressBar.style.width = percentComplete + '%';
        progressBar.textContent = percentComplete + '%';
      }
    });

    xhr.addEventListener('load', () => {
      pdfUploadProgress.style.display = 'none';

      if (xhr.status === 200) {
        const response = JSON.parse(xhr.responseText);
        showPdfStatus('PDF sikeresen feltöltve!', 'success');
      } else {
        const error = JSON.parse(xhr.responseText);
        showPdfStatus(error.detail || 'Hiba a feltöltés során!', 'danger');
      }
    });

    xhr.addEventListener('error', () => {
      pdfUploadProgress.style.display = 'none';
      showPdfStatus('Hálózati hiba a feltöltés során!', 'danger');
    });

    const authToken = getCurrentAccessToken();
    xhr.open('POST', `${API_BASE}/upload-pdf/${session_id}`);
    if (authToken) {
      xhr.setRequestHeader('Authorization', `Bearer ${authToken}`);
    }
    xhr.send(formData);

  } catch (error) {
    pdfUploadProgress.style.display = 'none';
    showPdfStatus('Hiba a feltöltés során!', 'danger');
  }
}

// PDF fájl törlése
async function deletePdfFile() {
  let session_id = localStorage.getItem(SESSION_KEY);
  const urlSession = getSessionIdFromUrl();
  if (urlSession) session_id = urlSession;

  if (!session_id) return;

  try {
    const response = await fetch(`${API_BASE}/delete-pdf/${session_id}`, {
      method: 'DELETE',
      headers: buildAuthorizedHeaders()
    });

    if (response.ok) {
      showPdfStatus('PDF sikeresen törölve!', 'success');
    } else {
      showPdfStatus('Hiba a törlés során!', 'danger');
    }
  } catch (error) {
    showPdfStatus('Hálózati hiba a törlés során!', 'danger');
  }
}

// PDF státusz megjelenítése
function showPdfStatus(message, type) {
  const pdfUploadStatus = document.getElementById('pdf-upload-status');
  if (!pdfUploadStatus) return;

  pdfUploadStatus.className = `alert alert-${type}`;
  pdfUploadStatus.textContent = message;
  pdfUploadStatus.style.display = 'block';

  // Automatikus elrejtés 5 másodperc után
  setTimeout(() => {
    pdfUploadStatus.style.display = 'none';
  }, 5000);
}

// Fájl méret formázása
function formatFileSize(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// PDF betöltése meglévő adatokból
function loadPdfFromData(pdfFilePath) {
  if (!pdfFilePath) return;

  const pdfFilename = document.getElementById('pdf-filename');
  const pdfPreview = document.getElementById('pdf-preview');
  const pdfPreviewName = document.getElementById('pdf-preview-name');

  if (pdfFilename && pdfPreview && pdfPreviewName) {
    const filename = pdfFilePath.split('/').pop();
    pdfFilename.textContent = filename;
    pdfPreviewName.textContent = filename;
    pdfPreview.style.display = 'block';
  }
}

// Formátumellenőrzési eseménykezelők beállítása
function setupFormatValidation() {
  // Email mezők ellenőrzése
  document.querySelectorAll('input[type="email"]').forEach(emailInput => {
    emailInput.addEventListener('blur', function () {
      const email = this.value.trim();
      if (email && !validateEmail(email)) {
        this.classList.add('is-invalid');
        this.setCustomValidity('Kérjük, adjon meg egy érvényes email címet!');

        // Hibaüzenet megjelenítése
        let errorDiv = this.parentNode.querySelector('.invalid-feedback');
        if (!errorDiv) {
          errorDiv = document.createElement('div');
          errorDiv.className = 'invalid-feedback';
          this.parentNode.appendChild(errorDiv);
        }
        errorDiv.textContent = 'Kérjük, adjon meg egy érvényes email címet!';
      } else {
        this.classList.remove('is-invalid');
        this.setCustomValidity('');

        // Hibaüzenet eltávolítása
        const errorDiv = this.parentNode.querySelector('.invalid-feedback');
        if (errorDiv) {
          errorDiv.remove();
        }
      }
    });

    emailInput.addEventListener('input', function () {
      if (this.classList.contains('is-invalid')) {
        this.classList.remove('is-invalid');
        this.setCustomValidity('');
        const errorDiv = this.parentNode.querySelector('.invalid-feedback');
        if (errorDiv) {
          errorDiv.remove();
        }
      }
    });
  });

  // Telefonszám mezők ellenőrzése és formázása
  document.querySelectorAll('input[type="tel"]').forEach(phoneInput => {
    phoneInput.addEventListener('blur', function () {
      const phone = this.value.trim();
      if (phone && !validatePhoneNumber(phone)) {
        this.classList.add('is-invalid');
        this.setCustomValidity('Kérjük, adjon meg egy érvényes telefonszámot!');

        // Hibaüzenet megjelenítése
        let errorDiv = this.parentNode.querySelector('.invalid-feedback');
        if (!errorDiv) {
          errorDiv = document.createElement('div');
          errorDiv.className = 'invalid-feedback';
          this.parentNode.appendChild(errorDiv);
        }
        errorDiv.textContent = 'Kérjük, adjon meg egy érvényes telefonszámot! (pl. +36 20 123 4567)';
      } else {
        this.classList.remove('is-invalid');
        this.setCustomValidity('');

        // Telefonszám formázása
        if (phone && validatePhoneNumber(phone)) {
          const formattedPhone = formatPhoneNumber(phone);
          if (formattedPhone !== phone) {
            this.value = formattedPhone;
          }
        }

        // Hibaüzenet eltávolítása
        const errorDiv = this.parentNode.querySelector('.invalid-feedback');
        if (errorDiv) {
          errorDiv.remove();
        }
      }
    });

    phoneInput.addEventListener('input', function () {
      if (this.classList.contains('is-invalid')) {
        this.classList.remove('is-invalid');
        this.setCustomValidity('');
        const errorDiv = this.parentNode.querySelector('.invalid-feedback');
        if (errorDiv) {
          errorDiv.remove();
        }
      }
    });
  });
}

// Textarea automatikus méretezés beállítása
function setupTextareaAutoResize() {
  // ResizeObserver a szélesség változás figyelésére
  const resizeObserver = new ResizeObserver(entries => {
    entries.forEach(entry => {
      if (entry.target.tagName === 'TEXTAREA') {
        autoResizeTextarea(entry.target);
      }
    });
  });

  // Minden textarea-ra alkalmazunk automatikus méretezést
  document.querySelectorAll('textarea').forEach(textarea => {
    // Input eseményre automatikus méretezés
    textarea.addEventListener('input', function () {
      autoResizeTextarea(this);
    });

    // ResizeObserver hozzáadása a szélesség változás figyelésére
    resizeObserver.observe(textarea);

    // Kezdeti méretezés
    autoResizeTextarea(textarea);
  });

  // Dinamikusan hozzáadott textarea-k figyelése
  const observer = new MutationObserver(function (mutations) {
    mutations.forEach(function (mutation) {
      mutation.addedNodes.forEach(function (node) {
        if (node.nodeType === 1) { // Element node
          const textareas = node.querySelectorAll ? node.querySelectorAll('textarea') : [];
          textareas.forEach(textarea => {
            textarea.addEventListener('input', function () {
              autoResizeTextarea(this);
            });
            // ResizeObserver hozzáadása
            resizeObserver.observe(textarea);
            autoResizeTextarea(textarea);
          });
        }
      });
    });
  });

  observer.observe(document.body, { childList: true, subtree: true });
}

// Textarea automatikus méretezés függvény
function autoResizeTextarea(textarea) {
  // Először eltávolítjuk a beállított magasságot, hogy mérni tudjuk a tartalmat
  textarea.style.height = 'auto';

  // Kiszámítjuk a szükséges magasságot
  const scrollHeight = textarea.scrollHeight;
  const minHeight = 80; // Minimum magasság (CSS-ben is ez van beállítva)

  // Beállítjuk a magasságot a tartalom alapján
  const newHeight = Math.max(scrollHeight, minHeight);
  textarea.style.height = newHeight + 'px';

  console.log('Textarea resized:', textarea.name, 'scrollHeight:', scrollHeight, 'newHeight:', newHeight);
} 

const API_BASE = "https://mtmi.onrender.com/api";

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

function showAdminListBlock() {
  document.getElementById("admin-login-block").style.display = "none";
  const listBlock = document.getElementById("admin-list-block");
  listBlock.style.display = "";
  listBlock.classList.add("wide-admin");
  const listCard = document.querySelector(".admin-list-card");
  if (listCard) listCard.classList.add("wide-admin");
  loadAdminList();
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
document.addEventListener("DOMContentLoaded", function() {
  if (isAdminLoggedIn()) {
    showAdminListBlock();
  } else {
    showAdminLoginBlock();
  }
});

// --- Admin login ---
document.getElementById("admin-login-form").addEventListener("submit", async function(e) {
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
document.addEventListener("DOMContentLoaded", function() {
  const logoutBtn = document.getElementById("admin-logout-btn");
  if (logoutBtn) {
    logoutBtn.addEventListener("click", function() {
      setAdminSession(false);
      showAdminLoginBlock();
    });
  }
});

let deleteSessionId = null;

// --- Kitöltések listázása ---
async function loadAdminList() {
  const resp = await fetch(`${API_BASE}/admin/list`);
  const list = await resp.json();
  const tbody = document.getElementById("admin-list-tbody");
  tbody.innerHTML = "";
  for (const row of list) {
    const tr = document.createElement("tr");
    // Iskola neve kattintható
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
      pdfLink.addEventListener("click", function(e) {
        e.preventDefault();
        // Lekérjük a pontos PDF fájl nevét
        fetch(`${API_BASE}/admin/result/${row.id}`)
          .then(resp => resp.json())
          .then(data => {
            if (data.pdf_file_path) {
              // URL encoding a fájlnévhez
              const encodedPath = encodeURIComponent(data.pdf_file_path);
              const pdfUrl = `${API_BASE.replace('/api', '')}/uploads/${encodedPath}`;
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

// Modal megerősítés gomb esemény
if (document.getElementById('confirmDeleteBtn')) {
  document.getElementById('confirmDeleteBtn').addEventListener('click', async function() {
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
  </style>`;
  html += `</head><body class='bg-light'><div class='container py-5'>`;
  // PDF link hozzáadása, ha van
  let pdfLinkHtml = '';
  if (res.pdf_file_path) {
    const encodedPath = encodeURIComponent(res.pdf_file_path);
    const pdfUrl = `${API_BASE.replace('/api', '')}/uploads/${encodedPath}`;
    pdfLinkHtml = `
      <div class="text-center mb-4">
        <a href="${pdfUrl}" target="_blank" class="btn btn-outline-danger">
          <i class="bi bi-file-earmark-pdf"></i> PDF megtekintése
        </a>
      </div>
    `;
  }
  
  html += `<h1 class='mb-4 text-center fw-bold'>MTMI Iskola Program<br><span class='text-primary'>Pályázati űrlap (összefoglaló)</span></h1>`;
  html += formClone.innerHTML;
  // PDF link a form után, de még a container-en belül
  if (res.pdf_file_path) {
    const encodedPath = encodeURIComponent(res.pdf_file_path);
    const pdfUrl = `${API_BASE.replace('/api', '')}/uploads/${encodedPath}`;
    html += `
      <div class="text-center mt-4 mb-4">
        <a href="${pdfUrl}" target="_blank" class="btn btn-outline-danger btn-lg">
          <i class="bi bi-file-earmark-pdf"></i> PDF megtekintése
        </a>
      </div>
    `;
  }
  html += `</div><script>
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
    }, 100);
  </script></body></html>`;
  // Új ablakban nyitjuk meg a nyomtatható nézetet
  const printWindow = window.open("", "_blank");
  printWindow.document.write(html);
  printWindow.document.close();
} 
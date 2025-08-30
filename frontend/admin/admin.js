const API_BASE = "https://mtmi.onrender.com/api"; // Production API

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
    
    // Excel export gomb
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
    /* Textarea automatikus méretezése a tartalomhoz */
    textarea {
      resize: none !important;
      min-height: 100px !important;
      overflow: visible !important;
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
  </style>`;
  html += `</head><body class='bg-light'><div class='container py-5'>`;
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
      const detailResp = await fetch(`${API_BASE}/admin/detail/${submission.session_id}`);
      const detail = await detailResp.json();
      
      // Minden mezőt hozzáadunk a headers-hez
      Object.keys(detail).forEach(key => headers.add(key));
      
      allData.push(detail);
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


 
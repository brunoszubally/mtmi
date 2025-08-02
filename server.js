const express = require('express');
const path = require('path');
const app = express();

const staticDir = __dirname;

// Statikus fájlok kiszolgálása
app.use(express.static(staticDir));

// /admin útvonalra admin.html
app.get('/admin', (req, res) => {
  res.sendFile(path.join(staticDir, 'admin.html'));
});

// Minden más útvonalra index.html (SPA)
app.get('*', (req, res) => {
  res.sendFile(path.join(staticDir, 'index.html'));
});

// Port beállítása (Render/Koyeb automatikusan PORT env változót ad)
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Szerver fut: http://localhost:${PORT}`);
}); 
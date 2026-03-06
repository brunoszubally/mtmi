-- MTMI Migration: Schools tábla és kapcsolódó módosítások
-- Futtasd le a Supabase SQL Editorban (supabase.com -> SQL Editor)

-- 1. school_id oszlop hozzáadása a forms táblához
ALTER TABLE forms ADD COLUMN IF NOT EXISTS school_id TEXT;

-- 2. schools tábla létrehozása
CREATE TABLE IF NOT EXISTS schools (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    password_hash TEXT,
    form_id TEXT,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- 3. Meglévő iskolák automatikus migrálása a forms táblából
-- (Csak azokat a formokat veszi figyelembe, amelyekhez még nincs school)
INSERT INTO schools (id, name, email, password_hash, form_id, created_at, updated_at)
SELECT
    gen_random_uuid()::text,
    data->>'palyazo_iskola_neve',
    NULL,
    NULL,
    forms.id,
    NOW(),
    NOW()
FROM forms
WHERE data->>'palyazo_iskola_neve' IS NOT NULL
  AND data->>'palyazo_iskola_neve' != ''
  AND forms.id NOT IN (SELECT form_id FROM schools WHERE form_id IS NOT NULL);

-- 4. forms.school_id kitöltése a schools tábla alapján
UPDATE forms SET school_id = schools.id
FROM schools
WHERE schools.form_id = forms.id AND forms.school_id IS NULL;

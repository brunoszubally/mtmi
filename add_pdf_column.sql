-- Add pdf_file_path column to forms table
ALTER TABLE forms ADD COLUMN IF NOT EXISTS pdf_file_path TEXT;

-- Check if the column was added successfully
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'forms' AND column_name = 'pdf_file_path'; 
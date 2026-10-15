Form concurrency regression checks
=================================

Pure merge tests (Node.js, no packages):

    node --test tests/form-concurrency.test.cjs

PostgreSQL integration tests use a unique temporary schema. They reject remote
database hosts and never load the application `.env`:

    MTMI_TEST_DATABASE_URL=postgresql://localhost:55439/mtmi_concurrency_test backend/venv/bin/python tests/test_form_writes.py -v

Browser tests need a disposable PostgreSQL database named
`mtmi_concurrency_test` on localhost:55439, Playwright available to Node.js, and
Google Chrome on macOS. Start the application explicitly against that database:

    DATABASE_URL=postgresql://127.0.0.1:55439/mtmi_concurrency_test BACKUP_ENABLED=0 AUTH_SECRET=mtmi-local-test-secret backend/venv/bin/uvicorn main:app --app-dir backend --host 127.0.0.1 --port 8097
    node tests/browser-concurrency.cjs

The browser test creates local fixture records, opens the local submission
window, then checks independent edits, an explicit conflict choice, legacy
draft recovery, typing during a pending save, and rejection of old clients.
Never start this test server against the production database.

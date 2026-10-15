"""Run with MTMI_TEST_DATABASE_URL pointing to a disposable local PostgreSQL DB."""
import os
import sys
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path
from threading import Barrier
from uuid import uuid4

import psycopg2
from psycopg2.extensions import parse_dsn
from fastapi import HTTPException

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
from form_writes import save_school_form, submit_school_form

DSN = os.environ.get('MTMI_TEST_DATABASE_URL')


@unittest.skipUnless(DSN, 'set MTMI_TEST_DATABASE_URL to run PostgreSQL integration tests')
class FormWritesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if parse_dsn(DSN).get('host') not in ('127.0.0.1', 'localhost', '/private/tmp', '/tmp'):
            raise RuntimeError('Tests require an explicitly local PostgreSQL server')
        cls.schema = 'mtmi_test_' + uuid4().hex
        with psycopg2.connect(DSN) as conn:
            with conn.cursor() as cur:
                cur.execute('CREATE SCHEMA ' + cls.schema)
                cur.execute('SET search_path TO ' + cls.schema)
                cur.execute('CREATE TABLE schools (id TEXT PRIMARY KEY, form_id TEXT, updated_at TIMESTAMP)')
                cur.execute('CREATE TABLE forms (id TEXT PRIMARY KEY, data JSONB, created_at TIMESTAMP, updated_at TIMESTAMP, school_id TEXT, submitted INTEGER)')

    @classmethod
    def tearDownClass(cls):
        with psycopg2.connect(DSN) as conn:
            with conn.cursor() as cur:
                cur.execute('DROP SCHEMA ' + cls.schema + ' CASCADE')

    def connect(self):
        return psycopg2.connect(DSN, options='-c search_path=' + self.schema)

    def setUp(self):
        self.school = str(uuid4())
        with self.connect() as conn:
            with conn.cursor() as cur:
                cur.execute('INSERT INTO schools(id) VALUES(%s)', (self.school,))

    def save(self, form_id, data, version, school=None):
        conn = self.connect()
        try:
            with conn:
                return save_school_form(conn, school or self.school, form_id, data, version)
        finally:
            conn.close()

    def assert_error(self, status, action, code=None):
        with self.assertRaises(HTTPException) as raised:
            action()
        self.assertEqual(raised.exception.status_code, status)
        if code:
            self.assertEqual(raised.exception.detail['code'], code)
        return raised.exception

    def test_stale_and_legacy_writes_cannot_overwrite(self):
        fid, version = self.save(None, {'a':'original'}, None)
        _, newer = self.save(fid, {'a':'new'}, version)
        conflict = self.assert_error(409, lambda: self.save(fid, {'a':'stale'}, version), 'version_conflict')
        self.assertEqual(conflict.detail['current']['data'], {'a':'new'})
        self.assert_error(428, lambda: self.save(fid, {'a':'legacy'}, None), 'reload_required')
        self.assertGreater(newer, version)
        self.assertEqual(self.save(fid, {'a':'new'}, newer)[1], newer)

    def test_two_first_saves_create_only_one_linked_form(self):
        barrier = Barrier(2)
        def first_save(value):
            barrier.wait()
            try:
                return self.save(None, {'a':value}, None)
            except HTTPException as exc:
                return exc.status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(first_save, ['one', 'two']))
        self.assertEqual(sum(isinstance(r, tuple) for r in results), 1)
        self.assertIn(409, results)
        with self.connect() as conn:
            with conn.cursor() as cur:
                cur.execute('SELECT COUNT(*) FROM forms WHERE school_id=%s', (self.school,))
                self.assertEqual(cur.fetchone()[0], 1)

    def test_simultaneous_updates_have_exactly_one_winner(self):
        fid, version = self.save(None, {'a':'original'}, None)
        barrier = Barrier(2)
        def write(value):
            barrier.wait()
            try:
                return self.save(fid, {'a':value}, version)
            except HTTPException as exc:
                return exc.status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(write, ['one', 'two']))
        self.assertEqual(sum(isinstance(r, tuple) for r in results), 1)
        self.assertIn(409, results)

    def test_wrong_form_id_cannot_replace_the_school_link(self):
        fid, version = self.save(None, {'a':'keep'}, None)
        self.assert_error(409, lambda: self.save(str(uuid4()), {}, version), 'form_link_changed')
        self.assert_error(409, lambda: self.save(None, {}, None), 'form_link_changed')
        with self.connect() as conn:
            with conn.cursor() as cur:
                cur.execute('SELECT form_id FROM schools WHERE id=%s', (self.school,))
                self.assertEqual(cur.fetchone()[0], fid)

    def test_submit_is_version_checked_and_blocks_further_writes(self):
        fid, version = self.save(None, {'a':'old'}, None)
        _, newer = self.save(fid, {'a':'new'}, version)
        with self.connect() as conn:
            self.assert_error(409, lambda: submit_school_form(conn, fid, self.school, version), 'version_conflict')
            submitted_at = submit_school_form(conn, fid, self.school, newer)
        self.assert_error(409, lambda: self.save(fid, {'a':'oops'}, submitted_at), 'form_submitted')

    def test_other_school_is_untouched_and_cannot_be_adopted(self):
        fid, version = self.save(None, {'a':'keep'}, None)
        other = str(uuid4())
        with self.connect() as conn:
            with conn.cursor() as cur:
                cur.execute('INSERT INTO schools(id,form_id) VALUES(%s,%s)', (other, fid))
        self.assert_error(403, lambda: self.save(fid, {'a':'foreign'}, version, other))
        self.assertEqual(self.save(fid, {'a':'keep'}, version)[1], version)

if __name__ == '__main__':
    unittest.main()

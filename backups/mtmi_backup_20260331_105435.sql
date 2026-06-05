--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA extensions;


--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql;


--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql_public;


--
-- Name: pgbouncer; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgbouncer;


--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA realtime;


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA storage;


--
-- Name: vault; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA vault;


--
-- Name: pg_graphql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_graphql WITH SCHEMA graphql;


--
-- Name: EXTENSION pg_graphql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_graphql IS 'pg_graphql: GraphQL support';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;


--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION supabase_vault IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: action; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'ERROR'
);


--
-- Name: equality_op; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.equality_op AS ENUM (
    'eq',
    'neq',
    'lt',
    'lte',
    'gt',
    'gte',
    'in'
);


--
-- Name: user_defined_filter; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.user_defined_filter AS (
	column_name text,
	op realtime.equality_op,
	value text
);


--
-- Name: wal_column; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_column AS (
	name text,
	type_name text,
	type_oid oid,
	value jsonb,
	is_pkey boolean,
	is_selectable boolean
);


--
-- Name: wal_rls; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_rls AS (
	wal jsonb,
	is_rls_enabled boolean,
	subscription_ids uuid[],
	errors text[]
);


--
-- Name: buckettype; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE storage.buckettype AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION email(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION role(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION uid(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: grant_pg_cron_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_cron_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_cron_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_cron_access() IS 'Grants access to pg_cron';


--
-- Name: grant_pg_graphql_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_graphql_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
        LEFT JOIN pg_catalog.pg_proc AS n
        ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        -- Update public wrapper to pass all arguments through to the pg_graphql resolve func
        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
            select graphql.resolve(
                query := query,
                variables := coalesce(variables, '{}'),
                "operationName" := "operationName",
                extensions := extensions
            );
        $$;

        -- This hook executes when `graphql.resolve` is created. That is not necessarily the last
        -- function in the extension so we need to grant permissions on existing entities AND
        -- update default permissions to any others that are created after `graphql.resolve`
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant select on all tables in schema graphql to postgres, anon, authenticated, service_role;
        grant execute on all functions in schema graphql to postgres, anon, authenticated, service_role;
        grant all on all sequences in schema graphql to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;

        -- Allow postgres role to allow granting usage on graphql and graphql_public schemas to custom roles
        grant usage on schema graphql_public to postgres with grant option;
        grant usage on schema graphql to postgres with grant option;
    END IF;

END;
$_$;


--
-- Name: FUNCTION grant_pg_graphql_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_graphql_access() IS 'Grants access to pg_graphql';


--
-- Name: grant_pg_net_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_net_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = 'supabase_functions_admin'
    )
    THEN
      CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
    END IF;

    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    IF EXISTS (
      SELECT FROM pg_extension
      WHERE extname = 'pg_net'
      -- all versions in use on existing projects as of 2025-02-20
      -- version 0.12.0 onwards don't need these applied
      AND extversion IN ('0.2', '0.6', '0.7', '0.7.1', '0.8', '0.10.0', '0.11.0')
    ) THEN
      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

      REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

      GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
      GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_net_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_net_access() IS 'Grants access to pg_net';


--
-- Name: pgrst_ddl_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: pgrst_drop_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: set_graphql_placeholder(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.set_graphql_placeholder() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$_$;


--
-- Name: FUNCTION set_graphql_placeholder(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.set_graphql_placeholder() IS 'Reintroduces placeholder function for graphql_public.graphql';


--
-- Name: get_auth(text); Type: FUNCTION; Schema: pgbouncer; Owner: -
--

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
begin
    raise debug 'PgBouncer auth request: %', p_usename;

    return query
    select 
        rolname::text, 
        case when rolvaliduntil < now() 
            then null 
            else rolpassword::text 
        end 
    from pg_authid 
    where rolname=$1 and rolcanlogin;
end;
$_$;


--
-- Name: apply_rls(jsonb, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer DEFAULT (1024 * 1024)) RETURNS SETOF realtime.wal_rls
    LANGUAGE plpgsql
    AS $$
declare
-- Regclass of the table e.g. public.notes
entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

-- I, U, D, T: insert, update ...
action realtime.action = (
    case wal ->> 'action'
        when 'I' then 'INSERT'
        when 'U' then 'UPDATE'
        when 'D' then 'DELETE'
        else 'ERROR'
    end
);

-- Is row level security enabled for the table
is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

subscriptions realtime.subscription[] = array_agg(subs)
    from
        realtime.subscription subs
    where
        subs.entity = entity_
        -- Filter by action early - only get subscriptions interested in this action
        -- action_filter column can be: '*' (all), 'INSERT', 'UPDATE', or 'DELETE'
        and (subs.action_filter = '*' or subs.action_filter = action::text);

-- Subscription vars
roles regrole[] = array_agg(distinct us.claims_role::text)
    from
        unnest(subscriptions) us;

working_role regrole;
claimed_role regrole;
claims jsonb;

subscription_id uuid;
subscription_has_access bool;
visible_to_subscription_ids uuid[] = '{}';

-- structured info for wal's columns
columns realtime.wal_column[];
-- previous identity values for update/delete
old_columns realtime.wal_column[];

error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

-- Primary jsonb output for record
output jsonb;

begin
perform set_config('role', null, true);

columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'columns') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

old_columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'identity') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

for working_role in select * from unnest(roles) loop

    -- Update `is_selectable` for columns and old_columns
    columns =
        array_agg(
            (
                c.name,
                c.type_name,
                c.type_oid,
                c.value,
                c.is_pkey,
                pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
            )::realtime.wal_column
        )
        from
            unnest(columns) c;

    old_columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(old_columns) c;

    if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            -- subscriptions is already filtered by entity
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 400: Bad Request, no primary key']
        )::realtime.wal_rls;

    -- The claims role does not have SELECT permission to the primary key of entity
    elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 401: Unauthorized']
        )::realtime.wal_rls;

    else
        output = jsonb_build_object(
            'schema', wal ->> 'schema',
            'table', wal ->> 'table',
            'type', action,
            'commit_timestamp', to_char(
                ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
            ),
            'columns', (
                select
                    jsonb_agg(
                        jsonb_build_object(
                            'name', pa.attname,
                            'type', pt.typname
                        )
                        order by pa.attnum asc
                    )
                from
                    pg_attribute pa
                    join pg_type pt
                        on pa.atttypid = pt.oid
                where
                    attrelid = entity_
                    and attnum > 0
                    and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
            )
        )
        -- Add "record" key for insert and update
        || case
            when action in ('INSERT', 'UPDATE') then
                jsonb_build_object(
                    'record',
                    (
                        select
                            jsonb_object_agg(
                                -- if unchanged toast, get column name and value from old record
                                coalesce((c).name, (oc).name),
                                case
                                    when (c).name is null then (oc).value
                                    else (c).value
                                end
                            )
                        from
                            unnest(columns) c
                            full outer join unnest(old_columns) oc
                                on (c).name = (oc).name
                        where
                            coalesce((c).is_selectable, (oc).is_selectable)
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                    )
                )
            else '{}'::jsonb
        end
        -- Add "old_record" key for update and delete
        || case
            when action = 'UPDATE' then
                jsonb_build_object(
                        'old_record',
                        (
                            select jsonb_object_agg((c).name, (c).value)
                            from unnest(old_columns) c
                            where
                                (c).is_selectable
                                and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                        )
                    )
            when action = 'DELETE' then
                jsonb_build_object(
                    'old_record',
                    (
                        select jsonb_object_agg((c).name, (c).value)
                        from unnest(old_columns) c
                        where
                            (c).is_selectable
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                    )
                )
            else '{}'::jsonb
        end;

        -- Create the prepared statement
        if is_rls_enabled and action <> 'DELETE' then
            if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                deallocate walrus_rls_stmt;
            end if;
            execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
        end if;

        visible_to_subscription_ids = '{}';

        for subscription_id, claims in (
                select
                    subs.subscription_id,
                    subs.claims
                from
                    unnest(subscriptions) subs
                where
                    subs.entity = entity_
                    and subs.claims_role = working_role
                    and (
                        realtime.is_visible_through_filters(columns, subs.filters)
                        or (
                          action = 'DELETE'
                          and realtime.is_visible_through_filters(old_columns, subs.filters)
                        )
                    )
        ) loop

            if not is_rls_enabled or action = 'DELETE' then
                visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
            else
                -- Check if RLS allows the role to see the record
                perform
                    -- Trim leading and trailing quotes from working_role because set_config
                    -- doesn't recognize the role as valid if they are included
                    set_config('role', trim(both '"' from working_role::text), true),
                    set_config('request.jwt.claims', claims::text, true);

                execute 'execute walrus_rls_stmt' into subscription_has_access;

                if subscription_has_access then
                    visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
                end if;
            end if;
        end loop;

        perform set_config('role', null, true);

        return next (
            output,
            is_rls_enabled,
            visible_to_subscription_ids,
            case
                when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                else '{}'
            end
        )::realtime.wal_rls;

    end if;
end loop;

perform set_config('role', null, true);
end;
$$;


--
-- Name: broadcast_changes(text, text, text, text, text, record, record, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text DEFAULT 'ROW'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$$;


--
-- Name: build_prepared_statement_sql(text, regclass, realtime.wal_column[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) RETURNS text
    LANGUAGE sql
    AS $$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{"id"}'::text[], '{"bigint"}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $$;


--
-- Name: cast(text, regtype); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime."cast"(val text, type_ regtype) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
  res jsonb;
begin
  if type_::text = 'bytea' then
    return to_jsonb(val);
  end if;
  execute format('select to_jsonb(%L::'|| type_::text || ')', val) into res;
  return res;
end
$$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
      /*
      Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
      */
      declare
          op_symbol text = (
              case
                  when op = 'eq' then '='
                  when op = 'neq' then '!='
                  when op = 'lt' then '<'
                  when op = 'lte' then '<='
                  when op = 'gt' then '>'
                  when op = 'gte' then '>='
                  when op = 'in' then '= any'
                  else 'UNKNOWN OP'
              end
          );
          res boolean;
      begin
          execute format(
              'select %L::'|| type_::text || ' ' || op_symbol
              || ' ( %L::'
              || (
                  case
                      when op = 'in' then type_::text || '[]'
                      else type_::text end
              )
              || ')', val_1, val_2) into res;
          return res;
      end;
      $$;


--
-- Name: is_visible_through_filters(realtime.wal_column[], realtime.user_defined_filter[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
    /*
    Should the record be visible (true) or filtered out (false) after *filters* are applied
    */
        select
            -- Default to allowed when no filters present
            $2 is null -- no filters. this should not happen because subscriptions has a default
            or array_length($2, 1) is null -- array length of an empty array is null
            or bool_and(
                coalesce(
                    realtime.check_equality_op(
                        op:=f.op,
                        type_:=coalesce(
                            col.type_oid::regtype, -- null when wal2json version <= 2.4
                            col.type_name::regtype
                        ),
                        -- cast jsonb to text
                        val_1:=col.value #>> '{}',
                        val_2:=f.value
                    ),
                    false -- if null, filter does not match
                )
            )
        from
            unnest(filters) f
            join unnest(columns) col
                on f.column_name = col.name;
    $_$;


--
-- Name: list_changes(name, name, integer, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer) RETURNS SETOF realtime.wal_rls
    LANGUAGE sql
    SET log_min_messages TO 'fatal'
    AS $$
      with pub as (
        select
          concat_ws(
            ',',
            case when bool_or(pubinsert) then 'insert' else null end,
            case when bool_or(pubupdate) then 'update' else null end,
            case when bool_or(pubdelete) then 'delete' else null end
          ) as w2j_actions,
          coalesce(
            string_agg(
              realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
              ','
            ) filter (where ppt.tablename is not null and ppt.tablename not like '% %'),
            ''
          ) w2j_add_tables
        from
          pg_publication pp
          left join pg_publication_tables ppt
            on pp.pubname = ppt.pubname
        where
          pp.pubname = publication
        group by
          pp.pubname
        limit 1
      ),
      w2j as (
        select
          x.*, pub.w2j_add_tables
        from
          pub,
          pg_logical_slot_get_changes(
            slot_name, null, max_changes,
            'include-pk', 'true',
            'include-transaction', 'false',
            'include-timestamp', 'true',
            'include-type-oids', 'true',
            'format-version', '2',
            'actions', pub.w2j_actions,
            'add-tables', pub.w2j_add_tables
          ) x
      )
      select
        xyz.wal,
        xyz.is_rls_enabled,
        xyz.subscription_ids,
        xyz.errors
      from
        w2j,
        realtime.apply_rls(
          wal := w2j.data::jsonb,
          max_record_bytes := max_record_bytes
        ) xyz(wal, is_rls_enabled, subscription_ids, errors)
      where
        w2j.w2j_add_tables <> ''
        and xyz.subscription_ids[1] is not null
    $$;


--
-- Name: quote_wal2json(regclass); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.quote_wal2json(entity regclass) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
      select
        (
          select string_agg('' || ch,'')
          from unnest(string_to_array(nsp.nspname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
        )
        || '.'
        || (
          select string_agg('' || ch,'')
          from unnest(string_to_array(pc.relname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
          )
      from
        pg_class pc
        join pg_namespace nsp
          on pc.relnamespace = nsp.oid
      where
        pc.oid = entity
    $$;


--
-- Name: send(jsonb, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    -- Generate a new UUID for the id
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    -- Attempt to insert the message
    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      -- Capture and notify the error
      RAISE WARNING 'ErrorSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: subscription_check_filters(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.subscription_check_filters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    /*
    Validates that the user defined filters for a subscription:
    - refer to valid columns that the claimed role may access
    - values are coercable to the correct column type
    */
    declare
        col_names text[] = coalesce(
                array_agg(c.column_name order by c.ordinal_position),
                '{}'::text[]
            )
            from
                information_schema.columns c
            where
                format('%I.%I', c.table_schema, c.table_name)::regclass = new.entity
                and pg_catalog.has_column_privilege(
                    (new.claims ->> 'role'),
                    format('%I.%I', c.table_schema, c.table_name)::regclass,
                    c.column_name,
                    'SELECT'
                );
        filter realtime.user_defined_filter;
        col_type regtype;

        in_val jsonb;
    begin
        for filter in select * from unnest(new.filters) loop
            -- Filtered column is valid
            if not filter.column_name = any(col_names) then
                raise exception 'invalid column for filter %', filter.column_name;
            end if;

            -- Type is sanitized and safe for string interpolation
            col_type = (
                select atttypid::regtype
                from pg_catalog.pg_attribute
                where attrelid = new.entity
                      and attname = filter.column_name
            );
            if col_type is null then
                raise exception 'failed to lookup type for column %', filter.column_name;
            end if;

            -- Set maximum number of entries for in filter
            if filter.op = 'in'::realtime.equality_op then
                in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
                if coalesce(jsonb_array_length(in_val), 0) > 100 then
                    raise exception 'too many values for `in` filter. Maximum 100';
                end if;
            else
                -- raises an exception if value is not coercable to type
                perform realtime.cast(filter.value, col_type);
            end if;

        end loop;

        -- Apply consistent order to filters so the unique constraint on
        -- (subscription_id, entity, filters) can't be tricked by a different filter order
        new.filters = coalesce(
            array_agg(f order by f.column_name, f.op, f.value),
            '{}'
        ) from unnest(new.filters) f;

        return new;
    end;
    $$;


--
-- Name: to_regrole(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.to_regrole(role_name text) RETURNS regrole
    LANGUAGE sql IMMUTABLE
    AS $$ select role_name::regrole $$;


--
-- Name: topic(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.topic() RETURNS text
    LANGUAGE sql STABLE
    AS $$
select nullif(current_setting('realtime.topic', true), '')::text;
$$;


--
-- Name: can_insert_object(text, text, uuid, jsonb); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


--
-- Name: delete_leaf_prefixes(text[], text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_leaf_prefixes(bucket_ids text[], names text[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_rows_deleted integer;
BEGIN
    LOOP
        WITH candidates AS (
            SELECT DISTINCT
                t.bucket_id,
                unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        ),
        uniq AS (
             SELECT
                 bucket_id,
                 name,
                 storage.get_level(name) AS level
             FROM candidates
             WHERE name <> ''
             GROUP BY bucket_id, name
        ),
        leaf AS (
             SELECT
                 p.bucket_id,
                 p.name,
                 p.level
             FROM storage.prefixes AS p
                  JOIN uniq AS u
                       ON u.bucket_id = p.bucket_id
                           AND u.name = p.name
                           AND u.level = p.level
             WHERE NOT EXISTS (
                 SELECT 1
                 FROM storage.objects AS o
                 WHERE o.bucket_id = p.bucket_id
                   AND o.level = p.level + 1
                   AND o.name COLLATE "C" LIKE p.name || '/%'
             )
             AND NOT EXISTS (
                 SELECT 1
                 FROM storage.prefixes AS c
                 WHERE c.bucket_id = p.bucket_id
                   AND c.level = p.level + 1
                   AND c.name COLLATE "C" LIKE p.name || '/%'
             )
        )
        DELETE
        FROM storage.prefixes AS p
            USING leaf AS l
        WHERE p.bucket_id = l.bucket_id
          AND p.name = l.name
          AND p.level = l.level;

        GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;
        EXIT WHEN v_rows_deleted = 0;
    END LOOP;
END;
$$;


--
-- Name: enforce_bucket_name_length(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.enforce_bucket_name_length() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


--
-- Name: extension(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.extension(name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    SELECT _parts[array_length(_parts,1)] INTO _filename;
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


--
-- Name: filename(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.filename(name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$$;


--
-- Name: foldername(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.foldername(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


--
-- Name: get_common_prefix(text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_common_prefix(p_key text, p_prefix text, p_delimiter text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT CASE
    WHEN position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)) > 0
    THEN left(p_key, length(p_prefix) + position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)))
    ELSE NULL
END;
$$;


--
-- Name: get_level(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_level(name text) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
SELECT array_length(string_to_array("name", '/'), 1);
$$;


--
-- Name: get_prefix(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_prefix(name text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
SELECT
    CASE WHEN strpos("name", '/') > 0 THEN
             regexp_replace("name", '[\/]{1}[^\/]+\/?$', '')
         ELSE
             ''
        END;
$_$;


--
-- Name: get_prefixes(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_prefixes(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    parts text[];
    prefixes text[];
    prefix text;
BEGIN
    -- Split the name into parts by '/'
    parts := string_to_array("name", '/');
    prefixes := '{}';

    -- Construct the prefixes, stopping one level below the last part
    FOR i IN 1..array_length(parts, 1) - 1 LOOP
            prefix := array_to_string(parts[1:i], '/');
            prefixes := array_append(prefixes, prefix);
    END LOOP;

    RETURN prefixes;
END;
$$;


--
-- Name: get_size_by_bucket(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_size_by_bucket() RETURNS TABLE(size bigint, bucket_id text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::bigint) as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


--
-- Name: list_multipart_uploads_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text) RETURNS TABLE(key text, id text, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


--
-- Name: list_objects_with_delimiter(text, text, text, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_objects_with_delimiter(_bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;

    -- Configuration
    v_is_asc BOOLEAN;
    v_prefix TEXT;
    v_start TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_is_asc := lower(coalesce(sort_order, 'asc')) = 'asc';
    v_prefix := coalesce(prefix_param, '');
    v_start := CASE WHEN coalesce(next_token, '') <> '' THEN next_token ELSE coalesce(start_after, '') END;
    v_file_batch_size := LEAST(GREATEST(max_keys * 2, 100), 1000);

    -- Calculate upper bound for prefix filtering (bytewise, using COLLATE "C")
    IF v_prefix = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix, 1) = delimiter_param THEN
        v_upper_bound := left(v_prefix, -1) || chr(ascii(delimiter_param) + 1);
    ELSE
        v_upper_bound := left(v_prefix, -1) || chr(ascii(right(v_prefix, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'AND o.name COLLATE "C" < $3 ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'AND o.name COLLATE "C" >= $3 ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- ========================================================================
    -- SEEK INITIALIZATION: Determine starting position
    -- ========================================================================
    IF v_start = '' THEN
        IF v_is_asc THEN
            v_next_seek := v_prefix;
        ELSE
            -- DESC without cursor: find the last item in range
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;

            IF v_next_seek IS NOT NULL THEN
                v_next_seek := v_next_seek || delimiter_param;
            ELSE
                RETURN;
            END IF;
        END IF;
    ELSE
        -- Cursor provided: determine if it refers to a folder or leaf
        IF EXISTS (
            SELECT 1 FROM storage.objects o
            WHERE o.bucket_id = _bucket_id
              AND o.name COLLATE "C" LIKE v_start || delimiter_param || '%'
            LIMIT 1
        ) THEN
            -- Cursor refers to a folder
            IF v_is_asc THEN
                v_next_seek := v_start || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_start || delimiter_param;
            END IF;
        ELSE
            -- Cursor refers to a leaf object
            IF v_is_asc THEN
                v_next_seek := v_start || delimiter_param;
            ELSE
                v_next_seek := v_start;
            END IF;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= max_keys;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(v_peek_name, v_prefix, delimiter_param);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Emit and skip to next folder (no heap access needed)
            name := rtrim(v_common_prefix, delimiter_param);
            id := NULL;
            updated_at := NULL;
            created_at := NULL;
            last_accessed_at := NULL;
            metadata := NULL;
            RETURN NEXT;
            v_count := v_count + 1;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := left(v_common_prefix, -1) || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_common_prefix;
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query USING _bucket_id, v_next_seek,
                CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(v_current.name, v_prefix, delimiter_param);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := v_current.name;
                    EXIT;
                END IF;

                -- Emit file
                name := v_current.name;
                id := v_current.id;
                updated_at := v_current.updated_at;
                created_at := v_current.created_at;
                last_accessed_at := v_current.last_accessed_at;
                metadata := v_current.metadata;
                RETURN NEXT;
                v_count := v_count + 1;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := v_current.name || delimiter_param;
                ELSE
                    v_next_seek := v_current.name;
                END IF;

                EXIT WHEN v_count >= max_keys;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: operation(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.operation() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


--
-- Name: protect_delete(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.protect_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if storage.allow_delete_query is set to 'true'
    IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
        RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            USING HINT = 'This prevents accidental data loss from orphaned objects.',
                  ERRCODE = '42501';
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: search(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;
    v_delimiter CONSTANT TEXT := '/';

    -- Configuration
    v_limit INT;
    v_prefix TEXT;
    v_prefix_lower TEXT;
    v_is_asc BOOLEAN;
    v_order_by TEXT;
    v_sort_order TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;
    v_skipped INT := 0;
BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_limit := LEAST(coalesce(limits, 100), 1500);
    v_prefix := coalesce(prefix, '') || coalesce(search, '');
    v_prefix_lower := lower(v_prefix);
    v_is_asc := lower(coalesce(sortorder, 'asc')) = 'asc';
    v_file_batch_size := LEAST(GREATEST(v_limit * 2, 100), 1000);

    -- Validate sort column
    CASE lower(coalesce(sortcolumn, 'name'))
        WHEN 'name' THEN v_order_by := 'name';
        WHEN 'updated_at' THEN v_order_by := 'updated_at';
        WHEN 'created_at' THEN v_order_by := 'created_at';
        WHEN 'last_accessed_at' THEN v_order_by := 'last_accessed_at';
        ELSE v_order_by := 'name';
    END CASE;

    v_sort_order := CASE WHEN v_is_asc THEN 'asc' ELSE 'desc' END;

    -- ========================================================================
    -- NON-NAME SORTING: Use path_tokens approach (unchanged)
    -- ========================================================================
    IF v_order_by != 'name' THEN
        RETURN QUERY EXECUTE format(
            $sql$
            WITH folders AS (
                SELECT path_tokens[$1] AS folder
                FROM storage.objects
                WHERE objects.name ILIKE $2 || '%%'
                  AND bucket_id = $3
                  AND array_length(objects.path_tokens, 1) <> $1
                GROUP BY folder
                ORDER BY folder %s
            )
            (SELECT folder AS "name",
                   NULL::uuid AS id,
                   NULL::timestamptz AS updated_at,
                   NULL::timestamptz AS created_at,
                   NULL::timestamptz AS last_accessed_at,
                   NULL::jsonb AS metadata FROM folders)
            UNION ALL
            (SELECT path_tokens[$1] AS "name",
                   id, updated_at, created_at, last_accessed_at, metadata
             FROM storage.objects
             WHERE objects.name ILIKE $2 || '%%'
               AND bucket_id = $3
               AND array_length(objects.path_tokens, 1) = $1
             ORDER BY %I %s)
            LIMIT $4 OFFSET $5
            $sql$, v_sort_order, v_order_by, v_sort_order
        ) USING levels, v_prefix, bucketname, v_limit, offsets;
        RETURN;
    END IF;

    -- ========================================================================
    -- NAME SORTING: Hybrid skip-scan with batch optimization
    -- ========================================================================

    -- Calculate upper bound for prefix filtering
    IF v_prefix_lower = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix_lower, 1) = v_delimiter THEN
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(v_delimiter) + 1);
    ELSE
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(right(v_prefix_lower, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'AND lower(o.name) COLLATE "C" < $3 ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'AND lower(o.name) COLLATE "C" >= $3 ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- Initialize seek position
    IF v_is_asc THEN
        v_next_seek := v_prefix_lower;
    ELSE
        -- DESC: find the last item in range first (static SQL)
        IF v_upper_bound IS NOT NULL THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower AND lower(o.name) COLLATE "C" < v_upper_bound
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSIF v_prefix_lower <> '' THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSE
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        END IF;

        IF v_peek_name IS NOT NULL THEN
            v_next_seek := lower(v_peek_name) || v_delimiter;
        ELSE
            RETURN;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= v_limit;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix_lower <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(lower(v_peek_name), v_prefix_lower, v_delimiter);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Handle offset, emit if needed, skip to next folder
            IF v_skipped < offsets THEN
                v_skipped := v_skipped + 1;
            ELSE
                name := split_part(rtrim(storage.get_common_prefix(v_peek_name, v_prefix, v_delimiter), v_delimiter), v_delimiter, levels);
                id := NULL;
                updated_at := NULL;
                created_at := NULL;
                last_accessed_at := NULL;
                metadata := NULL;
                RETURN NEXT;
                v_count := v_count + 1;
            END IF;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := lower(left(v_common_prefix, -1)) || chr(ascii(v_delimiter) + 1);
            ELSE
                v_next_seek := lower(v_common_prefix);
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix_lower is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(lower(v_current.name), v_prefix_lower, v_delimiter);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := lower(v_current.name);
                    EXIT;
                END IF;

                -- Handle offset skipping
                IF v_skipped < offsets THEN
                    v_skipped := v_skipped + 1;
                ELSE
                    -- Emit file
                    name := split_part(v_current.name, v_delimiter, levels);
                    id := v_current.id;
                    updated_at := v_current.updated_at;
                    created_at := v_current.created_at;
                    last_accessed_at := v_current.last_accessed_at;
                    metadata := v_current.metadata;
                    RETURN NEXT;
                    v_count := v_count + 1;
                END IF;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := lower(v_current.name) || v_delimiter;
                ELSE
                    v_next_seek := lower(v_current.name);
                END IF;

                EXIT WHEN v_count >= v_limit;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: search_by_timestamp(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_by_timestamp(p_prefix text, p_bucket_id text, p_limit integer, p_level integer, p_start_after text, p_sort_order text, p_sort_column text, p_sort_column_after text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_cursor_op text;
    v_query text;
    v_prefix text;
BEGIN
    v_prefix := coalesce(p_prefix, '');

    IF p_sort_order = 'asc' THEN
        v_cursor_op := '>';
    ELSE
        v_cursor_op := '<';
    END IF;

    v_query := format($sql$
        WITH raw_objects AS (
            SELECT
                o.name AS obj_name,
                o.id AS obj_id,
                o.updated_at AS obj_updated_at,
                o.created_at AS obj_created_at,
                o.last_accessed_at AS obj_last_accessed_at,
                o.metadata AS obj_metadata,
                storage.get_common_prefix(o.name, $1, '/') AS common_prefix
            FROM storage.objects o
            WHERE o.bucket_id = $2
              AND o.name COLLATE "C" LIKE $1 || '%%'
        ),
        -- Aggregate common prefixes (folders)
        -- Both created_at and updated_at use MIN(obj_created_at) to match the old prefixes table behavior
        aggregated_prefixes AS (
            SELECT
                rtrim(common_prefix, '/') AS name,
                NULL::uuid AS id,
                MIN(obj_created_at) AS updated_at,
                MIN(obj_created_at) AS created_at,
                NULL::timestamptz AS last_accessed_at,
                NULL::jsonb AS metadata,
                TRUE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NOT NULL
            GROUP BY common_prefix
        ),
        leaf_objects AS (
            SELECT
                obj_name AS name,
                obj_id AS id,
                obj_updated_at AS updated_at,
                obj_created_at AS created_at,
                obj_last_accessed_at AS last_accessed_at,
                obj_metadata AS metadata,
                FALSE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NULL
        ),
        combined AS (
            SELECT * FROM aggregated_prefixes
            UNION ALL
            SELECT * FROM leaf_objects
        ),
        filtered AS (
            SELECT *
            FROM combined
            WHERE (
                $5 = ''
                OR ROW(
                    date_trunc('milliseconds', %I),
                    name COLLATE "C"
                ) %s ROW(
                    COALESCE(NULLIF($6, '')::timestamptz, 'epoch'::timestamptz),
                    $5
                )
            )
        )
        SELECT
            split_part(name, '/', $3) AS key,
            name,
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
        FROM filtered
        ORDER BY
            COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz) %s,
            name COLLATE "C" %s
        LIMIT $4
    $sql$,
        p_sort_column,
        v_cursor_op,
        p_sort_column,
        p_sort_order,
        p_sort_order
    );

    RETURN QUERY EXECUTE v_query
    USING v_prefix, p_bucket_id, p_level, p_limit, p_start_after, p_sort_column_after;
END;
$_$;


--
-- Name: search_legacy_v1(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_legacy_v1(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select path_tokens[$1] as folder
           from storage.objects
             where objects.name ilike $2 || $3 || ''%''
               and bucket_id = $4
               and array_length(objects.path_tokens, 1) <> $1
           group by folder
           order by folder ' || v_sort_order || '
     )
     (select folder as "name",
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[$1] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where objects.name ilike $2 || $3 || ''%''
       and bucket_id = $4
       and array_length(objects.path_tokens, 1) = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


--
-- Name: search_v2(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_sort_col text;
    v_sort_ord text;
    v_limit int;
BEGIN
    -- Cap limit to maximum of 1500 records
    v_limit := LEAST(coalesce(limits, 100), 1500);

    -- Validate and normalize sort_order
    v_sort_ord := lower(coalesce(sort_order, 'asc'));
    IF v_sort_ord NOT IN ('asc', 'desc') THEN
        v_sort_ord := 'asc';
    END IF;

    -- Validate and normalize sort_column
    v_sort_col := lower(coalesce(sort_column, 'name'));
    IF v_sort_col NOT IN ('name', 'updated_at', 'created_at') THEN
        v_sort_col := 'name';
    END IF;

    -- Route to appropriate implementation
    IF v_sort_col = 'name' THEN
        -- Use list_objects_with_delimiter for name sorting (most efficient: O(k * log n))
        RETURN QUERY
        SELECT
            split_part(l.name, '/', levels) AS key,
            l.name AS name,
            l.id,
            l.updated_at,
            l.created_at,
            l.last_accessed_at,
            l.metadata
        FROM storage.list_objects_with_delimiter(
            bucket_name,
            coalesce(prefix, ''),
            '/',
            v_limit,
            start_after,
            '',
            v_sort_ord
        ) l;
    ELSE
        -- Use aggregation approach for timestamp sorting
        -- Not efficient for large datasets but supports correct pagination
        RETURN QUERY SELECT * FROM storage.search_by_timestamp(
            prefix, bucket_name, v_limit, levels, start_after,
            v_sort_ord, v_sort_col, sort_column_after
        );
    END IF;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE audit_log_entries; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';


--
-- Name: custom_oauth_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.custom_oauth_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_type text NOT NULL,
    identifier text NOT NULL,
    name text NOT NULL,
    client_id text NOT NULL,
    client_secret text NOT NULL,
    acceptable_client_ids text[] DEFAULT '{}'::text[] NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    pkce_enabled boolean DEFAULT true NOT NULL,
    attribute_mapping jsonb DEFAULT '{}'::jsonb NOT NULL,
    authorization_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    email_optional boolean DEFAULT false NOT NULL,
    issuer text,
    discovery_url text,
    skip_nonce_check boolean DEFAULT false NOT NULL,
    cached_discovery jsonb,
    discovery_cached_at timestamp with time zone,
    authorization_url text,
    token_url text,
    userinfo_url text,
    jwks_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custom_oauth_providers_authorization_url_https CHECK (((authorization_url IS NULL) OR (authorization_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_authorization_url_length CHECK (((authorization_url IS NULL) OR (char_length(authorization_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_client_id_length CHECK (((char_length(client_id) >= 1) AND (char_length(client_id) <= 512))),
    CONSTRAINT custom_oauth_providers_discovery_url_length CHECK (((discovery_url IS NULL) OR (char_length(discovery_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_identifier_format CHECK ((identifier ~ '^[a-z0-9][a-z0-9:-]{0,48}[a-z0-9]$'::text)),
    CONSTRAINT custom_oauth_providers_issuer_length CHECK (((issuer IS NULL) OR ((char_length(issuer) >= 1) AND (char_length(issuer) <= 2048)))),
    CONSTRAINT custom_oauth_providers_jwks_uri_https CHECK (((jwks_uri IS NULL) OR (jwks_uri ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_jwks_uri_length CHECK (((jwks_uri IS NULL) OR (char_length(jwks_uri) <= 2048))),
    CONSTRAINT custom_oauth_providers_name_length CHECK (((char_length(name) >= 1) AND (char_length(name) <= 100))),
    CONSTRAINT custom_oauth_providers_oauth2_requires_endpoints CHECK (((provider_type <> 'oauth2'::text) OR ((authorization_url IS NOT NULL) AND (token_url IS NOT NULL) AND (userinfo_url IS NOT NULL)))),
    CONSTRAINT custom_oauth_providers_oidc_discovery_url_https CHECK (((provider_type <> 'oidc'::text) OR (discovery_url IS NULL) OR (discovery_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_issuer_https CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NULL) OR (issuer ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_requires_issuer CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NOT NULL))),
    CONSTRAINT custom_oauth_providers_provider_type_check CHECK ((provider_type = ANY (ARRAY['oauth2'::text, 'oidc'::text]))),
    CONSTRAINT custom_oauth_providers_token_url_https CHECK (((token_url IS NULL) OR (token_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_token_url_length CHECK (((token_url IS NULL) OR (char_length(token_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_userinfo_url_https CHECK (((userinfo_url IS NULL) OR (userinfo_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_userinfo_url_length CHECK (((userinfo_url IS NULL) OR (char_length(userinfo_url) <= 2048)))
);


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text,
    code_challenge_method auth.code_challenge_method,
    code_challenge text,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone,
    invite_token text,
    referrer text,
    oauth_client_state_id uuid,
    linking_target_id uuid,
    email_optional boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE flow_state; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.flow_state IS 'Stores metadata for all OAuth/SSO login flows';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE identities; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN identities.email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: TABLE instances; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: TABLE mfa_amr_claims; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: TABLE mfa_challenges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: TABLE mfa_factors; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';


--
-- Name: COLUMN mfa_factors.last_webauthn_challenge_data; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_client_states (
    id uuid NOT NULL,
    provider_type text NOT NULL,
    code_verifier text,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE oauth_client_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.oauth_client_states IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    token_endpoint_auth_method text NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048)),
    CONSTRAINT oauth_clients_token_endpoint_auth_method_check CHECK ((token_endpoint_auth_method = ANY (ARRAY['client_secret_basic'::text, 'client_secret_post'::text, 'none'::text])))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: TABLE saml_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: TABLE saml_relay_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: TABLE schema_migrations; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: TABLE sessions; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN sessions.not_after; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN sessions.refresh_token_hmac_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN sessions.refresh_token_counter; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: TABLE sso_domains; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: TABLE sso_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN sso_providers.resource_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN users.is_sso_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


--
-- Name: webauthn_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_challenges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    challenge_type text NOT NULL,
    session_data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    CONSTRAINT webauthn_challenges_challenge_type_check CHECK ((challenge_type = ANY (ARRAY['signup'::text, 'registration'::text, 'authentication'::text])))
);


--
-- Name: webauthn_credentials; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    credential_id bytea NOT NULL,
    public_key bytea NOT NULL,
    attestation_type text DEFAULT ''::text NOT NULL,
    aaguid uuid,
    sign_count bigint DEFAULT 0 NOT NULL,
    transports jsonb DEFAULT '[]'::jsonb NOT NULL,
    backup_eligible boolean DEFAULT false NOT NULL,
    backed_up boolean DEFAULT false NOT NULL,
    friendly_name text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone
);


--
-- Name: app_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_settings (
    id integer NOT NULL,
    submission_mode text DEFAULT 'auto'::text NOT NULL,
    submission_start_at timestamp with time zone,
    submission_end_at timestamp with time zone,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: forms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forms (
    id text NOT NULL,
    data jsonb NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    submitted integer DEFAULT 0,
    pdf_file_path text,
    school_id text
);


--
-- Name: schools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schools (
    id text NOT NULL,
    name text NOT NULL,
    email text,
    password_hash text,
    form_id text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: messages; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
)
PARTITION BY RANGE (inserted_at);


--
-- Name: schema_migrations; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: subscription; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.subscription (
    id bigint NOT NULL,
    subscription_id uuid NOT NULL,
    entity regclass NOT NULL,
    filters realtime.user_defined_filter[] DEFAULT '{}'::realtime.user_defined_filter[] NOT NULL,
    claims jsonb NOT NULL,
    claims_role regrole GENERATED ALWAYS AS (realtime.to_regrole((claims ->> 'role'::text))) STORED NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    action_filter text DEFAULT '*'::text,
    CONSTRAINT subscription_action_filter_check CHECK ((action_filter = ANY (ARRAY['*'::text, 'INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


--
-- Name: subscription_id_seq; Type: SEQUENCE; Schema: realtime; Owner: -
--

ALTER TABLE realtime.subscription ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME realtime.subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: buckets; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets (
    id text NOT NULL,
    name text NOT NULL,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public boolean DEFAULT false,
    avif_autodetection boolean DEFAULT false,
    file_size_limit bigint,
    allowed_mime_types text[],
    owner_id text,
    type storage.buckettype DEFAULT 'STANDARD'::storage.buckettype NOT NULL
);


--
-- Name: COLUMN buckets.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.buckets.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: buckets_analytics; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_analytics (
    name text NOT NULL,
    type storage.buckettype DEFAULT 'ANALYTICS'::storage.buckettype NOT NULL,
    format text DEFAULT 'ICEBERG'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: buckets_vectors; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_vectors (
    id text NOT NULL,
    type storage.buckettype DEFAULT 'VECTOR'::storage.buckettype NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.migrations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_id text,
    name text,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_accessed_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/'::text)) STORED,
    version text,
    owner_id text,
    user_metadata jsonb
);


--
-- Name: COLUMN objects.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: s3_multipart_uploads; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads (
    id text NOT NULL,
    in_progress_size bigint DEFAULT 0 NOT NULL,
    upload_signature text NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    version text NOT NULL,
    owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_metadata jsonb
);


--
-- Name: s3_multipart_uploads_parts; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    upload_id text NOT NULL,
    size bigint DEFAULT 0 NOT NULL,
    part_number integer NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    etag text NOT NULL,
    owner_id text,
    version text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vector_indexes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.vector_indexes (
    id text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    bucket_id text NOT NULL,
    data_type text NOT NULL,
    dimension integer NOT NULL,
    distance_metric text NOT NULL,
    metadata_configuration jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.audit_log_entries (instance_id, id, payload, created_at, ip_address) FROM stdin;
\.


--
-- Data for Name: custom_oauth_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.custom_oauth_providers (id, provider_type, identifier, name, client_id, client_secret, acceptable_client_ids, scopes, pkce_enabled, attribute_mapping, authorization_params, enabled, email_optional, issuer, discovery_url, skip_nonce_check, cached_discovery, discovery_cached_at, authorization_url, token_url, userinfo_url, jwks_uri, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.flow_state (id, user_id, auth_code, code_challenge_method, code_challenge, provider_type, provider_access_token, provider_refresh_token, created_at, updated_at, authentication_method, auth_code_issued_at, invite_token, referrer, oauth_client_state_id, linking_target_id, email_optional) FROM stdin;
\.


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) FROM stdin;
\.


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.instances (id, uuid, raw_base_config, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_amr_claims (session_id, created_at, updated_at, authentication_method, id) FROM stdin;
\.


--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_challenges (id, factor_id, created_at, verified_at, ip_address, otp_code, web_authn_session_data) FROM stdin;
\.


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret, phone, last_challenged_at, web_authn_credential, web_authn_aaguid, last_webauthn_challenge_data) FROM stdin;
\.


--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_authorizations (id, authorization_id, client_id, user_id, redirect_uri, scope, state, resource, code_challenge, code_challenge_method, response_type, status, authorization_code, created_at, expires_at, approved_at, nonce) FROM stdin;
\.


--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_client_states (id, provider_type, code_verifier, created_at) FROM stdin;
\.


--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_clients (id, client_secret_hash, registration_type, redirect_uris, grant_types, client_name, client_uri, logo_uri, created_at, updated_at, deleted_at, client_type, token_endpoint_auth_method) FROM stdin;
\.


--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_consents (id, user_id, client_id, scopes, granted_at, revoked_at) FROM stdin;
\.


--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.one_time_tokens (id, user_id, token_type, token_hash, relates_to, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.refresh_tokens (instance_id, id, token, user_id, revoked, created_at, updated_at, parent, session_id) FROM stdin;
\.


--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_providers (id, sso_provider_id, entity_id, metadata_xml, metadata_url, attribute_mapping, created_at, updated_at, name_id_format) FROM stdin;
\.


--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_relay_states (id, sso_provider_id, request_id, for_email, redirect_to, created_at, updated_at, flow_state_id) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.schema_migrations (version) FROM stdin;
20171026211738
20171026211808
20171026211834
20180103212743
20180108183307
20180119214651
20180125194653
00
20210710035447
20210722035447
20210730183235
20210909172000
20210927181326
20211122151130
20211124214934
20211202183645
20220114185221
20220114185340
20220224000811
20220323170000
20220429102000
20220531120530
20220614074223
20220811173540
20221003041349
20221003041400
20221011041400
20221020193600
20221021073300
20221021082433
20221027105023
20221114143122
20221114143410
20221125140132
20221208132122
20221215195500
20221215195800
20221215195900
20230116124310
20230116124412
20230131181311
20230322519590
20230402418590
20230411005111
20230508135423
20230523124323
20230818113222
20230914180801
20231027141322
20231114161723
20231117164230
20240115144230
20240214120130
20240306115329
20240314092811
20240427152123
20240612123726
20240729123726
20240802193726
20240806073726
20241009103726
20250717082212
20250731150234
20250804100000
20250901200500
20250903112500
20250904133000
20250925093508
20251007112900
20251104100000
20251111201300
20251201000000
20260115000000
20260121000000
20260219120000
20260302000000
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sessions (id, user_id, created_at, updated_at, factor_id, aal, not_after, refreshed_at, user_agent, ip, tag, oauth_client_id, refresh_token_hmac_key, refresh_token_counter, scopes) FROM stdin;
\.


--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_domains (id, sso_provider_id, domain, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_providers (id, resource_id, created_at, updated_at, disabled) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) FROM stdin;
\.


--
-- Data for Name: webauthn_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.webauthn_challenges (id, user_id, challenge_type, session_data, created_at, expires_at) FROM stdin;
\.


--
-- Data for Name: webauthn_credentials; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.webauthn_credentials (id, user_id, credential_id, public_key, attestation_type, aaguid, sign_count, transports, backup_eligible, backed_up, friendly_name, created_at, updated_at, last_used_at) FROM stdin;
\.


--
-- Data for Name: app_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.app_settings (id, submission_mode, submission_start_at, submission_end_at, updated_at) FROM stdin;
1	forced_open	2026-03-04 23:05:00+00	2026-03-20 23:05:00+00	2026-03-15 09:21:39.435703
\.


--
-- Data for Name: forms; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.forms (id, data, created_at, updated_at, submitted, pdf_file_path, school_id) FROM stdin;
1df4ae33-742a-41ae-877a-45e7562a2b0a	{"iskolatipus": [], "gdpr_consent": [], "mtmi_csapat_tag1_szak": [], "mtmi_csapat_tag2_szak": [], "mtmi_csapat_tag3_szak": [], "mtmi_csapat_tag4_szak": [], "mtmi_csapat_tag5_szak": [], "mtmi_csapat_tag6_szak": [], "mtmi_csapat_tag7_szak": [], "mtmi_csapat_tag8_szak": [], "mtmi_szakkor_tantargyak": []}	2026-03-14 12:04:19.535845	2026-03-14 12:04:34.058921	0	\N	\N
b07750f0-2277-4ae2-bbf7-b6627d9528b4	{"iskolatipus": [], "gdpr_consent": [], "mtmi_csapat_tag1_szak": [], "mtmi_csapat_tag2_szak": [], "mtmi_csapat_tag3_szak": [], "mtmi_csapat_tag4_szak": [], "mtmi_csapat_tag5_szak": [], "mtmi_csapat_tag6_szak": [], "mtmi_csapat_tag7_szak": [], "mtmi_csapat_tag8_szak": [], "mtmi_szakkor_tantargyak": []}	2026-03-02 15:12:10.973567	2026-03-02 15:13:48.14026	0	\N	\N
d8ea5036-0aab-4e1f-88d8-8f111eac8264	{"iskolatipus": [], "gdpr_consent": [], "palyazo_iskola_neve": "J", "mtmi_csapat_tag1_szak": [], "mtmi_csapat_tag2_szak": [], "mtmi_csapat_tag3_szak": [], "mtmi_csapat_tag4_szak": [], "mtmi_csapat_tag5_szak": [], "mtmi_csapat_tag6_szak": [], "mtmi_csapat_tag7_szak": [], "mtmi_csapat_tag8_szak": [], "mtmi_szakkor_tantargyak": []}	2025-12-03 06:44:21.942173	2025-12-03 06:44:22.54406	0	\N	f2b0771b-def1-49ff-981f-71f8a5ea659a
b67ab677-54ed-4785-a143-2ad257bee4ec	{"iskola_cime": "4200 Hajdúszoboszló, Rákóczi u. 44.", "iskolatipus": ["gimnazium"], "gdpr_consent": ["on"], "szulo_bevonas": "megvalosul", "mtmi_koncepcio": "igen", "telepulesforma": "megyeszekhely_varos", "mtmi_nyilt_napok": "Iskolánk kiemelt figyelmet fordít az MTMI területek népszerűsítésére, valamint a továbbtanulási lehetőségek bemutatására. Ennek keretében rendszeresen részt veszünk partnerintézményeink, a Debreceni Egyetem (DE) és a Budapesti Műszaki és Gazdaságtudományi Egyetem (BME) programjain. \\nA BME középiskolásoknak szóló rendezvényeiről folyamatosan értesülünk, és több alkalommal szervezett formában is ellátogatunk rájuk – korábban például a lányoknak szóló eseményre, idén ősszel pedig a VIK Nyitott laborok programjára vittünk diákcsoportot.\\nA Debreceni Egyetem közelsége miatt még több közös programra van lehetőség. A pályaorientációs napon egy teljes évfolyam számára szoktunk programokat szervezni az egyetem közreműködésével. Idén terveink szerint a 9. és 10. évfolyam tanulói az egyetem különböző karait – természettudományi, gazdaságtudományi, informatikai, műszaki és egészségtudományi – látogatják meg, ahol betekintést nyerhetnek a felsőoktatás világába.\\n\\nEzek mellett az országos rendezvényeket, pl. az egyetemi nyílt napokat vagy a Lányok Napját is népszerűsítjük; utóbbira idén is budapesti kirándulást szerveztünk.\\n\\nAz MTMI pályaorientációt saját intézményi programjainkkal is támogatjuk. A Hőgyes-laborban tartott foglalkozásaink óvodásoknak és általános iskolásoknak kínálnak játékos természettudományos élményeket, míg a középiskolai nyílt napokon laborbemutatókkal és kísérletekkel várjuk az érdeklődőket. Az első félévben a tankerületi iskoláknak élménypedagógiai órákat is biztosítunk: tanáraink és diákjaink az intézményekbe látogatva interaktív matematikai és természettudományos foglalkozásokat tartanak. Ezekkel a tevékenységekkel iskolánk nemcsak a diákok pályaválasztását és saját beiskolázásunkat segíti, hanem hozzájárul az MTMI területek iránti érdeklődés növeléséhez is.\\n", "szulo_egyeztetes": "megvalosul", "mtmi_csapat_link1": "https://hogyes.hu/mtmi-targyak-a-jovoert-tehetseggondozas-es-palyaorientacio-gimnaziumunkban/", "mtmi_projektnapok": "Iskolánk elkötelezett az országos témahetek – mint a fenntarthatósági, pénzügyi és digitális témanap – színvonalas és korszerű megvalósítása mellett. Az utóbbi években ezeket megújult formában, témanapként, teljes tanítási napot lefedő, élményalapú projektként rendezzük meg. A diákok interaktív feladatokon, előadásokon, kísérleteken és csapatmunkán keresztül bővíthetik ismereteiket, miközben tapasztalatot szereznek a természettudományos, műszaki, informatikai és matematikai területek gyakorlati vonatkozásairól.\\n\\nMinden tanévben megrendezzük matematikai szakmai napunkat, amelyet kifejezetten matematika tagozatos diákjaink számára szervezünk. Ezen a napon a hat évfolyam tanulói vegyes csapatokban dolgoznak együtt, és nem hagyományos, kreatív problémákat oldanak meg, amelyekben a matematika eszközként szolgál különböző gyakorlati, illetve más tudományterületekhez kapcsolódó kérdések megértéséhez és megoldásához.  A nap során diákjaink bepillantást nyernek a tudományterület izgalmas, kevésbé ismert oldalába, megismerik annak gyakorlati alkalmazásait, és inspiráló példákon keresztül fedezhetik fel a matematika sokszínűségét. A program kettős célja, hogy egyrészt fejlessze a tanulók együttműködési és problémamegoldó képességét, másrészt segítse őket pályaorientációjukban, a tudományos és műszaki pályák felé nyitásban.\\n\\nEbben a tanévben tervezzük a „Éltető víz – a természet kincse és városunk büszkesége” című komplex projekt megvalósítását a 11. évfolyam bevonásával, a szoboszlói gyógyvíz felfedezésének 100. évfordulója alkalmából. A projekt a víz szerepét vizsgálja különböző tudományterületeken keresztül, és bemutatóval zárul, amelyre a többi diákot és a szülőket is meghívjuk.\\n", "szulo_kommunikacio": "megvalosul", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "8", "palyazo_iskola_neve": "Hőgyes Endre Gimnázium", "pedprog_mtmi_leiras": "Az iskola egyik kiemelt célja az MTMI-területek népszerűsítése, e tantárgyak jelentőségének felismertetése a mindennapi életben és a tanulók pályaválasztása során. Tanulóinknak 7-10. évfolyamon matematika tagozatos, illetve természettudományos orientációjú képzést is kínálunk. A tanórákon korszerű tudás átadására, tehetséggondozásra és az érdeklődés felkeltésére törekszünk, tanulóbarát módszertannal, digitális eszközök bevonásával. A tanórák és a 11-12. évfolyamon választható fakultációk mellett  szakkörök, versenyfelkészítők, projektnapok és laborprogramok biztosítanak lehetőséget az elmélyülésre, a gyakorlati tapasztalatszerzésre és a továbbtanulásra való felkészítésre. Pályaorientációs programjaink során diákjaink MTMI-területen dolgozó szakemberekkel, kutatókkal, egyetemi hallgatókkal is találkozhatnak, valamint üzem- és laborlátogatásokon vehetnek részt. Évente rendezünk MTMI-témájú témanapokat. Mentorprogrammal és kutatási lehetőségekkel támogatjuk a kiemelkedő érdeklődésű és tudású tanulókat. Rendszeresen részt veszünk országos és regionális rendezvényeken (pl. kutatók éjszakája, nyílt napok, lányok napja), kiemelt figyelmet fordítunk az élményalapú tudásszerzésre.", "mtmi_ceges_eloadasok": "nem", "mtmi_csapat_tag1_nev": "Balla Éva", "mtmi_csapat_tag2_nev": "Károlyné Teleki Anikó", "mtmi_csapat_tag3_nev": "Kiss István", "mtmi_csapat_tag4_nev": "Görög Arthur Zoltánné", "mtmi_csapat_tag5_nev": "Székely-Pintér Petra", "mtmi_csapat_tag6_nev": "Oláh Ádám", "mtmi_csapat_tag7_nev": "Farkas Fanni", "mtmi_csapat_tag8_nev": "Nemes József", "mtmi_koncepcio_link1": "https://hogyes.hu/a-hogyes-endre-gimnazium-mtmi-koncepcioja/", "mtmi_szakkorok_link1": "https://hogyes.hu/wp-content/uploads/2025/10/SZAKKOROK-2025.pdf", "mtmi_szakkorok_szama": "19", "mtmi_szulo_kepviselo": "igen", "mtmi_alumni_programok": "igen", "mtmi_csapat_tag1_szak": ["matematika", "fizika"], "mtmi_csapat_tag2_szak": ["matematika", "kemia"], "mtmi_csapat_tag3_szak": ["matematika"], "mtmi_csapat_tag4_szak": ["biologia", "foldrajz"], "mtmi_csapat_tag5_szak": ["matematika", "fizika"], "mtmi_csapat_tag6_szak": ["biologia"], "mtmi_csapat_tag7_szak": ["kemia", "biologia"], "mtmi_csapat_tag8_szak": ["digitalis_kultura"], "mtmi_koncepcio_leiras": "A program célja az MTMI tárgyak népszerűsítése, a műszaki, informatikai és természettudományos pályák iránti érdeklődés felkeltése, az ehhez szükséges ismeretek megalapozása, az érdeklődő tanulók számára célirányos tehetséggondozás. A program struktúrája: alsóbb évfolyamokon az érdeklődés felkeltése, interaktivitás,  képességfejlesztés van a fókuszban, felsőbb évfolyamokon hangsúlyosabb a pályaorientáció, egyetemek és cégek bevonásával szervezett programok. Kiemelt elemek a versenyfelkészítés, a kapcsolatrendszer további kiépítése, a pedagógusok támogatása és a kommunikáció. A megvalósítást az MTMI-csapat irányítja, szülői együttműködéssel, intézményvezetői támogatással.", "pedprog_mtmi_tartalom": "igen", "szulo_palyaorientacio": "megvalosul", "mtmi_fakultaciok_szama": "16", "mtmi_kapcsolatok_link1": "https://hogyes.hu/2024/12/13/gyarlatogatas-bmw-debrecen/", "mtmi_kapcsolatok_link2": "https://hogyes.hu/2025/04/08/ceglatogatas-az-emerson-ni-nal/", "mtmi_muzeumlatogatasok": "igen", "mtmi_nyilt_napok_link1": "https://hogyes.hu/curie-kemia-bemutato-a-thokolyben/", "mtmi_nyilt_napok_link2": "https://hogyes.hu/2025/01/07/matematikai-szakmai-nap-4/", "mtmi_nyilt_napok_link3": "https://hogyes.hu/2025/05/30/latogatas-a-debreceni-egyetem-mezogazdasag-elelmiszertudomanyi-es-kornyezetgazdalkodasi-karon/", "mtmi_nyilt_napok_link4": "https://hogyes.hu/2025/09/01/kutato-diakjaink-a-ttk-n/", "mtmi_nyilt_napok_link5": "https://hogyes.hu/2024/12/13/gyarlatogatas-bmw-debrecen/", "mtmi_nyilt_napok_link6": "https://hogyes.hu/2025/04/08/ceglatogatas-az-emerson-ni-nal/", "mtmi_nyilt_napok_link7": "https://hogyes.hu/2024/09/28/nagy-sikere-volt-a-kutatok-ejszakajanak-a-hogyesben/", "mtmi_nyilt_napok_link8": "https://hogyes.hu/2025/06/19/mta-alumi-eloadas-a-hogyesben-dr-bacsi-attila/", "mtmi_nyilt_napok_link9": "https://hogyes.hu/2025/06/19/mta-alumi-eloadas-a-hogyesben-dr-boros-zoltan/", "iskola_tanuloi_letszama": "495", "mtmi_nyilt_napok_link10": "https://hogyes.hu/2025/06/19/mta-alumi-eloadas-a-hogyesben-dr-szoor-arpad/", "mtmi_szakkor_tantargyak": ["matematika", "fizika", "kemia", "biologia", "foldrajz", "digitalis_kultura"], "mtmi_szakmak_bemutatasa": "igen", "szulo_egyeztetes_szoveg": "Az első iskolai SZM-értekezleten ismertette igazgatónő a program céljait. Terveink szerint ezeken a fórumokon évi 2 alkalommal jelen lesz a kapcsolattartó szülő is, aki az SZM szülőkkel együtt véleményezi az aktuális (félévi) programkínálatot.  Nyitottak vagyunk a kapcsolattartó szülő javaslataira, illetve számítunk a támogatására - a többi érintett szülő elérésében, aktivizálásában - a tervezett programok megvalósításához. Ilyen programok pl. az élménypedagógiai órák keretében történő labor- és munkahely látogatások (pl fürdő labor, gyógyszertár, orvosi rendelő), valamint a pályaorientációs nap és a témanapok (pénzügyi, digitális, fenntarthatósági), amelyeken az adott területen dolgozó szülők személyes közreműködésére számítunk.", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "igen", "mtmi_szakmai_gyakorlatok": "Partnerintézményeink, a Debreceni Egyetem (DE) és a Budapesti Műszaki és Gazdaságtudományi Egyetem (BME) évek óta meghatározó szerepet játszanak diákjaink szakmai fejlődésében. A DE és a BME különböző karai évente szerveznek pályaorientációs eseményeket, de nyitottak és fogadókészek arra is, hogy egy-egy csoportot a központi eseményeken kívül is fogadjanak laborlátogatásokra, ahol tanulóink valós kutatási és fejlesztési környezetben szerezhetnek tapasztalatot. A DE Természettudományi és Technológiai Kara, a Műszaki Kar és a MÉK laborjaiban több alkalommal voltunk természettudományos csoporttal, vagy faktos csoportokkal.  \\n\\nA DE TTK nyári táboraiban évről évre jelen vannak diákjaink, de volt már csoportunk a BME nyári táborában is szakmai gyakorlaton. A nyári táborokban részt vett diákjaink ezeken a programokon keresztül betekintést nyernek a mérnöki és kutatói munka mindennapjaiba.  \\n\\nTöbb éve részt veszünk diákjainkkal az NTA programjain: területi foglalkozások keretében orvosbiológiai kísérleteket végeznek, az országos programokon találkozhatnak Nobel-díjas tudósokkal, részt vehetnek a World Science Expo-n. A Nemzeti Tudósképző Akadémia rövid távú célkitűzése az orvosbiológiai és természettudományi kutatások iránt érdeklődő tehetséges fiatalok felkarolása, tudományos munkájuk támogatása, a tudós életpálya modell vonzóvá tétele, és hosszabb távon a fiatal kutatók Magyarországon tartása. Idén 14 tanulónk regisztrált a programra.\\n\\nA szakmai programok nemcsak az egyetemekhez kötődnek: TT-s és faktos tanulóink több alkalommal jártak a Hortobágyi Nemzeti Parkban, valamint az ATOMKI-ban, ahol interaktív workshopokon, laborlátogatásokon és tudományos előadásokon vettek részt. Ezek a programok segítik a pályaorientációt és hozzájárulnak ahhoz, hogy tanulóink tudatosan válasszanak továbbtanulási irányt az MTMI területeken. ", "mtmi_egyetemi_gyakorlatok": "igen", "mtmi_szakkor_diakok_szama": "132", "mtmi_szakkorok_bemutatasa": "A 7. és 9. évfolyamos bemeneti mérésen gyengén teljesítők számára hátránykompenzáló foglalkozásokat tartunk matematikából, fizikából.  Felzárkóztató szakkört matematikából a többi évfolyamon (8-tól 11-ig) is meghirdettünk. Versenyfelkészítő szakköröket indítunk a következő tárgyakból: matematika 7-12. évfolyamon, kémia (9-10. évfolyam, valamint faktosok),  illetve biológiából. Matematikából minden korosztályban indítunk versenyzőket a nagy hagyományokkal bíró, rangos országos versenyeken (Varga Tamás, Arany Dániel, OKTV, Zrínyi, Bolyai), illetve pályázatos versenyen (pl. SZTE Bolyai Intézet), kémiából az Irinyi, Hevesy, Curie-versenyekre és az OKTV-re, biológiából az OKTV mellett főleg kutató jellegű, illetve csoportos versenyekre készítjük a diákokat (TUDOK, Földi János Diákkonferencia, NTA-program).\\nÉrettségi felkészítő szakkörökre jelentkezhetnek a 11-12. évfolyamosok matematikából, földrajzból, illetve elsősorban az emelt érettségire készülőket célozza a kémia kísérletező szakkör. Ezeken a foglalkozásokon részben a fakultáción tanultak kiegészítésére, további gyakorlásra, érettségi és próbaérettségi feladatsorok megbeszélésére, valamint a szóbeli vizsgarészre való aktívabb felkészülésre (próbavizsgák) van lehetőség, de bekapcsolódhatnak olyan tanulók is, akik nem az adott tárgyat választották fakultációként.\\nFizikából kísérletező szakkört indítottunk 9-10. osztályosoknak.\\nMatematikai játékkuckót működtetünk, ahol különböző logikai játékokkal, társasjátékokkal játszhatnak a diákok szabadidejükben, illetve szünetekben. \\nA műszaki érdeklődésű tanulóknak IT-szakkört hirdettünk, ahol gépösszerakás, hálózati ismeretek, gép telepítés , router beállítás, üzembe helyezés a főbb témák.\\nA fentiek mellett indítottunk egy városi természettudományos szakkört 7-8. osztályosoknak \\"Tudósok - kísérletezni szeretők\\" címmel, melyet a kollégák témánként felváltva tartanak.", "szulo_munkakoz_ismertetes": "megvalosul", "mtmi_szakkor_tanarok_szama": "14", "iskola_mtmi_tanari_letszama": "10+", "mtmi_alumni_programok_link1": "https://hogyes.hu/2024/11/21/palyaorientacios-nap-2024/", "mtmi_diakok_kapcsolattartas": "igen", "mtmi_egyeb_partnerprogramok": "Az Öveges-pályázat keretében készült el iskolánk modern laboratóriuma, a pályázat fenntartási időszakában vállaltuk az általános iskolások számára is foglalkozások megtartását, illetve a partneriskolák pedagógusai részére tudásmegosztó fórumok, bemutató órák szervezését. Bár a fenntartási időszak már évekkel ezelőtt lejárt, az általános iskolásoknak szervezett kísérleti órák a Hőgyes-laborban továbbra is népszerű program a tankerületi partnerintézményekben. ", "mtmi_kapcsolatok_bemutatasa": "A 11-12. évfolyam informatikai-műszaki érdeklődésű diákjai az utóbbi időben minden évben lehetőséget kapnak az Emerson-NI debreceni vállalatának, illetve a debreceni BMW gyárnak a meglátogatására. A fiatalok megismerkedhetnek a gyártási folyamatokkal, az interaktív programok segítségével közelebb kerülnek az ipari termelés és technológia világához, feltérképezhetik a munkahelyi körülményeket, mindez többeket megerősíthet abban, hogy a jövőben műszaki területen tanuljon tovább. \\nIgyekszünk a cégek körét bővíteni: előző években a 11-12. biológia, kémia faktosai a Richter debreceni gyáregységének munkájába nyerhettek betekintést, egyik volt diákunkkal való kapcsolatnak köszönhetően.\\nA 7-8. osztályosokat a pályaorientációs napon helyi üzemlátogatásokra visszük, így képet kaphatnak többek között a gyógyfürdőben vagy a Leier cégnél elérhető műszaki munkakörökről.", "mtmi_online_palyaorientacio": "igen", "mtmi_rendezvenyek_reszvetel": "igen", "lanyok_mtmi_kiemelt_figyelem": "igen", "mtmi_alumni_programok_leiras": "Volt diákjaink jellemzően a pályaorientációs nap keretében (néha fakultációs órákon) tartanak előadást, illetve beszélgetéseket. A fiatalabbak az egyetemi életről, konkrét tanulmányaikról, az elhelyezkedési lehetőségekről beszélnek, és adnak tanácsokat az érdeklődőknek. A régebben végzettek beszámolnak a munkájukról, karrierlehetőségekről, így a tanulók valós példákon keresztül képet alkothatnak az őket érdeklő pályákról.  \\n", "mtmi_csapat_tag1_tevekenyseg": "Az MTMI csapat, a természettudományos, a matematika- és az informatikatanárok koordinálása, munkacsoport értekezletek vezetése. Kapcsolattartás külső partnerekkel (szülők, egyetemek, cégek), külsős programok szervezése. Szakkör, tehetséggondozó foglalkozások, iskolán kívüli felkészítő foglalkozások tartása.", "mtmi_csapat_tag2_tevekenyseg": "A természettudományos munkaközösség vezetője, természettudományos orientációjú osztály osztályfőnöke. A munkaközösséghez tartozó tanárok munkájának összefogása,  foglalkozások tartása a Hőgyes-Laborban, tehetséggondozás, iskolai és iskolán kívüli szakköri foglalkozások, tudománynépszerűsítő előadások, workshopok vezetése.", "mtmi_csapat_tag3_tevekenyseg": "A matematika-informatika munkaközösség vezetője, természettudományos orientációjú osztály főnöke. A szakos kollégák munkájának összefogása, versenyfelkészítő és tehetséggondozó foglalkozások vezetése, iskolán kívüli felkészítő szakkörök tartása.", "mtmi_csapat_tag4_tevekenyseg": "Természettudományos osztály osztályfőnöke, Hőgyes-laboros és tehetséggondozó foglalkozások tartása biológiából és földrajzból, komplex természettudományos projekt irányítása.", "mtmi_csapat_tag5_tevekenyseg": "Hőgyes-laboros és tehetséggondozó foglalkozások vezetője fizikából, kísérletező-kutató (Univerzoom) projekt irányítása, városi természettudományos szakkör tartása.", "mtmi_csapat_tag6_tevekenyseg": "Tehetséggondozó és kutatásalapú versenyek felkészítője biológiából, komplex természettudományos projekt irányítása, részvétel a Hőgyes-labor programjaiban, városi természettudományos szakkör tartása.", "mtmi_csapat_tag7_tevekenyseg": "Tehetséggondozó programok tartása és kísérleti versenyekre való felkészítés kémiából, biológiából, részvétel a Hőgyes-labor programjaiban.", "mtmi_csapat_tag8_tevekenyseg": "Versenyfelkészítés informatikából, témanap és honlap felelőse, pedagógusok digitális eszközhasználati készségeinek fejlesztése (workshopok tartása a tantestület részére).", "mtmi_muzeumlatogatasok_link1": "https://hogyes.hu/2025-26-tanev-tervezett-mtmi-programjai/", "mtmi_aktiv_tanulas_megvalosul": "reszben", "mtmi_csapat_kozos_tevekenyseg": "MTMI éves terv összeállítása, havonta megbeszélés az aktuális programokról. Előadók meghívása, fogadása. Természettudományos interdiszciplináris projekt feladatainak kidolgozása, feladatok megosztása a 11. évfolyamon. Tehetséggondozó programok tartása külső és iskolai helyszíneken a 7-10. évfolyam érintett tanulói számára (matematika, természettudomány). Egyetemi előadók, MTMI-területen dolgozó szakemberek (szülők, volt diákok) meghívása tudománynépszerűsítő, illetve pályaorientációs céllal. Külső programok szervezése: üzemlátogatások, egyetemi programok (előadások, nyílt napok, laborlátogatás), múzeumpedagógiai és egyéb (pl. lányok napja, kutatók éjszakája) programok. Külső helyszínekre tanulók kísérete. A tanulók és a szülők értesítése a programokról. Szakkörök tartása: versenyfelkészítés, felzárkóztatás, kísérleti és kutatásalapú versenyekre való felkészítés. Hőgyes-labor programok: nyílt napok általános iskolásoknak, Kutatók éjszakája program a Hőgyes-laborban, városi \\"kutató\\" szakkör tartása 7-8. osztályosoknak. Beszámolók készítése az eseményekről.", "mtmi_fakultaciok_diakok_szama": "199", "mtmi_kiallitoterek_megvalosul": "igen", "lanyoknak_szolo_mtmi_programok": "igen", "mtmi_egyeb_tevekenysegek_szama": "17", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_kutatási_versenyek_link1": "https://hogyes.hu/2025/06/12/kreativ-fizikaverseny/", "mtmi_kutatási_versenyek_link2": "https://hogyes.hu/2024/12/17/dr-foldi-janos-diakkonferecia/", "mtmi_kutatási_versenyek_link3": "https://www.facebook.com/photo.php?fbid=1307258244742302&set=pb.100063744172836.-2207520000&type=3", "mtmi_kutatási_versenyek_szama": "3", "mtmi_laboratoriumok_latogatasa": "igen", "mtmi_otlet_esszepalyazat_link1": "https://hogyes.hu/2023/04/25/szegeden-jartunk/", "mtmi_otlet_esszepalyazat_link2": "https://hogyes.hu/2023/03/09/tanulonk-a-magyar-tudomanyos-akademia-szekhazaban/", "mtmi_otlet_esszepalyazat_link3": "https://hogyes.hu/2024/11/18/erdei-utakon-14-fekete-istvan-biologiai-es-irodalmi-nemzetkozi-verseny/", "mtmi_otlet_esszepalyazat_link4": "https://online.fliphtml5.com/uvhrj/dlmf/#p=1", "mtmi_otlet_esszepalyazat_szama": "2", "intezmenytipus_tanuloi_letszama": "495", "mtmi_faliujsag_vitrin_reszvetel": "igen", "mtmi_palyaorientacio_megvalosul": "igen", "lanyok_mtmi_reszvetel_bemutatasa": "Eddigi pályaorientációs tevékenységünkben nem volt kifejezetten hangsúlyos a nők szerepe az MTMI szakmákban, de a pályaorientációs, illetve projektnapjainkra minden évben hívtunk  régi tanítványaink közül olyan lányokat, akik MTMI pályát választottak, mester- vagy Phd képzésre járnak, esetleg néhány éves munkatapasztalattal rendelkeznek, és hitelesen tudják bemutatni társaiknak választott szakmájukat, és a nők számára is elérhető karrierutakat.", "mtmi_faliujsag_vitrin_bemutatasa": "Az első emeleten elhelyezett paravánokra havonta kikerülnek a különböző versenyeken sikeresen szereplő tanulóink képei és rövid beszámolók a versenyekről.", "mtmi_felelos_kapcsolattarto_neve": "Balla Éva Margit", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "igen", "mtmi_tanoran_kivuli_rendezvenyek": "Számos tanórán kívüli programmal támogatjuk a pályaorientációt és a tehetséggondozást. Tagozatos és faktos diákjaink a pályaorientációs napunkon kívül is több alkalommal részt vesznek üzem- és céglátogatásokon, ahol a helyi és környékbeli vállalatok – például a Leier, BMW, Emerson-NI és Richter – működését ismerhetik meg. Ezek az alkalmak betekintést adnak a modern ipari technológiák világába, és hozzájárulnak a reál-műszaki érdeklődés erősítéséhez. \\n\\nIskolai tehetséggondozó programunk kiemelt területe a természettudományos, valamint matematikai érdeklődésű tanítványainknak szervezett foglalkozások. Ezek részben tanórai keretben zajló élménypedagógiai foglalkozások, amelyek kísérletekkel, digitális eszközhasználattal fejlesztik a tanulók képességeit és növelik a motivációt. Másrészt a 9-10. évfolyamosok számára tanórán kívüli kirándulásokat szervezünk különböző helyszínekre: egyetemekre, kutatóintézetekbe, interaktív tudományos központokba, természettudományos múzeumba, munkahelyekre. \\n\\nA matematika népszerűsítése érdekében pár éve megrendezzük az iskolai Pí-napot az osztályok közötti játékos vetélkedő formájában, amelyre előzetes feladatokkal készülhetnek a diákok, a nap során  kreatív feladatokat kapnak, logikai feladványokat, rejtvényeket fejtenek meg. Az esemény célja, hogy játékos, élményszerű formában közelebb hozza a matematikát a tanulókhoz, és megmutassa, hogy ez a tudomány gondolkodtató, kreatív és szórakoztató is lehet.  \\n\\nKiemelt eseményünk a Kutatók Éjszakája, amelyhez minden évben saját programokkal csatlakozunk. Ilyenkor természettudományos osztályaink diákjai és tanáraink közösen készülnek látványos kísérletekkel, bemutatókkal és interaktív tudományos állomásokkal, melyekre minden érdeklődőt várunk. \\n\\nÉrtékes eleme programunknak az MTA Alumni sorozat, amely során akadémikusokat és kutatókat hívunk meg iskolánkba. Vendégeink saját kutatásaikról tartanak élvezetes, tudománynépszerűsítő előadásokat, inspirálva ezzel a diákokat a tudományos pályák felé.", "mtmi_tanulmányi_versenyek_link1": "https://hogyes.hu/2025/03/12/karpat-medencei-megmerettetes/", "mtmi_tanulmányi_versenyek_link2": "https://hogyes.hu/2025/05/21/szenzaciok-a-medve-matek-szabadteri-versenyen/", "mtmi_tanulmányi_versenyek_link3": "https://hogyes.hu/2025/04/13/matech5-verseny-siker/", "mtmi_tanulmányi_versenyek_link4": "https://hogyes.hu/2025/02/11/hogyes-diakok-a-durer-orszagos-matematikaversenyen/", "mtmi_tanulmányi_versenyek_link5": "https://hogyes.hu/2025/04/15/beszamolo-a-nemzetkozi-kenguru-matematikaversenyrol/", "mtmi_tanulmányi_versenyek_link6": "https://hogyes.hu/2025/02/25/oromok-a-kemiaban/", "mtmi_tanulmányi_versenyek_link7": "https://hogyes.hu/2025/06/10/masodik-helyezes-a-debreceni-egyetem-mek-termeszetvedelmi-versenyen/", "mtmi_tanulmányi_versenyek_szama": "35", "mtmi_egyeb_partnerprogramok_link1": "https://hogyes.hu/munkakozossegek-oveges-labor/", "mtmi_muzeumlatogatasok_bemutatasa": "A 9-10. évfolyamon a természettudományos, illetve matematika orientációjú csoportoknak szervezünk foglalkozásokat a debreceni Agóra Tudományos és Élményközpontban, Budapesten a Csodák Palotájában és a Természettudományi Múzeumban. A tervezett programelemek: „Mateklabor” + Logikai Játszóház, Agóra robotika foglalkozás, Látványos fizikai-kémiai kísérletek + interaktív felfedezés, Élményalapú tudomány – fizika, kémia, biológia interaktívan, Orvosi technológiák + múzeumpedagógiai foglalkozás. A tanulóknak múzeumpedagógiai órákat tartanak, a következő héten az iskolában a tanulmányi kiránduláson látottak feldolgozása történik meg a szaktanárok vezetésével.", "mtmi_online_palyaorientacio_link1": "https://forms.office.com/pages/responsepage.aspx?id=arH-RFJUSUWxZzunT26hUOyTD1128i1Jof2O8ktXVXhUQkQ4Q0xROUpZQVVTOTY1UDdGNDNYSDY0RC4u&origin=lprLink&route=shorturl", "mtmi_rendezvenyek_reszvetel_link1": "https://hogyes.hu/2024/09/28/nagy-sikere-volt-a-kutatok-ejszakajanak-a-hogyesben/", "mtmi_rendezvenyek_reszvetel_link2": "https://hogyes.hu/kutatok-ejszakaja-2025-26/", "mtmi_rendezvenyek_reszvetel_link3": "https://www.youtube.com/watch?v=EQpP5aEvOp0", "programban_erintett_tanulok_szama": "495", "mtmi_diakok_kapcsolattartas_leiras": "10-12. évfolyamon az osztályfőnöki órák keretében tartott tájékoztatókon a tanulók választ kaphatnak a pályaválasztással kapcsolatos kérdéseikre. A végzősök szüleinek továbbtanulási szülői értekezletet szervezünk, melyet az igazgatóhelyettes tart, a felmerülő kérdésekre válaszol. A tanulóknak és a szülőknek lehetőségük van a pályaválasztási felelős igazgatóhelyettessel fogadó óra keretében is konzultálni egyéni kérdéseikről.", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyuttmukodes_palyaorientacio": "igen", "mtmi_felelos_kapcsolattarto_email1": "balla.eva@hogyes.hu", "mtmi_online_palyaorientacio_leiras": "A kérdőív az érdeklődési irányok feltérképezését célozza, hiszen az érdeklődési terület fontos szerepet játszik a foglalkozás kiválasztásában, illetve a választott munkával való elégedettségben. A kérdőívet a 9. évfolyamos tanulókkal töltetjük ki, a kiértékelést a pályaorientációért felelős igazgatóhelyettes végzi, az eredményeket az osztályfőnökkel együtt megbeszélik a gyerekekkel. Az eredmények ismeretében különböző pályatípusok ajánlhatók a tanulóknak.\\n", "mtmi_otlet_esszepalyazat_reszvetel": "igen", "mtmi_tanulmányi_verseny_reszvetel": "igen", "mtmi_tovabbkepzesi_programok_link1": "https://hogyes.hu/bazisprogram/", "intezmenyvezeto_kapcsolattarto_neve": "Sárkányné Kertész Éva", "lanyok_mtmi_nepszerusito_bemutatasa": "Terveink szerint minden évben keresünk lehetőségeket a lányok számára, az országos kampányok eseményeire külön felhívjuk a figyelmüket. A Nők a Tudományért Egyesület programjait, és az NI Hungary Kft-nek az Agóra Tudományos Élményközponttal együttműködésben elindított WATCH (Women at Tech) programját népszerűsítjük diákjainak körében. A budapesti programokra kellő létszámú jelentkező esetében csoportos látogatást szervezünk. \\n", "mtmi_kiallitoterek_megvalosul_link1": "https://www.facebook.com/photo.php?fbid=1192284026239725&set=pb.100063744172836.-2207520000&type=3", "mtmi_kutatási_verseny_diakok_szama": "17", "mtmi_kutatási_versenyek_bemutatasa": "Kutatási alapú versenyekre biológiából és fizikából készítünk diákokat. \\nTavaly két diákunk végzett biológiai kutatásokat egyetemi mentorok támogatásával.  Egyikük végzősként indult a TUDOK-on, ahol kategóriájában 1. helyezést ért el.  Jelenleg egy tanuló jár be a hidrobiológiai tanszékre egyetemi mentorhoz, a diákkonferenciára készülő kutatásai miatt, ő ebben a tanévben indul a TUDOK-on. Ketten jelentkeztek a Kutdiákra, ahol az egyetemi tanárok ajánlatából választanak egy-egy témát, ők jövőre fognak a TUDOK-on indulni. \\nBiológia szakos kollégánk a Dr. Földi János Diákkonferenciára készít fel versenyzőket, itt a diákok 3 fős csapatokban dolgoznak ki önálló kutatást, amit előadnak, ez a verseny az első lépcsőfok a kutatói pálya irányába. A tavalyi tanévben két csapatunk 1. és 3. helyezést ért el.\\nA Kreatív Fizikaversenyt 5-11. osztályosoknak hirdeti meg a Nyíregyházi Egyetem azzal a céllal, hogy  támogassa a tehetséges diákokat, lehetőséget biztosítson  kreatív ötletek megvalósítására és bemutatására, orientálja a diákokat a természettudományok és a műszaki tudományok felé.\\nA versenykiírásban meghatározott témákban a versenyzőknek maguknak kell a kísérletet megtervezni, a kísérleti eszközöket, mérő berendezéseket összeállítani, majd a kísérletet elvégezni, elemezni, minderről videó dokumentációt készíteni. Tavaly egy 8. osztályos tanítványunk 3. helyezést ért el. \\n", "mtmi_otlet_esszepalyazat_bemutatasa": "Évente 1-2 pályázaton veszünk részt, a korábbi években indultak tanulóink a Richter-TETTmeseíró pályázaton (erre idén is van indulónk), a Fekete István biológiai és irodalmi versenyen, illetve a szegedi egyetem által kiírt matematikai pályázaton. Mindegyik versenyen díjazottak lettek tanulóink, a matematikai pályázat inspirálta a honlapon is elérhető, matekos tanulók által szerkesztett szakköri füzetet.", "mtmi_digitalis_tananyagok_megvalosul": "igen", "mtmi_felelos_kapcsolattarto_beosztas": "igazgatóhelyettes", "mtmi_kutatási_verseny_tanarok_szama": "2", "mtmi_laboratoriumok_latogatasa_link1": "https://hogyes.hu/2023/06/15/tanulmanyi-kirandulas-a-debreceni-egyetemen/", "mtmi_laboratoriumok_latogatasa_link2": "https://hogyes.hu/2025/05/30/latogatas-a-debreceni-egyetem-mezogazdasag-elelmiszertudomanyi-es-kornyezetgazdalkodasi-karon/", "mtmi_laboratoriumok_latogatasa_link3": "https://hogyes.hu/2025/04/08/laborlatogatas/", "mtmi_laboratoriumok_latogatasa_link4": "https://hogyes.hu/2025/10/24/bme-nyitott-laborok-es-lanyok-napja/", "intezmenyvezeto_kapcsolattarto_email1": "iskola@hogyes.hu", "mtmi_egyeb_palyaorientacios_programok": "A tehetséggondozás keretében megvalósított külső programok, illetve a fakultációs csoportoknak szervezett külső laborfoglalkozások szintén hozzájárulnak a tanulók MTMI-pályák iránti érdeklődésének felkeltéséhez, valamint ezen területek jobb megismeréséhez. (3.1.2)", "mtmi_otlet_esszepalyazat_diakok_szama": "6", "mtmi_tanulmányi_verseny_diakok_szama": "170", "mtmi_tanulmányi_versenyek_bemutatasa": "Az előző tanév legkiemelkedőbb eredményei voltak: \\nArany Dániel matematikaverseny országos döntős tanuló, Bolyai Matematikaverseny országos döntős csapat, Dürer Országos matematikaverseny 2 döntős csapat, Matech5 verseny országos döntős csapat (3. hely), Medve Szabadtéri matematikaverseny országos döntős csapat, Curie kémia kísérletverseny országos döntős csapat (2. hely). Az OKTV-n 2. fordulós tanítványunk volt matematikából és biológiából. A Dr. Kónya Józsefné Emlékversenyen -megyei különdíj, Kenguru matematikaverseny megyei lista 2-3. hely, több tanulónk jutott 2. fordulóba az Arany Dániel, Zrínyi és Curie matematikaversenyeken. \\nAz idei tanévben a munkaközösségek munkatervei szerint a következő versenyeken indítunk tanulókat: \\nOKTV matematika, biológia, fizika, kémia, digitális kultúra, földrajz,\\nMatematika: Arany Dániel matematikaverseny, Varga Tamás matematikaverseny, Curie matematika levelezős verseny, Dürer matematikaverseny, Zrínyi Ilona verseny, Bolyai matematikaversenyek, Medve matematikaverseny,  Kenguru matematika verseny\\nInformatika: Nemes Tihamér digitális kultúra verseny, Hódítsd meg a BIT-eket digitális kultúra verseny\\nTermészettudomány: Bolyai Természettudományos Csapatverseny, GYKTV Természettudományi verseny\\nKémia: Oláh György Kémiaverseny,  Hevesy György Kémiaverseny, Irinyi János Országos Kémiaverseny, Dr. Kónya Józsefné Emlékverseny, Curie Kémia Kísérletverseny, Curie Kémiaverseny\\nBiológia: Herman Ottó Biológiaverseny, Dr. Árokszállásy Zoltán Biológiaverseny,   \\nFizika: Mikola Sándor Fizikaverseny, Öveges Fizikaverseny,\\nFöldrajz: Teleki Pál Országos Földrajz Földtan verseny,  Jakucs László Nemzetközi Földrajzverseny\\nEgyéb: Curie Környezetvédelmi Verseny, Elsősegélynyújtó verseny. \\n", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_otlet_esszepalyazat_tanarok_szama": "3", "mtmi_rendezvenyek_reszvetel_bemutatasa": "Kiemelt rendezvényünk a Kutatók Éjszakája, amelyhez a Hőgyes-labor adta lehetőségeket kihasználva aktívan csatlakozunk: intézményünk saját programokat is szervez. A 9. és 10. évfolyam természettudományos orientációjú osztályait mozgósítjuk, és a tanulókat is bevonjuk a program lebonyolításába. \\nKollégáink és diákjaink az iskolaépület különböző helyszínein, a természettudományos tantárgyakhoz kapcsolódó rövid előadásokkal és látványos kísérletekkel várják az érdeklődőket. A legtöbb kísérlet interaktív formában zajlik, így a vendégek is aktív résztvevői lehetnek az eseménynek. A nagyobbak részletes magyarázatot is kapnak a megfigyelt jelenségekre, ezért a rendezvényt alapos előkészítő munka előzi meg: a kísérletek kiválasztása és előkészítése mellett a diákok felkészítése is fontos szerepet kap.\\nAz utóbbi években programunkat valamilyen érdekes tematikára fűzzük fel, megcélozva a legnagyobb számban érdeklődő általános iskolás korosztályt. A rendezvény így a természettudományok népszerűsítése  mellett az iskolánk iránti érdeklődést is növelheti.", "mtmi_tanulmányi_verseny_tanarok_szama": "15", "intezmenyvezeto_kapcsolattarto_beosztas": "igazgató", "mtmi_interdiszciplinaris_projekt_leiras": "A projekt megvalósítását az idei tanévben, a 11. évfolyam tanulói számára tervezzük, a természettudomány órák keretében. Ezeket a tanórákat biológia, kémia, földrajz szakos kollégák tartják, de a megvalósításban az MTMI-csapat többi tagja is közreműködik. A projekt címe: „Éltető víz – a természet kincse és városunk büszkesége”, témája: Hogyan hat a víz az életünkre – a mindennapjainkra, egészségünkre, környezetünkre –, és miért különleges városunk gyógyvize?\\nA témaválasztást a hajdúszoboszlói gyógyforrás felfedezésének 100. évfordulója indokolja, a centenáriumi eseményekhez kapcsolódna a projektünk. \\nA megvalósítás során a diákok elméleti kutatómunkát végeznek, amelyet szakemberek előadásai és üzemlátogatások (például a gyógyfürdőben, a palackozó üzemben vagy a fürdő laboratóriumában), terepgyakorlatok (vízminták gyűjtése) egészítenek ki. A külső helyszíneken szerzett tapasztalatokat iskolai kísérletek követik: vízminták kémiai elemzése, a víz fizikai tulajdonságainak valamint a gyógyvíz biológiai hatásának vizsgálata. \\nA projekt záróeseményét egy kiállítás keretében rendezzük meg, ahol a diákok standokon poszterek, makettek, digitális prezentációk formájában és kísérleteken keresztül mutatják be munkájukat. Az esemény nyitott az iskola teljes közössége, a szülők és a város érdeklődői számára is, így a projekt egyszerre szolgál tanulási, közösségépítő és tudománynépszerűsítő célt.\\n", "mtmi_tovabbkepzesek_idokeret_megvalosul": "reszben", "mtmi_tovabbkepzesi_programok_megvalosul": "igen", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "A modern, tanulóközpontú módszerek alkalmazása iskolánkban elvárás. Minden tanórán többféle munkaforma, így a páros vagy csoportmunka is megjelenik legalább egy-egy feladat erejéig: a tanulók közösen, egymást segítve végeznek el pl. egy kísérletet, vagy egy matematikai probléma megoldását. A projektmódszer mindig megjelenik a témanapokon, és az iskolai ünnepségeken is leggyakrabban ebben a formában dolgozzák fel a tanulók az eseményekről való megemlékezést. Az MTMI tárgyakból gyakran egy-egy projektfeladat értékelésével történik a témakör lezárása. Az értékelésben jellemző a tanári oldalról a formatív értékelés: folyamatos és fejlesztő visszajelzés formájában, és törekszünk a tanulókban kialakítani az önértékelés és a társértékelés objektív, támogató kommunikációval történő kifejezését.", "mtmi_felelos_kapcsolattarto_telefonszam1": "0652557510", "mtmi_felelos_kapcsolattarto_telefonszam2": "+36 70 228 4534", "mtmi_kiallitoterek_megvalosul_bemutatasa": "A földszinti és első emeleti folyosón elhelyezett vitrinek és az első emeleten kiállított paravánok adnak helyet a tanulói munkák kiállítására. ", "mtmi_palyaorientacio_megvalosulas_leiras": "A 10. évfolyam számára a tanév egyik legfontosabb döntése a fakultációválasztás, amely közvetlenül befolyásolja a későbbi továbbtanulási lehetőségeket. A tanulók a pályaválasztásért felelős igazgatóhelyettes által tartott tájékoztatókon, osztályfőnöki órák keretében ismerhetik meg a fakultációk rendszerét, az egyetemek elvárásait és az egyes MTMI tantárgyakhoz kapcsolódó karrierutakat. A cél, hogy minden diák tudatosan, a saját érdeklődése és céljai alapján válasszon.\\nA felsőbb évfolyamokon a hangsúly a továbbtanulásra való felkészítésen van. Az igazgatóhelyettes tájékoztatókat tart az osztályfőnöki órákon a felsőoktatási felvételi rendszerről, az egyéb továbbtanulási lehetőségekről, az aktuális követelményekről, valamint az egyes MTMI szakirányok lehetőségeiről.\\n", "lanyoknak_szolo_mtmi_programok_bemutatasa": "Tavaly tavasszal a BME által szervezett programra látogattunk el, ahol a 9-11. évfolyamos lányok különböző szakterületek laboratóriumait tekinthették meg, ki is próbálhattak néhány tevékenységet. Idén ősszel a Lurdy Konferenciaközpontba vittük a 11. osztályos lányok érdeklődő csoportját, ahol számos egyetem, kutatóintézet és vállalat standja és workshopja fogadta a lányokat, hogy bemutassa a STEM terület lehetőségeit. ", "mtmi_egyuttmukodes_palyaorientacio_leiras": "Iskolánkban minden évfolyam számára biztosított a pályaorientációs tájékoztatás. A cél, hogy a diákok fokozatosan, saját érdeklődésüknek és képességeiknek megfelelően ismerjék meg a különböző továbbtanulási és elhelyezkedési irányokat, különös tekintettel az MTMI területekre. Az iskola kiemelt eseménye a pályaorientációs nap, amely évente egyszer kerül megrendezésre minden évfolyam számára. \\n7–9. évfolyamon az MTMI-területek megismerését  foglalkozás-bemutató filmek segítik. A szülők is aktívan bekapcsolódnak a programba: a pályaorientációs napon saját szakmájuk és pályájuk bemutatásával járulnak hozzá ahhoz, hogy a tanulók valós, gyakorlati példákon keresztül kapjanak képet a munka világáról.\\nA 10. évfolyamnak erre a napra a Debreceni Egyetemmel való kapcsolatnak köszönhetően a DE különböző karain szervezünk programokat. A 11-12. évfolyamos diákok a pályaorientációs napon közvetlenül találkozhatnak felsőoktatási intézmények és szakképző központok képviselőivel, volt diákjainkkal és szülőkkel, akik személyes tapasztalataikat megosztva hiteles képet nyújtanak a különböző szakmai életutakról. Ezen a napon a diákok megismerhetik a felsőoktatási és szakképzési kínálatot, részt vehetnek interaktív előadásokon, szakmai bemutatókon,  és lehetőségük nyílik közvetlen beszélgetésekre egyetemistákkal, egyetemi oktatókkal, kutatókkal, mérnökökkel, illetve vállalati szakemberekkel. \\nA 12. évfolyam számára egy másik héten a Debreceni Egyetem különböző karainak képviselőit hívjuk meg, hogy bemutassák kínálatukat. \\nDE Gazdaságtudományi Kara az együttműködésünk érdekében végzett munkánkat kari díjjal ismerte el.\\nA tanév során több alkalommal megszervezett üzem- és gyárlátogatások, valamint egyetemlátogatások további segítséget nyújtanak az MTMI tanulmányi irányok és lehetséges karrierpályák megismeréséhez.", "mtmi_laboratoriumok_latogatasa_bemutatasa": "Partnerintézményünk a Debreceni Egyetem, amellyel kialakított szoros kapcsolatunknak köszönhetően rendszeresen fogadja csoportjainkat, a profiljuknak megfelelő foglalkozások alkalmával ismertetve meg a diákokat az adott kar, tanszék választható szakjaival, az ott folyó munkával. Előző tanévekben ellátogattunk a Természettudományi és Technológiai Kar laboratóriumaiba, a Mezőgazdaság-, Élelmiszertudományi és Környezetgazdálkodási Karra, legutóbb a Műszaki Kar laborjait próbálhatták ki faktosaink. \\nAz idei tanévben a 9. évfolyamos érdeklődőket várják a TTK-n természettudományos laborlátogatásra és pályaorientációs beszélgetésre, a tizedikeseknek pedig a környezettudományi tanszék vízvizsgálati laborjába szervezünk programot. \\nA BME is kiemelt partnerintézményünk, így rendszeresen értesülünk a középiskolásoknak szervezett programjairól: ebben a tanévben a villamosmérnöki kar Nyitott laborok programjára látogattunk el.    ", "intezmenyvezeto_kapcsolattarto_telefonszam1": "0652557517", "mtmi_egyeb_palyaorientacios_programok_link1": "https://hogyes.hu/2024/11/21/palyaorientacios-nap-2024/", "mtmi_egyeb_palyaorientacios_programok_link2": "https://hogyes.hu/2025/09/01/kutato-diakjaink-a-ttk-n/", "mtmi_egyeb_palyaorientacios_programok_link3": "https://hogyes.hu/2024/12/13/gyarlatogatas-bmw-debrecen/", "mtmi_egyeb_palyaorientacios_programok_link4": "https://hogyes.hu/2025/04/08/ceglatogatas-az-emerson-ni-nal/", "mtmi_egyeb_palyaorientacios_programok_link5": "https://www.facebook.com/photo.php?fbid=1054342506700545&set=pb.100063744172836.-2207520000&type=3", "mtmi_digitalis_eszkozok_megvalosul_bemutatasa": "Iskolánkban a digitális eszközök rendszeres alkalmazása szerves része az oktatásnak. A tanórákon a pedagógusok interaktív táblákat, laptopokat használnak. A tanárok tudatosan törekednek arra, hogy a technológia ne öncélú eszköz, hanem a megértést, az élményszerű tanulást és a gyakorlati alkalmazást segítő támogatás legyen. \\nA matematikaórákon gyakori a GeoGebra alkalmazás használata, míg a természettudományos tárgyak esetében a PhET interaktív szimulációk bemutatása, az interneten fellelhető oktató videók segítik az elméleti ismeretek megértését és a szemléltetést, illetve minden tantárgyból használjuk az okostankönyvek digitális anyagait. \\nIskolánk a Microsoft Teams platformon minden osztálynak és tantárgynak saját csoportot működtet, ezen a felületen a diákok online kapják meg a tananyagokat, feladatokat.  Tanórákon gyakran kapnak a diákok interaktív teszteket, amelyeket egyéni vagy csoportmunkában saját telefonjukon oldanak meg. A diákok az órai vagy házi feladatként kapott digitális feladatok, projektmunkák (prezentációk, videós kísérletbemutatók) megoldását is a Teams-csoportba tölthetik fel. \\n\\n", "mtmi_digitalis_tananyagok_megvalosul_bemutatasa": "Az okostankönyvek és egyéb interneten elérhető online platformok interaktív feladatai alkalmasak az órai vagy otthoni gyakorlásra, a különböző szimulációknak, interaktív szoftvereknek a tanórák menetébe való beiktatása segít fenntartani a tanulók figyelmét és aktivitását.  A diákok kedvelik az online teszteket, kvízeket (pl. Kahoot, Quizizz, Learning Apps, Baamboozle), ezért ezeket is rendszeresen használjuk órákon a motivációjuk növelésére, de alkalmasak a tanulók tudásának felmérésére és értékelésére is. A szaktanárok közül többen is készítettek a tantárgyukhoz illeszkedő digitális feladatgyűjteményt, amelyeket a munkaközösségek Teams-csoportjában megosztanak, ezek egy része elérhető a honlapunkon is. Segítség, hogy a fizetős tartalmak egy részét a tanárok számára ingyenesen tették elérhetővé (pl. Mateking), illetve a gyakran használt platformra előfizetést vásárolhatott az iskola.", "mtmi_korszeru_felszereltseg_megvalosul_bemutatasa": "Iskolánk jól felszerelt, de folyamatosan törekszik a tantermi infrastruktúra és a laboratórium folyamatos fejlesztésére, hogy megfeleljen a korszerű oktatás igényeinek. \\nMinden nagy osztályteremben interaktív panelek vannak, laptopokkal összekötve, a kisebb tantermek többségében okostábla van felszerelve. Az iskolai laptop program keretében biztosított minden tanuló számára a tanuláshoz szükséges informatikai eszközök megléte. A megbízható wifi-hálózat biztosítja  a tanulók számára is az internet elérést, ezzel az órai online platformok, feladatok használatát. Az informatika termekben az elavult gépek cseréje, korszerűbb alkatrészekkel való felszerelése folyamatos.  A Hőgyes-labor jól felszerelt, lehetőséget biztosít kísérletek és interaktív foglalkozások lebonyolítására, nemcsak saját diákjaink, hanem általános iskolások és óvodások részére is. \\nKiemelt figyelmet fordítunk az épület tisztaságára, az  esztétikus környezet kialakítására és a környezettudatosságra is. A világos helyiségek, a tantermek és a közösségi terek berendezése, dekorációi, az olvasósarok, az étkező, a kiállítófalak hozzájárulnak az iskola tanulóinak és dolgozóinak jó közérzetéhez, és a motiváló tanulási légkört szolgálják.", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul": "igen", "mtmi_tovabbkepzesek_idokeret_megvalosul_bemutatasa": "A szaktanárok jellemzően a megyei pedagógiai központ által szervezett továbbképzéseken vesznek részt, amelyek legfeljebb néhány órát érintenek, ezek helyettesítése megoldott. Korábbi években volt olyan kollégánk, aki új MTMI-szak elvégzését vállalta az egyetemen, számára az órarend kialakítása annak figyelembe vételével történt,  hogy el tudjon járni az óráira és a vizsgákra, így az időkeret biztosítva volt.", "mtmi_tovabbkepzesi_programok_megvalosul_bemutatasa": "A megyei POK által szervezett programokon a kollégák nagy számban vesznek részt, az érdeklődési körüknek megfelelő képzéseken. Az Oktatási Hivatal bázisintézményeként időnként iskolánk is tart jó gyakorlatainkat bemutató előadást, foglalkozást. A tankerületi szakmai napokon is több alkalommal vállaltuk jól működő programjaink bemutatását, illetve műhelymunka vezetését. A továbbképzéseken szerzett tapasztalatokat belső továbbképzéseken adják át a kollégák a tantestületnek vagy a szakmai munkaközösségnek.\\nA tantestület digitális kompetenciájának fejlesztése céljából informatika szakos kollégánk évente több alkalommal tart belső továbbképzést.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul": "igen", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul_bemutatasa": "A matematika-informatika, valamint a természettudományi munkaközösség 14 tagjánál megjelennek az MTMI célok. A pedagógusok MTMI területekhez köthető vállalásai hozzájárulnak a diákok tehetséggondozásához, pályaorientációjához és egészségtudatos szemléletformálásához, és azt tükrözik, hogy az iskola tantestülete aktívan támogatja az élményalapú, korszerű és interaktív tanulást.\\nTöbb pedagógus vállalta tanulmányi versenyek, városi és házi vetélkedők lebonyolítását különböző MTMI területeken. A pedagógusok közül többen szerveznek külső helyszíni tanulási lehetőséget: egyetemi, gyár- vagy kiállítás látogatásokat. A vállalásokban kiemelt szerepet kap a tehetséggondozás és versenyfelkészítés, szakköri foglalkozások, laborfoglalkozások megvalósítása. Az iskola pedagógusai aktívan közreműködnek a különböző témanapok és projektek megvalósításában. A vállalások között megjelenik a pedagógusok közötti tudásmegosztás és szakmai együttműködés is. A vállalások jól illeszkednek az iskola pedagógiai programjához, és elősegítik az MTMI-területek élményszerű, gyakorlatközpontú megjelenését a mindennapi iskolai életben.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul_bemutatasa": "A továbbképzési programban megjelölt MTMI képzéseken való részvétel a tankerület jóváhagyásával és támogatásával valósulhat meg."}	2025-09-05 11:20:32.56912	2026-03-05 22:23:14.640211	1	b67ab677-54ed-4785-a143-2ad257bee4ec_MTMI_tartalmak_PP-ben.pdf	382360ca-29eb-4b2f-8416-10d57bfd83b5
a1046309-82d9-47df-815f-6bc946eb6fbf	{"iskola_cime": "1146 Budapest, Thököly út 48-54.", "iskolatipus": ["technikum"], "gdpr_consent": ["on"], "szulo_bevonas": "nem", "mtmi_koncepcio": "nem", "telepulesforma": "fovaros", "mtmi_nyilt_napok": "Számtalan nyílt napot rendez az iskola: \\nKutatók éjszakája , Petrik Junior Program, \\"Lányok a STEM-ben\\", a beiskolázási nyílt napok egyben tudomány és labor-bemutatók is, az egyetemek részvételével zajló Pályaorientációs napok. Folyamatos tehát a kommunikáció és a tudománybemutató a 8. osztályosoktól az egyetemekig, a külsősök és a saját diákjaink számára egyaránt.", "szulo_egyeztetes": "megvalosul", "mtmi_projektnapok": "Több projekthetet szervez az iskola: Codeweek, Pénz7, Fenntarthatósági témahét. A különböző ágazatban tanuló diákok számára itt is adott a közös munka lehetősége. \\nA fejlesztési projektek (Környezetkutató csoport) munkái néhány esetben kötődhetnek szakmai tantárgyakhoz, vagy inkább azok órakeretben zajló gyakorlataihoz. Hasonlóan zajlik ez az informatikai képzésen belül is. Nagyon jó lehetőség az órakereteken belül, hogy két ágazat (környezetvédelem, informatika) technikusi vizsgáinak része az un. projektmunka, illetve vizsgaremek elkészítése. A jelentősebb fejlesztések időkerete természetesen egyéni megbeszélések tárgya, de már több lehetőség is adódik arra, hogy egyes kiemelt tanulók, némely esetben oktatók is, az órakeretük bizonyos százalékának terhére foglalkozzanak az ilyen típusú munkájukkal.", "pedprog_mtmi_link1": "https://petrik.hu/wp-content/uploads/2025/02/Szakmai_program_2024_25_02.pdf", "szulo_kommunikacio": "nem", "iskola_honlap_link1": "https://petrik.hu/", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "4", "palyazo_iskola_neve": "Budapesti Műszaki SZC Petrik Lajos Két Tanítási Nyelvű Technikum", "pedprog_mtmi_leiras": "Iskolánk kiemelt figyelmet fordít az MTMI (matematika, természettudomány, műszaki tudományok és informatika) területek iránti érdeklődés felkeltésére és erősítésére. Ennek érdekében támogatjuk a tantárgyak közötti kapcsolatok feltárását, projektalapú tanulási formák megvalósítását, valamint a diákok részvételét kutatásalapú és innovációs programokban. Külön hangsúlyt fektetünk arra, hogy a megszerzett tudás és készségek a gazdaság igényeihez is igazodjanak.", "mtmi_ceges_eloadasok": "igen", "mtmi_csapat_tag1_nev": "Gőgh Zsolt", "mtmi_csapat_tag2_nev": "Forgó Zsuzsanna", "mtmi_csapat_tag3_nev": "Horváth Gyöngyi", "mtmi_csapat_tag4_nev": "Merényi Miklós", "mtmi_szakkorok_link1": "https://otio.hu/projektek_34.html", "mtmi_szakkorok_link2": "https://www.facebook.com/photo/?fbid=1339712197945657&set=a.269383511645203&locale=hu_HU", "mtmi_szakkorok_link3": "https://www.facebook.com/photo/?fbid=1370919461491597&set=a.269383518311869&locale=hu_HU", "mtmi_szakkorok_link4": "https://www.facebook.com/photo/?fbid=1355277179722492&set=a.269383518311869&locale=hu_HU", "mtmi_szakkorok_szama": "3", "mtmi_szulo_kepviselo": "igen", "mtmi_alumni_programok": "igen", "mtmi_csapat_tag1_szak": ["integralt_termeszettudomany", "egyeb"], "mtmi_csapat_tag2_szak": ["egyeb"], "mtmi_csapat_tag3_szak": ["egyeb"], "mtmi_csapat_tag4_szak": ["digitalis_kultura"], "mtmi_csapat_tag5_szak": [], "mtmi_csapat_tag6_szak": [], "mtmi_csapat_tag7_szak": [], "mtmi_csapat_tag8_szak": [], "pedprog_mtmi_tartalom": "igen", "szulo_palyaorientacio": "nem", "mtmi_fakultaciok_szama": "3", "mtmi_muzeumlatogatasok": "nem", "mtmi_nyilt_napok_link1": "https://njszt.hu/hu/event/2025-11-19/ujit-innovacio-es-informatikahttps://www.facebook.com/photo/?fbid=1350701510180059&set=a.269383518311869&locale=hu_HUhttps://www.facebook.com/photo?fbid=1362679032315640&set=pcb.1362682178981992&locale=hu_HUhttps://www.facebook.com/photo/?fbid=1362679018982308&set=pcb.1362682178981992&locale=hu_HU", "iskola_tanuloi_letszama": "935", "mtmi_szakkor_tantargyak": ["matematika", "fizika", "kemia", "integralt_termeszettudomany"], "mtmi_szakmak_bemutatasa": "igen", "szulo_egyeztetes_szoveg": "A diákoknak, akik jelenleg különböző projektekben vesznek részt, szüleikkel a projektet vezető oktatók egyeztetnek a versenyeredményekről. A több szülő is saját forrásaiból segített gyerekének a projektében, ilyenkor egyeztetve az oktatói csapattal.", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "igen", "mtmi_szakmai_gyakorlatok": "A szakképzés természetes része nagyon hangsúlyosan a gyakorlati képzés. Eddig kis létszámban (informatika), vagy rövid időtartamban (vegyész) sikerült kialakítani duálisnak nevezhető formát. A környezetvédelem területén összefüggő, egy hónapos nyári gyakorlat kötelező a 11. évfolyam után. Üzemi, vagy helyszíni látogatások egyértelműen részei az órakereten belüli képzésnek, nem is beszélve a minden évfolyamra jellemző, többórás labor-, terepi-, vagy géptermi gyakorlatokról.", "mtmi_egyetemi_gyakorlatok": "igen", "mtmi_szakkor_diakok_szama": "25", "mtmi_szakkorok_bemutatasa": "Az integrált MTMI szemléleti fejlesztés a technikum Környezetkutató csoportjában működik. Ennek keretében valóságos kutatásokban és fejlesztéseken dolgoznak a kiválasztott diákok. A sokszor 2-3 évig is tartó közös munka során többen már üzleti fejlesztési programokba is bekerülnek. A projektek kutatási versenyeken mérettetnek meg: OTIO, TUDOK, OTDK, innOTDK(legújabb szekció), Országos Középiskolai Földtudományi Diákkonferencia, Stockholm Ifjúsági Vízdíj. Az OTIO verseny iskolai díját immár ötödik éve rendszeresen megkapjuk. Egyetlen örökös díjazottjai vagyunk az Együtt a Jövő Mérnökeiért szervezet kifejezetten MTMI típusú pályázatának (iskolaként). Hangsúlyosan szakmai fejlesztésekbe fogtunk tehát, a három ágazat-Környezetvédelem, Vegyipar, Informatika háttértudására támaszkodva. A Környezetkutató csoport egyértelmű célja a projektek mentén történő  integrált szakmai fejlődés előmozdítása.\\nHagyományosabb szemléletű versenyfelkészítések folynak a kémia (Irinyi verseny), a matematika (OKTV), a biológia (OKTV), informatika (Lego versenyek, Szegedi Innovatív Informatika Verseny, skills versenyek) tudományok mentén. \\nAz informatikai képzés terén iskolánk elhíresült a codeweek, eTwinning akciók megrendezéséről, többszörös verseny győzelmeiről.\\nGazdasági vonalon az OTP Fáy Alapítvány kiemelt 20 iskolája közé tartozunk, illetve Pénz7 programok zajlanak nálunk kiemelt szakértők előadásaival, osztályok külső helyszíneken, projektekben való részvételével.\\n", "szulo_munkakoz_ismertetes": "nem", "mtmi_szakkor_tanarok_szama": "6", "iskola_mtmi_tanari_letszama": "5-6", "lanyok_mtmi_reszvetel_link1": "https://petrik.hu/lanyok-a-stem-ben-kulonleges-nyilt-nappal-keszulunk/", "mtmi_diakok_kapcsolattartas": "igen", "mtmi_kapcsolatok_bemutatasa": "Mint technikum, amiben az oktatás három különböző szakma ágazatát is érint, így a diákok a tanulmányaik alatt több informatikai, vegyipari és környezetvédelmi céghez is mennek céglátogatásra, de szakmai gyakorlatra is. Például Egis és Richter Gedeon gyógyszergyár, WEBváltó, Dél-pesti Szennyvíztisztító Telep.", "mtmi_online_palyaorientacio": "igen", "mtmi_rendezvenyek_reszvetel": "igen", "lanyok_mtmi_kiemelt_figyelem": "nem", "mtmi_alumni_programok_leiras": "A Pályaválasztási napon tudatos  volt diákjaink visszahívása, így személyes hangvételben számolhatnak egyetemi, illetve munkatapasztalataikról. Szervezés alatt van a Környezetkutató csoport korábbi tagjainak találkozója is.", "mtmi_csapat_tag1_tevekenyseg": "Környezetvédelem szakmai oktató, az iskolában \\"Környezetkutatók\\" csoport megalkotója, ami keretein belül több fenntarthatósági projekt is létrejött a diákokkal közösen. A projektek már több versenyen sikeresen részt vettek az évek során.", "mtmi_csapat_tag2_tevekenyseg": "Vegyész szakmai oktató, a természettudományok és a technológia összekapcsolására helyezi a hangsúlyt, az műszaki elméleti ismeretek gyakorlati alkalmazásának bemutatása a fő cél, miközben a diákok a projektjeiket megvalósítják.", "mtmi_csapat_tag3_tevekenyseg": "Közgazdász és német szakos oktató, több gazdasági programot szervezett az iskolába külsős szakmai partnerekkel közösen, a Pénz7 témahét fő szervezője és műszaki technikumoktól eltérően teljesen új gazdasági tantárgyat talált ki és alkotott meg.", "mtmi_csapat_tag4_tevekenyseg": "Informatikai szakmai oktató, támogatja a természettudományos és műszaki projektek digitalizálását és adatfeldolgozását, hangsúlyt fektet az adatkezelés és az automatizálás témakörére.", "mtmi_aktiv_tanulas_megvalosul": "igen", "mtmi_csapat_kozos_tevekenyseg": "A technikum oktatói csapatában központi szerepet kap a valós problémákra épülő, komplex gondolkodás fejlesztése, valamint a tanulói aktivitás és önállóság támogatása. Közös céljuk, hogy az iskola diákjai olyan tudást szerezzenek, amely összekapcsolja az elméletet a gyakorlattal, és felkészíti őket a továbbtanulásra, a munka világára és a fenntartható jövő alakítására a projekteken keresztül.", "mtmi_fakultaciok_diakok_szama": "30", "mtmi_kiallitoterek_megvalosul": "nem", "lanyok_mtmi_nepszerusito_link1": "https://petrik.hu/lanyok-a-stem-ben-kulonleges-nyilt-nappal-keszulunk/", "lanyoknak_szolo_mtmi_programok": "igen", "mtmi_egyeb_tevekenysegek_szama": "12", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_kutatási_versenyek_link1": "https://www.facebook.com/photo?fbid=1241413268027748&set=pcb.1241413848027690&locale=hu_HUhttps://www.facebook.com/photo/?fbid=1355978949652315&set=pcb.1355979789652231&locale=hu_HUhttps://www.inf.u-szeged.hu/sziiv/sziiv2024/eredmenyekhttps://petrik.hu/kornyezetvedo-informatikus-sikerek-miskolcon/https://www.facebook.com/photo/?fbid=1280494167200794&set=pcb.1280495390534005&locale=hu_HUhttps://www.facebook.com/photo/?fbid=1112212140928581&set=pcb.1112212280928567&locale=hu_HUhttps://www.facebook.com/photo/?fbid=1255488933034651&set=a.269383518311869&locale=hu_HU", "mtmi_kutatási_versenyek_szama": "4", "mtmi_laboratoriumok_latogatasa": "igen", "mtmi_otlet_esszepalyazat_szama": "4", "intezmenytipus_tanuloi_letszama": "935", "mtmi_ceges_eloadasok_bemutatasa": "Minden évben megrendezésre kerül a pályaorientációs nap, idén november 21-én, mikor is több egyetem több karáról, és több partnercégtől is érkeznek előadók, akik bemutatókat tartanak a diákoknak.", "mtmi_faliujsag_vitrin_reszvetel": "igen", "mtmi_palyaorientacio_megvalosul": "igen", "mtmi_faliujsag_vitrin_bemutatasa": "Az igazgatói szinten egy kiemelt helyen lévő vitrin szolgál a \\"dicsőségtabló\\" céljára. Ebben évente cserélődnek a legfőbb eredményeket bemutató oklevelek és fényképek. Az igazgatói irodában az iskolai szintű kiemelt eredmények oklevelei és egyéb relikviái egy kitüntetett helyen lévő polcon kerültek elhelyezésre.", "mtmi_felelos_kapcsolattarto_neve": "Gőgh Zsolt", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "igen", "mtmi_tanoran_kivuli_rendezvenyek": "A Környezetkutató csoport tagjai számára lehetőség adódik szakmai bemutatókon, szakmai konferenciákon való részvételre. Egyes esetekben iskolánk is szervezett már ilyet.", "mtmi_tanulmányi_versenyek_link1": "https://www.facebook.com/photo/?fbid=1243467634236781&set=a.269383511645203&locale=hu_HU", "mtmi_tanulmányi_versenyek_szama": "7", "mtmi_rendezvenyek_reszvetel_link1": "https://app.kutatokejszakaja.hu/intezmenyek/bmszc-petrik-lajos-ket-tanitasi-nyelvu-technikum?fbclid=IwY2xjawNomMFleHRuA2FlbQIxMQABHjUD9n9w-_pEQpoGOoXXQiubT0dgQFbagzoe6djaSeJb2-JaZ1KctcZArsHo_aem_hR9w0lTjwdPLtjZxJ_WYbg", "programban_erintett_tanulok_szama": "12", "mtmi_diakok_kapcsolattartas_leiras": "A pályaválasztásért technikumunkban Szolnok Ádám szervezésért és kommunikációért felelős igazgatóhelyettes felel. Ő szervezi a fent említett Pályaválasztási napot. A diákok személyes kérdéseikkel bármikor megkereshetik, mivel kiterjedt kapcsolati körrel rendelkezik. Ez utóbbi sok szaktanárról is elmondható egyébként.", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyuttmukodes_palyaorientacio": "igen", "mtmi_felelos_kapcsolattarto_email1": "zsgogh@gmail.com", "mtmi_online_palyaorientacio_leiras": "A Pályaorientációs napon néhány alkalommal pályaorientációs cég is tiszteletét tette. Tesztkitöltés és személyes tanácsadás is szerepelt a programjukban. Online formában ez nincs jelen az iskolai keretek között.", "mtmi_otlet_esszepalyazat_reszvetel": "igen", "mtmi_tanulmányi_verseny_reszvetel": "igen", "intezmenyvezeto_kapcsolattarto_neve": "Gál-Berey Csilla", "lanyok_mtmi_nepszerusito_bemutatasa": "Nyílt nap október 17-én, ahol a természettudományos, mérnöki és informatikai pálya iránt érdeklődő, pályaválasztás előtt álló lányokat és szüleiket várta az iskola.", "mtmi_kiallitoterek_megvalosul_link1": "https://www.facebook.com/BMSZCPetrik/posts/1343175050932705?ref=embed_post", "mtmi_kutatási_verseny_diakok_szama": "20", "mtmi_kutatási_versenyek_bemutatasa": "A Kutatási versenyek terén egyértelműen a technikum Környezetkutató csoportja viszi a prímet.  az általuk preferált versenyek a következők: OTIO, OTDK, Országos Középiskolai Földtudományi Diákkonferencia, TUDOK, Stockholm Ifjúsági Vízdíj\\nAz utóbbi öt évben: OTIO-7 döntős helyezés, egy 2. helyezés, iskolai díjazások (5)\\nAz informatikai képzésben a Lego, a skills versenyek voltak jellemzőek az utóbbi két évben. nagy siker volt a Szegedi Innovatív Informatika Versenyen elért I. helyezés (Műszaki informatika szekció).\\nVegyész vonalon is vannak kiemelkedő eredmények: (XVII. Grand Prix Chimique), \\nOTDK-innOTDK: 9 döntős részvétel, egy II.helyezés, három) különdíj, közönségdíj (innOTDK\\nTUDOK: három első helyezés, egy második helyezés, két különdíj\\nOrszágos Középiskolai Földtudományi Diákkonferencia (Miskolci Egyetem): három első helyezés, két második helyezés, két harmadik helyezés előadói különdíj\\nStokholm Ifjúsági Vízdíj: két második helyezés, egy különdíj", "mtmi_otlet_esszepalyazat_bemutatasa": "TUDOK esszépályázat, TUDOK-Kutatási Tervtömb, Miskolci Egyetem Búvárrobot ötletpályázat", "mtmi_digitalis_tananyagok_megvalosul": "igen", "mtmi_felelos_kapcsolattarto_beosztas": "szakmai oktató", "mtmi_kutatási_verseny_tanarok_szama": "6", "intezmenyvezeto_kapcsolattarto_email1": "galberey@petrik.hu", "mtmi_egyeb_palyaorientacios_programok": "Az iskola az általános iskolások számára szervezett iskolabörzéken jelentős energia ráfordítással vesz részt. Itt diákjaink nagy létszámban képviseltetik magukat, így is tudatosítva saját szakmájuk iránti elkötelezettségüket.", "mtmi_otlet_esszepalyazat_diakok_szama": "5", "mtmi_tanulmányi_verseny_diakok_szama": "57", "mtmi_tanulmányi_versenyek_bemutatasa": "OKTV versenyek:\\nbiológia ,kémia , digitális kultúra, matematika, fizika\\nMatematika OKTV: egy-két évente a kategóriájukban a  30-40. helyet elérő eredmények születnek.\\nOSZTV versenyek: vegyipari ágazatban a technikum egyeduralkodó, itt az indítható négy versenyző általában az 1-6- helyezés valamelyikét hozza el.\\nA környezetvédelem ágazatban az indítható négy versenyző a 4-12. hely valamelyikén végez.", "mtmi_interdiszciplinaris_projekt_link1": "https://otio.hu/projektek_34.html", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_otlet_esszepalyazat_tanarok_szama": "2", "mtmi_rendezvenyek_reszvetel_bemutatasa": "Immáron negyedik alkalommal vett részt az iskola a Kutatók éjszakája rendezvényen, ahol négy különböző előadáson és workshopon vehettek részt a látogatók kémia, biológia és fizika témakörében.", "mtmi_tanulmányi_verseny_tanarok_szama": "23", "intezmenyvezeto_kapcsolattarto_beosztas": "igazgató", "mtmi_interdiszciplinaris_projekt_leiras": "Az utóbbi 6-7 esztendőben nagyon sok (15) ilyen kutatási és/vagy fejlesztési projekt indult el. Ezek színvonalát is tekintve a Környezetkutató csoport egyedülálló helyet képvisel az országban ( 9 OTDK és innOTDK részvétel, a NIÜ IMPULSE fejlesztési programban két projektünk szerepelt, az OTIO-n immár négy éve iskolaként a  legtöbb projektünk jutott  a második fordulóba.\\nA legutóbbiak röviden: \\nNUTRILITH-szárított szennyvíziszap talajjavító célú felhasználása\\nKomposztKazán - a komposztálódás folyamán keletkezett hő szabályozott felhasználása\\nAgrofotovoltaikus területek vízháztartása - a napelemparkok mezőgazdasági hasznosításának lehetőségei\\nKomplex levegőminőség elemző rendszer  (hosszabban)\\nA projekt célja, hogy a szállópor összetevők tekintetében számszerű adatokat szolgáltasson a közutak mentén termelődő mikroműanyag, illetve a nehézfém terhelés fajsúlyát tekintve, illetve speciális területeken megoldásokat javasoljon a probléma mértékének csökkentésére.\\n\\nMódszerek\\n•\\tNemzetközi összehasonlításra alkalmas szabványos mintavételezés - Sigma-2 \\n•\\tMennyiségi analízis manuális, illetve MI klasszifikáció által\\n•\\tMinőségi szemcseanalízis kontroll műszeres analitikával\\n•\\tMintavételezés és hatásvizsgálat eltérő forgalmi környezetekben\\n•\\tCsatolt folyamatos PM mérés saját fejlesztésű mérőeszközzel - Sigma Duo\\n•\\tTerjedésvizsgálat az AERMOD program segítségével\\n\\nEredmények\\n•\\tSpeciális aeroszol összetevők esetében megfelelő \\nműszeres analitikai kontroll mellett MI alapú\\nklasszifikáció (mikrogumi szemcsék, „blackpower”)\\n•\\tTöbbhónapos észlelési eredménysor különböző frekventált területeken\\n•\\tSaját fejlesztésű mérő- és mintavételező\\nállomás együttesének létrehozása -szabványelemekből építve\\n•\\tAz AERMOD modellező program eredményes használata tagolt területen\\n•\\tZajvédő falak növényesítése -hatásvizsgálat, műszaki tervek\\n\\nInnováció és felhasználhatóság\\nSaját fejlesztésű mobil, mérő- és mintavételezési eszköz, MI alapú szemcse klasszifikáció, megfelelő műszeres analitikai kontroll, \\n", "mtmi_palyaorientacio_megvalosulas_link1": "https://www.facebook.com/photo?fbid=1090917829491763&set=pcb.1090918446158368&locale=hu_HU", "mtmi_tovabbkepzesek_idokeret_megvalosul": "igen", "mtmi_tovabbkepzesi_programok_megvalosul": "igen", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "A technikum rendszerben nagy hangsúlyt kap a gyakorlati oktatás, mely során rengeteg laboratóriumi órája van a diákoknak minden évben, illetve külön projektórák. Ezek során a diákok különböző projektmódszerekkel ismerkedhetnek meg, csoportban dolgozhatnak, gyakorlati fejlődésükről folyamatos visszajelzést kapnak a szakoktatóktól.", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 30 620 0510", "mtmi_palyaorientacio_megvalosulas_leiras": " Iskolánk évek óta sikeresen megrendezi a pályaorientációs napját. Ezek általában a tanév novemberi, vagy decemberi heteiben kerülnek megrendezésre. Idén ez november 21-én lesz. \\nAz eseményen általában 6-8 egyetem akár több karral is, cégek és pályaválasztási szervezetek vannak jelen. Természetesen az iskola profiljához illeszkedően (környezetvédelem, vegyipar, informatika) kapnak tájékoztatást a 11-12-13. évfolyamokba járó diákjaink. Sok esetben az iskola korábbi diákjai jönnek vissza, hogy már az adott egyetem hallgatóiként adjanak információkat, személyes elemekkel tarkítva. \\n\\"MTMI\\" iskolaként tervezzük, hogy az érkező egyetemi vendégek számára mi is ismertetőt adunk a nálunk folyó ilyen jellegű tevékenységéről. A kapcsolati hálónk fejlesztésében, projektötleteink szakmai támogatásában, diákjaink későbbi egyetemi karrierjében kamatozódhat mindez.", "lanyoknak_szolo_mtmi_programok_bemutatasa": "Az iskola minden évben rész vesz a Lányok Napja pályaorientációs programokon, amiért az intézményben Szolnok Ádám igazgatóhelyettes felel.", "mtmi_egyuttmukodes_palyaorientacio_leiras": "A fentebb leírtak részletes választ adnak a feltett kérdésekre. A szakképzés területén ezek a napirendi pontok jelentős előrelépésen mentek át.", "mtmi_laboratoriumok_latogatasa_bemutatasa": "A Környezetkutató csoport projektjei többször is meglátogatják illetve tartják a kapcsolatot egyetemi kutatókkal, miközben a megvalósításon dolgoznak. Így a diákok már többször meglátogathatták a gödöllői Magyar Agrár- és Élettudományi Egyetem vagy a budapesti Eötvös Loránd Tudományegyetem laborjait. Ezen alkalmak során a laboratóriumokban esetleges mintafeldolgozás vagy mérés is megvalósult a projektekhez.", "mtmi_egyeb_palyaorientacios_programok_link1": "https://www.facebook.com/photo?fbid=1363171862266357&set=pcb.1363170778933132&locale=hu_HUhttps://www.facebook.com/photo/?fbid=1363171822266361&set=pcb.1363170778933132&locale=hu_HU", "mtmi_digitalis_eszkozok_megvalosul_bemutatasa": "Az iskola összes dolgozója és tanulója a Microsoft Teams keretein belül tartja a kapcsolatot, az online órákat. Több tanár is alkalmaz a digitális tananyagokat és teszteket.", "mtmi_digitalis_tananyagok_megvalosul_bemutatasa": "Nagy hangsúlyt fektet az iskola a digitális kompetenciákra, mind elméleti, mind gyakorlati szinten. A tanulók a különböző és sokszínű felületeket már 9. évfolyamtól kezdve használják, gyakorolnak velük. Több számonkérés is digitális formában valósul meg, hisz a 13. évfolyam végén a technikusi írásbeli vizsgarész is digitális formátumban történik.", "mtmi_korszeru_felszereltseg_megvalosul_bemutatasa": "Az iskola minden termében elérhető projektor és vászon, az idei évben felszerelve lett két darab digitális tábla is. ", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul": "nem", "mtmi_tovabbkepzesek_idokeret_megvalosul_bemutatasa": "Az iskola több oktatója minden évben részt vesz a szakmai ágazatához tartozó több konferencián is, amik a szakmai oktatásról, módszertanról szólnak, A Projektkonferencia eseményen, Erasmus+ konferenciák", "mtmi_tovabbkepzesi_programok_megvalosul_bemutatasa": "Az MTMI csoport az iskolába előtérbe helyezte az egymás közötti tapasztalat megosztást, egymásnak továbbképzések tartását.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul": "nem"}	2025-10-02 07:34:13.485788	2026-03-05 22:23:14.31867	1	a1046309-82d9-47df-815f-6bc946eb6fbf_Fenntarthat_s_gi_projektjeink.pdf	d6c5af31-43a2-4d7a-bf3b-d3245087e930
d95ea7dd-e982-4b17-8c9c-7d246fa65169	{"iskola_cime": "8000-Székesfehérvár, Zentai u. 8.", "iskolatipus": ["altalanos_iskola"], "gdpr_consent": ["on"], "szulo_bevonas": "megvalosul", "mtmi_koncepcio": "igen", "telepulesforma": "megyeszekhely_varos", "mtmi_nyilt_napok": "Iskolánkban Iskolahívogató fogalkozások alkalmával mutatjuk be a szülőknek és a leendő iskolásoknak a többi között  MTMI tevékenységünket és a felszereltségünket. Múlt évben volt lehetőségük a szülőknek nyílt órákra regisztrálni, amivel sokan éltek is. Ezek a nyílt órák lehetőséget biztosítottak arra, hogy bemutathassuk az alkalmazott pedagógiai módszereinket, felszerelésünket, a gyerekek órai munkáját. ", "szulo_egyeztetes": "megvalosul", "mtmi_csapat_link1": "https://www.zentai.hu/mtmi-iskola/mtmi-csapat/", "mtmi_projektnapok": "Az éves szokásos iskolai rendezvényünkön, a Zentais Héten minden három napon keresztül választanak a diákok felajánlott foglalkozásokból, amelyeket mindig igyekszünk úh szervezni, hogy legyen közöttük szakemberek által tartott foglalkozás, íhol kipóbálhatják a gyerekek az egyes szakma fortélyait. Volt így már könyvkötés, cukrászat, ékszerkészítés, kémiai/fizikai kísérletezés. A nyolcadik évfolyamos vizsgát is projektnapnak telintjük, mivel az elkészült munkáikat az egész évfolyam előtt mutatják be. ", "pedprog_mtmi_link1": "https://www.zentai.hu/dokumentumaink/pedagogiai-program/", "szulo_kommunikacio": "megvalosul", "iskola_honlap_link1": "https://www.zentai.hu/", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "7", "palyazo_iskola_neve": "Zentai Úti Általános Iskola", "pedprog_mtmi_leiras": "A NAT által meghatározott kerettantervek óraszámát a szabadon tervezhető órakeret terhére megemeljük a 6. évfolyamon heti 1 órával természettudomány és 7. valamint 8. évfolyamon heti 1-1- órával matematika tantárgyakból az MTMI célok elérése érdekében.  ", "mtmi_ceges_eloadasok": "igen", "mtmi_csapat_tag1_nev": "dr. Rosnerné Danner-Stipkovits Mónika", "mtmi_csapat_tag2_nev": "Bottka Rózsa", "mtmi_csapat_tag3_nev": "Baloghné Kuska Éva", "mtmi_csapat_tag4_nev": "Gálné Pék Eszter", "mtmi_csapat_tag5_nev": "Kovács Béla", "mtmi_csapat_tag6_nev": "Magyaródi Zsófia ", "mtmi_csapat_tag7_nev": "Dávid Gergely", "mtmi_koncepcio_link1": "https://www.zentai.hu/mtmi-iskola/mtmi-kuldetes/", "mtmi_szakkorok_link1": "https://www.zentai.hu/mtmi-iskola/mtmi-szakkorok/", "mtmi_szakkorok_szama": "10", "mtmi_szulo_kepviselo": "igen", "mtmi_alumni_programok": "igen", "mtmi_csapat_tag1_szak": ["digitalis_kultura", "egyeb"], "mtmi_csapat_tag2_szak": ["matematika", "fizika"], "mtmi_csapat_tag3_szak": ["matematika", "kemia"], "mtmi_csapat_tag4_szak": ["matematika", "egyeb"], "mtmi_csapat_tag5_szak": ["matematika", "technika"], "mtmi_csapat_tag6_szak": ["biologia", "termeszettudomany", "integralt_termeszettudomany"], "mtmi_csapat_tag7_szak": ["foldrajz", "egyeb"], "mtmi_csapat_tag8_szak": [], "mtmi_koncepcio_leiras": "A Zentai Úti Általános Iskola Pedagógiai programjának alapelve, hogy tanulóinkat a 21. század kihívásaihoz szükséges tudással, készségekkel és attitűdökkel vértezzük fel. E cél megvalósításának kulcsterülete az MTMI (matematikai, természettudományos, műszaki és informatikai) kompetenciák fejlesztése, melyek a tanulók problémamegoldó, rendszerszintű és kreatív gondolkodását alapozzák meg.\\n\\nAz iskola MTMI-koncepciójának célja, hogy a tanórai és tanórán kívüli tevékenységek során erősítse az MTMI-tárgyak iránti érdeklődést, javítsa a tanulók motivációját és teljesítményét, valamint támogassa a pályaorientációt a természettudományos és műszaki irányok felé. \\nBővebben a weboldalunkon olvasható a részletes koncepció.", "pedprog_mtmi_tartalom": "igen", "szulo_palyaorientacio": "megvalosul", "mtmi_fakultaciok_szama": "0", "mtmi_kapcsolatok_link1": "https://www.zentai.hu/palyaorientacios-nap/", "mtmi_kapcsolatok_link2": "https://www.zentai.hu/palyaorientacios-nap-2/", "mtmi_kapcsolatok_link3": "https://www.zentai.hu/palyaorientacios-nap-3/", "mtmi_kapcsolatok_link4": "https://www.zentai.hu/palyaorientacios-nap-4/", "mtmi_muzeumlatogatasok": "igen", "mtmi_nyilt_napok_link1": "https://www.zentai.hu/mtmi-iskola/mtmi-esemenyek/", "iskola_tanuloi_letszama": "412", "mtmi_szakkor_tantargyak": ["matematika", "biologia", "foldrajz", "digitalis_kultura", "kornyezetismeret", "termeszettudomany", "integralt_termeszettudomany", "technika"], "mtmi_szakmak_bemutatasa": "igen", "szulo_egyeztetes_szoveg": "Iskolánknál hangsúlyos, hogy a szülők ne csupán passzív befogadói legyenek az iskolai tevékenységeknek, hanem aktív partnerei az MTMI (matematikai, természettudományos, műszaki és informatikai) területeken megfogalmazott pedagógiai célok megvalósításának. A szülőkkel való egyeztetés több szinten és formában történik, rendszeres időközönként és célzott tartalommal.\\n\\nA formális kommunikációs csatornák közé tartoznak a félévente megtartott szülői értekezletek, ahol az MTMI-hoz kapcsolódó fejlesztési irányokról, tanórán kívüli lehetőségekről és eredményekről is tájékoztatást adunk. Emellett iskolánk weboldalán és közösségi média felületein rendszeresen osztunk meg információkat a kapcsolódó programokról, tanulmányi versenyekről, szakkörökről, illetve pályaorientációs eseményekről.\\n\\nA fentieken túl hangsúlyt fektetünk a közvetlen, személyes visszajelzésekre is, amelyeket a szülők informális formában – szóban, e-mailben vagy fogadóórákon – juttatnak el hozzánk. Tapasztalataink szerint ez a közvetlen kommunikáció hatékonyabb és mélyebb párbeszédet tesz lehetővé, mint a hagyományos kérdőíves felmérések. A szülői véleményeket, észrevételeket rendszeresen összesítjük, és azokat figyelembe vesszük a következő tanév MTMI-hoz kapcsolódó programjainak és tevékenységeinek tervezésekor.", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "igen", "mtmi_szakmai_gyakorlatok": "Pedagógusaink közül nyolcan vettek részt az Okosterem program részeként az Alba Innovár továbbképzésén (2023-24). Közülük  került kiválasztásra egy PeDig menedzser, akinek a pedagógusok szakmai továbbképéózésének szervezése, a szakmai gyakorlatok megvalósítása tartozott a feladatai közé. Intézményünkben havi rendszeressséggel valósultak meg workshopok, illetve a városban meghirdetett (POK, Alba Innovár) által szervezett szakmai rendezvényeken. A tudásmegosztás iskolánkon belül is működik, formális és informális módon. ", "mtmi_egyetemi_gyakorlatok": "nem", "mtmi_szakkor_diakok_szama": "174", "mtmi_szakkorok_bemutatasa": "A szakkör célja, hogy a gyerekek játékos formában sajátítsák el a sakk alapjait, miközben fejlődik logikai gondolkodásuk, koncentrációjuk és problémamegoldó képességük.\\nA Pénzügyi Hősképző szakkör játékos és élményszerű módon vezeti be a gyerekeket a pénz világába, fejlesztve pénzügyi tudatosságukat, tervezési készségüket és felelős döntéshozó képességüket.\\nA grafika szakkörön a gyerekek különféle rajz-és kézműves technikákkal ismerkedhetnek meg, miközben kreativitásukat és vizuális kifejezőképességüket fejlesztik.\\nA természetjárás szakkör célja, hogy a gyerekek játékos formában fedezzék fel a természet szépségeit, miközben környezettudatosságuk, megfigyelőképességük és fizikai állóképességük is fejlődik. \\nA Digikaland szakkör izgalmas felfedezéseken keresztül vezeti be a gyerekeket a digitális világ alapjaiba, fejlesztve informatikai ismereteiket, kreativitásukat és digitális problémamegoldó képességüket. \\nA csoport egy részével “A jövő városa” projektet készítjük el idén.\\nA diákok gyalogtúrákon vesznek részt, ahol megismerik a természetet és különböző kirándulóhelyeket. Emellett megtanulják a helyes túrafelszerelés használatát, a tájékozódás alapjait és a természetbarát viselkedést is.\\nA LÜK (Logika Ügyesség Kitartás) szakkör játékos  feladatokon keresztül \\nA Barkács szakkörön a gyerekek különféle anyagokkal és eszközökkel dolgozva fejleszthetik kézügyességüket, kreativitásukat és gyakorlati problémamegoldó képességüket.\\nA tervezés folyamatától eljutnak a megvalósításig  különböző eszközök használatával. \\nA Papírcsodák szakkörön a gyerekek változatos hajtogatási, vágási és ragasztási technikákkal készítenek kreatív alkotásokat, miközben fejlődik finommotorikájuk és kézügyességük. \\nA szakkör résztvevői különféle gyöngyökből ékszereket, dísztárgyakat készítenek. Különböző fűzési technikákat tanulnak meg, miközben fejlesztik a kézügyességüket és a kreativitásukat.\\n\\n", "szulo_munkakoz_ismertetes": "megvalosul", "mtmi_ceges_eloadasok_link1": "https://www.zentai.hu/fenntarthtosagi-temahet/", "mtmi_szakkor_tanarok_szama": "12", "iskola_mtmi_tanari_letszama": "10+", "mtmi_alumni_programok_link1": "https://www.zentai.hu/palyaorientacios-nap/", "mtmi_alumni_programok_link2": "https://www.zentai.hu/palyaorientacios-nap-4/", "mtmi_alumni_programok_link3": "https://www.zentai.hu/palyaorientacios-nap-2/", "mtmi_alumni_programok_link4": "https://www.zentai.hu/palyaorientacios-nap-3/", "mtmi_diakok_kapcsolattartas": "igen", "mtmi_egyeb_partnerprogramok": "A tanév során folyamatosan figyeljük a felmerülő programlehetőségeket, így az MTMI-hez kapcsolódóakat is. Amennyiben lehetőségünk nyílik rá, akkor beleillesztjük a tanévbe, ha nem, akkor betervezzük a következő éves munkatervbe (pl. utazó planetárium)", "mtmi_kapcsolatok_bemutatasa": "A környezetünkben lévő Howmet, Kynrdyl és Grundfos cégekkel szorosan együttműködünk, valamint gyárlátogatásokat szervezünk. A cégek tárgyi támogatást is nyújtanak , amelyek némelyike igényünk szerint az MTMI irány segíti (társasjátékok), melyekkel az általános iskolás korcsoportnál játékos módon lehet a partnerek által megfogalmazott kompetenciákat fejleszteni. Ilyenek az együttműködés, csoportmunka, kritikus gondolkodás, kommunikáció és tudásmegosztás. A Fejér Megyei Kereskedelmi és Iparkamarával  és a Szakképzési Centrummal együttműködve szervezzük a Pályaorientációs kirándulásainkat minden évben. Meglátogatjuk a Szakmák Utcája rendezvényt, ami Székesfehérvár Fő utcáján található. Fenntartunk kapcsolatokat további szervezetekkel, vállalkozókkal, akikkel szakmai szervezetek bevonása nélkül, a személyes kapcsolatra való tekintettel tudunk programokat szervezni. Így a tűzoltótól kezdve az állatorvoson át az asztalos vállalkozóig sokféle területtel tudnak megismerkedni a tanulók. A szülői kapcsolatok sokkal személyesebbé tudják tenni a látogatásokat, a gyerekek szívesen látják a mindennapokból ismert apukát/anyukát munkahelyi környezetben.", "mtmi_online_palyaorientacio": "igen", "mtmi_rendezvenyek_reszvetel": "igen", "lanyok_mtmi_kiemelt_figyelem": "igen", "mtmi_alumni_programok_leiras": "Általános iskolaként nincsenek rendszeres alumni rendezvényeink, vagy szervezetünk. Viszont szép számmal hozzák vissza gyermekeiket a volt zentais szülők, így tulajdonképpen a velük való kapcsolat megmarad. Számon tartjuk, milyen ágazatban, pozícióban tevékenykednek és szívesen segítenek, ha továbbtanulási témában előadásra kérjük fel őket, vagy foglalkozásra van szükségünk.", "mtmi_csapat_tag1_tevekenyseg": "Digitális kultúra tantárgyat oktató pedagógusként, valamint PeDig menedzserként kiemelt figyelmet fordítok az IKT-eszközök, oktatási alkalmazások és digitális megoldások fejlődésére. Folyamatosan követem az újonnan megjelenő platformokat, szoftvereket, és ezekről rendszeresen tájékoztatom az érintett kollégákat. Webináriu,okat hallgatok, igény esetén belső továbbképzéseket is tartok az alkalmazások hatékony pedagógiai használatáról.\\n\\nA tantárgyhoz kapcsolódó számonkérések során előnyben részesítem az olyan tantárgyközi projektfeladatokat, amelyek során az adott témakör feldolgozása más tantárgy(ak) tananyagával is összekapcsolható. A feladatokat előzetesen egyeztetem az érintett szaktanárokkal, hogy tartalmilag és időzítés szempontjából is illeszkedjenek a többi tantárgy tematikájához. Az így létrejövő komplex produktumok – pl. digitális poszterek, prezentációk, videók, weboldalak – több tantárgyban is értékelhetők, így segítik a tanulók rendszerszintű gondolkodásának fejlődését.\\n\\nTanulmányi versenyek szervezése és tanulók kiválasztása esetén szintén együttműködöm a kollégákkal: kikérem véleményüket az indulásra javasolt tanulók alkalmasságáról, hogy a döntés közös pedagógiai megítélésen alapuljon.", "mtmi_csapat_tag2_tevekenyseg": "Matematika – fizika szakos tanár vagyok, a Zentai Úti Általános Iskola igazgatója. A pedagóguspályán töltött 30 évem alatt egyre tudatosabb igyekszem minél több olyan rendezvényre elvinni a tanulókat, ahol MTMI készségeket, kompetenciákat használó emberekkel ismerkedhetnek meg. Rendszeres látogatói vagyunk a Kutatók Éjszakájának akár Budapesten, akár Székesfehérváron. Itt a diákok nemcsak kutatókkal, de főiskolai, egyetemi hallgatókkal is megismerkedhetnek, illetve a legújabb innovációkkal is találkozhatnak. A Nők a Tudományban Egyesület programjain, az Alba Innovár foglalkozásain is részt veszünk azzal a céllal, hogy a munkaerőpiac igényeihez igazodva minél több lány válassza a mérnöki pályát. Szeretném, ha tanítványaim olyan szakmát választanának, amelyben később könnyen el tudnak majd helyezkedni. Három felnőtt mérnök édesanyjaként személyes példamutatással is próbálom őket a természettudományok és a matematika felé terelgetni, érdeklődésüket felkelteni, és igyekszem az alapokat az általános iskolában megtanítani. Büszke vagyok rá, hogy több tanítványom jól boldogul az életben műszaki pályán, sikeres volt a pályaorientációjuk.", "mtmi_csapat_tag3_tevekenyseg": "Fontosnak tartom, hogy környezettudatos, környezetért felelős diákok hagyják el az iskolánkat, továbbá, hogy a gyerekek észrevegyék és alkalmazni tudják a tantárgyak közötti összefüggéseket. A magolást, az értelmetlen tanulást felváltsa a logikus, értve tanulás. Tanóráimon lehetőséget adok tanítványaimnak, hogy ők maguk tapasztaljanak meg dolgokat. Kísérletezzenek bátran, kísérletező délelőttjeinken 20-25 diák mutat be kísérleteket kémiából, fizikából.\\n", "mtmi_csapat_tag4_tevekenyseg": "Szeretem összekapcsolni a két tantárgyat a közös területeken keresztül, mint például az aranymetszés, az arányok, az axonometria. Előszeretettel használok ábrákat, rajzokat a matematika tanításában is. Fontosnak tartom a természettudományok megszerettetését, a matematika gyakorlati alkalmazását a hétköznapi életben, más tantárgyakban is. \\n", "mtmi_csapat_tag5_tevekenyseg": " Nevelő-oktató pedagógusnak tartom magam, és arra törekszem, hogy munkámban a pedagógus-gyermek kapcsolatot kölcsönös tisztelet és pozitív érzelmi töltés jellemezze. Célom minél több diákkal megszerettetni a matematikát, mindig a következő lépcsőfok megtételére koncentrálva.", "mtmi_csapat_tag6_tevekenyseg": "Első és második tanári diplomámat is az ELTE-n szereztem, először biológia-olasz szakot, 2025-ben pedig természettudomány-környezettan szakot végeztem. A közoktatásban 9. éve dolgozom. Gyermekkorom óta kísér a természet szeretete és a megértése iránti igény, munkám során is ezt célom továbbadni.", "mtmi_csapat_tag7_tevekenyseg": "Mindig is hajtott, hogy a diákoknak megmutassam a természet szépségét, sokszínűségét, változatosságát. Túraszakkört vezetek 6 éve, melynek célja, hogy a diákok saját tapasztalatukon keresztül fedezzék fel szűkebb, majd egyre tágabb természeti környezetüket. A túráknál is mindig tervezés  előzi  meg a kivitelezést ugyanúgy, mint barkácsszakkörön, ahol alsótagozatos gyerekekkel fúrunk-faragunk.  Idén földrajztanári diplomát szerzek az ELTE TTK-on.", "mtmi_muzeumlatogatasok_link1": "https://www.zentai.hu/6986-2/", "mtmi_aktiv_tanulas_megvalosul": "igen", "mtmi_csapat_kozos_tevekenyseg": "A Zentai úti Általános Iskola MTMI csapatának célja, hogy a tanulók logikus gondolkodását, problémamegoldó képességét és digitalis tudását fejlesztve felkeltse érdeklődésüket a természettudományos és műszaki pályák iránt. \\nAz MTMI (matematika, természettudományok, műszaki és informatika) területek fejlesztése az iskolában – tantárgyközi együttműködés elősegítése a tanításban.\\nTanulók természettudományos, műszaki és informatikai érdeklődésének felkeltése és fejlesztése – motiváló, élményalapú tevékenységek szervezése.\\nInnovatív módszerek és eszközök bevezetése – korszerű pedagógiai és digitális eszközök alkalmazása a tanulás-tanítás folyamatában.\\nTanórán kívüli programok közös megtervezése és megvalósítása – pl. témanapok, versenyek, szakkörök, projektek, pályaorientációs programok.\\nProjektek és pályázatok előkészítése és lebonyolítása – együttműködés pályázati lehetőségek kihasználásában, projektfeladatok megvalósításában.\\nSzakmai együttműködés és tapasztalatcsere – egymás segítése, jó gyakorlatok megosztása, belső továbbképzések szervezése.\\nAz iskolai MTMI stratégia megvalósításának támogatása – közös célok kitűzése és elérése a vezetés által meghatározott irányok mentén.\\nTanulói tehetséggondozás és felzárkóztatás támogatása – differenciált foglalkozások, egyéni fejlesztési lehetőségek kidolgozása.\\nKapcsolattartás a szülőkkel és a közösséggel – MTMI programok, események, bemutatók szervezése a nyilvánosság számára.\\nAz MTMI-felelős munkájának támogatása – együttműködés a szervezési és adminisztratív feladatokban, közös tervezés és értékelés.", "mtmi_fakultaciok_diakok_szama": "0", "mtmi_kiallitoterek_megvalosul": "igen", "lanyoknak_szolo_mtmi_programok": "igen", "mtmi_egyeb_tevekenysegek_szama": "50", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_kutatási_versenyek_link1": "https://www.zentai.hu/kalandozas-a-tudomanyok-vilagaban-megyei-vetelkedo/", "mtmi_kutatási_versenyek_link2": "https://www.zentai.hu/kalandozas-a-termeszettudomanyok-birodalmaban/", "mtmi_kutatási_versenyek_link3": "https://www.zentai.hu/megyei-termeszettudomanyi-versenyt-nyertunk/", "mtmi_kutatási_versenyek_link4": "https://www.zentai.hu/kalandozas-a-termeszettudomany-birodalmaban/", "mtmi_kutatási_versenyek_szama": "1", "mtmi_laboratoriumok_latogatasa": "igen", "mtmi_otlet_esszepalyazat_szama": "2", "intezmenytipus_tanuloi_letszama": "412", "mtmi_ceges_eloadasok_bemutatasa": "Csonka Krisztina, a Karsai Műanyag Holding munkatársa (és egykori tanulónk édesanyja) évek óta tart előadást tanulóinknak a Fenntarthatósági témahétre szervezett programjaink között.", "mtmi_faliujsag_vitrin_reszvetel": "igen", "mtmi_palyaorientacio_megvalosul": "igen", "lanyok_mtmi_reszvetel_bemutatasa": "Az idei tanévben a Grundfosból érkező fiatal mérnökhölgy fog előadást tartani a műszaki pályáról. A diákok így közvetlenül tudnak kérdéseikre válaszokat kapni egy hozzájuk korban is közel álló személytől.", "mtmi_faliujsag_vitrin_bemutatasa": "Az iskola aulájában lévő faliújságon mindig olvashatóak az aktuális vesenyfelhívások, illetve a szaktanárok a szaktantermekben is ki szokták függeszteni azokat. Az aulában lévő vitrines polcokon a sporttrófeák mellett helyet kapnak az MTMI versenyen kapott kupák, bár jellemzően nem azt nyernek a gyerekek, az okleveleiket pedig hazaviszik. Vándorkupa (Kossuth Kupa - matematikaverseny) már volt a szekrényben, de értelemszerűen következő évben továbbadtuk. Terveinkben szerepel egy album, amelybe az oklevelek másolataik gyűjtjük, hogy visszanézhetőek legyenek. Ez fontos a vállalkozó kedvű diákok motiválásában is. Ugyanezt digitalizálva fel lehetne tölteni a weboldalra is.", "mtmi_felelos_kapcsolattarto_neve": "dr. Rosnerné Danner-Stipkovits Mónika", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "igen", "mtmi_tanoran_kivuli_rendezvenyek": "Az Alba Innovár Élményközpontba rendszeresen visszük az 5., 7. évfolyamos tanulókat osztályos foglalkozásokra, ahol MTMI tematikájú  órákat tartanak. Többen járnak iskolánkból a délutáni szakköreikre és idén a saját szakköröseinkkel beneveztünk a meghirdetett MTMI versenyükre is. ", "mtmi_tanulmányi_versenyek_link1": "https://www.zentai.hu/", "mtmi_tanulmányi_versenyek_link2": "https://www.zentai.hu/5253-2/", "mtmi_tanulmányi_versenyek_szama": "16", "mtmi_muzeumlatogatasok_bemutatasa": "Az osztálykirándulások szervezésekor kiemelt figyelmet fordítunk arra, hogy a tanulmányi cél és az élményszerzés egybekapcsolódjon. A múzeumlátogatások alkalmával visszakapcsolunk az eddig megszerzett tantárgyi ismeretekre, hogy az elméleti tudás gyakolati megvalósulását megtapasztalhassák. Természetesen a korosztályos érdeklődésnek megfelelő témájú múzeumlátogatásokat terveztünk. \\nAz idei tanév szeptemberében alsó tagozatosaink többek között jártak a Természettudományi Múzeumban, az agárdi Rönkvárban, a dinnyési Várparkban illetve vízi testnevelés órán Sukorón. A felsősök nagyrészt Budapestet vették célba, a Csodák palotáját, a Mezőgazdasági Múzeumot, a Vasarely Múzeumot, az Illúziók Múzeumát, az Elte Természettudományi Múzeumát és az érdi Földrajzi Múzeumot.", "mtmi_online_palyaorientacio_link1": "https://www.zentai.hu/tovabbtanulas/", "mtmi_rendezvenyek_reszvetel_link1": "https://www.zentai.hu/kutatok-ejszakaja/", "programban_erintett_tanulok_szama": "359", "mtmi_diakok_kapcsolattartas_leiras": "Pályaorientációs nap keretén belül minden évfolyam ismerkedik a különböző szakmákkal, foglalkozások, előadások, vagy gyárlátogatás formájában. A Fejér Vármegyei POK bevonásával szervezünk a gyermekeknek 7-8. évfolyamon önismereti, kommunikációs tréninget és pályaválasztási foglalkozást. ", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyeb_tovabbkepzesi_programok": "\\"A jövő városa\\" projekt keretében megkapott eszközpark használatához külön workshopot szerveztünk a tantestület számára az Alba Innovár oktatóinak bevonásával, amelyet több tovűbbi is követett. Így a lézervágást már több kolléga is használja  pedagógiai gyakorlatában, eszközök legyártásában, amelyeket az órákon fog használni.\\nElőző évben a programlehetőséget egymásnak ajánlva a tantestület egyharmada vett részt Mérő László MI-ről szóló előadásán - jellemző ránk az iskolán kívüli együttműködés és érdeklődés is a kollégák között. ", "mtmi_egyuttmukodes_palyaorientacio": "igen", "mtmi_felelos_kapcsolattarto_email1": "rosnerne.monika@zentai.hu", "mtmi_online_palyaorientacio_leiras": "Az Oktakási Hivatal https://merretovabb.oktatas.hu oldalon elérhető kérdőívét minden nyolcadik évfolyamos diák kitölti. Az eredményt, az ismeretlen fogalmakat közösen is megbeszéljük. További kérdések és igény esetén a pályaorientációs napon szakirányú foglalkozásokat szervezünk a diákoknak. A honlapon is feltüntetjük, milyen mérési felületet használunk. ", "mtmi_otlet_esszepalyazat_reszvetel": "igen", "mtmi_tanulmányi_verseny_reszvetel": "igen", "mtmi_tovabbkepzesi_programok_link1": "https://www.canva.com/design/DAGcXqAHUxE/16ClFdLSeBYOZCHJPyKNAA/edit?utm_content=DAGcXqAHUxE&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton", "intezmenyvezeto_kapcsolattarto_neve": "Bottka Rózsa", "lanyok_mtmi_nepszerusito_bemutatasa": "Ezen a területen meg kell fogalmaznunk célkitűzéseket, mivel nem voltak nagy számban csak lányoknak hirdetett programjaink. Kis létszámú iskolaként meg tudtuk eddig valósítani az egyéni odafigyelés által a személyre szabott pályaorientációs támogatást, így nem éreztük a hiányát a külön lányoknak szóló MTMI programoknak. A versenyek való részvételi arányon sem vesszük észre, hogy kevesebb lány indulna MTMI tárgyú megmérettetésen. Ezt betudhatjuk annak is, hogy az MTMI tárgyak tanárai közt is sok nő van. ", "mtmi_kutatási_versenyek_bemutatasa": "A Székesfehérvári Pedagógiai Oktatási Központ évek óta megrendezi a hetedik osztályos tanulók komplex csapatversenyét Kalandozás a Természettudomány Birodalmában névvel. Ezen a versenyen 2022-ben iskolánk (lány)csapata megyei második helyezést ért el. 2023-ban (fiú)csapatunk megnyerte a megyei döntőt. 2024-ben két csapattal is indultunk, (lány)csapatunk a második helyezést érte el. 2025-ben már három csapattal is indultunk, a döntőbe bejutottunk és csak pár ponttal maradtunk le a dobogós eredményről. Az eredményekből látszik, hogy iskolánka tanulói szívesen foglalkoznak természettudományos tárgyakkal, a lányok is kiemelkedő tudásról tesznek tanúbizonyságot. ", "mtmi_otlet_esszepalyazat_bemutatasa": "Richter TETT Mesepályázaton vesz részt iskolánk két tanulója, valamint Hullajó! - fenntarthatósági kreatív projektversenyt hirdetünk saját szervezésben, az idei évben először.", "mtmi_digitalis_tananyagok_megvalosul": "igen", "mtmi_felelos_kapcsolattarto_beosztas": "tanár", "mtmi_kutatási_verseny_tanarok_szama": "1", "intezmenyvezeto_kapcsolattarto_email1": "bottka.rozsa@zentai.hu", "mtmi_egyeb_palyaorientacios_programok": "Iskolánk szellemisége miatt (segítünk minden gyermeknek megtalálni az útját) minden programon jelen van a lehetőség, hogy egy-egy tanuló érdeklődését felkeltsük az MTMI pályák iránt. Figyelni szoktunk az osztálykirándulások szervezésekor is arra, hogy élvezetes formában találkozzanak a különböző szakmákkal. Azok képviselőivel, művelőivel közvetlenül kapcsolatba kerülhessenek, kérdezhessenek.  ", "mtmi_tanulmányi_verseny_diakok_szama": "200", "mtmi_tanulmányi_versenyek_bemutatasa": "AMV mat. versenyen megyei\\t3. helyezés,  Kodály Iskola által Báránybőrbe bújt farkas cínű  kiírt megyei rajzversenyen 2. helyezés, különdíj, Kodály Z. Ált. Is.k által kiírt \\"Az éden bánata\\" című rajzversenyen 2. helyezés, különdíj, Munkácsy-pályázaton hat tanulónk díjazott lett. Víz világnapi csapatverseny 2. helyezés, BitHÓDító verseny - 204 pont 4.hely,  196 pont 6.hely, 192 pont 7.hely, 192 pont 7.hely, 188 pont 9.hely, 184 pont 10.hely. Tóvárosi logikai kódfejtő bajnokság, 2 csapat indult 4. hely, Zrínyi Ilona matematika verseny vármegyei forduló (7.évf.) V. helyezés,  (5. évfolyam) 4 fő megyeire bejutott, (6. évfolyam) 3 fő megyeire bejutott, (2.évf.) megyei 2.hely, országos 63. hely, Országos Böngész levelező matematikaverseny(2.évf.) 8.hely, Kalandozás a Természettudomány birodalmában 4., 5., 8.hely, Városi fizikaverseny 2., 10. hely, Magyar Egészségügyi Szakdolgozói Kamara Fejér Vármegyei Területi Szervezetének Pályaválasztás 2025. 6x3-as játék pályázata: 1.hely\\nIdei évre tervezett versenyk a fentieken kívül: Közös Jövőnk Kárpát-medencei Környezetvédelmi Verseny, csapatverseny (7-8. évf.), online\\nSzabó Szabolcs Természettudományos Vándorkupa, csapatverseny (7-8. évf.)\\nKaán Károly Országos Természet- és Környezetismereti verseny (5-6. évf.)\\nVíz Világnapi Környezetvédelmi Verseny, csapatverseny (5-6. évf)", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_otlet_esszepalyazat_tanarok_szama": "3", "mtmi_rendezvenyek_reszvetel_bemutatasa": "A hetedik évfolyamosokkal a Mathias Corvinus Collegiumban vettünk részt fiatal kutatóhölgyek által tartott előadásokon, a nyolcadik évfolyamosok az ELTE TTK programját látogatták meg, ahol tudományos kísérletekben vehettek részt.", "mtmi_tanulmányi_verseny_tanarok_szama": "14", "intezmenyvezeto_kapcsolattarto_beosztas": "igazgató", "mtmi_interdiszciplinaris_projekt_leiras": "A 8. évfolyamos tanulók számára bevezetett projektvizsga a tantárgyi tudás integrált, élményszerű feldolgozását biztosítja, amely során a tanulók önállóan, párosan vagy háromfős csoportokban dolgoznak egy választott témán. A folyamat minden szakasza – a témaválasztástól a produktum bemutatásáig – a tanulói aktivitásra, kutatásra, kísérletezésre és kreatív problémamegoldásra épül.\\n\\nA pedagógiai cél, hogy a diákok aktív szereplőivé váljanak a tanulási folyamatnak: ők tervezik meg a feladataikat, gyűjtik az adatokat, készítik el és mutatják be produktumaikat. A projektvizsga nemcsak vizsga, hanem folyamatos tanulási folyamat, amely fejleszti a tanulók együttműködési, digitális, kommunikációs és innovációs kompetenciáit.\\n\\nA módszertan középpontjában az interaktivitás és a tanulói autonómia áll. A diákok szabadon választhatják a témát, a feldolgozás módját és a produktum formáját (pl. modell, játék, digitális prezentáció, videó). A munka során aktívan használják a digitális eszközöket és platformokat (pl. prezentációkészítés, online kvíz, videós tartalom), ami illeszkedik az MTMI-pályázat digitális tanulási céljaihoz.\\n\\nAz értékelés fejlődésközpontú és több szintű. A tanulók a projektmunka folyamata és az elkészült produktum alapján is értékelést kapnak, két tantárgyi érdemjeggyel (fő és kapcsolódó tantárgy). Az értékelő lapok lehetőséget biztosítanak a tanulói önreflexióra és a pedagógusok folyamatos, támogató visszajelzésére, amely irányt mutat a további fejlődéshez.\\n\\nA program sikerének kulcsa, hogy a projektvizsga nem egyszeri esemény, hanem az iskola pedagógiai kultúrájának része, amelyben a tanulás középpontjában a felfedezés, az együttműködés és az alkotás öröme áll – teljes összhangban az MTMI-pályázat aktív tanulást és kompetenciafejlesztést célzó elvárásaival.", "mtmi_palyaorientacio_megvalosulas_link1": "https://www.zentai.hu/nyilt-napok/", "mtmi_tovabbkepzesek_idokeret_megvalosul": "igen", "mtmi_tovabbkepzesi_programok_megvalosul": "igen", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "Iskolánkban az évek során a gyerekeknek többször van alkalmuk tantárgyközi projektek készítésére, amelyeket hol egyéni, hol csoportos feladatként kapnak(pl. Állatok Világnapja Projekt), a nyolcadik évfolyamos tanulók számára bevezetett projektvizsga a tantárgyi tudás integrált, élményszerű feldolgozását biztosítja. Ők 2-3 fős csoportokban dolgoznak egy választott témán. A folyamat minden szakasza – a témaválasztástól a produktum bemutatásáig – a tanulói aktivitásra, kutatásra, kísérletezésre és kreatív problémamegoldásra épül. A pedagógiai cél, hogy a diákok aktív szereplőivé váljanak a tanulási folyamatnak: mentortanáraik támogatásával tervezik meg a feladataikat, gyűjtik az adatokat, készítik el és mutatják be produktumaikat. A projektvizsga nemcsak vizsga, hanem folyamatos tanulási folyamat, amely fejleszti a tanulók együttműködési, digitális, kommunikációs és innovációs kompetenciáit. \\nA módszertan középpontjában az interaktivitás és a tanulói autonómia áll. A diákok szabadon választhatnak a tanárok által felkínált témákból, vagy saját ötletet hozhatnak. A feldolgozás módjáról és a produktum formájáról (pl. modell, játék, digitális prezentáció, videó) is szabadon dönthetnek. A munka során aktívan használják a digitális eszközöket és platformokat (pl. prezentációkészítés, online kvíz, videós tartalom). Az értékelés fejlődésközpontú és több szintű. A tanulók a projektmunka folyamata és az elkészült produktum alapján is értékelést kapnak, két tantárgyi érdemjeggyel (fő és kapcsolódó tantárgy). Az értékelő lapok lehetőséget biztosítanak a tanulói önreflexióra és a pedagógusok folyamatos, támogató visszajelzésére, amely irányt mutat a további fejlődéshez. A program sikerének kulcsa, hogy a projektvizsga nem egyszeri esemény, hanem az iskola pedagógiai kultúrájának része, amelyben a tanulás középpontjában a felfedezés, az együttműködés és az alkotás öröme áll – teljes összhangban az MTMI-pályázat aktív tanulást és kompetenciafejlesztést célzó elvárásaival. ", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 30 218 0066", "mtmi_kiallitoterek_megvalosul_bemutatasa": "Vannak állandó és időszakos kiállításaink. Mivel kevés a helyünk, így az Alulában lévő vitrines szekrényben találhatók az MTMI-vel kapcsolatos eredmények, a faliújságon pedig az elkészült projektmunkák láthatóak időszakosan. Egyik termünkben (biológia-földrajz terem) folyamatosan kikerülnek a faliújságra az aktuális projektek, az éves Zentais Gálán pedig az egész iskola munkáiból rendezünk látványos kiállítást, ahol évfolyamonként, minden tantárgy és szakkör legszebb produktumait lehet megcsodáni, a vásárra készült termékeket pedig megvásárolni. ", "mtmi_palyaorientacio_megvalosulas_leiras": "A Fejér Vármegyei Kereskedelmi és Iparkamara szakmabemutatóin diákjaink megismerik a különböző műszaki, informatikai és természettudományos hivatásokat, illetve a hozzájuk vezető képzési utakat. A Grundfos és a Hydro gyárlátogatásai során a tanulók betekintést nyernek a modern ipari technológiák, automatizálás és fenntartható gyártási folyamatok működésébe.\\n\\nA Karsai Holding fenntarthatósági bemutatóin a diákok környezetbarát ipari megoldásokat és újrahasznosítási technológiákat ismernek meg, míg a Fejér Vármegyei Szent György Kórház Skyll laborjában az orvostudomány és a természettudományos kutatás kapcsolódási pontjai kerülnek előtérbe. A Fejér Vármegyei Katasztrófavédelmi Igazgatóság tűzoltósági látogatása során pedig a biztonságtechnikai, kémiai és fizikai ismeretek gyakorlati alkalmazását tapasztalhatják meg.\\n\\nEzek az együttműködések segítik a tanulók pályaorientációját, motivációját és tudatos jövőtervezését, valamint erősítik az MTMI-területekhez való kötődésüket a valós életbeli tapasztalatokon keresztül, folyamatos egyeztetében vagyunk a POK, a Kamara és a Szakképzési Centrum rendezvényeiről, hogy diánkjaink számára minél több tájékoztatási lehetőséget kapjanak. Az iskolák által hozzánk eljuttatott tájékoztatóit közzétesszük a honlapunkon.", "lanyoknak_szolo_mtmi_programok_bemutatasa": "Lányok napja alkalmából szervezett a Grundfos gyárlátogtást, ahova a hetedik évfolyam lány tanulói látogattak el. ", "mtmi_egyuttmukodes_palyaorientacio_leiras": "Pályaválasztásban érdekelt felekkel pályaorientációs napok előtt felvesszük a kapcsolatot közvetlenül, vagy a Fejér Megyei Kereskedelmi- és Iparkamarán keresztül, valamint a POK és a Szakképzési Centrum munkatársaival egyeztetve. A pályaorintációs napi kirándulások az egész iskolát érintik, de a hetedik-nyolcadik évfolyamon komolyabb hangsúlyt fektetünk a diákok folyamatos tájékoztatására. AZ önismereti tréningtől kezdve a Szakmák utcáján át a személyes mentorálásig sokféle módon segítjük a továbbtanulásukat.", "mtmi_laboratoriumok_latogatasa_bemutatasa": "ELőző évben voltunk a Synlab székesfehérvári Egyetemi oktatókórház laborlátogatásán. \\nIdén a Lauder Javne Iskolában teszünk laborlátogatást a nyolcadik évfolyammal (Napfoltvizsgálattal) - 2026.02.24- re tervezve", "intezmenyvezeto_kapcsolattarto_telefonszam1": "+36 20 532 0376", "mtmi_egyeb_palyaorientacios_programok_link1": "https://www.zentai.hu/tovabbtanulas/", "mtmi_digitalis_eszkozok_megvalosul_bemutatasa": "Az iskola informatikai infrastruktúrája – okosterem, interaktív táblák, projektorok, tanulói laptopok, tabletek és internet-hozzáférés – lehetővé teszi a modern, szemléltető és interaktív tanulásszervezést.\\n\\nAz MTMI tanárgyak óráin a tanulók online tanulási platformokat (pl. GeoGebra, Wordwall, Redmenta, Kahoot, LearningApps) használnak az ismeretek gyakorlására és önellenőrzésre. A kísérletezéshez és mérésekhez digitális szimulációk, videók és adatgyűjtő eszközök segítik a megértést. \\nA tanulói projektekben gyakran megjelenik a programozás, robotika és digitális alkotás (pl. Scratch, micro:bit, Lego Education), melyek fejlesztik a logikus gondolkodást, a problémamegoldó képességet és az együttműködést. A tanárok a digitális tananyagokat Google Classroom vagy KRÉTA Digitális Kollaborációs Tér felületeken osztják meg, ezzel támogatva a hibrid és differenciált tanulási formákat.", "mtmi_digitalis_tananyagok_megvalosul_bemutatasa": "Az MTMI tanárgyak óráin a tanulók online tanulási platformokat (pl. GeoGebra, Wordwall, Redmenta, Kahoot, LearningApps) használnak az ismeretek gyakorlására és önellenőrzésre. A kísérletezéshez és mérésekhez digitális szimulációk, videók és adatgyűjtő eszközök segítik a megértést. A tanárok a digitális tananyagokat Google Classroom vagy KRÉTA Digitális Kollaborációs Tér felületeken osztják meg, ahol a számonkérés is megoldható online formában. \\nDigitális kultúra tantárgyból a felsősök mindegyike részt vesz a bitHÓDítás versenyen, amely jól alapoz a kompetenciamérésre és matematikából idén az ötödikesek MaTalent mérést próbáltak ki.", "mtmi_korszeru_felszereltseg_megvalosul_bemutatasa": "2022. A HOWMET-KÖFÉM Kft. pályázatán nyert 40.000 dollárt okosterem berendezésére és pedagógusok képzésére fordítottuk. Harminc új egyszemélyes paddal és székkel gazdagodtunk, amelyek könnyen mozgathatók, így a tanteremben pillanatok alatt lehet csoportmunkáról kiscsoportosra, vagy páros munkára váltani. Beszereztünk egy aktív panelt, harminc darab tabletet, nyolc darab Lego robotot, egy 3D-s nyomtatót, tíz laptopot, hat programozható kisautót (Indi Sphero). Novembertől a tanév végéig nyolc pedagógus szerzett az új eszközök használatában jártasságot az Alba Innovár oktatóitól, tudásukat a következő években workshopokon adják át kollégáiknak. Az „egymástól való tanulás” lehetőségét, a belső tudásmegosztást eddig is eredményesen alkalmaztuk iskolánkban. Okostermünkben megvalósítható a csoportmunka, a komplex problémamegoldás, a játékosítás, az azonnali visszajelzés, a motiváció növelése, a differenciálás modern eszközökkel. Az okosterem létrejöttét a Howmet-Köfém Kft- nek az Alba Innovár Digitális Élményközpontnak köszönhetjük, valamint a Székesfehérvári Tankerületi Központnak, amely a beruházást a tanterem festésével és a padlóburkolat felújításával támogatta.\\n2024- újabb tanulói laptopokkal és okostáblákkal gazdagodtunk.\\n2025- Iskolánk Alapítványa is támogatta eszközbeszerzéseinket, laptopok, tabletek és okostábla köszönhető nekik. Ebben az évben a Tankerülettől \\"A jövő városa\\" Maker's Red Box-os tananagycsomagot kaptuk meg a megvalósításhoz szükséges eszközparkkal együtt. 3D nyomtatók, lézervágó, micro:bitek, forrasztóállomások és további eszközök állnak rendelkezésünkre, hogy a gyerekek kipróbálhassák a fantáziájukban megszületett tárgyak tervezését és létrehozását. ", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul": "igen", "mtmi_tovabbkepzesek_idokeret_megvalosul_bemutatasa": "Az iskola vezetősége tudatosan biztosítja, hogy a pedagógusok számára megfelelő keretek álljanak rendelkezésre az MTMI-területekkel kapcsolatos szakmai fejlődéshez. Ennek keretében a pedagógusok részt vehetnek továbbképzéseken és nemzetközi konferenciákon, miközben a tantestület munkája úgy szervezett, hogy a részvételhez szükséges idő- és helyettesítési lehetőségeket igyekeznek biztosítani. Ezáltal az intézmény folyamatosan frissíti módszertani repertoárját, erősíti a digitális és STEM-kompetenciákat. Kollégáink közül volt, aki az Okosterem programról tartott előadást a MMO XXX. konferencián, vagy publikációja jelent meg a 3D tervezés oktatási célú alkalmazásáról (2024, Rosnerné Mónika) és idei tervünk, hogy a STEM konferencián (tervezett időpont: 2026. február utolsó hete, Magyaródi Zsófia, Dávid Gergely) vesznek részt és adnak elő résztvevőként és előadóként (pénteki napon). A tantesület támogató hozzáállása nagyban segíti a fejlődésre nyitott kollégák továbbképzését.", "mtmi_tovabbkepzesi_programok_megvalosul_bemutatasa": "Iskolánk szorosan együttműködik az Alba Innovár Digitális Élményközponttal. Az okosterem megvalósulása és kollégáink képzése után külföldi példára létrehozták a PeDig menedzseri státuszt az Önkormányzat támogatásával. A programban résztvevő iskolákban megbízott kolléga PeDig menedzserként segítit az iskolán belüli fejlődést, az iskolaközi együttműködéseket és az Innovárban megrendezett workshopok népszerűsítését. Így a továbbképzések, versenyek, szakmai konferenciák híre hatékonyabban jut el az érintettekhez, a kollégák pedig személyre szabott tájékoztatást kaphatnak érdeklődésük szerint. \\nIdei tervezetben Bottka Rózsa fog fizikatanári ankéton műhelyfoglalkozást tartani, illetve két kollégánk fog a Szabó Szabolcs Alapítvány által szervezett műhelymunkán részt venni. Van, aki a STREAM IT Őszi webinárium-sorozatra regisztrált, hogy azok tartalmáról tájékoztassa a többieket. A feladatok így megosztlanak, ahogy a tudás is.\\nBelső képzési programjainkról a honlapon nem teszünk fel híreket, de a plakát linkjét megosztjuk. ", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul": "igen", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul_bemutatasa": "Az MTMI tantárgyakat tanító pedagógusok egyéni teljesítményértékelésében rendszeresen megjelennek olyan célok, amelyek közvetlenül támogatják az MTMI-program megvalósítását és az intézmény innovatív szemléletét. A tanárok saját szakterületükön túlmutató, a tanulói érdeklődést és a gyakorlati tapasztalatszerzést elősegítő tevékenységeket valósítanak meg.  A Zentais Napok keretében például Newton-távcső bemutatása történt, amely élményszerű módon kapcsolta össze a fizika és a csillagászat tananyagát. A „Legkedvesebb kémiai kísérletem” program során a természettudományos érdeklődés felkeltését szolgáló kísérleti bemutatók valósultak meg. Az „Szemléltető eszköz készítése lézervágóval” projekt a műszaki és technológiai ismeretek gyakorlati alkalmazását segítette. A pedagógusok szakmai fejlődését is erősítik az MTMI-célok: például egyik kollégánk földrajz szakos tanulmányokat folytat a tantárgyi kompetenciák bővítése és a szakos ellátottság érdekében. Az iskola rendszeresen vesz részt és szervez versenyeket is: a Zrínyi Ilona matematikaverseny és a BitHódítók informatikai verseny iskolai fordulóinak lebonyolítása fejleszti a diákok logikus gondolkodását és digitális kompetenciáit. Emellett a „Hullajó” újrahasznosítási projektverseny és az Állatok Világnapi projekt az interdiszciplináris szemléletet és a környezettudatosságot erősíti.  A Zentais Logika verseny pedig az iskolai közösségen belül biztosít lehetőséget a problémamegoldó és elemző gondolkodás fejlesztésére.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul_bemutatasa": "Az igazgató felméri a feljődési igényeket és érdeklődési területeket, és segít a meghirdetett képzések közül választani, figyelembe véve az iskolai célkitűzéseket is."}	2025-09-18 16:52:01.090061	2026-03-05 22:23:14.385397	1	\N	5671aa3e-6607-4567-ba23-9af9c45501b5
94c2c4fe-faa6-4bf8-97e2-f7aa5473c849	{"iskola_cime": "9700 Szombathely, Bolyai u. 11. ", "iskolatipus": ["gimnazium", "altalanos_iskola"], "gdpr_consent": ["on"], "szulo_bevonas": "megvalosul", "mtmi_koncepcio": "nem", "telepulesforma": "megyeszekhely_varos", "mtmi_nyilt_napok": "A korábbi évekhez hasonlóan 2025. október 14-én iskolánkban nyílt napot tartottunk, ahol az MTMI-tantárgyak tanóráit is meglátogathatták az iskolánk iránt érdeklődő, leendő 5. és 9. évfolyamos tanulók és szüleik.", "szulo_egyeztetes": "megvalosul", "mtmi_projektnapok": "A Bolyai Nap (Tehetségnap), egy egésznapos programsorozat, melynek alkalmával találkoznak egymással iskolánk jelenlegi és korábban végzett diákjai, az aktív és már nyugdíjba vonult pedagógusok. A felsőgimnazisták az iskola már karriert befutott öregdiákjainak előadásait hallgathatják meg a legkülönfélébb témákban, a fiatalabbak játékos programokon vehetnek részt, az alsósok pedig projektjeiket mutatják be a „Miben vagy tehetséges?” című foglalkozáson. Általában 20-25 öregdiák látogat vissza az alma materbe, hogy megossza szakmai tapasztalatait a hallgatósággal. A két, egymást követő idősávban folyó programokra a tanulók érdeklődésüknek megfelelően regisztrálhatnak. A tradíciónak megfelelően az iskola 5-10 pedagógusa is tart bemutatót.", "pedprog_mtmi_link1": "http://www.bolyaigimnazium.elte.hu/dok/aziskola/dokumentumok/pedprog.pdf", "szulo_kommunikacio": "megvalosul", "iskola_honlap_link1": "http://www.bolyaigimnazium.elte.hu", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "8", "palyazo_iskola_neve": "ELTE Bolyai János Gyakorló Általános Iskola és Gimnázium", "pedprog_mtmi_leiras": "A pedagógiai programban jelenleg még nem olvasható, de a 2025.10.22-i Nevelőtestületi Értekezleten elfogadásra kerültek az alábbi kiegészítések, amelyek a legközelebbi fenntartói jóváhagyáskor (egyetemi szenátusi ülésen, 2025. novemberben vagy decemberben) bekerülnek:\\n\\nIntézményünk MTMI-koncepciója:\\nIskolánk pedagógiai programjának kiemelt célja az MTMI területek (matematika, természettudományok, informatika és mérnöki tudományok) iránti tanulói érdeklődés felkeltése és fenntartása, diákjaink felkészítése a 21. századi munkaerőpiaci kihívásokra, algoritmikus gondolkodásuk, problémamegoldó képességük és digitális kompetenciáik fejlesztése.\\nTanórai kereteken kívül is erősítjük a tantárgyak közötti kapcsolatokat: projektnapokon, tehetségnapokon és interdiszciplináris projektek keretében. Támogatjuk és ösztönözzük a kiemelkedő érdeklődésű tanulókat MTMI-fókuszú szakkörökön, versenyeken, kutatási programokban való részvételre. Aktívan segítjük a diákok pályaválasztását. Ennek érdekében kapcsolatot tartunk külső partnerekkel (vállalatokkal, felsőoktatási intézményekkel), MTMI-pályát választó női példaképekkel.\\nA célok megvalósítása érdekében iskolánkban egy elkötelezett MTMI-csapat működik, melybe a pedagógusok mellett bevonjuk a szülői közösség képviselőit is.", "mtmi_ceges_eloadasok": "igen", "mtmi_csapat_tag1_nev": "Pájer Szabolcs József", "mtmi_csapat_tag2_nev": "Zsiros Péter", "mtmi_csapat_tag3_nev": "Baranyai József", "mtmi_csapat_tag4_nev": "Szabó Bence Farkas", "mtmi_csapat_tag5_nev": "Rózsa Viktória", "mtmi_csapat_tag6_nev": "Dobre Norbert", "mtmi_csapat_tag7_nev": "Ladányi Veronika", "mtmi_csapat_tag8_nev": "Bognár Eszter", "mtmi_szakkorok_szama": "8", "mtmi_szulo_kepviselo": "igen", "mtmi_alumni_programok": "igen", "mtmi_csapat_tag1_szak": ["matematika", "fizika"], "mtmi_csapat_tag2_szak": ["matematika"], "mtmi_csapat_tag3_szak": ["biologia"], "mtmi_csapat_tag4_szak": ["kemia"], "mtmi_csapat_tag5_szak": ["foldrajz"], "mtmi_csapat_tag6_szak": ["digitalis_kultura"], "mtmi_csapat_tag7_szak": ["digitalis_kultura"], "mtmi_csapat_tag8_szak": ["egyeb"], "mtmi_koncepcio_leiras": "...", "pedprog_mtmi_tartalom": "reszben", "szulo_palyaorientacio": "megvalosul", "mtmi_fakultaciok_szama": "21", "mtmi_muzeumlatogatasok": "nem", "iskola_tanuloi_letszama": "989", "mtmi_szakkor_tantargyak": ["matematika", "fizika", "kemia", "biologia", "foldrajz", "digitalis_kultura"], "mtmi_szakmak_bemutatasa": "igen", "szulo_egyeztetes_szoveg": "Az MTMI-csapat (vagy képviselője) évente két alkalommal egyeztet az iskolaszék tagjával az éves MTMI-programról, tekintettel a továbbtanulásra.:\\n1. Tanév elején ismertetjük és egyeztetjük az éves (tanévre szóló) MTMI-programot.\\n2. (és esetleges további) alkalmakon az aktuális MTMI-témájú programokról és projektekről, dedikált rendezvényekről, pályaválasztási szülői értekezletekről.\\nAz iskolai honlapon a tájékoztatás folyamatos.", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "nem", "mtmi_szakmai_gyakorlatok": "Nyári egyetemi táborokban vesznek részt 10-11. évfolyamos tanulóink. Helyi közműszolgáltatókhoz szervezünk látogatásokat, amelynek során a tanulók megismerhetik a gyakorlatban is a technológiai folyamatokat (pl. vízkezelés, energiatermelés) és a karbantartási feladatokat.", "mtmi_egyetemi_gyakorlatok": "igen", "mtmi_szakkor_diakok_szama": "120", "mtmi_szakkorok_bemutatasa": "Fizika szakkörön a diákok kísérleteket és méréseket végeznek, áramköröket építenek és programoznak, és a hétköznapi élet jelenségeinek tudományos hátterét vizsgálják gyakorlati jelenségeken keresztül.\\n\\nMatematika szakkörön a diákok a tananyagon túlmutató logikai feladványokkal, stratégiai játékokkal és nehezebb versenyfeladatokkal fejlesztik absztrakt gondolkodásukat és problémamegoldó képességüket.\\n\\nDigitális kultúra (robotika) szakkörön a tanulók programozási nyelveket sajátítanak el, egyszerűbb alkalmazásokat kódolnak, illetve robotokat építenek és programoznak fel konkrét feladatok elvégzésére.\\n\\nA kémia szakkörön a tanulók laboratóriumi kísérleteket végeznek, vizsgálják a háztartásban található anyagok tulajdonságait, és megismerkednek a modern kémia gyakorlati alkalmazásaival.\\n\\nA biológia szakkörön a résztvevők mikroszkópos vizsgálatokat folytatnak, boncolnak, terepgyakorlaton tanulmányozzák a helyi élővilágot, vagy kisebb ökológiai kutatási projekteket valósítanak meg.\\n\\nA földrajz szakkörön a tanulók térinformatikai eszközöket használnak, környezeti adatokat gyűjtenek és elemeznek, valamint terepgyakorlatok és projektek révén vizsgálják a globális kihívásokat és a helyi tájak összefüggéseit.", "szulo_munkakoz_ismertetes": "megvalosul", "mtmi_szakkor_tanarok_szama": "8", "iskola_mtmi_tanari_letszama": "10+", "mtmi_diakok_kapcsolattartas": "nem", "mtmi_kapcsolatok_bemutatasa": "A szombathelyi TDK a nemzetközi TDK csoport egyik legjelentősebb európai elektronikai fejlesztő- és gyártóközpontja.\\nhttps://hu.tdk-electronics.tdk.com/\\n\\nA német BPW Bergische Achsen KG szombathelyi leányvállalata, az 1600 főt foglalkoztató BPW-Hungária Kft. nehézfutóművek, futóműrendszerek előállításával, illetve agrárgépipari termékek tervezésével, fejlesztésével, gyártásával és értékesítésével foglalkozik. A vállalat, amely 1991-es alapítása óta töretlenül fejlődik, jól képzett mérnökökkel és modern tervező eszközökkel éri el sikereit.\\nhttps://bpw-hungaria.hu/bpw-hungaria-kft/\\n\\nMindkét üzembe rendszeresen szervezünk látogatásokat.\\n", "mtmi_online_palyaorientacio": "igen", "mtmi_rendezvenyek_reszvetel": "igen", "lanyok_mtmi_kiemelt_figyelem": "igen", "mtmi_alumni_programok_leiras": "A Bolyai Nap (Tehetségnap), egy egésznapos programsorozat, melynek alkalmával találkoznak egymással iskolánk jelenlegi és korábban végzett diákjai. A felsőgimnazisták az iskola már karriert befutott öregdiákjainak programjain vehetnek részt a legkülönfélébb témákban. Általában 25-30 öregdiák látogat vissza az alma materbe, hogy megossza szakmai tapasztalatait a hallgatósággal. A két, egymást követő idősávban folyó programokra a tanulók érdeklődésüknek megfelelően regisztrálhatnak. A tradíciónak megfelelően az iskola 8-10 pedagógusa is tart bemutatót.", "mtmi_csapat_tag1_tevekenyseg": "MTMI csapat üléseinek vezetése\\nMTMI feladatok és rendezvények koordinálása\\niskolai honlap MTMI részének naprakészen tartása\\nfizika, elektronika és programozás szakkör vezetése", "mtmi_csapat_tag2_tevekenyseg": "matematika szakkör vezetése", "mtmi_csapat_tag3_tevekenyseg": "biológia szakkör vezetése", "mtmi_csapat_tag4_tevekenyseg": "kémia szakkör vezetése", "mtmi_csapat_tag5_tevekenyseg": "földrajz szakkör vezetése", "mtmi_csapat_tag6_tevekenyseg": "digitális kultúra szakkör vezetése", "mtmi_csapat_tag7_tevekenyseg": "robotika szakkör vezetése", "mtmi_csapat_tag8_tevekenyseg": "robotika szakkör vezetése", "mtmi_aktiv_tanulas_megvalosul": "igen", "mtmi_csapat_kozos_tevekenyseg": "Éves MTMI-tervet készítünk, ezt rögzítjük az iskolai programnaptárba (projektnapok, nyílt nap, rendezvények, üzemlátogatások)\\nA programnaptár elérhető az iskola honlapján: http://www.bolyaigimnazium.elte.hu/index.php/szuloknek/program3/month.calendar\\nÖsszeállítjuk a szakköri és versenykínálatot, majd közzétesszük az iskola honlapján. A versenyek listája és az eredmények elérhetők: \\nhttp://www.bolyaigimnazium.elte.hu/index.php/pages/versenyeredmenyek-2\\n\\nRendszeresen egyeztetünk az iskolaszékkel (szülői képviselők) a programokról.\\n\\nMTMI-fókuszú szakköröket, projektnapokat, projekteket indítunk. Ösztönözzük a diákok versenyeken való részvételét. Tájékoztatást nyújtunk az MTMI-karrierlehetőségekről: céglátogatásokat,  egyetemi és laborlátogatásokat szervezünk.\\n\\nKiemelten támogatjuk a lányok érdeklődését (lányoknak szóló versenyeken veszünk részt: pl.:  EGOI, aDAT, stb.).\\n\\nKapcsolatot építünk és tartunk fenn külső partnerekkel (vállalatok, egyetemek).\\n\\nBiztosítjuk az MTMI-tevékenységek láthatóságát (honlapon, közösségi médiában).\\n\\nRészt veszünk MTMI-témájú belső és külső továbbképzéseken.\\n\\nRendszeresen egyeztetünk egymással. MTMI-üléseken a fentiek előrehaladását, az előttünk álló feladatokat beszéljük meg.", "mtmi_fakultaciok_diakok_szama": "183", "mtmi_kiallitoterek_megvalosul": "igen", "lanyoknak_szolo_mtmi_programok": "igen", "mtmi_egyeb_tevekenysegek_szama": "9", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_kutatási_versenyek_link1": "http://www.bolyaigimnazium.elte.hu/index.php/pages/versenyeredmenyek-2", "mtmi_kutatási_versenyek_szama": "4", "mtmi_laboratoriumok_latogatasa": "igen", "mtmi_otlet_esszepalyazat_link1": "http://www.bolyaigimnazium.elte.hu/index.php/pages/versenyeredmenyek-2", "mtmi_otlet_esszepalyazat_szama": "1", "intezmenytipus_tanuloi_letszama": "989", "mtmi_ceges_eloadasok_bemutatasa": "A 6.1.1-ben említett két cég képviselői évente legalább egy-egy alkalommal előadást tartanak iskolákban.", "mtmi_faliujsag_vitrin_reszvetel": "nem", "mtmi_palyaorientacio_megvalosul": "igen", "lanyok_mtmi_reszvetel_bemutatasa": "Tehetségnapon: Öregdiákok MTMI-orientációs programjai iskolánk \\"Bolyai\\" és \\"Tehetségnapján\\" (9-12. évf.)\\n\\nTehetségbanketten: A tanév végén a legjobb versenyeredményt elérő tanulókat tehetségbanketten köszöntjük. Ebből az alkalomból rendszeresen meghívunk vendégeket, hogy beszéljenek a szakmájukról és a pályaválasztásról.", "mtmi_felelos_kapcsolattarto_neve": "Pájer Szabolcs", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "igen", "mtmi_tanoran_kivuli_rendezvenyek": "Kutatók Éjszakája programok tartása az iskolában (elektronika, biológia, kémia)\\nPályaválasztási szülői értekezlet (12. évfolyamos tanulóknak és szüleinek)\\nNyári táborok (elektronika, programozás, biológia)\\nTerepgyakorlatok (biológia)\\nÜzem- és gyárlátogatások (paksi atomerőmű, Audi-gyár)\\nEgyetemi laborlátogatások (ELTE Elektrotechnika labor, ELTE Gyártástechnológia labor)", "mtmi_tanulmányi_versenyek_link1": "http://www.bolyaigimnazium.elte.hu/index.php/pages/versenyeredmenyek-2", "mtmi_tanulmányi_versenyek_szama": "37", "programban_erintett_tanulok_szama": "350", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyuttmukodes_palyaorientacio": "igen", "mtmi_felelos_kapcsolattarto_email1": "pajer.szabolcs@bolyaigimnazium.elte.hu", "mtmi_felelos_kapcsolattarto_email2": "szabolcs.pajer@gmail.com", "mtmi_online_palyaorientacio_leiras": "A Felvi.hu felületen a Pályaorientációs teszteket hasznáják a 11-12. évfolyamos tanulóink, amelyet közvetlenül, de az iskola honlapjáról is elérhetnek.", "mtmi_otlet_esszepalyazat_reszvetel": "igen", "mtmi_tanulmányi_verseny_reszvetel": "igen", "intezmenyvezeto_kapcsolattarto_neve": "Papp Tibor", "mtmi_kutatási_verseny_diakok_szama": "17", "mtmi_kutatási_versenyek_bemutatasa": "Ifjú Fizikusok Nemzetközi Versenye\\nIfjúsági tudományos és innovációs tehetségkutató verseny\\nOrszágos Ifjúsági Innovációs Verseny\\n\\"a Dream About Tomorrow\\" innovációs verseny lányoknak\\n\\nEredmények: http://www.bolyaigimnazium.elte.hu/index.php/pages/versenyeredmenyek-2", "mtmi_otlet_esszepalyazat_bemutatasa": "Neumann János Nemzetközi Programtermék Verseny\\n1. helyezés", "mtmi_digitalis_tananyagok_megvalosul": "igen", "mtmi_felelos_kapcsolattarto_beosztas": "tanár", "mtmi_kutatási_verseny_tanarok_szama": "7", "intezmenyvezeto_kapcsolattarto_email1": "papp@bolyaigimnazium.elte.hu", "mtmi_otlet_esszepalyazat_diakok_szama": "1", "mtmi_tanulmányi_verseny_diakok_szama": "300", "mtmi_tanulmányi_versenyek_bemutatasa": "Eredmények: http://www.bolyaigimnazium.elte.hu/index.php/pages/versenyeredmenyek-2\\n\\nMTMI tanulmányi versenyek, amelyeken részt veszünk:\\nArany Dániel Matematikai Tanulóverseny\\nBolyai János vármegyei matematika verseny\\nBolyai matematika csapatverseny\\nBolyai természettudományi csapatverseny\\nCurie Kémia Emlékverseny\\nDusza Árpád országos programozói emlékverseny\\nDürer Matematika Verseny\\nEurópai Lány Informatikai Olimpia (EGOI)\\nHevesy György országos kémia verseny\\nIrinyi János országos középiskolai kémiaverseny\\nIzsák Imre Gyula komplex természettudományi verseny\\nJakucs László nemzetközi középiskolai földrajzverseny\\nKalmár László matematikaverseny\\nLess Nándor földrajzverseny\\nLóczy Lajos országos földrajzverseny\\nMegyei fizikaverseny\\nMikola Sándor országos tehetségkutató fizikaverseny\\nNemes Tihamér Nemzetközi Informatikai Tanulmányi Verseny - Alkalmazás kategória\\nNemes Tihamér Nemzetközi Programozási Verseny\\nNemzetközi Biológiai Diákolimpia (IBO)\\nNemzetközi Informatikai Olimpia (IOI)\\nNemzetközi Kémiai Torna\\nNemzetközi Kémiai Torna válogatóverseny\\nNemzetközi Kenguru Matematikaverseny\\nOláh György országos középiskolai kémiaverseny\\nOrszágos Középiskolai Tanulmányi Verseny: biológia\\nOrszágos Középiskolai Tanulmányi Verseny: fizika\\nOrszágos Középiskolai Tanulmányi Verseny: földrajz\\nOrszágos Középiskolai Tanulmányi Verseny: informatika alkalmazói\\nOrszágos Középiskolai Tanulmányi Verseny: informatika programozói\\nOrszágos Középiskolai Tanulmányi Verseny: kémia\\nOrszágos Középiskolai Tanulmányi Verseny: matematika\\nOrszágos Szilárd Leó Fizikaverseny\\nÖveges József Kárpát-medencei Fizikaverseny\\nTeleki Pál Kárpát-medencei földrajz–földtan verseny\\nVarga Tamás matematikaverseny\\nZrínyi Ilona Matematikaverseny", "mtmi_interdiszciplinaris_projekt_link1": "http://www.bolyaigimnazium.elte.hu/index.php/home/2021-02-14-22-30-11/ke1", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_otlet_esszepalyazat_tanarok_szama": "1", "mtmi_rendezvenyek_reszvetel_bemutatasa": "Iskolánk rendszeresen házigazdája a Kutatók Éjszakája rendezvényeknek. Tanáraink  programokat hirdetnek fizika, kémia, biológia és csillagászat témakörben.", "mtmi_tanulmányi_verseny_tanarok_szama": "25", "intezmenyvezeto_kapcsolattarto_beosztas": "igazgató", "mtmi_interdiszciplinaris_projekt_leiras": "Elektronika szakkörön áramköröket építünk és programozunk\\nEgyszerűbb, analóg áramkörök építésével kezdjük, majd mikrovezérlőket programozunk C nyelven, szenzorok működését tanuljuk meg és vezérléseket készítünk.", "mtmi_tovabbkepzesek_idokeret_megvalosul": "igen", "mtmi_tovabbkepzesi_programok_megvalosul": "igen", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "A tanulók rendszeresen dolgoznak páros- és csoportmunkában digitális platformokon (pl. Google Workspace), ahol közösen hoznak létre dokumentumokat, prezentációkat vagy gyűjtenek anyagot egy-egy MTMI-projekthez.", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 30 986 8362", "mtmi_felelos_kapcsolattarto_telefonszam2": "+36 94 513 683", "mtmi_kiallitoterek_megvalosul_bemutatasa": "A Bolyai Galéria (iskolánk aulájában lévő kiállítótér) rendszeresen bemutatja a tanulók munkáit.\\nDe itt kap helyet egy-egy nagyobb - az egész iskolát megmozgató - kísérlet is (pl. Foucault ingakísérlete).", "mtmi_palyaorientacio_megvalosulas_leiras": "Minden tanévben 3-4 alkalommal megvalósuló programok:\\n- pályaválasztással kapcsolatos szülői értekezletek (11-12. évf.),\\n- pályaválasztással kapcsolatos osztályfőnöki órák (10-12. évf.),\\n- gyár- és céglátogatások (9-12. évf.),\\n- egyetemi laborlátigatások (7-10. évf.)\\n- egyetemi nyílt napok látogatása (11-12. évf.)\\n\\nMinden tanévben legalább egyszer megvalósuló programok:\\n- öregdiákok MTMI-orientációs programjai iskolánk \\"Bolyai\\" és \\"Tehetségnapján\\" (9-12. évf.)\\n- az MTMI-területen dolgozó öregdiákok és szülők előadásai (9-12. évf.)", "lanyoknak_szolo_mtmi_programok_bemutatasa": "A Dream About Tomorrow egy 2 hónapos oktatási program (online felkészítő workshopok, előadások, oktatási anyagok), ahol a lányok valós technikai vagy üzleti problémákra, dilemmákra dolgoznak ki innovatív technológiai/üzleti/tudományos megoldásokat, mindezt mentorok és szakértők támogatásával. Az oktatási program a projektek bemutatásával, versenyével zárul. \\nA program 2005 októberében indult.\\n\\nEGMO - Lányok Európai Matematikai Olimpiája versenyen való részvétel\\n\\nEGOI - Európai Leány Informatikai Diákolimpia versenyen való részvétel", "mtmi_egyuttmukodes_palyaorientacio_leiras": "Egyetemek és főiskolák képviselőit hívjuk meg iskolánkba egy napra.\\n\\nMTMI-hez kapcsolódó egyetemi vagy nyári szakmai gyakorlatokon és/vagy táborokon való részvétel:\\nELTE és BME táboraiban 10-11. évfolyamos tanulók veszenek részt.\\n\\nA tanév során céglátogatásokat, MTMI-fókuszú karrierbemutatókon való részvételt szervez:\\nÜzem- és gyárlátogatások (paksi atomerőmű, Audi-gyár)\\nEgyetemi laborlátogatások (ELTE Elektrotechnika labor, ELTE Gyártástechnológia labor)\\n\\nAz év folyamán megfelelő évfolyamokban a pályaválasztásban érdekelt felek (vállalatok, kamarák, oktatási intézmények, alumnik, szülők stb.) bemutatják az MTMI szakmák lehetőségeit:\\nÖregdiákok MTMI-orientációs programjai iskolánk \\"Bolyai\\" és \\"Tehetségnapján\\" (9-12. évf.) (ld. korábbi pontokban)\\nAz MTMI-területen dolgozó öregdiákok és szülők előadásai (9-12. évf.) osztályfőnöki órákon, pályaválasztási szülői értekezleteken (10-12. évfolyamos tanulóknak és szüleinek)", "mtmi_laboratoriumok_latogatasa_bemutatasa": "Az ELTE szombathelyi duális gépészmérnöki képzése az egyik legnagyobb duális képzés, amely a hagyományos gépészmérnök BSc-re épül, és a korszerű műszaki és informatikai ismeretek elsajátítása mellett gyakorlati és elméleti tudást tovább bővítik a partnervállalatoknál tematikusan szervezett szakmai gyakorlatok során. A duális gépészmérnöki képzés mögött jelenleg 14, elsősorban gépjárműalkatrész-gyártó cég biztosítja a gyakorlati hátteret.\\nA képzés egyetemi laborjaiba (ELTE Elektrotechnika labor, ELTE Gyártástechnológia labor) rendszeresen szervezünk látogatásokat.", "intezmenyvezeto_kapcsolattarto_telefonszam1": "+36 20 327 8364", "intezmenyvezeto_kapcsolattarto_telefonszam2": "+36 94 513 681", "mtmi_digitalis_eszkozok_megvalosul_bemutatasa": "A fizika, kémia és biológia órákon digitális adatgyűjtő szenzorokat használunk, amelyekkel a diákok valós idejű méréseket végezhetnek és az adatokat azonnal grafikonon jeleníthetik meg.\\nBiológiából digitális mikroszkópokat alkalmazunk, így a látott kép kivetíthető és közösen elemezhető.\\nFizika és kémia órán olyan kísérleteket vagy jelenségeket, amelyeket a valóságban nehézkes, drága vagy veszélyes lenne bemutatni, interaktív szimulációk segítségével modellezünk. \\nMatematikából a dinamikus geometriai szoftverek használata állandó gyakorlat a függvények elemzésénél, geometriai transzformációknál vagy a térgeometriai testek szemléltetésénél. \\nFöldrajzból a diákok táblázatkezelő programokat használnak statisztikai adatsorok feldolgozására, elemzésére és diagramok készítésére. Informatika órákon a diákok nemcsak felhasználói, hanem alkotói is a digitális tartalomnak, programozási környezeteket használnak.\\n", "mtmi_digitalis_tananyagok_megvalosul_bemutatasa": "A pedagógusok digitális tananyagokat és feladatlapokat készítenek, valamint online kvízalkalmazásokat használnak a tanórai differenciálásra, gyakorlásra és a tudás gyors, formatív értékelésére. Ez azonnali visszajelzést ad a tanulóknak és a pedagógusnak is.", "mtmi_korszeru_felszereltseg_megvalosul_bemutatasa": "Az MTMI órák többségét MTMI-szaktantermekben tarjuk (fizika, kémia, biológia, digitális kultúra, szakkörök). A többi tanteremben is rendelkezésre áll interaktív megjelenítő panel. A tanároknak és a diákoknak lehetőségük van a megjelenítőeszközre – akár egyidejűleg sokan – rácsatlakozni a jól működő, egész iskolát lefedő WLAN-on keresztül.\\nAz iskola rendelkezik jól felszerelt Öveges laboratóriummal.", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul": "igen", "mtmi_tovabbkepzesek_idokeret_megvalosul_bemutatasa": "A tanév elején a munkaközösségek az egyéni igények és az intézményi stratégiai célok alapján javaslatot tesznek a vezetőség felé a releváns szakmai programokon való részvételekre és ezek bekerülnek az iskola éves továbbképzési tervébe.\\nRövidebb, 1-2 napos távollétek (módszertani vagy egyéb hazai konferencia, POK-os műhelymunka) esetén a helyettesítést elsősorban a munkaközösségen belül, óraátcsoportosítással vagy a párhuzamos osztályokat tanító kollégák bevonásával oldjuk meg. \\nHosszabb távollét (pl. többnapos nemzetközi konferencia, Erasmus+ mobilitás) esetén a vezetés központilag szervezi meg a helyettesítést. Online képzések esetén is biztosítja az iskola a pedagógus számára a nyugodt részvétel feltételeit  és az óráinak helyettesítését.\\n\\nAz elmúlt 3 év tevékenységei:\\nOrszágos Fizikatanári Ankét és Eszközbemutató\\nOrszágos Kémiatanári Konferencia\\nBiológia Tanárok Országos Konferenciája\\nInformatika-Számítástechnika Tanárok Egyesületének (ISZE) Konferenciái\\nMagyar Földrajzi Társaság (MFT) Tanári Szakosztályának rendezvényei\\nEducatio Nemzetközi Oktatási Szakkiállítás\\nMatematikatanárok Rátz László Vándorgyűlése", "mtmi_tovabbkepzesi_programok_megvalosul_bemutatasa": "Tapasztalt, innovatív mesterpedagógusaink és szaktanácsadóink rendszeresen tartanak bemutató foglalkozásokat, „Jó gyakorlatokat” saját, jól bevált projektjeikről, módszereikről.\\nIskolánk bázisintézményként működik, ezért regionális szinten is tartunk műhelymunkákat, meghívva a környező iskolák pedagógusait egy-egy sikeres gyakorlatunk bemutatására.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul": "igen", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul_bemutatasa": "- MTMI-szakkörök vezetése,\\n- MTMI-versenyekre történő felkészítés,\\n- új digitális eszköz vagy szoftver tanórai gyakorlatba való bevezetése,\\n- akkreditált MTMI továbbképzés elvégzése", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul_bemutatasa": "A megvalósulás formái megegyeznek a 7.2.1-ben leírtakkal."}	2025-09-10 13:37:53.825377	2026-03-05 22:23:14.504293	1	\N	b6abbfc3-1299-4b68-a1e4-15cd97b0df9a
77789430-a252-48d7-9d12-de0d8c17085d	{"iskolatipus": [], "gdpr_consent": [], "mtmi_csapat_tag1_szak": [], "mtmi_csapat_tag2_szak": [], "mtmi_csapat_tag3_szak": [], "mtmi_csapat_tag4_szak": [], "mtmi_csapat_tag5_szak": [], "mtmi_csapat_tag6_szak": [], "mtmi_csapat_tag7_szak": [], "mtmi_csapat_tag8_szak": [], "mtmi_szakkor_tantargyak": []}	2026-03-04 19:09:33.503682	2026-03-11 19:30:47.333945	0	\N	\N
e44cfee3-99d3-4ac2-8214-6c31f8ab2413	{"iskola_cime": "s", "iskolatipus": [], "gdpr_consent": [], "palyazo_iskola_neve": "Belavolgyi", "mtmi_csapat_tag1_szak": [], "mtmi_csapat_tag2_szak": [], "mtmi_csapat_tag3_szak": [], "mtmi_csapat_tag4_szak": [], "mtmi_csapat_tag5_szak": [], "mtmi_csapat_tag6_szak": [], "mtmi_csapat_tag7_szak": [], "mtmi_csapat_tag8_szak": [], "mtmi_szakkor_tantargyak": []}	2026-03-05 22:14:51.065793	2026-03-15 09:13:36.283902	0	\N	4167fe85-5bfa-4756-b33c-bf3c599b2edf
62e4f5d4-41f5-4665-8070-44d65712e7ac	{"iskola_cime": "2230 Gyömrő, Fő tér 2b", "iskolatipus": ["altalanos_iskola"], "gdpr_consent": ["on"], "szulo_bevonas": "megvalosul", "mtmi_koncepcio": "igen", "telepulesforma": "megyeszekhely_varos", "mtmi_nyilt_napok": "A robotika szakkör tevékenységét évente egy alkalommal bemutatjuk az érdeklődőknek.", "szulo_egyeztetes": "nem", "mtmi_csapat_link1": "https://www.facebook.com/profile.php?id=100057297676619", "mtmi_projektnapok": "Semilab üzemlátogatások", "pedprog_mtmi_link1": "https://weoresiskola.hu/wp-content/uploads/2024/03/Pedagogiai-program_zaradekkal.pdf", "szulo_kommunikacio": "megvalosul", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "8", "palyazo_iskola_neve": "Gyömrői Weöres Sándor Általános Iskola és Alapfokú Művészeti Iskola", "pedprog_mtmi_leiras": "Korszerű természettudományos és társadalomtudományos műveltségkép kialakítása, melyet\\ntanulóink eszközként használnak a valóság viszony-rendszerének megértéséhez,\\nés alkalmaznak különböző cselekvés-formákban. 1-4 éfolyamon fogékonnyá tesszük saját környezetük, a természet értékei iránt. Ebben a szakaszban a kíváncsiságra és az érdeklődésre építünk, és az ezáltal motivált\\nmunkában, fejlesztjük a kisgyermekben a felelősségtudatot, a kitartás képességét és előmozdítjuk\\nérzelemviláguk gazdagodását. ÖKO iskola - környezetvédelmi nevelés\\nIsmerjék meg a gyerekek azokat a világban zajló természeti és társadalmi folyamatokkal,\\namelyek gazdasági, társadalmi válságjelenségeket okoznak. A tanulók kapcsolódjanak be\\nközvetlen környezetük értékeinek megőrzésébe, gyarapításába. Kapcsolódjanak be akciókba (pl.\\npapírgyűjtés, elemgyűjtés, hulladékhasznosítási tevékenységek, madáretetés).\\nÉletmódjukban a természet tisztelete, a felelősség, a környezeti károk megelőzésére való\\ntörekvés váljon meghatározóvá.\\nA „jeles napokról” (állatok világnapja, tudatos vásárlók napja, víz világnapja, Föld napja,\\nmadarak és fák napja, környezetvédelmi világnap) műsorokkal, akciókkal, versenyek és kiállítások\\nszervezésével emlékezzünk meg, illetve témaheteket szervezünk. Az Öko-iskolai műhely\\nmunkatervét az intézményi munkatervvel együtt készíti el. Környezetvédelmi és természettudományos foglalkozást és tábort szervezünk alsós diákok számára. Természettudományos és informatikai témájú szakköröket biztosítunk 5. évfolyamtól. Lehetőséget biztosítunk ECDL bizonyítvány megszerzésére. Felső tagozatban a digitális eszközökkel, módszerekkel nem csak az informatika, hanem a\\nfizika, természetismeret, biológia és technika tantárgyakban is gyakorlatközpontúvá tudjuk tenni a\\ntananyagot. A KAP Az Életgyakorlat-alapú alprogrammal\\ntámogatjuk a diák és természeti környezete kölcsönhatásának tudatos és felelős\\nalakítását. A Digitális alprogrammal az IKT eszközök használata folyamatos.", "mtmi_ceges_eloadasok": "igen", "mtmi_csapat_tag1_nev": "Antalné Csorba Katalin", "mtmi_csapat_tag2_nev": "Klima Eszter", "mtmi_csapat_tag3_nev": "Szatvári-Varga Katalin", "mtmi_csapat_tag4_nev": "Török Sándor", "mtmi_csapat_tag5_nev": "Tusorné Fekete Éva", "mtmi_csapat_tag6_nev": "Velkei Éva", "mtmi_csapat_tag7_nev": "Baturinné Balassa Renáta", "mtmi_csapat_tag8_nev": "Konrádné Kozma Katalin", "mtmi_szakkorok_szama": "6", "mtmi_szulo_kepviselo": "nem", "mtmi_alumni_programok": "nem", "mtmi_csapat_tag1_szak": ["fizika", "technika"], "mtmi_csapat_tag2_szak": ["kemia", "termeszettudomany"], "mtmi_csapat_tag3_szak": ["biologia", "termeszettudomany"], "mtmi_csapat_tag4_szak": ["matematika", "egyeb"], "mtmi_csapat_tag5_szak": ["digitalis_kultura"], "mtmi_csapat_tag6_szak": ["foldrajz", "technika"], "mtmi_csapat_tag7_szak": ["foldrajz"], "mtmi_csapat_tag8_szak": ["fizika", "termeszettudomany", "technika"], "mtmi_koncepcio_leiras": "Egészséges életmódra nevelés: Egészségvédelmi hónap programjai, \\nTagozati  szintű programok szervezésére teamet hozunk létre.\\nSzakórákba beépítve: minden osztályban osztályfőnöki órán és adott szakórákon megjelenik a téma.\\nKörnyezetvédelmi nevelés: A téma beépítése a tanmenetekbe. \\nA tagozati szintű programok szervezésére teameket hozunk létre.\\nKörnyezetvédelmi kampány: \\nolajgyűjtés\\npapírgyűjtés egyszer\\nSulizsák program kétszer (tavasz, ősz)\\nÁllatok világnapja témanap\\nAutómentes nap\\nTémahetek:\\nFenntarthatósági Hét, \\nPénzügyi Tudatosság Hete megszervezése\\nÁllatok világnapja\\nDigitális témahét\\nBudapest projektnap\\nTermészettudományos szemléletmód kialakítása, természettudományos tehetséggondozás: Verseny (felkészítés)\\nBolyai természettudományi csapatverseny\\nBolyai matematika csapatverseny\\ne-Hód Nemzetközi számítástechnika verseny\\nWRO  robotika\\nKódolás hete \\nDigitális Tematikus hét\\nTehetséggondozó szakkörök:\\nSarkig tárt világ\\nProgramozás-robotika szakkör \\nKAP projektek\\nFelvételi előkészítő", "pedprog_mtmi_tartalom": "igen", "szulo_palyaorientacio": "megvalosul", "mtmi_fakultaciok_szama": "0", "mtmi_muzeumlatogatasok": "igen", "iskola_tanuloi_letszama": "1030", "mtmi_szakkor_tantargyak": ["fizika", "digitalis_kultura", "kornyezetismeret", "termeszettudomany"], "mtmi_szakmak_bemutatasa": "igen", "szulo_egyeztetes_szoveg": "Az iskolai alapdokumentumokban egyértelműen megfogalmazott MTMI célok rögzítésre kerültek. A dokumentumokat a szülők a honlapon keresztül érik el. Az SZM szülői közösséggel a dokumentumokat érintő változásokat egyezetjük. A szülői értekezleteken az MTMI versenyekről, programokról a szülőket tájékoztatjuk. Iskolai tanórán kívüli, és iskolán kívüli programokon a szülők számára részvételi lehetőséget biztosítunk. Ökotevékenység keretében adventi vásárt közösen szervezünk újrahasznosított termékekkel. Szülők kíséretében veszünk részt a robotika versenyeken. Drogprevenciós és cyberbiztonsági workshopot szervezünk a szülők számára.", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "nem", "mtmi_szakmai_gyakorlatok": "nem releváns", "mtmi_egyetemi_gyakorlatok": "igen", "mtmi_szakkor_diakok_szama": "91", "mtmi_szakkorok_bemutatasa": "Sarkig tárt világ: Terészetismeret tantárgyhoz kapcsolódó tevékenységek, egyszerű kísérletek, öko-programok, újrahasznosítás, kirándulás, Madárkórház meglátogatása. Bolyai csapatversenyre való felkészítés. Robotika szakkörök: A microbit programozástól az egyszerűbb padlórobotokon át a komolyabb, szekzorokkal ötvözött Lego robotokig. WRO, FFL versenyekre való felkészítés. \\nFizika szakkör: csillagászati, űrkutatási programok szervezése, versenyfelkészítés, kompetenciafejlesztés, fizika kísérletek elvégzése.", "szulo_munkakoz_ismertetes": "nem", "mtmi_szakkor_tanarok_szama": "4", "iskola_mtmi_tanari_letszama": "10+", "mtmi_diakok_kapcsolattartas": "nem", "mtmi_kapcsolatok_bemutatasa": "A nyolcadik évfolyam (100) fő évente ellátogat a Semilabhoz. E mellett a Mobil Planetáriumba, Csillagászati Kutatóintézetbe, a Madárkórházba és a BME kísérleti bemutatóira is szervezünk programot.", "mtmi_online_palyaorientacio": "nem", "mtmi_rendezvenyek_reszvetel": "nem", "lanyok_mtmi_kiemelt_figyelem": "igen", "mtmi_csapat_tag1_tevekenyseg": "Semilab üzemlátogatások, Fizika mobillabor, MTMI pályázat koordinálása, mentortanár, versenyek, űrkutatási-csillagászati szakkör, 3d tervezés és nyomtatás", "mtmi_csapat_tag2_tevekenyseg": "Öko programok koordinálása, Bolyai csapatverseny felkészítés,  Egészségvédelmi hét, Környezetvédelmi kampány, Közlekedés", "mtmi_csapat_tag3_tevekenyseg": "Fenntarthatósági Hét,  Pénz Hét, továbbtanulás, felvételi felkészítés", "mtmi_csapat_tag4_tevekenyseg": "Matematika versenyek koordinálása, Bolyai Csapatverseny, felvételi előkészítő", "mtmi_csapat_tag5_tevekenyseg": "IKT,  Biztonságos Internet Hete, DTH, Kódolás hete, eHód, Robotika", "mtmi_csapat_tag6_tevekenyseg": "Egészségvédelmi hét, Öko tevékenységek mentálhig.tev. Állatok világnapja, Sakk, Madarak és fák napja", "mtmi_csapat_tag7_tevekenyseg": "öko tevékenységek, fenntarthatósági témahét", "mtmi_csapat_tag8_tevekenyseg": "Robotika, 3D tervezés és nyomtatás, Állatok világnapja, egészségvédelem", "mtmi_aktiv_tanulas_megvalosul": "igen", "mtmi_csapat_kozos_tevekenyseg": "Az MTMI (matematika, természettudományos, műszaki és informatikai) tantárgyakkal\\nfoglalkozó pedagógusok munkaközössége aktívan dolgozik azért, hogy diákjaink\\nérdeklődően és motiváltan forduljanak ezen tantárgyak irányába. A modern világ\\nműködéséhez elengedhetetlen tudományok terén munkálkodók utánpótlásának\\nbiztosítása az iskolák feladata, ebben nagy szerepet kap az általános iskola, ahol a\\ndiákok először tapasztalhatják meg a felfedezés izgalmát strukturált keretben.\\nMunkaközösségünk színes programokkal igyekszik felkelteni a jövő mérnökeinek,\\ntudósainak az érdeklődését.\\nRobotika versenyzőink már az első héten egy nemzetközi World Robot Olimpiad\\n(WRO) versenyen vehettek részt Ljubljanában, ahol eredményesen szerepeltek.\\n4 csapat nevezett az „Irány az űr” űrkutatási versenyre.\\nZajlik a Bolyai csapatversenyek (természettudomány, matematika) csapatainak\\nösszeállítása.\\nIndulnak a matematika felvételi előkészítők a hetedik és nyolcadik évfolyamon.\\nAz ősz folyamán nyolcadikosaink üzemlátogatáson vesznek részt a félvezetőiparban\\nélenjáró SEMILAB-nál.\\nCsoportos látogatást szervezünk a HUNIVERZUM kiállításra a Millenáris Parkba.", "mtmi_fakultaciok_diakok_szama": "0", "mtmi_kiallitoterek_megvalosul": "igen", "lanyoknak_szolo_mtmi_programok": "nem", "mtmi_egyeb_tevekenysegek_szama": "1", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_kutatási_versenyek_szama": "2", "mtmi_laboratoriumok_latogatasa": "nem", "mtmi_otlet_esszepalyazat_link1": "https://www.facebook.com/photo/?fbid=1011791560740757&set=pcb.1011791927407387", "mtmi_otlet_esszepalyazat_szama": "1", "intezmenytipus_tanuloi_letszama": "1030", "mtmi_ceges_eloadasok_bemutatasa": "A Fizika mobillabor évente 5 alkalommal kísérleti bemutatót tart a hetedik évfolyamnak.", "mtmi_faliujsag_vitrin_reszvetel": "igen", "mtmi_palyaorientacio_megvalosul": "igen", "lanyok_mtmi_reszvetel_bemutatasa": "Pályaorientációs napra Fröhlich Georginával onilne találkozót szerveztünk. ", "mtmi_faliujsag_vitrin_bemutatasa": "Faliújságot tartunk fenn, amit 1-2 hetente frissítünk. Az aulában rendezett kiállításokon mutatják be diákjaink az alkotásaikat.", "mtmi_felelos_kapcsolattarto_neve": "Antalné Csorba Katalin", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "igen", "mtmi_tanulmányi_versenyek_link1": "https://www.facebook.com/photo?fbid=1239823187937592&set=pcb.1239823607937550", "mtmi_tanulmányi_versenyek_link2": "https://www.facebook.com/profile.php?id=100057297676619", "mtmi_tanulmányi_versenyek_link3": "https://www.facebook.com/photo/?fbid=1207902214463023&set=pcb.1207902547796323", "mtmi_tanulmányi_versenyek_szama": "11", "mtmi_muzeumlatogatasok_bemutatasa": "Idei tanévben október 2-án a Huniverzum kiállításra 18 fő, egy évfolyam a Vasúttörténeti pakba látogat el.", "programban_erintett_tanulok_szama": "300", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyuttmukodes_palyaorientacio": "nem", "mtmi_felelos_kapcsolattarto_email1": "antalne.csorba@weoresiskola.com", "mtmi_otlet_esszepalyazat_reszvetel": "igen", "mtmi_tanulmányi_verseny_reszvetel": "igen", "intezmenyvezeto_kapcsolattarto_neve": "Seresné Mészáros Katalin", "mtmi_kutatási_verseny_diakok_szama": "21", "mtmi_kutatási_versenyek_bemutatasa": "A WRO Future innovators csapatai az előző 2 nanévben egyik alkalommal a vulkánkitürések negatív következményeinek enyhítésére, idén pedig az űrkolonizációval kapcsolatos növénytermesztésre fókuszáltak. A Hunor program-Legyél te is űrjajós! versenyre való felkészülés során számos csillagászati és űrkutatási problémát elemeztek.", "mtmi_otlet_esszepalyazat_bemutatasa": "A MOME egyetem STEAM témájú pályázatára 3D nyomtató segítségével társasjátékot készítettek diákjaink.", "mtmi_digitalis_tananyagok_megvalosul": "igen", "mtmi_felelos_kapcsolattarto_beosztas": "pedagógus", "mtmi_kutatási_verseny_tanarok_szama": "2", "intezmenyvezeto_kapcsolattarto_email1": "seresne.katalin@weoresiskola.com", "mtmi_otlet_esszepalyazat_diakok_szama": "3", "mtmi_tanulmányi_verseny_diakok_szama": "390", "mtmi_tanulmányi_versenyek_bemutatasa": "E-hód, Code Week, Wro, Microbit programozási, Bolyai matemartika, Házi matematika, vVárosi matematika, Bolyai természettudományos, Petrik Lajos Verseny, Fizika adatelemző verseny, Méh-Ész Logikai verseny, Városi sakkverseny, Területi sakkverseny, Matific Olimpia Számos dobogós helyezéssel rendelkezünk. A teljes dokumentáció online egyben nem elérhető, de szükség eseén xls formátumban rendelkezésre bocsátjuk. ", "mtmi_interdiszciplinaris_projekt_link1": "https://www.youtube.com/watch?v=SneBTYn97XA", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_otlet_esszepalyazat_tanarok_szama": "1", "mtmi_tanulmányi_verseny_tanarok_szama": "9", "intezmenyvezeto_kapcsolattarto_beosztas": "főigazgató", "mtmi_interdiszciplinaris_projekt_leiras": "A WRO future innovators kategóriához komplex természettudományos projektet hoztunk létre (automatizált robotvezérelt üvegház)", "mtmi_tovabbkepzesek_idokeret_megvalosul": "igen", "mtmi_tovabbkepzesi_programok_megvalosul": "igen", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "A tanulók képességeinek és kulcskompetenciáinak lehetőség szerint egyénre szabott fejlesztése és megerősítése.\\nLehetőség szerint minden kolléga vezessen le legalább egy projektet. A cél az, hogy minden tanulócsoport találkozzon a módszerrel. Fontos a tehetség kibontakozásának a segítése, a differenciálással történő fejlesztés, kooperatív technikák alkalmazása és a hátránykompenzálás az iskolai élet minden területén- tehetség műhelyek, szakkörök\\nAz IKT-eszközök alkalmazásának folyamatos bevezetése /Internet, e-tananyagok, projektmunkák/\\n", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 30 576 0580", "mtmi_felelos_kapcsolattarto_telefonszam2": "+36 29 330 135 ", "mtmi_kiallitoterek_megvalosul_bemutatasa": "Témanapok, projektek produktumait időszakos kiállítások segítégével mutatjuk be a diákközösségnek és a szülőknek, érdeklődőknek. Faliújságaink a diákok munkái mellett tájékoztató anyagokat, aktualitásokat tartalmaznak.", "mtmi_palyaorientacio_megvalosulas_leiras": "Pályaorientációs napra régi diákjainkat hívjuk vissza, akik bemutatják iskolájukat. Online találkozót szerveztünk dr. Fröhlich Georginával, aki bemutatta tudományos tevékenységét.", "mtmi_egyuttmukodes_palyaorientacio_leiras": "MTMI alapú tábort szervezünk diákjainknak. Üzemlátogatásra megyünk a Semilab céghez. Előző években a Csillagászati Kutatóintézetbe és a KFKI-ba is szerveztünk programot.", "intezmenyvezeto_kapcsolattarto_telefonszam1": "+36 30 792 9339", "intezmenyvezeto_kapcsolattarto_telefonszam2": "+36 29 330 135", "mtmi_digitalis_eszkozok_megvalosul_bemutatasa": "Az IKT-eszközök adaptív alkalmazása (internet, e-tananyagok,\\nprojektmunkák, digitális számonkérések, tanulást segítő eszközök, blended, learning módszer\\nalkalmazása különböző tantárgyakban. A hátrányos helyzetű és a sajátos nevelési igényű (SNI) tanulók esélyegyenlőségének\\njavítása. Intézményünk 2009 óta Tehetségpont, 2010 óta kiválóra értékelt akkreditált Tehetségpont.\\nJelenleg működő 9 tehetséggondozó műhelyünk közül: 2 teljesen IKT-s alapú (programozás), több\\ncsoportunkban digitális eszközökkel is fejlesztünk. belső IKT képzésen megismert gyakoroltató, illetve\\nértékelő eszközzel (LearningApps, Socrative) is rendszeresen dolgozik, órai felhasználásra, illetve\\notthoni munkáltatásra.\\nFelső tagozaton a diagnosztikus mérésekhez digitális mérőeszközöket készítettünk, mind\\ntanulói megismerési, mind tantárgyi (matematika) mérésekhez. Ezeket az eszközöket innovatív\\nmesterpedagógusaink készítették, akik a mérések lebonyolításában és kiértékelésében is segítséget\\nnyújtatnak a mérést vezető pedagógusoknak.\\nTöbb pedagógus digitális osztályteremet is használ a tanulókkal való online kapcsolattartásra,\\nfeladat kiosztásra, támogatva a digitális tanulói portfolió létrehozását. Több természettudományos tantárgyban (fizika, kémia, biológia, természetismeret,\\nkörnyezetismeret) és angol nyelv tantárgyban is használnak a pedagógusok online értékelő\\neszközöket, egyelőre leginkább formatív eszközként. (Socrative, Redmenta, Google Forms,\\nLearningApps, Edmodo, Quizlet, Kahoot stb.) A Komplex Alapprogram Digitális Alprogramja megvalósul a  tanórákon.", "mtmi_digitalis_tananyagok_megvalosul_bemutatasa": "Pályaorientációs mérés, Learningapps, Redmenta, Kahoot, Quizizz, MAtific stb.", "mtmi_korszeru_felszereltseg_megvalosul_bemutatasa": "Minden pályázati lehetőséget megragadunk, hogy fejleszthessük felszereltségünket. ", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul": "igen", "mtmi_tovabbkepzesek_idokeret_megvalosul_bemutatasa": "Fizikatanári Ankét, Komplex természettudományos egyetemi képzés, Fizika tanítása Doktori Iskola", "mtmi_tovabbkepzesi_programok_megvalosul_bemutatasa": "Fizika tanítása Doktori Iskolában 1 fő phD tanulmányokat végez. 1 kolléga környezettan szakon folytat tanulmányokat. IKT módszerek bemutatása a munkaközösségi értekezleteken\\nRészvétel a POK szakmai képzésein, programjain.\\nLegoMatek, Logikd képzésen való részvétel, ECDL vizsgalehetőség., High TEch Suli Konferencia.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul": "igen", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul_bemutatasa": "Minden pedagógus esetén egy teljesítménycél a munkatervben szereplő feladat, program megvalósítására,\\n egy teljesítménycél a tantárgyi, tantárgypedagógiai feladatok megvalósítására,\\n egy teljesítménycél pedig az érintett személyes szakmai fejlődésére vonatkozik.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul_bemutatasa": "Fizikatanári Ankét, a továbbképzés nyilvántartási száma: A/13605/2025; a továbbképzés jegyzékre vételi száma: J/6317/2025"}	2025-09-17 05:45:59.202387	2026-03-15 09:31:08.209971	1	\N	1a4039ac-ecab-4f5a-8544-d01732c8f95c
c55a7231-0fae-470e-a75d-dc2df297b09c	{"iskolatipus": [], "gdpr_consent": [], "mtmi_csapat_tag1_szak": [], "mtmi_csapat_tag2_szak": [], "mtmi_csapat_tag3_szak": [], "mtmi_csapat_tag4_szak": [], "mtmi_csapat_tag5_szak": [], "mtmi_csapat_tag6_szak": [], "mtmi_csapat_tag7_szak": [], "mtmi_csapat_tag8_szak": [], "mtmi_szakkor_tantargyak": []}	2026-03-11 19:31:05.090244	2026-03-12 14:05:31.956702	0	\N	\N
008c0533-8474-4af1-90e9-8408a60c0c47	{"iskola_cime": "8000, Székesfehérvár Széna tér 10.", "iskolatipus": ["altalanos_iskola"], "gdpr_consent": ["on"], "szulo_bevonas": "megvalosul", "mtmi_koncepcio": "igen", "telepulesforma": "megyeszekhely_varos", "mtmi_nyilt_napok": "A „Jövő városa” projekt zárásaként az iskola külön bemutatót szervez a programban részt vevő tanulók szülei számára. A rendezvény célja, hogy a szülők közvetlenül megismerjék gyermekeik alkotásait, a projekt során használt digitális eszközöket és az MTMI szemlélet gyakorlati megvalósulását.\\nA projekt eredményeit egy másik alkalommal bázisintézményi bemutató keretében is ismertetjük, ahol más intézmények pedagógusai számára nyílik lehetőség a jó gyakorlatok megismerésére, szakmai párbeszédre és tapasztalatcserére. Mindkét esemény előzetesen meghirdetésre kerül az iskola honlapján, és dokumentációval együtt utólag is elérhető lesz, ezzel is erősítve az MTMI tevékenységek láthatóságát és szakmai beágyazottságát.", "szulo_egyeztetes": "megvalosul", "mtmi_csapat_link1": "https://szenateri.hu/", "mtmi_projektnapok": "Iskolánkban kiemelt szerepet kapnak a projektnapok, amelyek a kompetenciaalapú, élményközpontú oktatást szolgálják. Célunk, hogy tanulóink gyakorlati tapasztalatokon keresztül ismerkedjenek meg a világ működésével, különös tekintettel az MTMI területekre.\\nA Pályaorientációs nap évek óta működik intézményünkben. Ezen a napon a tanulók üzemlátogatásokon, cégeknél, vállalatoknál vesznek részt, vagy az iskolába érkező szülők, volt diákok mesélnek szakmájukról, karrierútjukról. A program célja, hogy minél több hivatást, köztük MTMI szakmákat is megismerjenek, és tudatosabb pályaválasztási döntéseket hozzanak. A szervezést a pályaválasztásért felelős pedagógus koordinálja, az osztályfőnökök aktív közreműködésével.\\nAz Egészségvédelmi nap a helyes életmódra nevelés jegyében zajlik. A tanulók előadásokon és interaktív foglalkozásokon vesznek részt, ahol megismerkednek az egészséges táplálkozás alapjaival, az elsősegélynyújtás elméleti és gyakorlati tudnivalóival. A program fejleszti a szociális kompetenciákat, az empátiát, és együttműködünk helyi mentőszervezetekkel, laborokkal is.\\nA Digitális Témahét ötödik alkalommal kerül megrendezésre iskolánkban. A program célja a digitális kompetenciák fejlesztése, a digitális eszközhasználat tudatos és kreatív alkalmazása minden tantárgyban. A tanulók projektmunkák során digitális technológiákat\\nhasználnak, ezzel is felkészülve a továbbtanulás és a munka világának elvárásaira.\\nA Fenntarthatósági Témahét keretében a tanulók környezeti és társadalmi problémákat dolgoznak fel projektalapon. A programban megjelenik a természettudomány, a technológia és a mérnöki gondolkodás, miközben a diákok kutatnak, kísérleteznek, adatokat gyűjtenek és prezentálnak. A fenntarthatóság elveinek megismerése mellett szemléletformálás is történik, amely hosszú távon segíti a felelős állampolgárrá válást.\\nPénz7-Pénzügyi és Vállakozási Témahéthez iskolánk a tavalyi tanévben csatlakozott először. A témahét sikere miatt az idén is az MTMI munkatervünk része.", "pedprog_mtmi_link1": "https://szenateri.hu/doku/PP2023.pdf", "szulo_kommunikacio": "megvalosul", "iskola_honlap_link1": "https://szenateri.hu/", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "8", "palyazo_iskola_neve": "Székesfehérvári Széna Téri Általános Iskola", "pedprog_mtmi_leiras": "\\"Iskolánkban nagy hangsúlyt fektetünk a középiskolai tanulmányokra való felkészítésre. Emelt óraszámú matematikaoktatásunk, idegennyelvi- és digitáliskultúra-oktatásunk, valamint a természettudományok oktatása kiemelt helyen való kezelése biztos alapokat nyújt tanulóinknak. Pályaorientációs koordinátor pedagógus fogja össze széleskörű pályaorientációs tevékenységünket, melynek során komplex módon valósul meg a szaktanárok, osztályfőnökök, szülők, tanulók és a külső szakmai szervezetek hatékony együttműködése. Ezen együttműködések (FMKI, Szakma Sztár Kiállítás, Székesfehérvári Szakképzési Centrum, vállalatok, vállalkozók, műhelyek stb.) keretében a tanulók közvetlen tapasztalatokat szerezhetnek a szakmákról, azonnali információt kapnak a munkaerő piaci igényekről, azok folyamatos változásait követve tudnak dönteni pályaválasztásukról. \\"\\n\\"Célunk, hogy tudatos pályaorientációs tevékenységünkkel nyújtsunk segítséget a tanulóknak a továbbtanulás során.  Feladatunk: a pályaorientációt célzó tájékoztatások, előadások, fórumok, szakmai műhelyek beépítése a munkatervbe első évfolyamtól, a partnerek és a szülők bevonásával, pályaválasztásai kiállítások látogatásának megszervezésével, kamarai együttműködéssel.  Indikátorok: a szülők visszajelzései, beiskolázási mutatók. \\"\\n\\"3.5.12. A tanulók munkára nevelése, pályaorientáció Feladatunk felhívni a tanulók figyelmét a munka jelentőségére. Olyan foglalkozásokat szervezünk számukra, amelyek során betekintést nyerhetnek a munka világába, hogy aztán képesek legyenek tájékozottan és megfontoltan dönteni jövőbeli pályaválasztásukról. Segítjük őket annak érdekében, hogy felmérjék saját képességeiket, és érdeklődési területüknek, lehetőségeiknek és tudásuknak megfelelően határozott célokat tudjanak kitűzni maguk elé az optimális pályaválasztás érdekében, később pedig a munkaerőpiacon való helytálláshoz. \\"\\n \\"Tanítványaink pályaorientációját, aktív szakmai életútra történő felkészítését folyamatosan irányítjuk\\"", "mtmi_ceges_eloadasok": "igen", "mtmi_csapat_tag1_nev": "Viszugyelné Tanárki Erika", "mtmi_csapat_tag2_nev": "Kovácsné Koska Eszter ", "mtmi_csapat_tag3_nev": "Tandariné Takács Ibolya", "mtmi_csapat_tag4_nev": "Simon Judit", "mtmi_csapat_tag5_nev": "Gubián Dániel", "mtmi_csapat_tag6_nev": "Prédli Erika", "mtmi_csapat_tag7_nev": "Radics Rita ", "mtmi_csapat_tag8_nev": "Csapó Andrea", "mtmi_koncepcio_link1": "https://szenateri.hu/", "mtmi_szakkorok_szama": "6", "mtmi_szulo_kepviselo": "igen", "mtmi_alumni_programok": "igen", "mtmi_csapat_tag1_szak": ["biologia", "termeszettudomany", "technika"], "mtmi_csapat_tag2_szak": ["biologia", "foldrajz", "termeszettudomany"], "mtmi_csapat_tag3_szak": ["matematika", "fizika"], "mtmi_csapat_tag4_szak": ["matematika", "kemia"], "mtmi_csapat_tag5_szak": ["egyeb"], "mtmi_csapat_tag6_szak": ["kornyezetismeret", "egyeb"], "mtmi_csapat_tag7_szak": ["matematika", "egyeb"], "mtmi_csapat_tag8_szak": ["matematika", "kornyezetismeret", "egyeb"], "mtmi_koncepcio_leiras": "Alapozzuk együtt a jövőt – tudással, szívvel, közösségben!\\nElkötelezettek vagyunk tanulóink fejlesztő és támogató környezetének biztosítása érdekében, hogy ezzel is segítsük tudatos pályaválasztásukat és sikeres középfokú beiskolázásukat. Célunk, hogy a tanulók képességeikhez, érdeklődésükhöz és személyes céljaikhoz illeszkedő életpályát választhassanak, ehhez pedig több szinten és többféle eszközzel nyújtunk számukra segítséget. \\nTámogatjuk az MTMI tantárgyakhoz kapcsolódó tevékenységeket. Iskolánk felső tagozatán emelt óraszámú matematika- és digitális kultúraoktatás bevezetésére került sor 2020 szeptemberétől. \\nRendszeresen szervezünk tanulmányi versenyeket, és ösztönözzük a részvételt városi, megyei, országos megmérettetéseken. A szemléletformálás és a fenntarthatósági kompetenciák fejlesztése jegyében kiemelt figyelmet fordítunk a környezetvédelmi vetélkedőkön és programokban való részvételre. \\nKiemelt figyelmet fordítunk az egészségtudatos szemlélet közvetítésére és a fenntarthatósági kompetenciák fejlesztésére. Szakkörökkel, vetélkedőkkel, mozgáslehetőségek biztosításával, előadásokkal és foglalkozásokkal teremtünk támogató környezetet tanulóink testi-lelki jólléte érdekében. Célunk, hogy a gyerekek már korán elsajátítsák az egészséges életmód alapjait, gyakorlati ismereteket szerezzenek az alapvető életmentő technikákról és hosszú távon is képesek legyenek gondoskodni saját egészségükről miközben erősítjük bennük a felelős gondolkodást és a közösségi szerepvállalást.\\nAz iskola digitális infrastruktúrájának folyamatosan fejlődésével tanulóink korszerű eszközökkel, dolgozhatnak. A témanapok, témahetek és szakkörök keretében megvalósuló projektalapú tanulás során kreatív problémamegoldásra és együttműködésre ösztönözzük őket. A Microsoft felületek mindennapos használata támogatja a digitális oktatás hatékonyságát.\\nPályaorientációs rendezvények keretében működünk együtt középfokú intézményekkel, helyi vállalkozásokkal és szakmai szervezetekkel. \\n\\n", "pedprog_mtmi_tartalom": "igen", "szulo_palyaorientacio": "megvalosul", "mtmi_fakultaciok_szama": "0", "mtmi_muzeumlatogatasok": "igen", "iskola_tanuloi_letszama": "610", "mtmi_szakkor_tantargyak": ["matematika", "biologia", "digitalis_kultura", "termeszettudomany"], "mtmi_szakmak_bemutatasa": "igen", "szulo_egyeztetes_szoveg": "Az iskola a szülőkkel való rendszeres egyeztetést elsősorban az SZM (Szülői Munkaközösség) képviselőin keresztül valósítja meg. Évente két alkalommal kerül sor SZM-gyűlésre, ahol az intézmény vezetése tájékoztatást ad az aktuális oktatási célokról, így az MTMI területeket érintő fejlesztésekről is. Az itt elhangzott információkat az osztályok szülői képviselői e-mailben továbbítják a szülőtársaknak, illetve a szülői értekezleteken is részletes tájékoztatás történik.\\nAz MTMI célokhoz kapcsolódó programokról a szülők rendszeresen értesülnek az igazgató asszony által küldött tájékoztató e-mailekből, valamint a KRÉTA- rendszeren keresztül. Kiemelt figyelmet kapnak a DTH (Digitális Témahét) és FTH (Fenntarthatósági Témahét) eseményei, melyek előtt minden alkalommal az osztályfőnökök továbbítják az igazgatói tájékoztatót, ismertetve a témahetek céljait, tartalmát és elveit.\\nAz évfolyamokat vagy osztályokat érintő MTMI-kezdeményezésekről az osztályfőnökök külön e-mailben tájékoztatják a szülőket. A témahetek lebonyolítása szigorú forgatókönyv szerint történik, amelynek egyik kiemelt eleme a szülők és tanulók előzetes tájékoztatása.\\nTovábbi jó gyakorlatként az iskola honlapján rendszeresen megjelennek beszámolók, fotók és eredmények az MTMI-hez kapcsolódó projektekről, versenyekről és eseményekről, ezzel is erősítve a szülők bevonását és az intézményi láthatóságot. A szülők részéről érkező visszajelzéseket az iskola vezetése figyelembe veszi a jövőbeli programok tervezésekor, ezzel is elősegítve az MTMI szemlélet hosszú távú beépülését az intézményi működésbe.", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "nem", "mtmi_szakmai_gyakorlatok": "Iskolánk rendszeresen szervez szakmai napokat bázisintézményi bemutató foglalkozások formájában, amelyek célja az innovatív pedagógiai gyakorlatok megosztása, különös tekintettel az MTMI területekhez kapcsolódó módszerekre. A 2023/24-es tanévben a Digitális Témahét keretében a hatodik évfolyamos tanulók „Mesterséges intelligencia: A kreativitás vége vagy egy új kezdet? – TOLDI a MI szemszögéből” című projektjükkel országos első helyezést értek el. A projekt során a tanulók digitális eszközökkel dolgozták fel az irodalmi művet, mesterséges intelligenciát alkalmazva kreatív tartalmakat hoztak létre. A projektet vezető pedagógusok bázisintézményi bemutató órát tartottak, ahol a résztvevők megismerhették a digitális pedagógia és az MTMI kompetenciák fejlesztésének gyakorlati lehetőségeit.\\nAz idei tanévben is aktívan részt veszünk a pedagógiai napokon, mind az őszi, mind a tavaszi alkalmakon. Október 6-án Magilniczki-Galambos Kitti kolléganőnk „Internetbiztonság gyerekeknek és felnőtteknek – Képernyő mögött leselkedő veszélyek” címmel tartott előadást, amely nagy érdeklődést váltott ki. Az előadás során bemutatásra kerültek a digitális térben való biztonságos viselkedés alapelvei, a kiberbiztonság pedagógiai megközelítése, valamint a szülők és pedagógusok szerepe a digitális tudatosság kialakításában.\\nA szakmai gyakorlatok célja, hogy a pedagógusok megismerjék és alkalmazzák az MTMI területekhez kapcsolódó korszerű módszertani eszközöket, és ezeket beépítsék a mindennapi oktatásba. A bemutató órák és előadások hozzájárulnak a tantestület szakmai fejlődéséhez, a tanulók pedig élményszerű, kompetenciaalapú tanulásban vehetnek részt.\\n", "mtmi_egyetemi_gyakorlatok": "nem", "mtmi_szakkor_diakok_szama": "70", "mtmi_szakkorok_bemutatasa": "Iskolánkban több szakkör is támogatja az MTMI szemléletet. Az elsősegély szakkör évek óta sikeresen működik. Mentőtiszt bevonásával tanulják meg a diákok az életmentő technikákat. A „Jövő városa” projekt a Maker’s Redbox program része, ahol a gyerekek digitális eszközökkel (lézervágó, 3D nyomtató, Microbit) tervezik meg a jövő városát, fejlesztve kreativitásukat és technológiai tudásukat.\\nA szorobán szakkörön japán számolóeszközt használnak, algoritmusokat tanulnak, figyelmet fejlesztenek. BTMN és SNI-s tanulók is aktívan részt vesznek. \\nA természetismeret szakkör a negyedikes tananyag gyakorlati kiegészítése kísérletekkel, megfigyelésekkel.\\nA Beebot programozási foglalkozásokon alsós diákok robotméhecskékkel ismerkednek a programozás alapjaival. A foglalkozások fejlesztik a logikai gondolkodást, szövegértést, játékos formában. A program idén második évfolyamon folytatódik.\\nA matematika szakkör a 4. évfolyamon versenyfelkészítést és digitális platformok használatát ötvözi, fejlesztve a logikus gondolkodást. Tehetséggondozó foglalkozások (matematika, biológia, természettudomány) versenyekre készítenek fel. A felzárkóztató órák (matematika) esélyegyenlőséget biztosítanak a gyengébben teljesítőknek.\\n", "szulo_munkakoz_ismertetes": "megvalosul", "mtmi_szakkor_tanarok_szama": "6", "iskola_mtmi_tanari_letszama": "10+", "mtmi_diakok_kapcsolattartas": "igen", "mtmi_kapcsolatok_bemutatasa": "Iskolánkban rendszeresen szervezünk céglátogatásokat és szakembertalálkozókat, melyek célja, hogy a tanulók közvetlen tapasztalatot szerezzenek az MTMI területekhez kapcsolódó szakmákról és munkahelyekről. A programok során diákjaink ellátogatnak különböző cégekhez, mint például a Denso, Emerson, Interspar, Táska Rádió, Zrínyi cukrászda, Etyeki filmgyár, SKILL labor, valamint helyi pékségek, asztalosműhelyek és családi vállalkozásokhoz is.\\nEmellett szakemberek és szülők is rendszeresen bemutatják hivatásukat az osztályoknak: játékkészítő, építészmérnök, informatikus, könyvkötő, szakács, régész, orvos, röntgenasszisztens, valamint dróntechnológiával foglalkozó szakember is megosztotta tapasztalatait. Többek között a  Székesfehérvári Deák Ferenc Kereskedelmi és Vendéglátóipari Szakközépiskola igazgatója is tartott pályaorientációs előadást.\\nRendszeresen visszük osztályainkat az Alba Innovár Digitális Élményközpontba.\\nA céglátogatásokról és szakmai programokról honlapunkon és az iskola Facebook oldalán, illetve az osztálycsoportokban rendszeresen beszámolunk, ezzel is erősítve a tanulók pályaválasztási tudatosságát és az MTMI területek iránti érdeklődésüket.", "mtmi_online_palyaorientacio": "igen", "mtmi_rendezvenyek_reszvetel": "igen", "lanyok_mtmi_kiemelt_figyelem": "igen", "mtmi_alumni_programok_leiras": "A sikeres életutak nem csak célba érnek.\\n\\nVisszatérnek, hogy aztán másokat is elindítsanak.\\n\\nA Széna Téri Általános Iskola nevelőtestülete aktív szerepet vállal abban, hogy tanulóink felkészülten, motiváltan és tudatosan lépjenek tovább a középfokú oktatás irányába. Az intézmény célja, hogy minden tanuló számára biztosítsa azokat a lehetőségeket, amelyek révén képességeik kibontakozhatnak, és megalapozott döntést hozhatnak jövőjükről.\\n\\n\\nAz iskola egykori növendékei, az alumni közösség tagjai értékes példaképek tanulóink számára. Osztályfoglalkozásokra, pályaorientációs napokra vagy beszélgetésekre való meghívásuk lehetővé teszi, hogy a gyerekek valós életutakat ismerjenek meg, nyitottabban mérjék fel lehetőségeiket és inspirációt kapjanak saját jövőjük tervezéséhez.\\n\\n\\nÖregdiákjaink személyes történetei, sikerei és tapasztalatai hitelesen mutatják meg, hogy az általános iskolai alapok milyen sokféle irányba vezethetnek, egy-egy tanulságos történet pedig megerősítheti a gyerekeket abban, hogy érdemes célokat kitűzni és kitartani mellettük.", "mtmi_csapat_tag1_tevekenyseg": "Feladatai közé tartozik:\\n• \\tTermészettudományos versenyekre való felkészítés (pl. Hanon Környezetvédelmi vetélkedő, Madarak és Fák napja Országos verseny, Kaán Károly Országos Természet- és Környezetvédelmi verseny, Herman Ottó Kárpát-medencei Biológia verseny, ZöldOkos Kupa)\\n• \\tTehetséggondozás az 5–6. évfolyamon\\n• \\tVersenyszervezés (pl. Víz világnapja területi csapatverseny)\\n• \\tTantárgyközi együttműködés koordinálása", "mtmi_csapat_tag2_tevekenyseg": "Tevékenységei az MTMI programhoz kapcsolódóan:\\n• \\tTermészettudományos versenyekre való felkészítés: Hanon Környezetvédelmi vetélkedő, Madarak és Fák napja Országos verseny, Kaán Károly Országos Természet- és Környezetvédelmi verseny, Herman Ottó Kárpát-medencei Biológia verseny, ZöldOkos Kupa\\n• \\tSzakkörvezetés: Elsősegély szakkör\\n• \\tVersenyszervezés: Madarak és Fák napja Országos verseny megyei fordulója, Bázisiskolai Elsősegély verseny\\n• \\tKözösségi szerepvállalás: Osztályfőnök és az osztályfőnöki munkaközösség vezetője\\nMunkájában kiemelt figyelmet fordít a tanulók tehetséggondozására, az együttműködésre épülő tanulási formákra, valamint a természettudományos gondolkodás fejlesztésére. Tantárgyközi szemlélete és szervezői tevékenysége révén aktívan hozzájárul az MTMI program sikeres megvalósításához. Vöröskeresztes Bázisiskola koordinátoraként támogatja a diákok egészségfejlesztését és segíti  közösségi.\\nA pályaorientációs tevékenységek koordinátora\\n\\n", "mtmi_csapat_tag3_tevekenyseg": "Matematika tehetséggondozás felső tagozaton\\n• \\tZrínyi Ilona matematika versenyre való felkészítés\\n• \\t„UNIverZOOM – Kísérletezz velünk!” program vezetése, amelyben fizikai kísérleteken keresztül mutatja be a természettudományos gondolkodás gyakorlati alkalmazását – Földön és az űrben zajló jelenségek vizsgálatával\\nMunkájában kiemelt szerepet kap a kísérletezés, a problémamegoldás és az élményszerű tanulás, amely erősíti a tanulók érdeklődését a természettudományos pályák iránt. A programok során rendszeresen alkalmaz kooperatív tanulási formákat, digitális eszközöket, és támogatja a tanulók önálló gondolkodását.", "mtmi_csapat_tag4_tevekenyseg": "- Versenyszervezés: Sudoku területi verseny, Kenguru Matematika verseny, Zrínyi Ilona matematika verseny\\n- Tehetségmérés: MaTalent matematika tehetségazonosító program koordinálása az 5. évfolyamon\\n- Közösségi szerepvállalás: Osztályfőnök, aktív részvétel az osztályfőnöki munkaközösségben\\n- Reál munkaközösség vezetője\\nMunkájában kiemelt figyelmet fordít a matematikai tehetséggondozásra, a tanulók motiválására és a versenyeken való részvétel ösztönzésére. A versenyek szervezésével és a tehetségmérési programokkal hozzájárul az MTMI kompetenciák fejlesztéséhez, valamint a tanulók pályaorientációs lehetőségeinek bővítéséhez.", "mtmi_csapat_tag5_tevekenyseg": "Gubián Dániel történelem–etika szakos pedagógus, az MTMI csapat tagja, aki a „Jövő városa” című Maker’s Red Box projekt vezető pedagógusaként aktívan hozzájárul az MTMI szemlélet tantárgyközi megvalósításához.\\nA projekt szakköri keretek között valósul meg, és célja, hogy a tanulók kreatív módon, interdiszciplináris megközelítéssel dolgozzanak várostervezési, környezettudatossági és technológiai témákon. A program során kiemelt szerepet kap a digitális eszközhasználat, a problémamegoldás, a kooperatív tanulás és a pályaorientáció. \\nA kolléga elkötelezett a pénzügyi tudatosság fejlesztése iránt is, ennek jegyében évek óta aktívan részt vesz a Pénz7 országos program lebonyolításában  8. évfolyamos tanulókkal. A program nemcsak a tanulók pénzügyi ismereteit bővíti, hanem hozzájárul a kritikus gondolkodás és a problémamegoldó képesség fejlesztéséhez is, amely szorosan kapcsolódik az MTMI területekhez.\\nOsztályfőnökként is aktív szerepet vállal a tanulók közösségi nevelésében, és munkájával erősíti az MTMI program társadalomtudományi kapcsolódásait, különös tekintettel az etikai, történelmi és környezeti összefüggésekre.", "mtmi_csapat_tag6_tevekenyseg": "Alsós tanító, az MTMI csapat tagja, aki az alsó tagozatos munkaközösség vezetője. Tanítóként kiemelt szerepet vállal a természettudományos  kompetenciák megalapozásában.\\nFőbb tevékenységei:\\n-Természettudományos versenyekre való felkészítés\\n- Közösségi szerepvállalás: osztályfőnök, alsós munkaközösség vezető\\nMunkájában kiemelt figyelmet fordít a differenciált fejlesztésre, a tanulók egyéni képességeinek kibontakoztatására, valamint a korai MTMI kompetenciák megerősítésére. Az alsó tagozaton végzett munkája megalapozza a felsőbb évfolyamokon történő tehetséggondozást és a tantárgyközi szemléletű MTMI program sikeres megvalósítását.\\nA pályaorientációs tevékenységek koordinátora.", "mtmi_csapat_tag7_tevekenyseg": "Alsós és felsős pedagógusként, az MTMI csapat tagja, aki kiemelt figyelmet fordít a matematikai kompetenciák fejlesztésére.\\nFőbb tevékenységei:\\n• \\tSzorobán szakkör vezetése, amely a japán abakusz módszerével fejleszti a számolási készséget, koncentrációt és logikai gondolkodást\\n• \\tVersenyfelkészítés: Medve Matek, Láng-Ész Kreatív verseny, Zrínyi Ilona matematika verseny\\n• \\tMatematikai felzárkóztatás: egyéni és kiscsoportos fejlesztés a tanulók egyéni szükségleteihez igazítva\\nMunkájában kiemelt szerepet kap a differenciált oktatás, az élményszerű tanulás és a tehetséggondozás. A szorobán módszer alkalmazása különösen hatékony az alsó tagozatos MTMI kompetenciák megalapozásában, és hozzájárul a tanulók önbizalmának és tanulási motivációjának növeléséhez. Expertként is támogatja a nevelőtestületet a digitális oktatás hatékonyságának növelése érdekében.", "mtmi_csapat_tag8_tevekenyseg": "\\nAlsós tanító, az MTMI csapat tagja, aki kiemelt figyelmet fordít a természettudományos és matematikai kompetenciák megalapozására az alsó tagozaton.\\nFőbb tevékenységei:\\n• \\tTermészetismeret szakkör vezetése a 4. évfolyamon, amely játékos, élményszerű módon fejleszti a tanulók környezeti érzékenységét és megfigyelőképességét\\n• \\tVersenyfelkészítés alsós matematika versenyekre\\n• \\tMatematikai felzárkóztatás egyéni és kiscsoportos formában\\n• \\tKapcsolattartás állat- és természetvédő szervezetekkel lehetőséget biztosítva a tanulók környezettudatos szemléletének formálására, iskolán kívüli tanulási alkalmak szervezésére\\nMunkájában kiemelt szerepet kap a környezeti nevelés, a tanulók aktív bevonása és a tapasztalati tanulás. Tevékenységei hozzájárulnak az MTMI szemlélet korai megalapozásához, és elősegítik a tanulók érdeklődésének felkeltését a természettudományos világ iránt.", "mtmi_aktiv_tanulas_megvalosul": "igen", "mtmi_csapat_kozos_tevekenyseg": "Közös tevékenységek az egész tanévet átfogják, és különböző korosztályokat szólítanak meg:\\nTémahetek\\n• Digitális Témahét (DTH) – felső tagozaton projektalapú tanulással, digitális eszközökkel támogatott kutatómunkával\\n• Fenntarthatósági Témahét (FTH) – alsó tagozaton játékos, élményszerű foglalkozásokkal, környezettudatos szemléletformálással\\n• \\"Pénz7\\" pénzügyi és vállalkozói témahét – a felsős tanulók pénzügyi tudatosságát fejlesztő, interaktív foglalkozásokkal kiegészített országos program\\nTémanapok\\n• Pályaorientációs nap – MTMI pályák bemutatása, interaktív foglalkozások, szakmabemutatók\\n• Egészségvédelmi nap – biológiai, kémiai és életviteli ismeretek integrált feldolgozása\\nVersenyszervezések\\n• Sudoku verseny – logikai gondolkodás fejlesztése\\n• Madarak és Fák Napja Országos Verseny – vármegyei forduló\\n• Víz világnapja – területi csapatverseny 5–6. évfolyamosoknak\\n• „Légy SZER-telen!” – háziverseny 5–8. évfolyam számára\\n• Bázisiskolai Elsősegély verseny – területi forduló\\n• Újraélesztés napja – interaktív egészségügyi ismeretterjesztés\\n• „Év számolója” verseny – 5–8. évfolyam\\n• „Matek Mikulás” – szabadulószoba – játékos, kooperatív problémamegoldás matematikai feladatokon keresztül\\nA programok során a pedagógusok közösen terveznek, megosztják módszertani tapasztalataikat, és aktívan bevonják a tanulókat a szervezésbe is. A tevékenységek célja, hogy élményszerű tanulási helyzeteken keresztül fejlesszék a 21. századi kompetenciákat, erősítsék a tanulók motivációját, és támogassák a tudatos pályaválasztást.\\n\\n", "mtmi_fakultaciok_diakok_szama": "0", "mtmi_kiallitoterek_megvalosul": "igen", "lanyoknak_szolo_mtmi_programok": "igen", "mtmi_egyeb_tevekenysegek_szama": "8", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_kutatási_versenyek_link1": "https://szenateri.hu/", "mtmi_kutatási_versenyek_szama": "6", "mtmi_laboratoriumok_latogatasa": "nem", "mtmi_otlet_esszepalyazat_link1": "https://szenateri.hu/", "mtmi_otlet_esszepalyazat_szama": "1", "intezmenytipus_tanuloi_letszama": "610", "mtmi_ceges_eloadasok_bemutatasa": "Iskolánk rendszeresen fogad céges előadókat és szakembereket, akik MTMI témájú előadásokat és interaktív foglalkozásokat tartanak tanulóinknak. Vendégként érkeztek már informatikusok, építészmérnökök, dróntechnológiával foglalkozó szakemberek, könyvkötők, orvosok, röntgenasszisztensek, valamint a Székesfehérvári Deák Ferenc Kereskedelmi és Vendéglátóipari Szakközépiskola igazgatója is.\\nEmellett az Iparkamara által szervezett gyárlátogatásokon is részt veszünk, ahol a tanulók közvetlenül ismerkedhetnek meg MTMI területeken működő cégekkel és munkafolyamatokkal.\\nAz eseményekről honlapunkon is beszámolunk, ezzel is támogatva a pályaorientációt és az MTMI területek iránti érdeklődést.", "mtmi_faliujsag_vitrin_reszvetel": "igen", "mtmi_palyaorientacio_megvalosul": "igen", "mtmi_faliujsag_vitrin_bemutatasa": "Iskolánkban a versenyek meghirdetése és az eredményes tanulók elismerése többféle módon történik, biztosítva ezzel a széles körű tájékoztatást és a közösségi elismerést.\\nA versenykiírások és eredmények az osztályok Teams csoportjaiban jelennek meg, ahol a tanulók közvetlenül értesülnek a részletekről. A szülők számára emailben továbbítjuk a versenyekkel kapcsolatos tudnivalókat, míg a szaktanárok szóban és papíralapon is tájékoztatják az érdeklődőket. Emellett a versenykiírásokat az iskola folyosóin elhelyezett faliújságokon is közzétesszük, így minden tanuló számára látható módon jelennek meg az aktuális lehetőségek.\\nAz eredményes tanulók bemutatása az iskola több pontján is megvalósul. Az első emeleti aula vitrinjében helyezést elért tanulóink kupái, oklevelei kerülnek kiállításra, így mindenki számára látható módon jelennek meg az elért sikerek. A folyosói faliújságokon rendszeresen frissítjük a versenyeredményeket, míg az osztálytermek faliújságain az adott osztályhoz tartozó tanulók eredményei kapnak helyet.\\nA ballagási ünnepségek alkalmával Pro Díjakat adunk át a kiemelkedő teljesítményt nyújtó tanulóknak, nevüket és elismerésüket szintén az első emeleti aula központi részén tesszük közzé, ezzel is példát állítva a fiatalabb évfolyamok számára.\\nKiemelt figyelmet fordítunk arra, hogy a sikerek ne csak írásban jelenjenek meg: minden hónapban a hangosbemondón keresztül is felolvassuk az aktuális versenyeredményeket, így az egész iskolai közösség közvetlenül értesül a tanulók teljesítményéről, ami motiváló és közösségformáló hatású.\\nA versenyek meghirdetése és az eredmények bemutatása így nemcsak informatív, hanem inspiráló erejű is, hozzájárulva az MTMI területek iránti érdeklődés növeléséhez és a tanulói közösség megerősítéséhez.", "mtmi_felelos_kapcsolattarto_neve": "Viszugyelné Tanárki Erika", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "igen", "mtmi_tanoran_kivuli_rendezvenyek": "- pályaválasztási szülői\\n- Alba Innovár élményközpont látogatások 5. és 7. évfolyamosok\\n- Iparkamara által szervezett üzemlátogatások,  versenyek\\n- Pedagógiai szakszolgálat által tartott pályaorientációs foglalkozások\\n- Osztályfőnökök által szervezett pályaorientációs foglalkozások, múzeumlátogatások\\n-  Szakmai kiállítások\\n- Újraélesztés Világnapja\\n", "mtmi_tanulmányi_versenyek_szama": "22", "mtmi_muzeumlatogatasok_bemutatasa": "Iskolánk kiemelt figyelmet fordít arra, hogy a tanulók élményszerű módon ismerkedjenek meg a természettudományos és technikai területekkel. Ennek részeként rendszeresen szervezünk múzeumlátogatásokat, amelyek beépülnek az éves MTMI-tervezetbe, és ezekről honlapunkon is beszámolunk.\\nA programok jellemzően osztályfőnöki szervezésben, osztálykirándulások, pályaorientációs napok, erdei iskolák vagy nyári táborok keretében valósulnak meg. A látogatások célja, hogy a tanulók közvetlen élményeken keresztül mélyítsék el tudásukat és érdeklődésüket a természettudományos világ iránt.Az elmúlt években diákjaink ellátogattak többek között a bakonybéli Pannon Csillagdába, a Csodák Palotájába, a martonvásári Agroverzumba, a székesfehérvári Csillagvizsgálóba, a Patikamúzeumba, a Szent István Király Múzeumba (múzeumi foglalkozások és kiállítások keretében), a zirci Bakonyi Természettudományi Múzeumba, a Seeds Bonbon magkiállításra, valamint a Bakonyi Erdők Házába.\\nTechnikai és természeti témájú helyszíneink között szerepel még a budapesti és veszprémi állatkert, a LightArt múzeum, a Gaja-völgyi Tájcentrum, a Pákozdi Arborétum, a keszthelyi Vasúttörténeti és Természettudományi Kiállítás, a székesfehérvári Sóstói Tanösvény, valamint a szilvásváradi Archeopark.\\nEzek a látogatások nemcsak  diákjaink ismeretét bővítik, hanem motiváló hatásúak is, hozzájárulnak a tanulók pályaorientációjához és az MTMI-területek iránti érdeklődésük elmélyítéséhez.", "programban_erintett_tanulok_szama": "592", "mtmi_diakok_kapcsolattartas_leiras": "Iskolánkban biztosított a tanulók számára a személyes kapcsolattartás lehetősége a pályaválasztásért felelős pedagógussal, különös tekintettel az MTMI tanulmányi irányokra és karrierlehetőségekre. A diákok az iskola épületében előre egyeztetett időpontban közvetlenül felkereshetik a pályaorientációs feladatokat ellátó kollégát, aki egyéni beszélgetések, tanácsadások keretében segíti őket az érdeklődési körüknek megfelelő továbbtanulási irányok feltérképezésében.\\nEmellett az osztályfőnökök is aktív szerepet vállalnak a kapcsolattartás elősegítésében: szükség esetén közvetítenek a tanulók és a pályaválasztásért felelős pedagógus között, illetve tájékoztatást nyújtanak az MTMI területekhez kapcsolódó lehetőségekről. Az osztályfőnöki órákon rendszeresen szó esik a továbbtanulásról, pályaválasztásról, és az MTMI szakmákhoz kapcsolódó kompetenciák fejlesztéséről.\\nAz osztályfőnökök kapcsolatban állnak a pedagógiai szakszolgálattal, így szükség esetén a tanulók számára elérhetővé teszik a szakszolgálat pályaorientációs tanácsadási szolgáltatásait is. Ez különösen hasznos lehet azoknak a diákoknak, akik komplexebb támogatást igényelnek az érdeklődési körük, képességeik és lehetőségeik összehangolásához.\\nA kapcsolattartás lehetősége minden évfolyam számára nyitott, de kiemelt figyelmet fordítunk a 7–8. évfolyamos tanulókra, akik a továbbtanulás küszöbén állnak. A személyes konzultációk, az osztályfőnöki közvetítés és a szakszolgálati együttműködés együttesen biztosítják, hogy tanulóink megalapozott döntést hozhassanak az MTMI területeken való továbbtanulásról.", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyeb_tovabbkepzesi_programok": "Az iskola pedagógusai számára elérhető egyéb MTMI-témájú képzések:\\n• \\tMaker’s Red Box – A jövő városa projekt\\n• \\tBelső coaching és mentori támogatás\\n• \\tOnline képzések és webináriumok\\n• \\tBázisintézményi jógyakorlatok megosztása\\n• \\tDigitális eszközökkel támogatott oktatás módszertani képzései\\nA képzések kiválasztásánál szempont, hogy gyakorlatorientáltak legyenek, és azonnal alkalmazható módszereket kínáljanak. Bár anyagi támogatás nem minden esetben biztosított, a pedagógusok elkötelezetten vesznek részt a fejlődést szolgáló programokban.", "mtmi_egyuttmukodes_palyaorientacio": "igen", "mtmi_felelos_kapcsolattarto_email1": "tanarki76@gmail.com", "mtmi_felelos_kapcsolattarto_email2": "iskola@szenateri.hu", "mtmi_online_palyaorientacio_leiras": "Iskolánk aktívan használja az Oktatási Hivatal által fejlesztett Pályaorientációs Mérő- és Támogatóeszközt (POM), amely egy online platformként segíti a tanulók pályaválasztását. A POM célja, hogy a diákok érdeklődési körük, képességeik és attitűdjeik alapján kapjanak visszajelzést arról, mely pályaterületek illenek hozzájuk – különös tekintettel az MTMI irányokra.\\nA platform négy kérdőívet tartalmaz, amelyek az érdeklődést, kompetenciákat, személyes tulajdonságokat és a pályaválasztási attitűdöket vizsgálják. A kitöltés után a tanulók részletes visszajelzést kapnak erősségeikről, érdeklődési területeikről, valamint ajánlásokat a hozzájuk illő szakmákról és képzésekről. A rendszer különösen hasznos a 7–8. évfolyamos tanulók számára, akik a továbbtanulás előtt állnak, de az alsóbb évfolyamokon is alkalmazható önismereti célból. A POM használata egyéni és csoportos formában is megvalósul, pedagógusi irányítással. A pályaválasztásért felelős pedagógus segíti a tanulókat a regisztrációban, a kérdőívek értelmezésében és az eredmények feldolgozásában. A platform elérhetősége, valamint a használatára vonatkozó tájékoztató anyagok megtalálhatók az iskola honlapján is, ezzel is támogatva a tanulók és szüleik tudatos döntéshozatalát.\\nA POM alkalmazása jól illeszkedik az iskola pályaorientációs programjába, és hatékonyan kiegészíti a személyes tanácsadást, a pályaorientációs napokat, valamint az MTMI területekhez kapcsolódó versenyeket és projekteket.", "mtmi_otlet_esszepalyazat_reszvetel": "igen", "mtmi_tanulmányi_verseny_reszvetel": "igen", "mtmi_tovabbkepzesi_programok_link1": "https://szenateri.hu/", "intezmenyvezeto_kapcsolattarto_neve": "Dr. Lórodiné Lajkó Ágnes", "mtmi_kutatási_verseny_diakok_szama": "69", "mtmi_kutatási_versenyek_bemutatasa": "Versenyek: UNIverZoom - még zajlik, Kapu Tibor űrállomáson végzett kísérleteit a gyerekek tanáruk mentorálásával megismerik és ő maguk is elvégik földi környezetben.\\nKörnyezetvédelem a jövőér! - a legjobb 25 csapatba bejutott 3 csapatunk, ebből a legjobb eredményt elérő csapat 5. lett (2024-ben). A versenyt a Hanon Systems Kft szervezi már 26 éve, a többfordulós verseny a gyerekek széleskörű természettudományi tudására épít.\\nSzebeni Mária Kémiai Emlékverseny - országos 4. és 6. hely (2024-ben). Egyéni kémiaverseny, több online forduló után az országos verseny  személyes megjelenéssel zajlik.\\nProjektek:  \\"Jövő városa\\" projekt, Digitális Témahét, Fenntarthatósági Témahét, Pénz7-Pénzügyi és Vállalkozási Témahét, Egészségvédelmi nap", "mtmi_otlet_esszepalyazat_bemutatasa": "Iskolánk a Digitális Témahét országos ötletpályázatán vett részt hatodik évfolyamos tanulóival. A pályázat témája a mesterséges intelligencia és a kreativitás kapcsolata volt: „Mesterséges intelligencia – a kreativitás vége vagy egy új kezdet?” Diákjaink „Toldi a MI szemszögéből” című projektjükkel országos 1. helyezést értek el.\\nProjektben résztvevő pedagógusok: Magilniczki-Galambos Kitti, Kovácsné Koska Eszter, Majorné Szarka Tünde, Gubián Dániel és Mészáros Katalin.\\nA projekt során a tanulók Arany János Toldiját dolgozták fel digitális eszközök segítségével, kreatív és kutatásalapú megközelítéssel. A három osztály (6.i, 6.m, 6.ny) különböző énekeket kapott feldolgozásra. A diákok mesterséges intelligenciát alkalmaztak történetgenerálásra (CoPilot), képgenerálásra (tengr.ai), kvízkészítésre (Quizalize), valamint zenei feldolgozásra (Suno). Toldi történetének egyes részeit mai nyelvre, szlengre írták át, interjút készítettek Toldi karakterével, és saját rapszövegeket alkottak.\\nA projekt során a tanulók megismerkedtek a nádasok, az Alföld élővilágával és ezekből kvízeket készítettek. \\nA generált képeket papíron kiegészítették, így ötvözték a digitális és manuális alkotást.\\nA pályázat nemcsak a digitális kompetenciák fejlesztését szolgálta, hanem a kreatív gondolkodás, a csapatmunka és a kutatásalapú tanulás erősítését is. A projekt példaértékű módon mutatta be, hogyan válhat a mesterséges intelligencia az oktatásban a kreativitás eszközévé.\\n", "mtmi_digitalis_tananyagok_megvalosul": "igen", "mtmi_felelos_kapcsolattarto_beosztas": "tanár", "mtmi_kutatási_verseny_tanarok_szama": "8", "intezmenyvezeto_kapcsolattarto_email1": "igazgató@szenateri.hu", "intezmenyvezeto_kapcsolattarto_email2": "iskola@szenateri.hu", "mtmi_egyeb_palyaorientacios_programok": "Iskolánk a tanév során több olyan pályaorientációs programban is részt vesz, amelyek a korábban felsorolt tevékenységeken túlmutatnak, és tovább bővítik a tanulók lehetőségeit az MTMI területek megismerésére.\\nTanulóink rendszeresen látogatják a Pályaválasztási Kiállítást Székesfehérváron, ahol középiskolák, szakmai szervezetek és vállalatok mutatják be képzési kínálatukat, szakmáikat és karrierlehetőségeiket. A kiállítás lehetőséget ad arra, hogy a diákok közvetlenül tájékozódjanak a továbbtanulási irányokról, köztük az MTMI szakmákhoz kapcsolódó képzésekről.\\nRészt veszünk a Szakmasztár versenyen, amelyet Budapesten, a Hungexpo területén rendeznek meg. A program során a tanulók interaktív módon ismerkedhetnek meg különböző szakmákkal, kipróbálhatják az egyes tevékenységeket, és közvetlen kapcsolatba kerülhetnek szakemberekkel, oktatókkal. Iskolánk bekapcsolódik a „Mi a pálya?” rendezvénysorozat székesfehérvári állomásába is, amely kifejezetten az MTMI pályák népszerűsítését célozza. A rendezvényen látványos bemutatók, szakmai standok és interaktív foglalkozások várják a tanulókat.\\nA Fejér Vármegyei Kereskedelmi és Iparkamara által meghirdetett „Iparkodjunk Gyerekek” szakmaismereti vetélkedőn is rendszeresen részt vesznek tanulóink. A verseny során csapatban dolgozva ismerhetik meg a különböző szakmaterületeket, fejleszthetik együttműködési és problémamegoldó készségeiket.\\nAz idei tanévben iskolánk benevezett a „Szakmák világa” projektversenyre, amely lehetőséget ad arra, hogy a tanulók kreatív módon dolgozzanak fel egy-egy szakmához kapcsolódó témákat.\\nEzek a programok szervesen kiegészítik az iskola pályaorientációs tevékenységeit, és hozzájárulnak ahhoz, hogy tanulóink széles körű, élményszerű tapasztalatokat szerezzenek az MTMI területeken.", "mtmi_otlet_esszepalyazat_diakok_szama": "69", "mtmi_tanulmányi_versenyek_bemutatasa": "Alsó tagozatos versenyeink: Láng-Ész Kreatív verseny\\nBendegúz Matekász\\nIskolai matek versenyek 1-3.évf.\\nVíz világnapja  (rajz)\\nHétfejű tündér komplex alsós verseny\\nSudoku, helyi sudoku\\nMedve matek\\nÉn és az erdő (rajz)\\nZrínyi matek\\nAlapműveleti matek\\nFelsős versenyek: \\nZrínyi Ilona Matematika verseny\\nBolyai Matematika verseny\\nSudoku\\n  Légy Szer-telen!                                 \\nElsősegélyverseny\\nVíz világnapja verseny\\nMedve Szabadtéri Matematika verseny\\nKenguru Matematikaverseny\\nMatekÁsz\\nAlapműveleti Matematikaverseny\\nUNIverZoom \\nKaán Károly Országos Természet és Környezetvédelmi Verseny\\nHerman Ottó Kárpát-medencei biológia verseny\\nMadarak és Fák Napja Országos Verseny\\nHanon System \\"Környezetvédelem a jövőért\\"- vetélkedő\\nRákóczi kupa -matematika és természettudomány \\nZöldOkos kupa\\nEredményeink címszavakban:\\n• \\tOrszágos döntőbe jutás: Kaán Károly, Madarak és Fák Napja, MatekÁsz, Szebenyi Mária Kémia Verseny, Digitális Témahét, Elsősegély verseny\\n• \\tVármegyei I–III. helyezések: Alapműveleti matek, Elsősegélynyújtó verseny, Herman Ottó Biológia, Hanon System, Kaán Károly\\n• \\tTerületi és regionális sikerek: Sudoku, MedveMatek, Darts-matek, Nagy Digitális Kaland\\n• \\tIskolai és városi szintű eredmények: Víz világnapja, Rákóczi Kupa, Láng-Ész, helyi versenyek\\nA versenyeken való részvétel hozzájárul a tanulók tudásának elmélyítéséhez, motivációjuk növeléséhez, valamint az MTMI területek iránti érdeklődésük fejlesztéséhez.\\nAz elért eredményekről külön táblázatos összefoglalót csatolunk a pályázathoz.\\nA versenyeredményeket a pályázat végén csatolom.\\n\\n\\n                             \\n                                 ", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_otlet_esszepalyazat_tanarok_szama": "5", "mtmi_rendezvenyek_reszvetel_bemutatasa": "Iskolánk rendszeresen részt vesz országos és regionális MTMI-fókuszú rendezvényeken, amelyek célja a természettudományos és műszaki pályák népszerűsítése. Tanulóink több alkalommal látogattak el a Csodák Palotájába, ahol interaktív kiállításokon és tudományos bemutatókon vehettek részt.\\nRészt vettünk a SKILL Labor programjain is, ahol a diákok valósághű szimulációs környezetben próbálhatták ki az egészségügyi és MTMI területekhez kapcsolódó technológiákat. A laboratóriumi foglalkozások során modern eszközökkel sajátíthatták el a diagnosztikus, életmentő és műszaki beavatkozások alapjait, így gyakorlati tapasztalatot szerezhettek a pályaválasztásukat érintő területeken.\\nEmellett tanulóink ellátogattak a martonvásári Agroverzumba is, ahol a fenntartható mezőgazdaság, az élelmiszeripari innovációk és a természettudományos kutatások világába nyerhettek betekintést. Az interaktív kiállítások és tudományos bemutatók hozzájárulnak a környezettudatos gondolkodás és az MTMI területek iránti érdeklődés erősítéséhez.\\nEzek a programok élmény szerűen támogatják a tanulók pályaorientációját, és a részvételről honlapunkon is beszámolunk.", "mtmi_tanulmányi_verseny_tanarok_szama": "18", "intezmenyvezeto_kapcsolattarto_beosztas": "igazgató", "mtmi_interdiszciplinaris_projekt_leiras": "Iskolánkban kiemelt figyelmet fordítunk az interdiszciplináris projektekre, amelyek a STEAM szemléletet és az MTMI területekhez kapcsolódó kompetenciák fejlesztését szolgálják. A „Jövő városa” Makers Redbox-projekt során tanulóink csapatmunkában terveztek fenntartható várost, miközben 3D nyomtatást, micro:bit programozást, lézervágást és forrasztást alkalmaztak. A projekt fejleszti a mérnöki gondolkodást, a kreativitást és a digitális kompetenciákat, miközben valós problémákra keresnek megoldást.\\nAz „UNIverZOOM – Kísérletezz velünk!” programban iskolánk 8.i osztálya vesz részt Tandariné Takács Ibolya vezetésével. A program különlegessége, hogy Kapu Tibor, az Ax-4 űrmisszió magyar kutatóűrhajósa 2025 júniusában a Nemzetközi Űrállomáson végzett olyan fizikai kísérleteket, amelyeket szeptemberben a részt vevő iskolák diákjai földi környezetben is megismételnek. A tanulók a kísérleti dobozok eszközeivel dolgoznak, miközben videón követik az űrbeli kísérleteket, fizikatanáruk mentorálása mellett. A program egyedülálló lehetőséget biztosít a természettudományos gondolkodás és a kutatói attitűd fejlesztésére.\\nIskolánk ötödik éve vesz részt a Digitális Témahéten, ahol a tanulók projektmunkák során digitális eszközöket alkalmaznak. A program célja a digitális kompetenciák fejlesztése, a kreatív eszközhasználat és az MTMI területekhez kapcsolódó gyakorlati tudás elmélyítése élményszerű tanuláson keresztül.", "mtmi_tovabbkepzesek_idokeret_megvalosul": "igen", "mtmi_tovabbkepzesi_programok_megvalosul": "igen", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "Iskolánkban kiemelt cél az aktív tanulás ösztönzése, amely a tanulók bevonásán, együttműködésén és önálló gondolkodásán alapul. A tanítási gyakorlatban rendszeresen alkalmazzuk a projektmódszert, különösen a Digitális Témahét (DTH) és a Fenntarthatósági Témahét (FTH) keretében, ahol a tanulók kutatnak, alkotnak, prezentálnak, és saját élményeken keresztül mélyítik el tudásukat.\\nA páros- és csoportmunka tanórai keretek között és versenyhelyzetekben is kiemelt szerepet kap. A tanulók együtt dolgoznak problémamegoldó feladatokon, közösen terveznek, érvelnek, és reflektálnak egymás munkájára, ami fejleszti az együttműködési készséget, a kommunikációt és az önálló tanulási képességeket.\\nFelső tagozaton a tanulók érdeklődési területüknek megfelelően választhatnak emelt szintű angol, matematika vagy informatika orientációjú osztályok közül, ami lehetőséget ad a személyre szabottabb tanulási utak kialakítására, és erősíti a tanulói motivációt.\\nAz aktív tanulást támogatja a digitális eszközök széles körű használata: az okostanterem notebookjai, a tanulói saját eszközök, a BeeBot robotok, Micro:bit mikrokontrollerek, LEGO-robotok, valamint a 3D nyomtató és lézervágó lehetőséget adnak az interaktív, élményszerű tanulásra.\\nAz értékelés során kiemelt szerepet kap a tanulók önreflexiója, amelyet életkoruknak megfelelő formában alkalmazunk.  A pedagógusok folyamatos, támogató visszajelzései segítik a tanulók fejlődését, megerősítik az erősségeiket, és irányt mutatnak a továbblépéshez.\\nA tanulási környezet – beleértve az okostantermet, a digitális kultúra termet és a kiállítótereket – ösztönzi a tanulókat arra, hogy aktív szereplői legyenek saját tanulási folyamatuknak, és a megszerzett tudást kreatívan, együttműködve alkalmazzák.", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 70 453 4283", "mtmi_felelos_kapcsolattarto_telefonszam2": "+36 22 316 183", "mtmi_kiallitoterek_megvalosul_bemutatasa": "Iskolánk nagy hangsúlyt fektet a tanulói munkák és projektek láthatóvá tételére, hiszen ezek nemcsak az elvégzett munka elismerését szolgálják, hanem motiváló erővel is bírnak a diákok és pedagógusok számára egyaránt. A tanulói alkotások bemutatása hozzájárul az iskolai közösség építéséhez, az önbizalom erősítéséhez, valamint az MTMI-területekhez kapcsolódó kreatív gondolkodás és problémamegoldás megbecsüléséhez.\\nA 4.4-es pontban részletezett kiállítóterek egyúttal a tanulói projektek és munkák bemutatására is szolgálnak. Az első emeleti és a földszinti központi aula tágas, jól látható helyszínként funkcionál, ahol rendszeresen rendezünk tematikus kiállításokat, például természettudományos tablók, digitális kultúrához kapcsolódó munkák, vagy pályaorientációs projektek bemutatására.\\nA folyosói faliújságok szintén állandó felületet biztosítanak az osztályok munkáinak, tantárgyi projekteknek, versenyeredményeknek és kreatív alkotásoknak. Ezeket a felületeket rendszeresen frissítjük, így a tanulók munkái folyamatosan reflektorfénybe kerülnek.\\nEmellett az osztálytermekben is kialakítottunk kisebb kiállítófelületeket, ahol az adott osztály tanulói saját munkáikat, kutatásaikat, posztereiket vagy digitális projektjeik nyomtatott változatait mutathatják be. Ezek a terek lehetőséget adnak az egyéni és csoportos teljesítmények elismerésére, valamint a tanulási folyamat dokumentálására.", "mtmi_palyaorientacio_megvalosulas_leiras": "Iskolánkban a tanulók rendszeres és célzott tájékoztatást kapnak az MTMI tanulmányi lehetőségekről és karrierprofilokról. A pályaválasztásért felelős pedagógus, az osztályfőnökök és a szaktanárok összehangolt munkájával az 5–8. évfolyam tanulói számára több formában is biztosítjuk az információátadást.\\nA 2020 óta működő Országos Pályaorientációs Mérés (OPM) a 8. évfolyamos tanulók számára kötelezően kitöltendő kérdőív, amely az érdeklődési körük és kompetenciáik alapján segít irányt mutatni a továbbtanuláshoz. A mérés során a diákok 90 kérdésre válaszolnak, amelyek alapján visszajelzést kapnak arról, mely pályaterületek illenek leginkább hozzájuk – köztük kiemelten az MTMI irányok. Az eredményekről a tanulók, szülők és pedagógusok is tájékoztatást kapnak, így támogatva a tudatos pályaválasztást.\\nA Pályaorientációs Mérő- és Támogatóeszköz (POM) egy komplex, online platform, amelyet a tanulók önállóan vagy pedagógusi irányítással használhatnak. A POM négy különböző kérdőívet tartalmaz, amelyek az érdeklődést, képességeket és pályaválasztási attitűdöket vizsgálják. A rendszer ajánlásokat ad a tanulókhoz leginkább illő szakmákról, köztük az MTMI területekhez kapcsolódó lehetőségekről. A POM különösen hasznos a 7–8. évfolyamon, ahol a továbbtanulás előkészítése kiemelt szerepet kap.\\nA tájékoztatás kiegészül pályaorientációs napokkal, üzemlátogatásokkal, alumni előadásokkal, MTMI versenyekkel és projektekkel. A pályaválasztásért felelős pedagógus tevékenysége és az MTMI irányú tájékoztató anyagok elérhetők az iskola honlapján is, ezzel is támogatva a tanulók és szüleik tudatos döntéshozatalát.\\n", "lanyoknak_szolo_mtmi_programok_bemutatasa": "Iskolánkban az MTMI területekhez kapcsolódó programok és versenyek minden tanuló számára nyitottak, és a lányok ezekben aktívan és eredményesen vesznek részt. Bár külön, kizárólag lányoknak szóló MTMI programot eddig nem szerveztünk, a részvételi arányuk kiemelkedően magas, így nem volt szükség külön kiemelésükre.\\nA versenyeken, projektekben és pályaorientációs rendezvényeken (pl. „Mi a pálya?”, Szakmasztár, Hanon System által szervezett Környezetvédelem a jövőért verseny) a lánytanulók rendszeresen szerepelnek, gyakran díjazottként. Az eredményeikről honlapunkon és közösségi felületeinken is beszámolunk.\\nA jövőben nyitottak vagyunk olyan programok szervezésére vagy külső kezdeményezésekhez való csatlakozásra, amelyek kifejezetten a lányok MTMI területeken való részvételét támogatják és ösztönzik.", "mtmi_egyuttmukodes_palyaorientacio_leiras": "Iskolánk aktívan együttműködik a pályaválasztási folyamatban érdekelt szervezetekkel, különös tekintettel az MTMI területekre. A tanév során rendszeresen szervezünk pályaorientációs napokat, amelyek az iskola valamennyi évfolyamát érintik – az alsó tagozattól a 8. évfolyamig. A program célja, hogy életkorhoz igazított formában minden tanuló betekintést nyerjen a különböző pályaterületekbe, különösen az MTMI szakmák világába.\\nA pályaorientációs napokon vállalatok, az Iparkamara, oktatási intézmények, alumnik, szülők és a pedagógiai szakszolgálat képviselői tartanak előadásokat, interaktív bemutatókat, beszélgetéseket. Emellett középiskolákban tanító pedagógusok mutatják be saját intézményeik képzési kínálatát, különös figyelmet fordítva az MTMI irányokra. A tanulók így közvetlenül tájékozódhatnak a továbbtanulási lehetőségekről, felvételi követelményekről és a választható szakirányokról.\\nAz iskola üzemlátogatásokat is szervez, ahol a diákok közvetlenül megismerhetik a műszaki, informatikai és természettudományos területeken működő cégek működését. \\nSzoros együttműködés jellemzi munkánkat a Fejér Vármegyei Pedagógiai Szakszolgálat továbbtanulási, pályaválasztási csoportjának munkatársaival. A személyes tanácsadások, pályaorientációs foglalkozásokon felül szülői értekezletek alkalmával is támogatják munkánkat.", "mtmi_laboratoriumok_latogatasa_bemutatasa": "Iskolánk jelenleg nem vesz részt egyetemek vagy más iskolák laboratóriumainak rendszeres látogatásában, és ilyen típusú együttműködés még nem valósult meg. Ennek ellenére fontosnak tartjuk, hogy tanulóink gyakorlati tapasztalatokat szerezzenek az MTMI területeken, ezért alternatív partnerprogramok keretében biztosítunk számukra interaktív élményeket.\\nMinden tanévben, az egészségvédelmi hét vagy a pályaorientációs nap keretében, osztályaink ellátogatnak a székesfehérvári SKILL laborban, ahol interaktív laborfoglalkozásokon vesznek részt. A program során a tanulók megismerkedhetnek a laboratóriumi munkafolyamatokkal, eszközökkel, valamint az egészségügyi és biológiai vizsgálatok alapjaival. A foglalkozások célja, hogy élményszerűen mutassák be az MTMI területekhez kapcsolódó szakmai gyakorlatokat, és felkeltsék a tanulók érdeklődését a természettudományos pályák iránt.\\nA SKILL laborban szerzett tapasztalatokról honlapunkon és közösségi médiafelületeinken is beszámolunk, ezzel is erősítve a program láthatóságát és motiváló hatását.\\n A jövőben célunk, hogy hasonló jellegű együttműködéseket más intézményekkel is kialakítsunk, különösen olyan egyetemekkel vagy középiskolákkal, amelyek MTMI profilú laboratóriumokat működtetnek.", "intezmenyvezeto_kapcsolattarto_telefonszam1": "+36 22 316 183", "mtmi_digitalis_tananyagok_megvalosul_bemutatasa": "Iskolánk pedagógiai programjának egyik alapelve a digitális módszertan alkalmazása a tanórákon és a tanórán kívüli foglalkozásokon. Az MTMI tantárgyak oktatása során rendszeresen használunk digitális tananyagokat, interaktív feladatlapokat és online mérőeszközöket, amelyek segítik a tanulók motivációját, a differenciált tanulást, valamint a 21. századi kompetenciák fejlesztését. A tanórákon és projektmunkák során előszeretettel alkalmazzuk a következő digitális eszközöket és platformokat: Blooket, Kahoot, Matific, Quizizz, Quizlet, Wordwall, LearningApps, OkosDoboZ, Liveworksheets, valamint a Microsoft alkalmazásokat ( Teams,Word, Forms, OneNote, PowerPoint, OneDrive), továbbá a NAT-hoz illeszkedő NKP okostankönyveket. A programozási és algoritmikus gondolkodás fejlesztését támogatja a Scratch és a micro:bit használata, míg a Tinkercad segítségével a tanulók a 3D tervezés és a mérnöki gondolkodás alapjaival ismerkedhetnek meg. A digitális eszközök beépítése az oktatásba hozzájárul a tanulók problémamegoldó gondolkodásának, logikai készségeinek és kreativitásának fejlesztéséhez, különösen a matematika, informatika és természettudományos tantárgyak esetében.\\nA tanulói teljesítmények nyomon követésére és fejlesztési irányok meghatározására szolgál az országos kompetenciamérés, amely objektív képet ad a diákok képességeiről. Az első évfolyamos tanulók esetében a DIFER (Diagnosztikus Fejlődésvizsgáló Rendszer) mérések segítségével feltérképezzük az alapkészségek – például az írás, olvasás, számolás, figyelem és emlékezet – fejlettségi szintjét, amely megalapozza a további célzott fejlesztést. ", "mtmi_korszeru_felszereltseg_megvalosul_bemutatasa": "Iskolánk kiemelt célja, hogy a tanulók számára korszerű, motiváló és digitálisan támogatott tanulási környezetet biztosítson. Ennek érdekében folyamatosan fejlesztjük eszközparkunkat és tantermi infrastruktúránkat.\\nMinden tantermünk projektorral felszerelt, több osztályban interaktív táblák működnek, emellett három okostábla (interaktív panel) is segíti a tanórai munkát. A tanulók rendelkezésére állnak saját tanulói notebookok, amelyeket rendszeresen használnak tanórákon. Az iskola könyvtárában  notebookok állnak a diákok rendelkezésére tanulási célra.\\nKülön tanteremként működik egy teljesen felszerelt digitális kultúra terem, ahol asztali számítógépeken folyik az informatikai oktatás. Emellett az okostanterem egy osztálynyi iskolai notebookkal és 30 darab tanulói tablettel van felszerelve, amelyek az interaktív, kooperatív tanulási formákat és a digitális kompetenciák fejlesztését szolgálják.\\nAz alsó tagozaton a BeeBot robotok segítik a logikai gondolkodás és algoritmikus szemlélet játékos fejlesztését. A felsőbb évfolyamokon a LEGO-robotok, a Micro:bit mikrokontrollerek, valamint a 3D nyomtató és a lézervágó biztosítanak lehetőséget a kreatív, gyakorlatorientált tanulásra. Ezek az eszközök különösen népszerűek a szakköri és pályaorientációs foglalkozásokon.\\nA pedagógusok munkáját tanári laptopok, valamint JBL hangszórók és egyéb digitális kiegészítők segítik, amelyek lehetővé teszik a multimédiás tartalmak hatékony bevonását a tanításba. A tantermek elrendezése és felszereltsége támogatja a differenciált oktatást, az egyéni tanulási utak kialakítását, valamint a 21. századi kompetenciák fejlesztését.", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul": "igen", "mtmi_tovabbkepzesek_idokeret_megvalosul_bemutatasa": "A Székesfehérvári Széna Téri Általános Iskola vezetése elkötelezett az MTMI (matematika, természettudományok, műszaki és informatikai) területek fejlesztése iránt, és stratégiai fontosságúnak tartja a pedagógusok szakmai fejlődésének támogatását. Ennek érdekében biztosítja a továbbképzéseken, szakmai műhelyeken, valamint hazai és nemzetközi konferenciákon való részvételhez szükséges időkeretet és szervezési feltételeket. A belső kommunikációs csatornák (pl. Teams) segítségével folyamatosan tájékoztatjuk a pedagógusokat a releváns képzési lehetőségekről, és ösztönözzük őket az innovatív oktatási programokban való részvételre.\\nAz elmúlt három évben kollégáink több akkreditált MTMI területi továbbképzésen vettek részt, melyeket az Oktatási Hivatal, a Klebelsberg Központ és a Pedagógiai Oktatási Központ szervezett. Aktívan részt vesznek az őszi és tavaszi Pedagógiai Napokon, tapasztalataikat rendszeresen megosztják a tantestületi értekezleteken. \\nA képzések kiválasztásánál kiemelt szempont volt a gyakorlatorientáltság, hogy a megszerzett tudás azonnal alkalmazható legyen tanórákon, szakkörökön, tehetséggondozásban, témanapokon és témahetek projektjeiben. Emellett támogatjuk az online képzéseket, webináriumokat, szakmai fórumokat, mentori támogatást és belső coachingot. Törekszünk a pályázati lehetőségek kihasználására, különösen nemzetközi konferenciák elérését célzó programokban.", "mtmi_tovabbkepzesi_programok_megvalosul_bemutatasa": "Iskolánk aktívan kihasználja az MTMI területén elérhető továbbképzési lehetőségeket, és ösztönzi a pedagógusokat a belső és regionális szakmai fejlődésre. A tantestület tagjai rendszeresen részt vesznek webináriumokon, szakmai fórumokon, bázisintézményi jógyakorlatokon, valamint belső tudásmegosztáson és mentori támogatáson alapuló műhelymunkákon.\\nA 2025/26-os tanévben induló Maker’s Red Box – A jövő városa projekt szakköri keretek között valósul meg, amelyhez a résztvevő pedagógusok számára belső és külső képzéseket biztosítunk. A projekt célja, hogy a megszerzett tudás megjelenjen a tanórákon, szakkörökön, témanapokon és témahetek projektjeiben.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul": "igen", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul_bemutatasa": "Az MTMI tantárgyakat tanító pedagógusok egyéni teljesítményértékelési céljai intézményünkben szorosan kapcsolódnak az MTMI program gyakorlati megvalósításához. A vállalások célja, hogy a tanulók kompetenciái célzottan fejlődjenek, miközben a pedagógusok innovatív módszerekkel, tantárgyközi szemlélettel és élményszerű tanulási helyzetekkel támogatják a motivációt és pályaorientációt.\\nKompetenciafejlesztés és mérés\\n• \\tEgységes szintfelmérő és tanév végi vizsga szervezése\\n• \\tPróba felvételi összeállítása, differenciált feladatlapokkal\\n• \\tFelvételi eredmények elemzése, reflexió\\nVersenyek szervezése\\n• \\t„Év számolója”, Zrínyi, Kenguru, Medve Matek, Sudoku, Matek Mikulás\\n• \\tFeladatbank, javítókulcs, eredményértékelés\\n• \\tElsősegély és környezetvédelmi versenyek\\nInnovatív projektek\\n• \\tMaker’s Red Box eszközhasználat és tanórai alkalmazás• \\tUNIverZOOM – fizikai kísérletek Földön és az űrben\\n• \\tKéMia Titka bemutató\\nKörnyezeti nevelés\\n• \\tMagaságyások, sziklakert, fűszerkert kialakítása\\n• \\tNövénymegfigyelés, plakátkészítés\\nDigitális kompetenciák\\n• \\tDigitális Témahét\\n• \\tInternetbiztonsági előadások, DTH pályázat bemutatása\\nPályaorientáció és témanapok\\tPályaorientációs foglalkozások szervezése\\n• \\tIntézményen kívüli programok\\n• \\tÉvi 4 témanap: holisztikus gondolkodás, tantárgyak összekapcsolása.\\nA vállalások széles spektrumot ölelnek fel, és hozzájárulnak a tanulók holisztikus fejlődéséhez, a tantárgyak közötti összefüggések felismeréséhez, valamint a 21. századi készségek megerősítéséhez.\\n", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul_bemutatasa": "Az MTMI területek fejlesztése kulcsfontosságú a jövő kompetenciáinak megalapozásában, ezért pedagógusaink célzott támogatása ezen a területen stratégiai jelentőségű.\\n\\nA 419/2024. (XII. 23.) Korm. rendelet értelmében 2025. szeptember 1-jétől csak az Oktatási Hivatal által nyilvánosságra hozott pedagógus-továbbképzési programok számíthatók be a továbbképzési kötelezettségek teljesítésébe.\\n\\nA nevelőtestület képzési igényeinek felmérése során kiemelt figyelmet kaptak az MTMI területek, így az intézményi programba teljes támogatottsággal épülhettek be az MTMI kompetenciákat fejlesztő képzések:\\n\\n· Alapműveleti képességek fejlesztése a darts matek segítségével\\n\\n· Digitális eszközökkel támogatott projektalapú oktatás\\n\\n· Digitális kultúra tanítása\\n\\n· Algoritmikus, matematikai gondolkodás fejlesztése változatos módszerekkel\\n\\nA képzések kiválasztása során szempont volt, hogy gyakorlatorientáltak legyenek, ezáltal azonnal alkalmazható módszereket kínáljanak. Anyagi támogatás továbbképzési díjjal járó képzés során sajnos nem biztosított, ezért a képzéssel kapcsolatban felmerülő költségeket szükség esetén a pedagógusok fedezik.\\n\\nAz akkreditált továbbképzési lehetőségek mellett nagy hangsúlyt kapnak a szakmai közösségek támogatásában az online képzések, webináriumok, bázisintézményi jógyakorlatok, szakmai fórumok, a belső tudásmegosztás, mentori támogatás és belső coaching.\\n\\nSzakmai innovációként jelenik meg a 2025/26. tanévben a Maker’s Red Box - A jövő városa projekt, amely szakköri keretek között valósul meg történelemtanár vezetésével. A projekt eszközigénye miatt a folyamatban résztvevő pedagógusoknak további belső és külső képzéseket biztosítunk.\\n\\nCélunk, hogy a képzések során megszerzett tudás megjelenjen tanórákon, szakkörökön, tehetséggondozásban, témanapok és témahetek projektjeiben, ezzel is növelve a tanulás hatékonyságát, a tanulói motiváció fenntartását és növelését és a tudatos pályaválasztást."}	2025-09-07 12:16:45.308784	2026-03-05 22:23:14.559518	1	008c0533-8474-4af1-90e9-8408a60c0c47_Sz_kesfeh_rv_ri_Sz_na_T_ri__ltal_nos_Iskola_bemutat_sa_MTMI_szellemis_gben..pdf	6813a421-8116-42e5-a9bd-15c493ef5b11
6fb006f4-1cc4-4b75-a7e3-a89d531854ea	{"iskola_cime": "7400 Kaposvár, Bajcsy-Zsilinszky u.17", "iskolatipus": ["gimnazium"], "gdpr_consent": ["on"], "szulo_bevonas": "megvalosul", "mtmi_koncepcio": "igen", "telepulesforma": "megyeszekhely_varos", "mtmi_nyilt_napok": "Őszi MTMI Tájékoztató és Kísérletező Nyílt Nap\\nIdőpont és Célcsoport: Az eseményt általában október végén/november elején tartjuk, a középiskolai jelentkezések előtti időszakban. Elsősorban a 7-8. osztályos diákoknak és szüleiknek szól.\\n\\nFókusz: A gimnázium MTMI-képzésének (emelt szintű matematika és fizika, digitális kultúra) átfogó bemutatása.\\n\\nProgram:\\n\\n\\"Fedezd fel a Labort\\" Foglalkozások: Interaktív bemutatók és látványos kísérletek a Dr. Kontra József Természettudományi Laborban. A fizika, kémia és biológia szekciókban a diákok a Matics Martin-féle elveket követve maguk is bekapcsolódhatnak a kísérletezésbe.\\n\\nDigitális Bemutatók: Rövid workshopok az informatika terén, különös tekintettel az AJTP Informatika Verseny témáira és a mesterséges intelligencia alapjaira.\\n\\nKonzultáció: Találkozási lehetőség a tanárokkal és az OTIO-n sikeres idősebb diákokkal.\\n\\n2. Tavaszi Tudományos és Innovációs Nyílt Nap: Science Fair Előzetes\\nIdőpont és Célcsoport: Március/április folyamán, kapcsolódva a regionális Science Fair/OTIO eseményekhez. A jelenlegi diákok, az MTMI iránt elkötelezett szülők és a nagyközönség számára nyitott.\\n\\nFókusz: A projektalapú munka eredményeinek prezentálása.\\n\\nProgram:\\n\\nMTMI Projektek Kiállítása: A tanév során, szakkörök és tanórán kívüli foglalkozások keretében készült OTIO és Science Fair projektek (pl. környezetvédelmi innovációk, méréstechnikai fejlesztések) bemutatása.\\n\\nPrezentációs Fórum: A diákok előadásokat tartanak kutatási eredményeikről, ami egyben felkészülést is jelent a regionális és nemzetközi versenyekre.\\n\\nPályaorientáció: Tájékoztatók a MATE-val való együttműködés keretében a reáltudományi továbbtanulási és szakmai lehetőségekről.\\n\\nA két nyílt nap együtt garantálja a célzott tájékoztatást, az interaktív élményszerzést, és megerősíti a szülői bevonást a tehetséggondozó folyamatba.\\n", "szulo_egyeztetes": "megvalosul", "mtmi_projektnapok": ". Őszi Projektnap: Kutatási Téma és Módszertani Tréning\\nIdőpont: Szeptember/Október (a tanév elején).\\n\\nCél: A tehetséggondozó programba bekerülő diákok projekttervezési, témaazonosítási és kutatásmódszertani felkészítése.\\n\\nFókusz: Az egyéni vagy csoportos MTMI projektjavaslatok véglegesítése.\\n\\nProgram:\\n\\nTémaötletelés és Mentorválasztás: A diákok bemutatják kezdeti ötleteiket, és párosulnak a megfelelő szaktanárokkal (matematika, fizika, kémia, biológia, informatika) vagy külső mentorokkal.\\n\\nMódszertani Workshopok: Rövid, intenzív képzések a kutatási protokollokról, a hiteles forráskezelésről és a tudományos dokumentációról, segítve a TUDOK-ra (Tudományos Diákkörök Országos Konferenciája) való felkészülést.\\n\\nLaboratóriumi Előkészületek: Bevezető foglalkozások a Dr. Kontra József Természettudományi Labor eszközhasználatába, különös tekintettel a méréstechnikai és adatgyűjtési feladatokra.\\n\\n2. Tavaszi Projektnap: Megvalósítás, Prezentáció és Zsűrizés\\nIdőpont: Február/Március (a Science Fair és OTIO regionális válogatók előtt).\\n\\nCél: A projektek szakmai zárása, a prezentációs készségek fejlesztése és a versenyhelyzet szimulálása.\\n\\nFókusz: A projektek prototípusainak és kutatási eredményeinek befejezése és bemutatása.\\n\\nProgram:\\n\\nProjektkritika és Véglegesítés: A diákok prezentálják a kész vagy majdnem kész projektet egy belső zsűri előtt. A visszajelzések alapján történik a végső finomhangolás a regionális Science Fair/OTIO események előtt.\\n\\nMűszaki és Természettudományi Konzultáció: Célzott matematika, fizika, informatika konzultációk a projektek számítási, technikai (pl. kódolási) és elméleti problémáinak megoldására.\\n\\nPrezentációs Tréning: Workshop a tudományos eredmények hatékony, TUDOK és OTIO elvárásoknak megfelelő bemutatására, a poszterkészítési technikák elsajátításával.\\n\\nEzek a Projektnapok biztosítják a diákok számára az intenzív, koncentrált munkát és a magas színvonalú felkészülést a legnagyobb országos és nemzetközi MTMI versenyekre.", "szulo_kommunikacio": "megvalosul", "iskola_honlap_link1": "https://www.klgbp.hu/", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "8", "palyazo_iskola_neve": "Budapest XX. Kerületi Kossuth Lajos Gimnázium", "pedprog_mtmi_leiras": "Jelenleg kialakítás alatt van, a programot nyáron lehetséges módosítani", "mtmi_ceges_eloadasok": "igen", "mtmi_csapat_tag1_nev": "Matics Martin", "mtmi_csapat_tag2_nev": "Vámosi László", "mtmi_csapat_tag3_nev": "Trembeczki Csaba", "mtmi_csapat_tag4_nev": "Kertész Róbert ", "mtmi_csapat_tag5_nev": "Kertészné Bagi Beatrix", "mtmi_csapat_tag6_nev": "Dr. Huszákné Mikós Dóra", "mtmi_csapat_tag7_nev": "Raskoványi Miklós", "mtmi_csapat_tag8_nev": "Máté-Márton Gergely", "mtmi_szakkorok_szama": "10", "mtmi_szulo_kepviselo": "igen", "mtmi_alumni_programok": "igen", "mtmi_csapat_tag1_szak": ["matematika", "fizika"], "mtmi_csapat_tag2_szak": ["matematika", "kemia", "termeszettudomany", "egyeb"], "mtmi_csapat_tag3_szak": ["matematika"], "mtmi_csapat_tag4_szak": ["kemia", "biologia"], "mtmi_csapat_tag5_szak": ["kemia", "biologia"], "mtmi_csapat_tag6_szak": ["matematika", "kemia"], "mtmi_csapat_tag7_szak": ["digitalis_kultura"], "mtmi_csapat_tag8_szak": ["biologia"], "mtmi_koncepcio_leiras": "A Kaposvári Táncsics Mihály Gimnázium MTMI koncepciójának fő célja a természettudományi, műszaki és informatikai területek oktatásának és tehetséggondozásának rendszerszintű erősítése, reagálva ezzel a 21. századi, technológiaalapú gazdaság kihívásaira.\\n\\nA koncepció a gimnázium meglévő, regionális szinten is kiemelkedő tevékenységeire épül, mint az évente megrendezésre kerülő Science Fair tudományos kiállítás és az Országos Tudományos és Innovációs Olimpia (OTIO) regionális válogatója. A gimnázium központként funkcionál a dél-dunántúli régióban a projektalapú tudományos munkában, aktívan együttműködve a Magyar Agrár- és Élettudományi Egyetemmel (MATE) és a Magyar Innovációs Szövetséggel.\\n\\nA tehetséggondozás nem csupán a szakkörökre korlátozódik, hanem az interdiszciplináris gondolkodás fejlesztésére helyezi a hangsúlyt.\\n\\nMatematika területén az emelt szintű képzés mellett kiemelt szerepe van a rendszerlogika és a problémamegoldó képesség fejlesztésének, melyet külső szakértők, például Dr. Pintér Ferenc-féle előadás-sorozatok támogatnak.\\n\\nFizika és Kémia oktatásban a Dr. Kontra József Természettudományi Labor intenzív, gyakorlatorientált használatával biztosítjuk a kísérletezés magas szintjét. A tehetségbázis szélesítését a Matics Martin-féle interaktív fizika szakkörök segítik, melyek már 7-8. osztályos kortól bevonják a diákokat a látványos természettudományos világba.\\n\\nDigitális Kultúra és Informatika területén a fő program az AJTP Országos Informatika Verseny szervezése, mellyel a gimnázium országos versenyközponttá vált. Különös figyelmet fordítunk a mesterséges intelligencia (MI) alapjainak beépítésére a tananyagba és az innovációs projektekbe.\\n\\nA tehetséggondozás eszköze a MTMI Projekt-Mentorprogram, ahol a tapasztaltabb, korábbi OTIO-n részt vett diákok segítik az alsóbb évesek kutatómunkáit. A program minőségét és a szülői támogatást az éves kommunikációs stratégia biztosítja, mely évente kétszer valósul meg: ősszel egy tájékoztató szülői fórumban a programo", "pedprog_mtmi_tartalom": "reszben", "szulo_palyaorientacio": "megvalosul", "mtmi_fakultaciok_szama": "12", "mtmi_muzeumlatogatasok": "igen", "iskola_tanuloi_letszama": "620", "mtmi_szakkor_tantargyak": ["matematika", "fizika", "kemia", "biologia", "digitalis_kultura", "technika"], "mtmi_szakmak_bemutatasa": "igen", "szulo_egyeztetes_szoveg": "A Kaposvári Táncsics Mihály Gimnázium MTMI tehetséggondozó programjában az évi két alkalmas szülői egyeztetés és bevonás stratégiailag épül fel, biztosítva a folyamatos kommunikációt és a támogatást:\\n\\n1. Éves Tájékoztató és Tervezés (Őszi Félév)\\n\\nCél: Átfogó tájékoztatás az aktuális tanévről, beszámoló az előző évi eredményekről és közös tervezés.\\n\\nForma: Szülői értekezlet vagy dedikált MTMI szülői fórum.\\n\\nTartalom:\\n\\nBeszámoló (Eredmények): Részletes bemutatás az előző évi OTIO, Science Fair továbbjutókról, országos versenyeredményekről (matematika, informatika, természettudományok) és a végzett projektekről.\\n\\nProgramterv (Fókuszpontok): A szülők tájékoztatása a speciális programokról, mint a fizika tehetséggondozó szakkörök (7-8. osztály), az AJTP informatika versenyre való felkészülés, az emelt szintű matematika képzés részletei, valamint a projektmunkák ütemezése (pl. OTIO-ra való felkészülés).\\n\\nEgyeztetés (Támogatás): Lehetőség a pedagógusokkal és mentorokkal való személyes konzultációra a diák egyéni motivációjával, terhelhetőségével és a tehetséggondozáshoz szükséges otthoni támogatás (pl. anyagi, logisztikai) biztosításával kapcsolatban.\\n\\n2. Science Fair Nyílt Nap és Projektek Bemutatója (Tavaszi Félév)\\n\\nCél: A tehetséggondozás eredményeinek látványos bemutatása, a diákok munkájának elismerése és a szülői elköteleződés erősítése.\\n\\nForma: Kaposvári Science Fair Nyílt Nap (az OTIO regionális válogató nyilvános része), illetve a szakkörök és projektek záró bemutatója.\\n\\nTartalom:\\n\\nSzülői Meghívás: A szülőket hivatalos úton hívják meg a kiállításra. Ez a Science Fair/Nyílt Nap központi esemény, ahol a diákok a fizika, kémia, digitális kultúra és egyéb MTMI területekhez kapcsolódó kutatásaikat és innovációikat prezentálják.\\n\\nInterakció: A szülők személyesen megtekinthetik és kipróbálhatják a projekteket, ezzel közvetlen élményt szerezve a tehetséggondozó munka minőségéről. A diákok bemutatják a kutatási folyamatot, a felmerülő nehézségeket és a tanulságokat.\\n\\n", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "nem", "mtmi_szakmai_gyakorlatok": "MTMI Szakmai Gyakorlatok Éves Terve (Kaposvári Táncsics Mihály Gimnázium)\\nA Táncsics Gimnázium MTMI tehetséggondozó programjának kiemelt elemei a szakmai gyakorlatok és a külső intézményekkel való együttműködések. Ezek célja a tanult elméleti ismeretek gyakorlati alkalmazása, a valós munkakörnyezet megismerése, és a pályaorientáció támogatása. A szakmai gyakorlatok évente, több fázisban valósulnak meg.\\n\\n1. Őszi/Téli Félév: Bevezető Látogatások és Előadások\\nCél: Átfogó képet adni az MTMI területekhez kapcsolódó karrierlehetőségekről és a legújabb technológiákról.\\n\\nForma: Rendszeres, rövidebb, néhány órás szakmai látogatások és a gimnáziumban tartott szakértői előadások.\\n\\nFókusz:\\n\\nEgyetemi Kapcsolatok: Részvétel a Magyar Agrár- és Élettudományi Egyetem (MATE) Kaposvári Campusának nyílt napjain és laborbemutatóin. A diákok megismerik a felsőoktatásban zajló kutatásokat (pl. agrárinformatika, környezetvédelem).\\n\\nCéges Előadások: Külső IT, mérnöki vagy gyógyszeripari partnerek (pl. Richter Gedeon Alapítványi kapcsolata) bevonása. Az előadók bemutatják a digitális kultúra, fizika, kémia területeken megvalósuló innovációs projekteket (pl. MI alkalmazások).\\n\\n2. Nyári Félév: Intenzív Szakmai Gyakorlat és Projektmunka\\nCél: Hosszabb időtartamú, valós munkatapasztalat szerzése az OTIO és Science Fair projektekhez kapcsolódóan.\\n\\nForma: Egyhetes, intenzív nyári szakmai gyakorlat (esetenként kutatótábor) a kiemelt tehetségek számára.\\n\\nFókusz:\\n\\nLaborgyakorlatok: Részvétel egyetemi fizika, kémia, biológia laboratóriumok munkájában. A diákok kutatói felügyelet mellett dolgoznak komplex méréstechnikai és analitikai feladatokon.\\n\\nKutatás-Fejlesztés (K+F) Projektek: Közös munkában való részvétel helyi vállalatok vagy kutatóintézetek (pl. MATE) által javasolt problémák megoldásában. Ez a gyakorlat szorosan kötődik a Science Fair-re vagy a TUDOK-ra készülő projektekhez, biztosítva a magas szintű műszaki és természettudományos felkészülést.\\n\\nMentorálás: A gyakorlat során külső MTMI mentoro", "mtmi_egyetemi_gyakorlatok": "igen", "mtmi_szakkor_diakok_szama": "150", "mtmi_szakkorok_bemutatasa": "A Kaposvári Táncsics Mihály Gimnázium MTMI tehetséggondozó rendszere a kiemelt tantárgyak köré szervezett szakkörökben és az innovációs programokban ölt testet, melyek célja a diákok érdeklődésének elmélyítése és a versenyekre való felkészítés.\\n\\nFizika, Kémia, Biológia Szakkörök (Természettudományok)\\nA természettudományos szakkörök kiemelt hangsúlyt fektetnek a kísérletezésre és a jelenségalapú tanulásra, kihasználva a Dr. Kontra József Természettudományi Laboratórium infrastruktúráját.\\n\\nFizika Tehetséggondozó Szakkörök: Kifejezetten a 7-8. osztályosok számára indított, heti rendszerességű foglalkozások. Ezeket a szakköröket a Matics Martin által képviselt innovatív szemlélet jellemzi, aki a FITT-díjjal elismert módszertanával (látványos kísérletek és animációk) célozza a reál érdeklődés felkeltését és a gimnáziumi felkészítést. Felső tagozaton a versenyekre, mint az OTIO-ra, és az emelt szintű érettségire való felkészítés a fókusz.\\n\\nKémia és Biológia Szakkörök: A laboratóriumi gyakorlatok elmélyítését szolgálják. A diákok összetettebb kísérleteket végeznek, felkészülve a biológia és kémia tantárgyakban elinduló tudományos versenyekre és az egyetemi szintű laboratóriumi munkára. Céljuk az is, hogy projekttémákat generáljanak a Science Fair kiállításra.\\n\\nMatematika és Innovációs Tevékenységek\\nMatematika Szakkörök: A tehetséggondozás egyik alapköve az emelt szintű képzést támogató, versenyfelkészítő foglalkozások rendszere. Ezek nemcsak az OKTV-re vagy a Kenguru versenyre való felkészítést szolgálják, hanem bepillantást engednek a modern matematika mélyebb összefüggéseibe is (pl. Dr. Pintér Ferenc által vezetett előadások).\\n\\nInnovációs/MTMI Projektszakkörök: Ezek a szakkörök integrálják a különböző MTMI területeket, főleg a Science Fair és az OTIO (Országos Tudományos és Innovációs Olimpia) projektekhez kapcsolódóan. A diákok kutatási módszertant, adatgyűjtést, és projektmenedzsmentet tanulnak. A témák gyakran a digitális kultúrát ötvözik a természettudományokkal ", "szulo_munkakoz_ismertetes": "megvalosul", "mtmi_szakkor_tanarok_szama": "10", "iskola_mtmi_tanari_letszama": "10+", "mtmi_diakok_kapcsolattartas": "igen", "mtmi_kapcsolatok_bemutatasa": "Ebben az évben folyamatosan látogatják diákjaink a KMOK Skill laborját, rendszeresen járnak a kaposvári cégekhez és az ország más cégeinél is. Látogatást tettünk a Mercedes, az SAP, az AUDI, az ELTE Kuckó, a Győri MOBILIS labor, a Kaposvári Digitális Tudásközpont a Zselici Csillagpark területén is.Az iskola aktív kapcsolatot tart fenn számos helyi és regionális vállalattal, valamint gazdasági szereplővel, hogy a diákok betekinthessenek az MTMI-vel (Matematika, Természettudományok, Műszaki, Informatika) kapcsolatos valós munkahelyi környezetbe.  Ezen együttműködések keretében rendszeresen szervezünk céglátogatásokat iskolai csoportok számára, melyek beszámolói elérhetők az iskola honlapján.\\nAz együttműködő partnerek az MTMI terület széles spektrumát képviselik, a technológiai fejlesztéstől az élelmiszeripari mérnöki munkáig:\\n\\nUltimate Waterprobe Kft. (MTMI, Műszaki, Környezettan): Ezzel a céggel folytatott együttműködés keretében a diákok megismerhetik a vízanalitikai eszközök fejlesztését és gyártását, valamint a környezetvédelmi technológiákat, ami szorosan kapcsolódik a Limnoscan projekthez is.\\n\\nSzabó Fogaskerékgyártó (Műszaki, Gépészet): A diákok betekintést nyerhetnek a gépészeti tervezés, a precíziós gyártás és a fémipari technológiák világába, ami a műszaki pálya iránt érdeklődők számára ad fontos tapasztalatokat.\\n\\nVideoton (Műszaki, Elektronika, Informatika): A nagyvállalatnál tett látogatásokon a diákok a gyártástechnológiai folyamatokat, az elektronikai összeszerelést és az ipari automatizálást ismerhetik meg.\\n\\nFino, Kométa, Privát-hús (Természettudományok, Élelmiszeripari Mérnöki Tudományok): Bár elsősorban élelmiszeripari cégek, az MTMI szempontjából kulcsfontosságú a minőség-ellenőrzés, a laboratóriumi vizsgálatok, a kémia/biológia alkalmazása a termelésben, valamint a gyártási folyamatok informatikai támogatása és optimalizálása.\\n\\nEzek a látogatások hozzájárulnak a pályaorientációhoz, segítve a diákokat abban, hogy valós környezetben lássák az MTMI-ben ", "mtmi_online_palyaorientacio": "igen", "mtmi_rendezvenyek_reszvetel": "igen", "lanyok_mtmi_kiemelt_figyelem": "igen", "mtmi_alumni_programok_leiras": "Az iskola MTMI (Matematika, Természettudományok, Műszaki, Informatikai) témájú alumni programjai és vendégelőadásai jelentős szerepet játszanak a diákok inspirálásában és tájékoztatásában. Ezek a programok a Kaposvári Táncsics Mihály Gimnázium Baráti Körének szervezésében, valamint a Magyar Tudományos Akadémia (MTA) Alumni hálózatának támogatásával valósulnak meg.\\nKiket látnak vendégül?\\nAz alumni eseményeken olyan sikeres, MTMI-területen dolgozó egykori diákok, valamint a tudományos élet kiemelkedő képviselői tartanak előadásokat, akik hiteles és inspiráló példaképek a mai tanulóknak:\\n\\nSchlégl Ádám (Űrhajósjelölt):\\n\\nTéma: A leginkább inspiráló példák egyike. Előadásai bemutatják az űrkutatás, a mérnöki tudományok és a fizika élvonalát, konkrét karrierutat vázolva az extrém kihívások felé.\\n\\nDr. Vajda Péter (Facebook (Meta) vezető munkatársa):\\n\\nTéma: A digitális kultúra és informatika területét hozza közel a diákokhoz. Bemutatja a globális IT-világ működését, az AI (mesterséges intelligencia) és az adatkezelés területén rejlő karrierlehetőségeket.\\n\\nMTA Alumni hálózat előadói:\\n\\nTéma: Az MTA alumni keretein belül számos neves kutató és tudós tart előadásokat a legkülönfélébb MTMI-témákban. Ezáltal a diákok közvetlenül első kézből szerezhetnek információt a legújabb tudományos felfedezésekről, kutatási módszerekről (például anyagtudomány, biotechnológia, kvantumfizika) és az akadémiai életpályáról.\\n\\nA Programok szerepe:\\nAz alumni programok lényege, hogy ne csak elméleti tudást adjanak, hanem életszerű, motiváló példákon keresztül mutassák be az MTMI-ben rejlő potenciált. A diákok közvetlen kapcsolatba kerülnek az előadókkal, kérdezhetnek tőlük, ami jelentősen segíti a pályaválasztási döntésüket és megerősíti a természettudományok iránti elkötelezettségüket.", "mtmi_csapat_tag1_tevekenyseg": "Matematika-fizika tehetséggondozást végez, illetve általános iskolásoknak városi szintű fizika szakkört tart.Matics Martin oktatási stílusát a gyakorlatiasság, a látványosság és az interaktivitás határozza meg, különösen a fizika területén:\\n\\nLátványos Kísérletek és Animációk: Aktívan használ videókat, animációkat és látványos kísérleteket az elvont fizikai fogalmak szemléltetésére és a diákok motiválására. Ezzel a megközelítéssel igyekszik leküzdeni a természettudományokkal szembeni esetleges ellenállást, és megmutatni a fizika mindennapi vonatkozásait.\\n\\nFiatal Tehetségek Bevonása: Különösen fontos szerepe van a 7-8. osztályos tehetséggondozó fizika szakkörök vezetésében. Ezek az ingyenes foglalkozások a gimnáziumi képzésre készítik fel a diákokat, és korán megteremtik a tehetségbázist az MTMI területen.\\n\\n2. Elismerések és Innovációs Szerep\\nPedagógiai kiválóságát szakmai elismerések is fémjelzik:\\n\\nFITT-díj: A Richter Gedeon Centenáriumi Alapítványtól elnyerte a Fiatal Természettudományos Tanár (FITT) alkotói díjat, amely az innovatív szemléletű, eredményes természettudományos oktatói munka elismerése. A díjjal járó összeget Matics Martin saját bevallása szerint részben a diákok további támogatására fordítja.\\n\\nMotiváció és Projektmunka: Azt vallja, hogy az eredményes munka alapja a jókedvű és motivált légkör. Ezzel a hozzáállással ösztönzi a diákokat a mélyebb, tanórán túli tanulásra és a projektmunkákban való részvételre, segítve őket a fizika alapjainak elsajátításában.\\n\\nMatics Martin a Táncsics Gimnázium MTMI programjában a fizikai ismeretek alapozásáért és a projektorientált, digitális szemléletű oktatásért felelős kulcsfigura.", "mtmi_csapat_tag2_tevekenyseg": "Vámosi László a Kaposvári Táncsics Mihály Gimnázium igazgatójaként és korábbi pedagógusként az intézmény MTMI (Matematika, Természettudományi, Műszaki, Informatikai) tevékenységének motorja és legfőbb stratégiai vezetője. Tevékenysége nem csupán az oktatásra terjed ki, hanem az innovációra, a tehetséggondozás nemzetközi színtérre emelésére és a gimnázium regionális központi szerepének erősítésére.\\n\\nNeve évek óta összefonódik a Science Fair tudományos kiállítás és az Országos Tudományos és Innovációs Olimpia (OTIO) szervezésével és a diákok mentorálásával.\\n\\nScience Fair/OTIO Központ: Irányításával a Táncsics Gimnázium a Science Fair és az OTIO regionális válogatójának kiemelt, központi helyszínévé vált. Aktívan szorgalmazza, hogy a diákok olyan komplex és mély projektekkel készüljenek, amelyek túlmutatnak a középiskolai tananyagon.\\n\\nA projektalapú tehetséggondozás terén elért kiemelkedő eredményeiért elismerésben részesült (pl. a 34. OTIO díjátadóján). A mentorált projektjei rendszeresen érnek el országos és nemzetközi sikereket, például a Science Fair országos döntőjében 2. helyezést, az OTIO nemzetközi döntőjében 2. helyezést és különdíjat.\\n\\n2. Nemzetközi Szintű Technológiai Projektek\\nKiemelten fontos szerepe van azokban a műszaki és informatikai projektekben, amelyek a Nemzetközi Űrállomásig (ISS) is eljutottak:\\n\\nESA Astro Pi Challenge:  mentora volt azoknak a diákcsapatoknak, amelyek programjait az Európai Űrügynökség (ESA) Astro Pi számítógépeire írták, és amelyek kódjait az ISS-en futtatták. Ez a tevékenység a fizika, informatika (Python programozás) és a műszaki fejlesztés rendkívül magas szintű ötvözését igényli. Egy korábbi projekt során például a Föld mágneses terét vizsgálták a diákok saját kódjukkal.\\n\\nMagaslégköri Kutatás: A Táncsics Gimnáziumban megvalósult \\"Irány a közeli világűr – magaslégköri sugárzásmérés saját eszközzel\\" projektek is Vámosi László nevéhez köthetők, ahol a diákok saját építésű mérőrendszert és ballonos technológiát alkalmaztak.", "mtmi_csapat_tag3_tevekenyseg": "Matematika tehetséggondozás, tankönyvírás", "mtmi_csapat_tag4_tevekenyseg": "Természettudományos laborvezető, Selye program működtetése, Nemzeti Tudósképző Akadémia regionális felelőse. Kertész Róbert a Dr. Kontra József Természettudományos Laboratórium vezetője (intézményegység-vezető helyettes). Ez a pozíció biztosítja, hogy a kémia és biológia oktatás a legmagasabb szakmai színvonalon, modern eszközökkel történjen, és szervesen támogassa az MTMI-projekteket és a méréseket.\\n\\nGyakorlati Módszertan: Kiemelkedő szerepe van a digitális mérések és a kísérleti munka tanórákba és projektekbe való beépítésében, segítve a diákokat a valós adatok gyűjtésében és elemzésében. Részt vesz az MTMI tanárok digitális módszertani workshopjain, ahol a laboratóriumi lehetőségeket mutatja be.\\n\\n2. Kiemelt Tehetséggondozás és Versenyfelkészítés\\nOKTV és OKJ-s Sikerek: Rendszeresen készít fel diákokat az Országos Középiskolai Tanulmányi Versenyre (OKTV) biológia és kémia tantárgyakból, ahol tanítványai évről évre sikeresen jutnak be a második fordulóba, és érnek el dobogós helyezéseket. Tevékenységének célja, hogy segítse tanítványait az emelt szintű érettségire való felkészülésben és a szakmai igényesség fejlesztésében.\\n\\nSzakmai Igényesség: Pedagógiai hitvallása, hogy támogassa a diákok belülről fakadó érdeklődésének megerősítését és szakmai igényességének fejlesztését a természettudományok terén.\\n\\n3. Regionális Tudományos Kapcsolatok Erősítése\\nSzegedi Tudós Akadémia (SzTA): Feleségével, Kertészné Bagi Beatrixszal együtt a Szegedi Tudós Akadémia Középiskolai Képzési Programjának Kaposvári Területi Központjának Vezető Tanárai. Ez a feladatkör megerősíti a gimnázium regionális központi szerepét a természettudományos és orvosbiológiai kutatások területén.\\n\\nMentorálás és Szaktanácsadás: Mestertanárként szaktanácsadói feladatokat is ellát, ezzel segítve a természettudományos tárgyak helyzetének javítását, és aktívan bekapcsolódva a tudományos diákmunka és a tehetségútlevél programok támogatásába.", "mtmi_csapat_tag5_tevekenyseg": "Biológia-kémia tehetséggondozás NTA projekt működtetése.Évről évre jelentős sikereket ér el diákjaival országos tanulmányi versenyeken. Tanítványai rendszeresen jutnak tovább az OKTV (Országos Középiskolai Tanulmányi Verseny) és az Oláh György Kémiaverseny döntőjébe, de felkészít az Árokszállásy Zoltán Biológia-környezetvédelmi versenyre és a Biológiai Diákolimpiára (IBO) is.\\n\\nEmelt szintű oktatás: Emelt szintű fakultációs csoportokat vezet biológiából és kémiából, segítve a diákokat a sikeres érettségiben és a további orvosi, gyógyszerészi, biológusi vagy vegyészi tanulmányokra való felkészülésben.\\n\\nMotiváció: A gyerekeket izgalmas előadásokkal, programokkal és innovatív laborgyakorlatokkal várja, a versenyeket pedig eszközként használja, ami segíti a diákokat céljaik elérésében.\\n\\n2. A Nemzeti Tudósképző Akadémia (NTA) Vezetője\\nFérjével, Kertész Róberttel együtt kiemelkedő szerepet tölt be a regionális tudományos hálózatban.\\n\\nTerületi Központ Vezetése: Ő és férje a Kaposvári Táncsics Mihály Gimnáziumban működő Szegedi Tudós Akadémia (ma Nemzeti Tudósképző Akadémia - NTA) Középiskolai Képzési Programjának Területi Központjának vezető tanárai. Ezzel a szereppel Somogy és Tolna megye több gimnáziumával tartják a kapcsolatot.\\n\\nKorszerű Labortechnika: Aktívan alkalmazza a modern molekuláris biológiai eszközöket (pl. PCR, gélelektroforézis), és ezek elsajátítását biztosítja a diákok számára, ezzel követve a természettudományok gyors fejlődését és az érettségi követelmények változásait.\\n\\nNobel-díjas Találkozók: A program keretében lehetővé teszi a diákok számára, hogy részt vegyenek a Nobel-díjasok és Tehetséges Diákok Konferenciáin, és találkozzanak a világ élvonalába tartozó kutatókkal.", "mtmi_csapat_tag6_tevekenyseg": "Matematika-kémia tehetséggondozás, felkészítés.r. Huszákné Miklós Dóra kiemelt figyelmet fordít arra, hogy a kémiát minél látványosabban és izgalmasabban mutassa be a diákok számára, ezáltal növelve a tantárgy iránti érdeklődést.\\n\\nRendhagyó Kémiaórák: Rendszeresen tart látványos, színes kémiai kísérletekkel fűszerezett előadásokat nemcsak az iskolában, hanem iskolán kívüli helyszíneken is (például könyvtárban az Országos Könyvtári Napok programsorozat keretében).\\n\\nLátványos Kísérletek: Ezeken a bemutatókon olyan látványos kísérleteket végez, mint például a \\"lombikba cuppant tojás\\" vagy a \\"vulkánkitörés,\\" amellyel a kémia varázslatos és misztikus oldalát igyekszik bemutatni a fiatalabb korosztály számára.\\n\\nDiákok bevonása: Saját gimnáziumi diákjait (gyakran kémia-biológia szakosokat) is bevonja a kísérletek segítésébe, ezzel gyakorlati tapasztalatszerzési lehetőséget nyújtva nekik.\\n\\n\\nRészt vesz a Kaposvári Táncsics Mihály Gimnázium tehetséggondozó munkájában a szaktárgyai területén.\\n\\nMatematika és Kémia Szak: Matematika és kémia szakos tanárként mindkét területen részt vesz a diákok oktatásában és fejlesztésében.\\n\\nCurie Kémia Emlékverseny: Diákjait sikeresen készíti fel a kémiai tanulmányi versenyekre, mint például a Curie Kémia Emlékversenyre, ahol tanítványai területi döntőkben érnek el eredményeket.", "mtmi_csapat_tag7_tevekenyseg": "Versenyfelkészítés digitális kultúra, robotika.Raskoványi Miklós munkájának kiemelt területe a diákok felkészítése a legjelentősebb hazai informatikai versenyekre.\\n\\nVersenyfelkészítés: Diákjaival rendszeresen ér el szép eredményeket rangos országos versenyeken.\\n\\nInformatika OKTV: Tanítványai jutnak be az Országos Középiskolai Tanulmányi Verseny (OKTV) Informatika II. kategória döntőjébe.\\n\\nNemes Tihamér Verseny: Aktívan részt vesz a diákok felkészítésében a Nemes Tihamér Országos Alkalmazói Tanulmányi Versenyen, ahol tanítványai döntős helyezéseket érnek el.\\n\\nE-hód verseny: Sikeres felkészítő tanár az E-hód nemzetközi informatikai és számítógép-készség verseny országos döntőjében is.\\n\\nTehetséggondozó Foglalkozások: Rendszeresen tart tehetséggondozó foglalkozásokat 8. osztályos tanulóknak, előkészítve őket a középiskolai informatika oktatásra és felvételire.\\n\\n🏅 Szakmai Elismertség\\nA kaposvári informatikai életben elismert szakember.\\n\\nDíjazás: 2022-ben a Somogy megye Év Informatika Tanára pályázaton IV. helyezést ért el, ami mutatja a helyi informatikai közösségben betöltött elismert szerepét és a korszerű oktatás iránti elkötelezettségét.\\n\\nA Táncsics Gimnáziumban kulcsszerepet vállal az informatikai események és projektek szervezésében.\\n\\nAJTP Országos Informatikaverseny: Szervezője és szakmai támogatója az Arany János Tehetséggondozó Program (AJTP) Országos Informatikaversenynek, amely Kaposváron, a Táncsics Gimnáziumban kerül megrendezésre. Ebben a szerepben aktívan hozzájárul a tehetséggondozáshoz regionális és országos szinten.\\n\\nNeumann 120 Kiállítás: Részt vett a Neumann 120 vándorkiállítás kaposvári megnyitójának szervezésében és dokumentálásában (fotósként is), ezzel is népszerűsítve a számítástechnika tudományát.", "mtmi_csapat_tag8_tevekenyseg": "Biológia és elsősegélynyújtás tehetséggondozás.Alapvető tevékenységét a gimnáziumi biológia és környezettan oktatása jelenti.\\n\\nSzaktárgyak: Biológia-környezettan szakos tanárként a természettudományok élővilágra és környezetre vonatkozó területeinek oktatásában vesz részt.\\n\\nFelvételi Előkészítés: Aktívan közreműködik a gimnázium tehetséggondozó programjában. Részt vesz a 8. osztályos tanulók számára szervezett biológia-kémia előkészítő foglalkozások tartásában, segítve ezzel a továbbtanulásra való felkészülést.\\n\\n\\nAz MTMI területén kívül is fontos szerepet tölt be az iskola életében, ami áttételesen támogatja a diákok szélesebb körű fejlődését és közösségi tevékenységét.\\n\\nOsztályfőnöki Feladatok: Osztályfőnöki feladatokat is ellát (pl. 12. B osztályfőnöke).\\n\\nDiákönkormányzat Segítése: A Diákönkormányzatot (DÖK) segítő tanárként kulcsszerepet játszik a diákok önálló kezdeményezéseinek és projektjeinek támogatásában, ami hozzájárul a közösségi élet és az esetleges tudományos témájú diákprojektek megvalósításához.\\n\\nMáté-Márton Gergely MTMI tevékenysége tehát a biológián és a környezettanon keresztül a természettudományok alapjainak átadására, a fiatalabbak felkészítésére és az iskolai közélet aktív támogatására irányul.", "mtmi_aktiv_tanulas_megvalosul": "igen", "mtmi_csapat_kozos_tevekenyseg": "A Kaposvári Táncsics Mihály Gimnázium MTMI csapata (Matematika, Természettudományi, Műszaki, Informatikai) kiemelkedő szerepet tölt be a régió tehetséggondozásában és az innováció népszerűsítésében.\\n\\nKiemelt Tevékenységek\\nOTIO és Science Fair Rendszeres Szervezése: A gimnázium a Magyar Innovációs Szövetséggel és a Magyar Agrár- és Élettudományi Egyetemmel (MATE) együttműködve rendezi meg az Országos Tudományos és Innovációs Olimpia (OTIO) regionális válogatóját, a Kaposvári Science Fair kiállítást. Ezzel központi szerepet kapnak a fiatal kutatók és innovátorok számára, teret adva nekik természet-, műszaki- és agrártudományos projektek (kémia, fizika, informatika, biológia) bemutatására. A Science Fairen évről évre több tucat projekt és nagyszámú diák vesz részt.\\n\\nMatematika Tehetséggondozás: Az emelt szintű matematika képzés mellett a tehetséggondozás hangsúlyos elemét jelenti a magas szakmai színvonalú, külső szakemberek bevonásával tartott előadások szervezése. Például a 2024-es évben Dr. Pintér Ferenc (az Erdős Pál Iskola egyik alapítója) tartott előadást az emelt szintű képzésben résztvevőknek.\\n\\nDigitális Kultúra és Informatika: A gimnázium 2026-ban már 23. alkalommal rendezi meg az AJTP Országos Informatikaversenyt két korcsoportban, mely a NAT2020 és ECDL követelményekre épül. A verseny témakörei között szerepel a mesterséges intelligencia napjainkban. Ez aktív szerepvállalást mutat a digitális tehetségek felkutatásában és képzésében.\\n\\nFizika és Kémia (Természettudományok):\\n\\nFizika: Ingyenes fizika tehetséggondozó szakköröket indítanak 7-8. osztályos diákoknak látványos kísérletekkel, a középiskolai tanulmányokra való felkészítés és a természettudományok iránti érdeklődés felkeltése céljából.\\n\\nÁltalános Természettudományok: A Science Fair keretein belül a diákok a kémia és a fizika területén is bemutathatják innovációikat (pl. korábbi projektek között szerepelt napelemes hibrid okosroller is).\\n\\n", "mtmi_fakultaciok_diakok_szama": "200", "mtmi_kiallitoterek_megvalosul": "igen", "lanyoknak_szolo_mtmi_programok": "igen", "mtmi_egyeb_tevekenysegek_szama": "2", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_laboratoriumok_latogatasa": "igen", "mtmi_otlet_esszepalyazat_szama": "12", "intezmenytipus_tanuloi_letszama": "620", "mtmi_faliujsag_vitrin_reszvetel": "igen", "mtmi_palyaorientacio_megvalosul": "igen", "mtmi_faliujsag_vitrin_bemutatasa": "A laboratóriumi tér kiválóan alkalmas a tudományos eredmények közvetlen bemutatására:\\n\\nPoszterkiállítások: A laborban rendszeresen állítanak ki posztereket a különböző MTMI-versenyek (pl. TUDOK, kutatói pályázatok) lezajlása után. Ez lehetőséget ad a diákoknak, hogy bemutassák a kutatási eredményeiket, módszereiket és a projektek tanulságait (például Limnoscan, vagy sugárzásmérés).\\n\\n Asztrofotó kiállítás\\nAz asztrofotó kiállítás a technika, a fizika és a vizuális művészetek interdiszciplináris találkozása:\\n\\nVizuális udomány: Az iskola tehetséges diákjainak csillagászati fotóit rendszeresen kiállítják. Ez nem csupán a csillagászat és az optika iránti érdeklődést növeli, hanem bemutatja a diákok technikai és művészi felkészültségét is.\\n Táncsics galéria\\nAz iskola saját galériája alkalmas nagyobb, reprezentatív tárlatok megrendezésére:\\n\\nRendszeres kiállítások: A Táncsics Galériában is rendszeresen kerülnek bemutatásra MTMI témájú alkotások, poszterek vagy projektdokumentációk, amelyek így szélesebb iskolai közösség számára válnak láthatóvá.\\n\\n\\n\\nDigitális rendezvények: A Digitális témahét rendezvényein a diákok és tanárok bemutatják az informatikai, programozási és digitális kultúra területén elért projektjeiket (pl. 3D modellezés, tereptárgyak felismerése), gyakran interaktív módon.\\n\\nEzek a vizuális és digitális bemutató terek sokkal hatékonyabban ösztönzik a többi diákot az MTMI területek felé, mint egy hagyományos hirdetőtábla, hiszen konkrét, látható eredményeket mutatnak be.", "mtmi_felelos_kapcsolattarto_neve": "Matics Martin", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "igen", "mtmi_tanoran_kivuli_rendezvenyek": "1. Tudományos és Innovációs Események\\nScience Fair és OTIO Regionális Válogató: Évente megrendezett, nagyszabású tudományos kiállítás és innovációs verseny a gimnáziumban, mely egyben az Országos Tudományos és Innovációs Olimpia (OTIO) regionális válogatója. Ez az esemény regionális központként funkcionál, lehetőséget biztosítva a diákoknak kémiai, fizikai, biológiai, informatikai kutatási projektek és innovációk zsűri előtti bemutatására.\\n\\nTUDOK Felkészítő Szemináriumok: Rendszeres, délutáni szemináriumok a Tudományos Diákkörök Országos Konferenciájára (TUDOK) készülő diákok számára, ahol a kutatási protokollok, a tudományos publikációk készítése és a prezentációs technikák állnak a fókuszban.\\n\\n2. Digitális Kultúra és Pályaorientációs Rendezvények\\nDigitális Témahét a Somogy Megyei TST-vel: Évente megrendezett, intenzív programsorozat a Somogy Megyei Táncsics Szakképző Iskola és Technikummal (TST) együttműködésben. Ez a rendezvény a digitális kultúra és a műszaki területeket kapcsolja össze, bemutatva a legújabb technológiai trendeket, MI-alkalmazásokat és robotikai megoldásokat. A cél a műszaki pályaorientáció támogatása és a gyakorlati digitális tudás átadása.\\n\\nAJTP Országos Informatika Verseny: A gimnázium által évi rendszerességgel megrendezett, országos verseny, amelynek regionális és országos fordulói is komoly szakmai rendezvénynek számítanak.\\n\\nMTMI Fórumok és Kerekasztal-beszélgetések: Alkalmankénti találkozók külső szakértőkkel, egyetemi oktatókkal (pl. MATE), ahol a diákok aktuális tudományos és innovációs kérdésekről vitatkozhatnak, és tájékozódhatnak a reál diplomák nyújtotta karrierlehetőségekről.\\n\\n3. Kiegészítő Versenyek és Workshopok\\nMatematikai Versenyek Helyi Fordulói: Az iskola ad otthont a Nemzetközi Kenguru Matematikaverseny, az Arany Dániel Matematikai Tanulóverseny és más regionális matematikaversenyek fordulóinak.\\n\\nFizika és Kémia Kísérletező Délutánok: A természettudományok iránt érdeklődők számára szervezett délutáni workshopok a laboratóriu", "mtmi_tanulmányi_versenyek_szama": "25", "programban_erintett_tanulok_szama": "200", "mtmi_diakok_kapcsolattartas_leiras": "A kapcsolattartó tanár közvetítőként és szervezőként segíti az MTMI-vel kapcsolatos gyakorlati tapasztalatok megszerzését:\\n\\nVersenyek és Pályázatok: Tájékoztat a releváns tanulmányi versenyekről (pl. Nemes Tihamér, OKTV, Curie-verseny), nyári táborokról (pl. informatikai, robotikai táborok) és kutatói pályázatokról. Ő maga vagy kollégái segítségével bekapcsolja a diákokat a versenyfelkészítésbe.\\n\\nIskolán Kívüli Projektek: Szervezi a diákok részvételét a gimnázium MTMI projektjeiben (mint pl. a Limnoscan, vagy a meteorológiai ballon), segítve a diákok beosztását a projektcsapatokba.\\n\\nSzakmai Kapcsolatok: Felveszi a kapcsolatot helyi MTMI cégekkel, egyetemekkel vagy kutatóintézetekkel (például a Kaposvári Campus) a pályaorientációs napok, gyárlátogatások, szakmai előadások és nyílt napok szervezése érdekében.\\n\\nA kapcsolattartó tehát nem csupán elméleti tanácsokat ad, hanem konkrét, gyakorlati lehetőségekhez is juttatja a diákokat, segítve őket abban, hogy a legmegfelelőbb MTMI területen találják meg a jövőjüket", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyeb_tovabbkepzesi_programok": "Folyamatos tudásmegosztás zajlik a csapat tagjai között és a tagok felől valamennyi pedagógus felé munkaértekezleteken, szakmai napokon", "mtmi_egyuttmukodes_palyaorientacio": "igen", "mtmi_felelos_kapcsolattarto_email1": "matics.tancsics.kaposvar@gmail.com 0630", "mtmi_felelos_kapcsolattarto_email2": "iskola@tancsics.hu", "mtmi_online_palyaorientacio_leiras": "Minden 9.-10. évfolyamos diák kitölti a POM mérőeszköz kérdőívét, mely az Oktatási Hivatal fejlesztése és 3 pedígógus vett részt ezzel kapcsolatos továbbképzésen", "mtmi_otlet_esszepalyazat_reszvetel": "igen", "mtmi_tanulmányi_verseny_reszvetel": "igen", "intezmenyvezeto_kapcsolattarto_neve": "Vámosi László", "mtmi_kutatási_verseny_diakok_szama": "6", "mtmi_digitalis_tananyagok_megvalosul": "igen", "mtmi_felelos_kapcsolattarto_beosztas": "szaktanár", "mtmi_kutatási_verseny_tanarok_szama": "2", "intezmenyvezeto_kapcsolattarto_email1": "igazgato.ktmg@gmail.com", "intezmenyvezeto_kapcsolattarto_email2": "iskola@tancsics.hu", "mtmi_otlet_esszepalyazat_diakok_szama": "5", "mtmi_tanulmányi_verseny_diakok_szama": "200", "mtmi_tanulmányi_versenyek_bemutatasa": "A tehetséggondozás sikerét a matematika, fizika, biológia, kémia tárgyakra fókuszáló, intenzív felkészítő munka és az innovációs projektek adják.\\nMatematika és Természettudományos Eredmények\\nMatematikából a diákok kiemelkedő országos sikereket értek el: az AJTP Országos Matematikaverseny országos döntőjében 2. helyezést, míg az OKTV Matematika II. kategóriában 7. helyet szereztek. Az Izsák Imre Gyula Komplex Természettudományi Versenyen a diákok mind a matematika, mind a fizika szekcióban 2. helyezést értek el, demonstrálva a tantárgyak közötti erős áthallást. A nemzetközi mezőnyben is helyt álltak: öt tanuló különdíjat kapott a Nemzetközi Magyar Matematika Versenyen. A Dürer Fizikaversenyen (F kategória) pedig egy csapat a 2. helyet szerezte meg az országos döntőben.\\n\\nBiológia, kémia és Tudományos Diákkörök Országos Konferenciája (TUDOK)\\nA biológia és kémia szaktárgyakban elért országos eredmények a legmagasabb szintű tudományos felkészítést mutatják. A diákok országos döntő 1. helyezést értek el a neves Árokszállásy Zoltán biológia-környezetvédelmi versenyen és a Fodor József Biológia verseny több kategóriájában is. A Kontra József Országos Kémia Versenyen és az Irinyi János Középiskolai Kémia Versenyen is több 1. helyezés született. Külön kiemelendő, hogy egy tanuló ezüstérmes minősítést kapott az European Olympiad of Experimental Science nemzetközi versenyen (7. helyezés).\\n\\nA Tudományos Diákkörök Országos Konferenciáján (TUDOK) egy diák a műszaki és természettudományi, valamint biológia és környezettudományi szekciót is érintő Élet és Környezettudományi Szekcióban nemzetközi döntő 2. helyezést ért el, ami a kutatói munka legmagasabb szintű gimnáziumi elismerése.\\n\\nInnováció és technológia\\nAz iskola vezető szerepét az innováció terén az Országos Tudományos és Innovációs Olimpia (OTIO) és a Science Fair eredményei is megerősítik: a diákok Science Fair országos döntő 2. és 3. helyezést, valamint OTIO nemzetközi döntő 2. helyezést és különdíjat szereztek. ", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_otlet_esszepalyazat_tanarok_szama": "2", "mtmi_tanulmányi_verseny_tanarok_szama": "20", "intezmenyvezeto_kapcsolattarto_beosztas": "igazgató", "mtmi_interdiszciplinaris_projekt_leiras": "Néhány a sok futó projekt közül(jelenleg 12 db) : \\nLimnoscan\\nA Limnoscan a hidrobiológia/környezetvédelem és az informatika/műszaki tudomány találkozása.\\nLényeg: Egy vízminőséget vizsgáló szonda vagy rendszer kifejlesztése.\\nInterdiszciplinaritás: Szenzorok (fizika/kémia/biológia) és a gyűjtött adatok valós idejű feldolgozása, vizualizálása és elemzése (informatika/elektronika). A cél a vízi ökoszisztémák monitoringozása, ami komplex természettudományos tudást igényel.\\n Fixit 3D\\nEz egy műszaki, digitális kultúra és informatika fókuszú projekt.\\n\\nLényeg: Egy 3D nyomtatásra épülő szolgáltatás vagy platform, amely törött, elhasználódott tárgyak (pl. háztartási eszközök, alkatrészek) pótlását, javítását teszi lehetővé.\\n\\nInterdiszciplinaritás: Tervezés (CAD/matematika), 3D modellezés (informatika), a megfelelő anyagminőség kiválasztása (kémia/anyagismeret) és a gyártástechnológia (műszaki tudományok) ötvöződik a cél érdekében.\\nGyerekstop\\nA Gyerekstop egy informatikai, szenzorika és biztonságtechnikai fókuszú, gyakran az egészségügyi/pedagógiai szempontokat is bevonó kezdeményezés.\\nLényeg: Gyermekek járműben (pl. autóban) felejtésének megakadályozására szolgáló riasztórendszer.\\n\\nInterdiszciplinaritás: Szenzorok (elektronika/fizika) telepítése és a beolvasott adatok (pl. súly, mozgás, hőmérséklet) értékelése, riasztási logika megtervezése (programozás/informatika), valamint a hardveres megvalósítás.\\n\\nTereptárgyak felismerése\\nA Tereptárgyak felismerése egy tiszta informatikai és matematikai (analitikai) projekt.\\n\\nLényeg: Különböző adatokból (kép, radar, LiDAR) objektumok azonosítására és osztályozására szolgáló algoritmusok (pl. gépi tanulás, mesterséges intelligencia) fejlesztése.\\nInterdiszciplinaritás: Képfeldolgozás, algoritmus-fejlesztés  statisztikai és matematikai modellezés ), a valós környezet fizikai jellemzőinek megértésével (fizika/földrajz).\\nMeteorológiai ballonnal történő sugárzásmérés\\nEz a projekt a fizika, a műszaki tudományok és a meteorológia/környezettan\\n", "mtmi_tovabbkepzesek_idokeret_megvalosul": "igen", "mtmi_tovabbkepzesi_programok_megvalosul": "igen", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "Az Erasmus+ projekt keretében, bolgár román iskolákkal közösen dolgoztunk ilyen jellegű digitális projekten, illetve az Innovációs Tehetséggondozó műhelyünk is ezzel a módszerrel dolgozik", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 30 867 3523", "mtmi_felelos_kapcsolattarto_telefonszam2": "0682512128", "mtmi_kiallitoterek_megvalosul_bemutatasa": "A Táncsics Galériában és a Természettudományis Laborban kiállítjuk a tanulóink munkáit innovációit, illetve képgalériában elérhetők az innovatívprojektjeink ", "intezmenyvezeto_kapcsolattarto_telefonszam1": "+36 30 634 7577", "intezmenyvezeto_kapcsolattarto_telefonszam2": "0682512128", "mtmi_digitalis_eszkozok_megvalosul_bemutatasa": "Fizika és Kémia: A diákok aktívan használják a Dr. Kontra József Természettudományi Laboratórium digitális felszerelését. Ez magában foglalja a valós idejű adatrögzítést segítő szenzorokat, mérőrendszereket és adatgyűjtő interfészeket. Például fizikaórán a mozgások vagy elektromos áramkörök paramétereit rögzítik digitálisan, majd az adatokat táblázatkezelő vagy speciális analitikai szoftverekkel dolgozzák fel. A kísérletek elvégzését szimulációs szoftverek és animációk is támogatják, különösen a bonyolultabb jelenségek, mint a kvantumfizika vagy a kémiai reakciókinetika vizualizálásánál.\\n\\nBiológia: A digitális mikroszkópok és a képelemző szoftverek segítik a sejtek, szövetek vizsgálatát, míg a nagyméretű biológiai adatok elemzéséhez digitális módszereket (pl. adatábrázolás, statisztika) alkalmaznak.\\n\\n2. Matematika és Informatikai Modellezés\\nMatematika: A komplexebb számítások és a függvényábrázolások vizualizálására rendszeresen használnak matematikai szoftvereket (pl. GeoGebra, speciális grafikonrajzoló programok). Ez lehetővé teszi a diákok számára, hogy a tanult elméleti összefüggéseket (pl. geometriai transzformációk, differenciálszámítás) azonnal, vizuálisan értelmezzék. Az emelt szintű felkészítés során a diákok a felkészítő feladatok megoldásához és a komplex adatok kezeléséhez is alkalmaznak digitális eszközöket.\\n\\nDigitális Kultúra: A tantárgy maga is a digitális eszközök használatára épül. A programozás oktatásában a vizuális és szöveges programozási nyelvekhez szükséges fejlesztői környezeteket használják. A digitális kultúra integrálódik az MTMI tárgyakba a projektmenedzsment és a tudományos prezentáció (pl. poszterkészítés a Science Fair-re) digitális eszközeinek oktatásával.Science Fair / OTIO / TUDOK: A projektmunkák során a digitális eszközök a prototípusfejlesztéshez (pl. 3D-modellezés, mikrokontrollerek programozása), az adatgyűjtéshez és a kutatási eredmények prezentálásához (pl. tudományos poszterek, prezentációk) elengedhetetlenek.\\n\\n", "mtmi_digitalis_tananyagok_megvalosul_bemutatasa": "Digitális Tananyagok Alkalmazása\\nA gimnáziumban használt digitális tananyagok és módszerek célja az elvont MTMI fogalmak vizualizálása és a tanulók aktív bevonása:\\n\\nMultimédiás Tartalmak: A laborpályázatok révén létrehozott animációkat és videókat integrálják a tanórákba. Ezek segítik a nehezen megfigyelhető folyamatok (pl. kémiai reakciómechanizmusok, fizikai mozgások, biológiai folyamatok) megértését. A fizika szakkörök és a tanórák is előszeretettel használnak ilyen vizuális elemeket a motiváció növelésére.\\n\\nInteraktív Tananyagok: A digitális tananyagok között szerepelnek interaktív munkafüzetek és feladatlapok, amelyek azonnali visszajelzést adnak a diákoknak, segítve az önálló tanulást. A matematika és informatika órákon ezek a feladatok gyakran tartalmaznak programozási, modellezési vagy problémamegoldó szimulációkat.\\n\\nMérések és Gyakorlatok Digitalizálása\\nDigitális Mérések: A Dr. Kontra József Természettudományi Laborban a méréseket teljes egészében digitalizálták. A diákok digitális szenzorokkal és adatgyűjtőkkel dolgoznak fizika, kémia és biológia órákon, rögzítve a valós idejű adatokat. Ez nem csupán gyorsítja a méréseket, hanem lehetővé teszi a méréstechnikai hibák azonnali felismerését és korrigálását is.\\n\\nAdatfeldolgozó Eszközök: A mérések során gyűjtött adatok feldolgozásához speciális szoftvereket és táblázatkezelő programokat használnak. Ez a digitális gyakorlat készíti fel a diákokat a Science Fair, OTIO és TUDOK projektek szigorú adatelemzési és statisztikai követelményeire, melyek a modern tudományos munkához elengedhetetlenek.", "mtmi_korszeru_felszereltseg_megvalosul_bemutatasa": "Folyamatosan fejlesztjük eszközparkunkat pályázatok segítségével, ahol digitális eszközöket, mikroszkópokat, planetáriumot, számítógépeket szerzünk be NTP,illetve a Selye pályázat keretében", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul": "igen", "mtmi_tovabbkepzesek_idokeret_megvalosul_bemutatasa": "Több kollégfánk vett részt az elmúlt években az OH által szervezett STEM továbbképzésen, illetve Matics Martin részt vesz a fizikatanári ankéteken, illetve 2024-ben Lengyelországban, 2025-ben Csehországban vett részt nemzetközi továbbképzésen. A Selye Diáklabor pályázat során részt vettünk EMBL digitális mikroszkóp képzésen, 3D nyomtatással kapcsolatos illetve mobillabor busz használatáról szóló továbbképzéseken a Magyarországi Diáklaborok egyesületének szervezésében és tagjaként,", "mtmi_tovabbkepzesi_programok_megvalosul_bemutatasa": "Az OH bázisintézményeként folyamatosan tartunk rendezvényeket műhelymunkákat, STEM bemutatókat", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul": "igen", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul_bemutatasa": "A STEM-es csapat tagjainak a teljesítménycélok többsége az MTMI célokról, azok megvalósításáról szól", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul_bemutatasa": "Az iskola igazgatója elkészítette az éves továbbképzési tervet, ahol több MTMI csapattag fiatal jolléga részt vesz képzéseken"}	2025-09-21 17:43:34.367399	2026-03-30 11:06:31.433065	0	6fb006f4-1cc4-4b75-a7e3-a89d531854ea_KTMG_II_Science_Fair_felhivas_final.pdf	1a4039ac-ecab-4f5a-8544-d01732c8f95c
8199a4f5-45bf-4c2e-8dd5-bf7a3e7984e2	{"iskola_cime": "8000 Székesfehérvár, Budai út 43.", "iskolatipus": ["gimnazium"], "gdpr_consent": ["on"], "szulo_bevonas": "nem", "mtmi_koncepcio": "nem", "telepulesforma": "megyeszekhely_varos", "mtmi_nyilt_napok": "Eddig nem volt ilyen.", "szulo_egyeztetes": "nem", "mtmi_csapat_link1": "https://www.lkg.hu/alkotohet-2024/", "mtmi_projektnapok": "A tanév során tavasszal a Lánczosban tematikus hetet tartunk. Ekkor nem tartunk szakórákat, hanem meghívással, jelentkezéssel alakulnak tematikus csoportok, minden évben megjelenítve az MTMI tevékenységeket, legalább 10-12 diák részvételével tudományterületenként.", "pedprog_mtmi_link1": "https://www.lkg.hu/wp-content/uploads/2025/09/PP-2025.pdf", "szulo_kommunikacio": "megvalosul", "mtmi_ceglatogatasok": "nem", "mtmi_csapat_letszam": "5", "palyazo_iskola_neve": "Lánczos Kornél Gimnázium", "mtmi_csapat_tag1_nev": "dr. Ujvári Sándor", "mtmi_csapat_tag2_nev": "dr. Nyerkiné Alabert Zsuzsanna Ágnes", "mtmi_csapat_tag3_nev": "Szulik Ákos", "mtmi_csapat_tag4_nev": "Erdélyi Zsuzsanna", "mtmi_csapat_tag5_nev": "Kovács Gergely", "mtmi_szakkorok_szama": "1", "mtmi_szulo_kepviselo": "nem", "mtmi_alumni_programok": "nem", "mtmi_csapat_tag1_szak": ["fizika"], "mtmi_csapat_tag2_szak": ["fizika", "kemia"], "mtmi_csapat_tag3_szak": ["kemia", "biologia"], "mtmi_csapat_tag4_szak": ["biologia"], "mtmi_csapat_tag5_szak": ["matematika"], "mtmi_csapat_tag6_szak": [], "mtmi_csapat_tag7_szak": [], "mtmi_csapat_tag8_szak": [], "pedprog_mtmi_tartalom": "nem", "szulo_palyaorientacio": "nem", "mtmi_fakultaciok_szama": "8", "mtmi_nyilt_napok_link1": "https://www.lkg.hu/alkotohet-2025/", "iskola_tanuloi_letszama": "240", "mtmi_szakkor_tantargyak": ["fizika", "kemia", "biologia"], "mtmi_szakmak_bemutatasa": "nem", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "nem", "mtmi_szakmai_gyakorlatok": "Évente két alkalommal - a tanév elején és végén - a 9. évfolyamos természetismeret irányultságú osztály tagjai terepgyakorlaton vesz részt. A gyakorlat célja, hogy a gyerekek ízelítőt kapjanak a terepgyakorlati munka rejtelmeiből, és megismerkedjenek néhány olyan kísérleti módszerrel, amelyek a terepen dolgozó földrajzos, környezettudós vagy épp biológus-kémikus kutatók repertoárját színesítik. A terepmunka során talaj-, víz- és növényminta gyűjtése (is) történik, amelyek vizsgálatát a következő hetekben, a laboratóriumi gyakorlati órákon végzik el a tanulók.", "mtmi_egyetemi_gyakorlatok": "igen", "mtmi_szakkor_diakok_szama": "10", "mtmi_szakkorok_bemutatasa": "A Lánczos Kornél Gimnázium a 2019/2020 évi akkreditációs folyamatban való részvétele eredményeként az Akkreditált kiváló Tehetségpont címet nyerte el.\\n\\nAz akkreditációs folyamat tapasztalatai megerősítették a Nemzeti Tehetségpont munkatársai számára, hogy iskolánk tehetségpontja szakmailag hiteles és kompetens tagja a Matehetsz Tehetséghálózat egyre bővülő családjának, valamint működésünkkel már ma is aktív részesei vagyunk hálózatuknak. \\nAz sikolai szakkör célja a diákok által választott projektek megbeszélése, vezetése, végrehajtása. Konzultációs lehetőség biztosítása. A versenyekre való felkészülés is szerves része az éves tevékenységeknek (TUDOK, Lánczos-verseny, stb...) Külön projekt tervezése és végrehajtása az iskola saját tematikus hetében, az Alkotóhéten.", "szulo_munkakoz_ismertetes": "nem", "mtmi_szakkor_tanarok_szama": "1", "iskola_mtmi_tanari_letszama": "5-6", "mtmi_diakok_kapcsolattartas": "igen", "mtmi_online_palyaorientacio": "nem", "lanyok_mtmi_kiemelt_figyelem": "nem", "mtmi_csapat_tag1_tevekenyseg": "Kutató diák szakkör szervezése, fizika projektek vezetése\\nLánczos Kornél megyei fizikaverseny szervezése, zsűrizése\\nRészecskefizikai diákműhely szervezése\\nEmelt fizika érettségi felkészítés\\nFizika laboratóriumi mérések vezetése, laboratórium fejlesztése\\nKísérleti bemutatók ( tábor, Kutatók éjszakája)\\nAlkotóhéten projektvezetés, a beszámoló elkészítése\\n\\nIskolán kívül:\\nNukleáris tábor szervezése\\nSzilárd Leó Nukleáris Fizikaverseny szervezése, feladatkitűzés, zsűrizés\\nFizika Szemle szerkesztőbizottsága\\nFizikatanári ankét szervezése\\n", "mtmi_csapat_tag2_tevekenyseg": "Mindkét tantárgyamból készítek emelt szintű érettségire. Iskolánkban kémiából kidolgoztam minden témakörhöz laboratóriumi gyakorlatot, amit vezetek is. Rendszeresen készítek versenyre. Igazán a csapatversenyek a specialításom. Általam patronált csapatok nélkül már elképzelhetetlen a Halavy József Országos Környezettudományi és Műszaki Konferencia Junior mérnök verseny döntője, ahol mindig dobogós helyet érnek el. Bay Zoltán Kutatóképző versenyen is döntősök voltak a tanítványaim. Kapcsolatot tartok a \\"Nők a tudományban\\"  egyesülettel. Motiválom diákjaimat az önálló kutatómunkára, ha már túlnőttek rajtam, egyetemekhez közvetítem őket. A látványok kémiai és fizikai kísérletekkel hívom fel a figyelmet rendezvényeken a tantárgyaim fontosságára. A HUNOR űrkutatási programmal népszerűsítem a műszaki tanulmányokat. TUDOK versenyeire készítem diákjaimat, ha nem índítok, zsűrizéssel segítem munkájukat. A Lánczos Kornél Fizikaverseny házigazdája és zsűritagja vagyok minden évben.", "mtmi_csapat_tag3_tevekenyseg": "A biológia és a kémia tantárgyak tanításában nyolc éve alkalmazom a játékosított oktatási keretrendszer bizonyos elemeit, ezzel motiválva diákjaimat e két diszciplína szépségeinek felfedezésére, és segítve őket az érdeklődésüknek megfelelő értékelési elemek kihasználására. Növendékeimmel évek óta részt veszünk a KutDiák által szervezett TUDOK megmérettetésen, ezzel buzdítva őket a kutatómunkában való részvételre. A konferencia előadói képességeiket is fejleszti. Közel egy évtizede szervezek diákjaimnak laboratóriumi gyakorlatokat, amelyeket terepgyakorlatokkal is színesítünk. Több mint egy évtizede, korábbi és jelenlegi iskolám berkein belül is szervezek természettudományos táborokat az erre nyitott nagyérdeműnek, korábban országos és regionális, jelenleg települési szinten.", "mtmi_csapat_tag4_tevekenyseg": "Több, mint 20 éve tanítok biológiát a középfokú oktatásban. Iskolánk keretein belül visszük a diákokat terepgyakorlatra, természettudományi táborba. A terepgyakorlat elsősorban az erre orientálódott osztály kiváltsága, de gyakran fedezzük fel más osztályokkal is a környékünk ökológiai érdekességeit. A természettudományi tábor pedig a Gaja-völgy szomszédságában, állandó helyszínen adja a megfigyelések, vizsgálatok lehetőségét.\\nIskolánk egyik állandó programja az alkotóhét is, melynek során anatómiai, bonctani foglalkozásokat szervezek az ilyen érdeklődésű diákoknak.", "mtmi_csapat_tag5_tevekenyseg": "A matematika (oktatása mellett) népszerűsítése céljából évek óta sikeresen veszünk részt hazánk legnagyobb nyílt országos versenyén, a Medve matematika versenyen. Egyedi tehetségek egyéni foglalkoztatása matematikából, felkészítés és megalapozás az MTMI tudományok  megsegítése és együttműködése céljából. 6 éven át igazgatóként, jelenleg igazgatóhelyettesként elkötelezett támogatója vagyok a természettudományok népszerűsítésének, összefogásának!Komoly erőfeszítés nélkül a matematikában nem juthatunk messzire. Aki azonban megízlelte a matematika szépségét, hajlandó lesz komoly erőfeszítéseket is tenni.", "mtmi_aktiv_tanulas_megvalosul": "reszben", "mtmi_fakultaciok_diakok_szama": "50", "mtmi_kiallitoterek_megvalosul": "igen", "lanyoknak_szolo_mtmi_programok": "igen", "mtmi_egyeb_tevekenysegek_szama": "3", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_kutatási_versenyek_link1": "https://www.lkg.hu/hirek/szent-gyorgyi-albert-nyomaban-2/", "mtmi_kutatási_versenyek_szama": "3", "intezmenytipus_tanuloi_letszama": "240", "mtmi_faliujsag_vitrin_reszvetel": "nem", "mtmi_palyaorientacio_megvalosul": "igen", "mtmi_felelos_kapcsolattarto_neve": "dr. Ujvari Sándor", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "igen", "mtmi_tanoran_kivuli_rendezvenyek": "Nyáron megrendezésre kerülő tábor természettudományi blokkjában fizikai kísérletek, vízrakéta építés valamint vitaminok kimutatása gyümölcsökben. A foglalkozások során közel 80 diák kerül közelebbi kapcsolatba az MTMI tudományokkal, felkínálva a lehetőséget a további kutatásokra, foglalkozásokra, szakkörökre.", "mtmi_tanulmányi_versenyek_link1": "https://www.lkg.hu/hirek/hetvegen-veszpremben-gyozelem/", "mtmi_tanulmányi_versenyek_szama": "4", "programban_erintett_tanulok_szama": "23", "mtmi_diakok_kapcsolattartas_leiras": "Egyetemlátogatások évente valósulnak meg(10-11-12. évfolyam). Az érdeklődés felmerülése esetén egyéni tanácsadási lehetőség az iskolában, amellyel minden évvben élnek is. ", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyuttmukodes_palyaorientacio": "nem", "mtmi_felelos_kapcsolattarto_email1": "ujvasa36@gmail.com", "mtmi_otlet_esszepalyazat_reszvetel": "nem", "mtmi_tanulmányi_verseny_reszvetel": "igen", "intezmenyvezeto_kapcsolattarto_neve": "Kovács Gergely", "mtmi_kutatási_verseny_diakok_szama": "12", "mtmi_kutatási_versenyek_bemutatasa": "Lánczos Kornél Megyei Fizikaverseny (házigazdaként)\\nKutDiák Konferencia: TUDOK mindhárom részében\\nSzent-Györgyi Albert Tanulmányi Verseny", "mtmi_felelos_kapcsolattarto_beosztas": "fizika tanár", "mtmi_kutatási_verseny_tanarok_szama": "3", "intezmenyvezeto_kapcsolattarto_email1": "kovacs.gergely@lkg.hu", "mtmi_egyeb_palyaorientacios_programok": "Sikeres alumni diákok részvételével pályaorientációs kerekasztal beszélgetés során tájékoztatjuk a diákokat. Az esemény a Pályaorientációs napunk keretein belül minden év november-december magasságában zajlik, figyelembe véve a felvételi időszak kezdetét. Az egyetemistákkal később egyéni konzultációra is van lehetőségük a diákoknak.", "mtmi_tanulmányi_verseny_diakok_szama": "25", "mtmi_tanulmányi_versenyek_bemutatasa": "Hlavay József Országos Környezet- és Műszaki Tudományos Konferencia (egyéni kutatások és Junior Mérnök Csapatverseny)\\nSzilárd Leó Fizikaverseny\\nSzent-Györgyi Tanulmányi Csapatverseny-Szeged\\nRészecskefizikai diákműhely (országos) házigazdájaként minden évben kutató nap szervetése iskolánkban", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_tanulmányi_verseny_tanarok_szama": "3", "intezmenyvezeto_kapcsolattarto_beosztas": "igazgatóhelyettes/matematika, földrajz", "mtmi_interdiszciplinaris_projekt_leiras": "A gimnázium 9. évfolyamán minden osztály csoportbontásban részt tud venni kémia/biológia laborgyakorlaton, ahol ismerkedhetnek a tudományok multidiszciplináris lehetőségeivel. Kifejezetten igaz ez a természetismereti irányultságú osztálynál, ahol külön laborgyakorlatok jelennek meg az órarendben. ", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "A természettudományok oktatásában részben portfólióértékelést alkalmaz az iskola. A JOKER, játékosított keretrendszer alkalmazásával a diákok az ellenőrző dolgozat mellett önálló és páros feladataira, otthoni és iskolai munkáira is pontokat kapnak, értékelésük sokszínű, előre deklarált keretek között zajlik. ", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 30 435 2033", "mtmi_felelos_kapcsolattarto_telefonszam2": "0622329105", "mtmi_kiallitoterek_megvalosul_bemutatasa": "A gimnázium alsó szintjén, a kémia/biológia laborok szomszédságában található vitrinszekrény a megvalósult projektek bemutatására, a természettudományos projektek bemutatására hivatott. A folyosón tablók felfüggesztésére van lehetőség.", "mtmi_palyaorientacio_megvalosulas_leiras": "Minden évben pályaorientációs napot szervezünk, amelyen a 9-12. évfolyamos diákok megismerkedhetnek a különféle felsőoktatási intézmények programkínálatával, valamint betekintést kaphatnak korábbi diákok eddigi életútjába. Emellett minden tanévben egy alkalommal diákjaink látogatást tehetnek egy-egy egyetemeken (minden évben különböző egyetemlátogatást szervezünk, iskolai szinten), ahol az induló szakok mellett az interdiszciplináris lehetőségek is komoly hangsúlyt kapnak, köztük at MTMI területek is.", "lanyoknak_szolo_mtmi_programok_bemutatasa": "Az iskola tematikus hetében natúrkozmetikumok készítésével egy héten keresztül intenzív kémia, biológia laborgyakorlat valósul meg. ", "mtmi_egyuttmukodes_palyaorientacio_leiras": "Az egyetemek és a tudományos szövetségek által meghirdetett pályázatokat és táborokat figyeljük, tájékoztatjuk a diákokat. A szükséges ajánlásokkal sikeresen segítjük a diákok részvételének lehetőségét.", "intezmenyvezeto_kapcsolattarto_telefonszam1": "+36 30 820 3199", "intezmenyvezeto_kapcsolattarto_telefonszam2": "0622329105", "mtmi_egyeb_palyaorientacios_programok_link1": "https://www.lkg.hu/hirek/palyaorientacios-nap-2024/", "mtmi_digitalis_eszkozok_megvalosul_bemutatasa": "Felszerelt fizika és biológia/kémia labor segíti a tanórák színesítését, a laborgyakorlatok szerves részei a tanmenetnek. A mérések jegyzőkönyvei, a laborgyakorlatok jegyzőkönyvei a portfólióértékelés részét képezik, árnyalják azt. A fizika laborban található digitális tábla lehetőséget biztosít online tartalmak beépítésére a munkamenetben.", "mtmi_korszeru_felszereltseg_megvalosul_bemutatasa": "A fizika labor és a kémia-biológia labor tervezett mérésekkel és gyakorlatokkal részét képezi a természettudományos tantárgyak emelt óraszámban történő oktatási tantervének. Az elektromos mikroszkópok mellett mindkét tanterem digitális táblával felszerelt, 10 fő befogadására képes szakteremként funkcionál iskolánkban."}	2025-09-16 07:36:19.715076	2026-03-05 22:23:14.44375	1	\N	2cc199b5-d2c5-4ca4-9373-9fad51866cd1
1b645429-cfb6-4608-a085-7a1889fc5456	{"iskola_cime": "8000 Székesfehérvár Budai út 7.", "iskolatipus": ["gimnazium"], "gdpr_consent": ["on"], "szulo_bevonas": "megvalosul", "mtmi_koncepcio": "igen", "telepulesforma": "megyeszekhely_varos", "mtmi_nyilt_napok": "A TDK keretén ebből a tanév során 2 alkalommal a diákok aktív részvételével tartunk nyílt napokat, melyre minden diákot, pedagógust hívunk, ill. általános iskolából is szívesen várunk érdeklődőket. Igény szerint a POK által szervezett tavaszi Pedagógiai Napok programjához is kapcsolódhatunk.\\nA nyílt napokon a “Fogadj örökbe egy fizikai kísérletet!” felhívás keretében jelentkező diákok mutatják be, és kommentálják a kísérleteket, úgy, mint a TDK karácsony megvalósításánál. \\nA novemberi nyílt napon, amikor a középiskolai képzésünk iránt érdeklődő általános iskolásokat fogadjuk és foglalkoztatjuk, akkor is diákjaink segítségével mutatjuk be kísérletek, ill. önállóan végezhető gyakorlatok formájában, hogy milyen lehetőségeik vannak az iskolánkban.\\n", "szulo_egyeztetes": "megvalosul", "mtmi_csapat_link1": "https://telekiblanka.hu/gimnazium-mtmi-iskola/", "mtmi_projektnapok": "A januári pályaorientációs napunkra rengeteg MTMI területhez kötődő előadót hívunk meg: gyakorló orvos, gyógyszerész, mérnök, informatikus stb. mesél majd a munkájáról, életútjáról. Az előadók között alumni diákok, egyetemi oktatók is vannak. Az évek óta sikeres rendezvényünk nagyon sokat segít diákjaink felvételihez kapcsolódó döntéshozatalában.\\nAz osztályfőnökök és a szaktanárok egyéni preferenciái alapján a honlapon megtalálható programkínálatban soroljuk fel az általunk ajánlott MTMI területekhez kapcsolódó szakmai programokat.\\n", "pedprog_mtmi_link1": "https://telekiblanka.hu/gimnazium-dokumentumok/", "szulo_kommunikacio": "megvalosul", "iskola_honlap_link1": "https://telekiblanka.hu/gimnazium/", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "7", "palyazo_iskola_neve": "Székesfehérvári Teleki Blanka Gimnázium és Általános Iskola", "pedprog_mtmi_leiras": "A pedagógiai programunk megfogalmazza az MTMI területekhez kapcsolódó kulcskompetenciák, azaz a matematikai, a természettudományos és digitális fejlesztésének szükségességét az ismeret, a készségek és attitűdök szintjeit. A kompetenciák fejlesztésének megvalósítása részletesen az MTMI koncepciónkban olvasható. Emellett a projektnapok szervezési lehetősége (pl: terepgyakorlatok, üzemlátogatások lehetősége) az egyetemekkel, mint külső partnerekkel való kapcsolattartás mikéntje kap külön hangsúlyt a dokumentumban.\\nA pedagógiai programunk “Oktatási Program” fejezete kifejti, hogy iskolánk tanulóinak a fele matematika irányultságú, vagy reál irányultságú képzést kap. A “B” jelű 6 évfolyamos osztályok, és a “C” jelű 4 évfolyamos osztályok. Így deklaráltan felvállaljuk a matematika és a természettudományokra épülő nevelés és oktatás fontosságát. Ennek megfelelően a következő tantárgyi programok olvashatóak a dokumentumban: Hat évfolyamos \\"B \\"osztály programja: matematikából emelt szintű képzésben részesül az emelt szintű matematika kerettantervre épülő helyi tanterv alapján. Négy évfolyamos emelt óraszámú idegen nyelvi (angol/német) osztály (kerettantervre épülő) – matematika többletórával. Négy évfolyamos reál irányultságú osztály programja (többletórával biológia, kémia, fizika, matematika tantárgyakból). A felsorolt tantárgyi programok minden MTMI területhez kötődő tantárgy esetén biztosítják az ismeretanyag elsajátítását, és a kompetenciák fejlesztését  a tanórai keretek között.", "mtmi_ceges_eloadasok": "igen", "mtmi_csapat_tag1_nev": "Kiss Ildikó", "mtmi_csapat_tag2_nev": "Siposné Tóth Krisztina", "mtmi_csapat_tag3_nev": "Lévayné Egyházi Piroska", "mtmi_csapat_tag4_nev": "Arany Csaba", "mtmi_csapat_tag5_nev": "Szabó Gábor", "mtmi_csapat_tag6_nev": "Vörös Ágnes", "mtmi_csapat_tag7_nev": "Gál Zsolt", "mtmi_koncepcio_link1": "https://telekiblanka.hu/wp-content/uploads/2025/10/MTMI-koncepcio-1.pdf", "mtmi_szakkorok_link1": "https://telekiblanka.hu/gimnazium-mtmi-iskola/", "mtmi_szakkorok_szama": "11", "mtmi_szulo_kepviselo": "igen", "mtmi_alumni_programok": "igen", "mtmi_csapat_tag1_szak": ["kemia", "biologia"], "mtmi_csapat_tag2_szak": ["matematika", "fizika"], "mtmi_csapat_tag3_szak": ["matematika", "fizika", "digitalis_kultura"], "mtmi_csapat_tag4_szak": ["foldrajz", "digitalis_kultura"], "mtmi_csapat_tag5_szak": ["matematika", "fizika"], "mtmi_csapat_tag6_szak": ["matematika", "fizika", "digitalis_kultura"], "mtmi_csapat_tag7_szak": ["foldrajz", "egyeb"], "mtmi_csapat_tag8_szak": [], "mtmi_koncepcio_leiras": "Iskolánk kiemelt célja, hogy a tanulók korszerű természettudományos, műszaki, matematikai és informatikai ismeretek birtokában, a tudomány iránt nyitott, önállóan gondolkodó, kreatív és problémamegoldó felnőttekké váljanak.\\nAz MTMI koncepciónk az iskola hagyományaira, tanári közösségünk szakmai tapasztalatára és a tanulók kíváncsiságára épül. Célunk, hogy a diákok számára a tudomány felfedezés, ne pedig tantárgy legyen – olyan élmény, amelyben az elmélet és a gyakorlat szervesen kapcsolódik egymáshoz.\\nA 21. század világában kulcsfontosságú, hogy tanulóink képesek legyenek adatokat értelmezni, kísérleteket tervezni, problémákat megoldani és digitális eszközökkel dolgozni. Az MTMI-területek fejlesztése ezért iskolánk stratégiai célja, amely szorosan összekapcsolódik a tehetséggondozással és a pályaorientációval.\\nAz iskolánkban folyó MTMI-nevelés az alábbi alapelvekre épül:\\nÉlményalapú tanulás. Interdiszciplinaritás. Projektalapú tanítás. Digitális kompetenciák fejlesztése.  Pályaorientáció és motiváció.\\n Az alapelvekhez kapcsolódóan határoztuk meg a fejlesztési irányokat, és tevékenységeket: tárgyaink tanításában hangsúlyt kap a gyakorlatorientált tanóra, kísérletezés, az adatmérés és -elemzés, valamint a kritikai gondolkodás fejlesztése, Ennek jegyében szervezzük a tanórán kívüli tevékenységeinket is (TDK, terepgyakorlat, NTA program, pályaorientáció stb.)Az előzőekhez kapcsolódóan a koncepció része a pedagógus tudásfejlesztése, és tudásmegosztás is.", "pedprog_mtmi_tartalom": "reszben", "szulo_palyaorientacio": "megvalosul", "mtmi_fakultaciok_szama": "9", "mtmi_muzeumlatogatasok": "igen", "mtmi_nyilt_napok_link1": "https://telekiblanka.hu/gimnazium-mtmi-iskola/", "iskola_tanuloi_letszama": "1169", "mtmi_szakkor_tantargyak": ["matematika", "fizika", "kemia", "biologia", "digitalis_kultura"], "mtmi_szakmak_bemutatasa": "igen", "szulo_egyeztetes_szoveg": "Az intézmény főigazgatója minden tanév szeptemberében és februárjában szülői munkaközösségi értekezletet tart, melyen minden osztályt 2 fő szülő képvisel. A megbeszélésen az előző időszakhoz tartozó beszámoló hangzik el. Ezen a fórumon van lehetőség az MTMI területhez kapcsolódó programok, eredmények ismertetőjére is. Az itt elhangzottakat az SZMK képviselők az osztály szülői értekezleten továbbadják.", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "nem", "mtmi_szakmai_gyakorlatok": "Támogatjuk, hogy diákjaink nyári táborokban gyarapítsák ismereteiket, egyetemi kutatási projektekbe bekapcsolódjanak. Rendszeresen tanári ajánlásokat adunk nekik, mellyel sikeresen pályáznak az egyetemek által felkínált nyári táborokban (BME TTK Sience Camp, DE TTK Nyári Tábor, Matehetsz tutorhálózat, Ifiegyetem, …) \\nEgyütt a Jövő Mérnökei Szövetség (EJMSZ) a természettudományi tárgyak népszerűsítéséért és a mérnökgenerációk kineveléséért díjat adományozott intézményünknek 2023-ban. Valamint két diákunk a EJMSZ által tutorált diákok közé is bekerült.\\nAz NTA programhoz kapcsolódó diákoknak van lehetősége arra, hogy az ezüstdiploma elvárásait teljesítők 1 hetes nyári táborban vegyenek részt, mely során különböző tanszékek kutató munkájába bekapcsolódhassanak. Helyszínként a Szegedi, Pécsi és Debreceni és a Semmelweis Egyetem szolgál.\\n", "mtmi_egyetemi_gyakorlatok": "igen", "mtmi_szakkor_diakok_szama": "78", "mtmi_szakkorok_bemutatasa": "Matematika tantárgyhoz kötődően:\\n(7-12.évfolyam) a különböző típusú versenyekre (teszt, feladatmegoldó, OKTV) készítjük fel diákjainkat, valamint érettségi előkészítő foglalkozásokat tartunk a 12. évfolyamosok számára, emellett felzárkóztató szakkör is indul a 9. évfolyam számára\\nFizika tantárgyhoz kötődően:\\nSzakkör a 7. és 8. évfolyam diákjai számára, matematika ,  a 12. évfolyam fizika érettségi előkészítőn részt vevő diákok számára mérési, demonstrációs foglalkozásokat tartunk, hogy megismerjék a mérési technikákat, mérés-kiértékeléseket és gyakorlati jártasságot szerezzenek a mérőeszközök használatában\\nKémia tantárgyhoz kötődően: \\nSzakkör a 12.évfolyam kémia érettségi előkészítőre járó diákjai számára. melynek célja az emelt szintű kémia érettségi vizsga írásbeli részére való felkészítés kiegészítése, számolási feladatok gyakorlása.\\nBiológia tantárgyhoz kötődően:\\nSzakkör a 12.évfolyam biológia érettségi előkészítőre járó diákjai számára, melynek célja az emelt és középszintű biológia érettségi vizsgára való felkészítés kiegészítése, feladatok gyakorlása. Szakkör a 10.évfolyam diákjai számára melynek célja az emberélettanhoz kapcsolódó ismeretanyag elmélyítése gyakorlatorientált foglalkozások segítségével. \\nInformatika szakkör keretében versenyfelkészítés és robotikai foglalkozásokat tartunk", "szulo_munkakoz_ismertetes": "megvalosul", "mtmi_szakkor_tanarok_szama": "10", "iskola_mtmi_tanari_letszama": "10+", "lanyok_mtmi_reszvetel_link1": "https://telekiblanka.hu/gimnazium-tdk/", "mtmi_alumni_programok_link1": "https://telekiblanka.hu/gimnazium-tdk/", "mtmi_diakok_kapcsolattartas": "nem", "mtmi_kapcsolatok_bemutatasa": "Az osztályfőnökök a pedagógiai programunk által biztosított projektnap terhére saját szervezésben viszik el a diákokat különböző cégekhez. A látogatott cégek: Emerson, Audi, Mercedes gyár, Fejér Megyei Szennyvíztelep, Harman, Thyssenkrupp", "mtmi_online_palyaorientacio": "igen", "mtmi_rendezvenyek_reszvetel": "igen", "lanyok_mtmi_kiemelt_figyelem": "igen", "mtmi_alumni_programok_leiras": "Hagyományosan minden tanév januárjában pályaorientációs napot tartunk, amelyre alumni diákokat is várunk, akik vagy még egyetemisták, vagy már aktív dolgozóként tevékenykednek. Ezen a rendezvényen saját életpályájukról mesélnek az érdeklődő diákoknak, és hasznos tanácsokat adnak a sikeres felvételihez, döntéshez. Ez a nap tanítás nélküli munkanap az iskolában, a diákoknak előzetesen kell jelentkezniük a különböző órákra. Az alumni előadóink között orvos, fogorvos, biológus, erdész, gyógyszerész, mentős, informatikus, vegyész, környezet és egészségügyi mérnök, biomérnök, állatorvos is megtalálható. Emellett öregdiákjaink a szakórákon is megjelennek, pl. orvostanhallgatóként prevenciós előadásokat tartanak, ill. elsősegélynyújtási ismereteket oktatnak. A TDK foglalkozásain ill. a TDK Feszt elnevezésű nagy rendezvényünket is elsősorban alumni diákok bevonásával valósítjuk meg. A TDK Fesztről részletesen a honlapunkon olvasható.", "mtmi_csapat_tag1_tevekenyseg": "A biológia-földrajz-kémia munkaközösség vezetője, a Nemzeti Tudósképző Akadémia tehetséggondozó programját megvalósító Székesfehérvári Területi Képzési központjának vezetőtanára, a biológia és kémia tantárgyhoz kapcsolódó programok, versenyek szervezéséért, koordinálásáért felelős tanár", "mtmi_csapat_tag2_tevekenyseg": "Az intézmény főigazgatójaként az MTMI foglalkozások, rendezvények legfőbb szakmai koordinátora", "mtmi_csapat_tag3_tevekenyseg": "A fizika-informatika munkaközösség vezetője, az iskola tudományos diákkörének (TDK) vezetője, rendezvényszervezője, az Óbudai Egyetemmel és Budapesti Műszaki Egyetemmel való együttműködés koordinátora, versenyszervező", "mtmi_csapat_tag4_tevekenyseg": "A digitális kultúra tantárgyhoz kapcsolódó programok, versenyek szervezéséért, koordinálásáért felelős tanár", "mtmi_csapat_tag5_tevekenyseg": "A matematika munkaközösség vezetője, a matematika tantárgyhoz kapcsolódó programok, versenyek szervezéséért, koordinálásáért felelős matematika-fizika szakos középiskolai tanár", "mtmi_csapat_tag6_tevekenyseg": "Az MTMI területhez kötődő rendezvények, versenyek szervezésért felelős tanár", "mtmi_csapat_tag7_tevekenyseg": "A földrajz tantárgyhoz kapcsolódó rendezvények, versenyek szervezésért felelős tanár", "mtmi_aktiv_tanulas_megvalosul": "igen", "mtmi_csapat_kozos_tevekenyseg": "A novemberi nyílt nap megszervezése, lebonyolítása a középiskolai képzésünk iránt érdeklődő diákok foglalkoztatása. A Digitális és Fenntarthatósági Témahéthez kapcsolódó programok szervezése, megvalósítása. A januári pályaorientációs nap megszervezése, különböző szakmákhoz kapcsolódó előadók meghívása (öregdiákok, szülők, egyetemek képviselői) Tudományos Diákkör (TDK) foglalkozásainak szervezése, megvalósítása, melyeken diákok és tanárok egyaránt tartanak előadásokat, gyakorlatokat. TDK feszt megszervezése, lebonyolítása. Alba Innovár által felkínált programokon való részvétel. Lányok Napjához kapcsolódó programok népszerűsítése. Egyetemi laborlátogatások megszervezése, megvalósítása. Szakkörök tartása tehetséggondozás, versenyfelkészítés céljából. Közös pályázatok (Alcoa, Howmet, NTP) eszközfejlesztésre és tanórán kívüli foglakozások megtartására. •\\tÜzem/céglátogatások megszervezése, megvalósítása", "mtmi_fakultaciok_diakok_szama": "177", "mtmi_kiallitoterek_megvalosul": "nem", "lanyoknak_szolo_mtmi_programok": "igen", "mtmi_egyeb_tevekenysegek_szama": "10", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_kutatási_versenyek_szama": "5", "mtmi_laboratoriumok_latogatasa": "igen", "mtmi_otlet_esszepalyazat_link1": "https://www.kodolanyi-kozepisk.hu/hirekhirek/1083-kodolanyi-muveltsegi-vetelkedo-eredmenyei-2024", "mtmi_otlet_esszepalyazat_link2": "https://telekiblanka.hu/wp-content/uploads/2025/01/Palyazati-kiiras-2024_2025.pdf", "mtmi_otlet_esszepalyazat_szama": "1", "intezmenytipus_tanuloi_letszama": "635", "mtmi_ceges_eloadasok_bemutatasa": "AZ idei tanévtől kezdve szorosabb kapcsolatot tartunk a \\tGeneral Electric Global Services GmBH Magyarországi Fióktelepével, akinek képviselője egyben az MTMI szülői felelőse is. Terveink szerint a pályaorientációs napunkon is bemutatkozik majd más cégekkel együtt.", "mtmi_faliujsag_vitrin_reszvetel": "igen", "mtmi_palyaorientacio_megvalosul": "igen", "lanyok_mtmi_reszvetel_bemutatasa": "A gimnázium által megrendezett TDK Feszt előadói között több női egyetemi kutató is szerepelt, ill. a 21 Nő az egészségügyért Alapítvány képviselői tartottak előadást.\\nA pályaorientációs napunkon több szülő is tartott előadást a diákok számára. Pl.: orvosanyuka saját gyermekorvosi  tevékenységéről.", "mtmi_faliujsag_vitrin_bemutatasa": "A különböző versenyeken sikeres diákok eredményeit elektronikusan a folyosókon található kivetítő/televízió segítségével tesszük közé.", "mtmi_felelos_kapcsolattarto_neve": "Kiss Ildikó", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "igen", "mtmi_tanoran_kivuli_rendezvenyek": "A honlapon megtalálható programkínálatban részletesen olvashatóak a tanórán kívüli tevékenységek tartalmi leírásai, a következőkben csak felsoroljuk azokat: TDK foglalkozások, TDK Feszt, NTA programhoz kapcsolódó gyakorlatok, UNIverZOOM , Digitális és Fenntarthatósági Témahét programjai, terepgyakorlatok", "mtmi_tanulmányi_versenyek_szama": "27", "mtmi_muzeumlatogatasok_bemutatasa": "A következő MTMI területhez kapcsolódó múzeumok látogatása valósult meg eddig, elsősorban osztályfőnöki szervezésben: Duna Múzeum, Természettudományi Múzeum, Csodák Palotája, Közlekedési Múzeum", "programban_erintett_tanulok_szama": "200", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyuttmukodes_palyaorientacio": "igen", "mtmi_felelos_kapcsolattarto_email1": "ildiko.kiss70@gmail.com", "mtmi_felelos_kapcsolattarto_email2": "kissi.teleki@gmail.com", "mtmi_online_palyaorientacio_leiras": "A Semmelweis Egyetem Junior Akadémia című programsorozatához kapcsolódhat diákjaink, akik online előadásokat hallgathatnak meg egyetemi előadók közreműködésével. A program az orvosi pályára készülő diákjainknak nyújt segítséget, akik így bepillantást nyerhetnek különböző tanszékek munkájába is. A diákok az előadások után kitöltött kvíz eredményei alapján a Semmelweis-Kerpel Tehetségtáborba is eljuthatnak. Az pályaorientációs programon való részvételre azért van lehetősége a diákjainknak, mert A Semmelweis Egyetem partner iskolájaként Kerpel-Fronius Ödön Tehetséggondozó Programban részt vehetünk.", "mtmi_otlet_esszepalyazat_reszvetel": "igen", "mtmi_tanulmányi_verseny_reszvetel": "igen", "intezmenyvezeto_kapcsolattarto_neve": "Siposné Tóth Krisztina ", "mtmi_kiallitoterek_megvalosul_link1": "https://telekiblanka.hu/gimnazium-palyazatok-ntp-tfj/", "mtmi_kutatási_verseny_diakok_szama": "16", "mtmi_kutatási_versenyek_bemutatasa": "Lánczos Kornél vármegyei általános iskolai fizikaverseny (1-3 hely)Lánczos Kornél megyei középiskolai fizikaverseny (1-2 díjazott)Irány az Űr!, (2. fordulós eredmény) Bejczy Antal Műszaki Innovációs Középiskolai Verseny (4-6.hely)\\nA Mavesz és a Szabó Szabolcs Alapítvány által alapított természettudományos projektversenyen vettek részt a 2024-25-s évben a diákjaink A verseny célja egy önálló projekt létrehozás, egy életközeli probléma megoldása érdekében. A 3 fős csapatunk A tűzijátékok hatásai címmel mutatta be saját projektjét, melyben saját tervezésű kísérletek elvégzésével bizonyította a nehézfémek hatásait az élővilágra, és megoldásokat is kínált a probléma kivédésére. A verseny országos döntőjén a zsűri javaslata alapján a versenybizottság által kiválasztott projektek bemutatása történt egynapos workshop formájában, ahol iskolánk csapata is részt vehetett a BME K épületében megrendezett eseményen.\\nA Semmelweis Egészségverseny online fordulói után az országos döntőbe jutás feltételeként egy egészségvédelemhez kapcsolódó projektet kell végigvinniük a versenyzőknek. AZ elmúlt öt évben ez eddig 3 iskolai csapatnak sikerült.", "mtmi_otlet_esszepalyazat_bemutatasa": "A székesfehérvári Kodolányi János Gimnázium által megrendezett Kodolányi Műveltségi Vetélkedőre évek óta küldünk csapatokat. A vetélkedő internetes fordulójának van egy esszéírást kívánó része, mely során előre megadott szavak, kifejezése alapján kell egy összefüggő esszét írni, címet is adva a fogalmazásnak. A megadott fogalmak között látszólag nincs összefüggés, de mégis egy téma köré épül. A diákoknak kell rájönniük az kapcsolatra. Az esszé értékelése alapján hívja meg a zsűri a csapatokat a jelenléti fordulóra. A Teleki csapata a legtöbbször az első 3 hely valamelyikén végzett.\\nIskolai fizikapályázat saját diákjaink számára. ", "mtmi_digitalis_tananyagok_megvalosul": "igen", "mtmi_felelos_kapcsolattarto_beosztas": "munkaközösség vezető", "mtmi_kutatási_verseny_tanarok_szama": "3", "mtmi_laboratoriumok_latogatasa_link1": "https://telekiblanka.hu/2025/10/18/lanyitott-laborok-delutanja-a-bme-villamosmernoki-karan/", "intezmenyvezeto_kapcsolattarto_email1": "igazgato@sztbg.hu", "intezmenyvezeto_kapcsolattarto_email2": "tkrisztina.sipos@gmail.com", "mtmi_egyeb_palyaorientacios_programok": "A Semmelweis Egyetem partner iskolájaként Kerpel-Fronius Ödön Tehetséggondozó Program immár harmadik éve részt vesznek diákjaink az egyetem által szervezett novemberi tehetségnapon. Az eseményen előzetes jelentkezés alapján az egyetem különböző intézeteibe látogatnak el a diákok. (pl. Bőrgyógyászati Klinika, Biofizikai és Sugárbiológiai Intézet, Élettani Intézet, Genetikai, Sejt- és Immunbiológiai Intézet)\\nAz idei tanév októberében a Millenáris épületében megrendezett Science Expo-n is részt veszünk. A rendezvényen interaktív bemutatók, látványos kísérletek, előadások és kiállítások várják a diákokat, akik az előzetes programterv szerint megismerhetik:  a matematika, fizika, kémia, biológia és orvostudomány friss eredményeit,  az űrkutatás és a mesterséges intelligencia újdonságait,  az energiatudomány és az egészségmegőrzés legfontosabb irányait.\\nOsztályszintű programok keretében diákjaink egyéb pályaorientációs tevékenységben is részt vettek: Pénzmúzeum látogatása, laborlátogatások (BME VIK, BME VBK), szülők segítségével különböző szakmákba nyerhettek bepillantást: Fejérvíz Víztisztító Labor, Emerson üzemlátogatás,  kórházlátogatás.\\n21 Nő az Egészségügyért Alapítvány Mentorprogramjához is csatlakoztunk, így segítve az egészségügy iránt érdeklődő diákok pályaválasztását. A program többek között gyógyszergyár, vérellátó központ, több kórház látogatására is lehetőséget adott.\\n", "mtmi_otlet_esszepalyazat_diakok_szama": "3", "mtmi_tanulmányi_verseny_diakok_szama": "290", "mtmi_tanulmányi_versenyek_bemutatasa": "Fizikából OKTV (2. fordulóba 1-1 diák jut tovább), Tatai Öveges József Emlékverseny (országos 3.hely) , Mikola Sándor Fizikaverseny (1-2 diák továbbjutóval )\\nInformatikából Nemes Tihamér Nemzetközi Programozói Verseny (új néven Zsakó László informatikaverseny) (országos 13. hely), -\\tE-Hód (országos 1-10. hely), -\\tEurópai Junior Informatika Diákolimpia , EJOI hazai válogatóversenyére és felkészülőtáborába meghívót kapott 1 tanulónk, \\nMatematikából 2024/25 tanévben VII. Nemzetközi Magyar Matematikaverseny 2.hely, Zrínyi Ilona Matematikaverseny (országos döntőben 18,. 22.hely), Varga Tamás Matematikaverseny (országos 21.hely), Kalmár László Matematikaverseny , Megyei Matematikaverseny, KENGURU Nemzetközi Matematikaverseny (8.oszt. 1.hely), Arany Dániel Matematikaverseny (országos 17.hely), Bolyai Matematika Csapatverseny, OKTV\\nBiológiából OKTV (2. fordulóig jutott tanulók), Semmelweis Egészségverseny (országos döntő 8-11 hely), Állategészségügyi verseny\\nKémiából OKTV , Oláh György Országos Kémia Verseny\\nIrinyi János Kémia Verseny (országos döntőn való részvétel), Földrajzól OKTV, Jakucs László Nemzetközi Középiskolai Földrajzverseny\\nBolyai Természettudományi Csapatverseny (regionális szinten i.hely, országos döntőben való részvétel\\n\\n\\n\\n", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_otlet_esszepalyazat_tanarok_szama": "3", "mtmi_rendezvenyek_reszvetel_bemutatasa": "Bár a tavalyi évben nem, de előzőleg az érdeklődő diákokkal  együtt közösen részt vettünk a budapesti egyetemek (BME, ELTE) által szervezett programokra a Kutatók Éjszakája című rendezvényen", "mtmi_tanulmányi_verseny_tanarok_szama": "24", "intezmenyvezeto_kapcsolattarto_beosztas": "főigazgató", "mtmi_interdiszciplinaris_projekt_leiras": "Fenntarthatósági projekt :\\n2025. januárjában az akkori 9.b osztály földrajz órán egy fenntarthatósági projektbe kezdett, melynek célja a zöld szemléletmód mellett, az állampolgári kezdeményezés erősítése is.  \\nA diákok párban vagy csapatokban dolgoztak, a feladatokat a teams felületet használva folyamatosan rögzítették. A projekt során megismerték a párizsi klímaegyezmény célkitűzéseit, adatokat kerestek arra, hogy ez jelenleg hogyan teljesül. Átismételték az üvegházhatás jelenségét és tanulmányozták, mely gázok, ill. mely emberi tevékenységek járulnak ehhez.  \\nA Green Lab 2025 márciusában 1 héten keresztül méret az iskola udvarán elhelyezett autójával  a levegőt szennyező por, különböző gázok mennyiségét. Az így kapott adatokat a tanulók diagrammokon szemléltették, ábrázolták az egészségügyi határértéket. Ez valóban jó hivatkozási alap a projekt fő célkitűzéséhez, amikor is a szennyezettségi adatokra támaszkodva kezdeményezik a város önkormányzatánál az iskola előtti parkoló felszámolásával fák telepítését. Sajnos a május a projekt szempontjából nem volt kimagaslóan meleg, de így is kimutatható az épület előtti parkoló jóval magasabb hőmérséklete a fákkal árnyékolt közeli területekkel szemben. Hátra van még egy kérdőíves felmérés, a kezdeményezés támogatottságának kimutatása, a munka összegzése és a polgármester megkeresése. ", "mtmi_tovabbkepzesek_idokeret_megvalosul": "igen", "mtmi_tovabbkepzesi_programok_megvalosul": "igen", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "A tanítási órákon és a tanítási órán kívüli tevékenység során is törekszünk a gyakorlatorientált a tanulók aktív bevonásán alapuló gyakorlatorientált oktatásra. Fizikából, kémiából és biológiából is gyakran végeznek diákjaink önállóan vagy csoportosan különböző kísérleteket, méréseket, élettani vizsgálatokat, melyekről a legtöbb esetben jegyzőkönyv is készül. Támogatjuk, hogy a biológia középszintű érettségi gyakorlati részéhez az önálló kutatáson alapuló projektmunka készítését vállalják. A házi feladatok között gyakran szerepel önálló, saját kutatást, vizsgálódást igénylő feladat.", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 20 364 6172", "mtmi_palyaorientacio_megvalosulas_leiras": "Nincs külön pályaválasztásért felelős személy az iskolánkban, viszont a vezetőségen és a munkaközösség vezetőkön keresztül megvalósul a tájékoztatás. Az iskola számtalan levelet kap különböző szervezetektől (pl NATE), egyetemektől nyílt napok, nyári táborok, előkészítő foglalkozások, különböző gyakorlatokról, rendezvényekről, amit vagy a szaktanárok továbbítanak a diákok felé, vagy az osztályfőnökönkeresztül jut el az információ az érdeklődőkhöz  személyes megkeresés vagy az iskolában használt TEAMS felületen keresztül üzenet formájában. Elsősorban 11. és 12.évfolyamosokat érinti az említett tájékoztatás, de 9. és 10. osztályosokat is érinti több felkínált program.", "lanyoknak_szolo_mtmi_programok_bemutatasa": "Minden évben népszerűsítjük A Nők a Tudományban Egyesület által szervezett Lányok Napját, és több diákunk is részt vett már a programon. a NaTE nagyköveti hálózatának tagjai között is voltak már Telekis Diákok. Ahogy eddig is, az idei évben is jelentkezett 10. évfolyamos diákunk az egyesület által meghirdetett Smartíz programra. A \\"Női mérnök leszek\\" konferencián való részvétel is ezt a célt szolgálta", "mtmi_egyuttmukodes_palyaorientacio_leiras": "2018. januárja óta évente megrendezzük a saját tervezésű pályaorientációs napunkat. Kezdetben 5 egyetem, ill. kar mellett egy cég és főleg egykori diákjaink tartottak előadásokat. Majd ez 2024-ben már diákjaink 123 előadásból, 89 témakörben válogathattak ezen a napon 6 előadást, mely az érdeklődési körükhöz legközelebb állt. A diákok az aznapi „órarendjüket” online regisztrációs felületen önállóan állították össze minden órában közel 20 felkínált programból. Egyetemi oktatók, egyetemi hallgatók (általában volt diákjaink), szülők és cégképviselők nyújtottak a pályaválasztáshoz hasznos információkat. Ezeken a fórumokon diákjain sokkal bátrabban tették fel kérdéseiket, megtiszteltetésnek vették, hogy a „nagy egyetemekről” hozzájuk jöttek el oktatók. A 7-8. évfolyam diákjai üzemlátogatáson vettek részt. \\nTámogatjuk, hogy diákjaink nyári táborokban gyarapítsák ismereteiket, egyetemi kutatási projektekbe bekapcsolódjanak. Rendszeresen tanári ajánlásokat adunk nekik, mellyel sikeresen pályáznak az egyetemek által felkínált nyári táborokban (BME TTK Sience Camp, DE TTK Nyári Tábor, Matehetsz tutorhálózat, Ifiegyetem, …) \\nEgyütt a Jövő Mérnökei Szövetség (EJMSZ) a természettudományi tárgyak népszerűsítéséért és a mérnökgenerációk kineveléséért díjat adományozott intézményünknek 2023-ban. Valamint két diákunk a EJMSZ által tutorált diákok közé is bekerült.\\nAz NTA programhoz kapcsolódóan is több lehetőség van szakmai gyakorlatokhoz való kapcsolódásra. A Területi Képzési Központ gyakorlatain kívül a szombathelyi, pécsi, szegedi, debreceni Országos Képzési Központjaiban is több napos szakmai gyakorlaton vehetnek részt a jelentkező diákok. Az ezüstdiploma elvárásait teljesítők 1 hetes nyári táborban vegyenek részt, mely során különböző tanszékek kutató munkájába bekapcsolódhatnak. Helyszínként a Szegedi, Pécsi és Debreceni és a Semmelweis Egyetem szolgál. \\n", "mtmi_laboratoriumok_latogatasa_bemutatasa": "2024-ben A BME VBK Szervetlen és Analitikai Tanszékén közel 20 diák számára titrálási gyakorlatot tartott volt Telekis diákunk, az idén ősszel a BME VIK Nyitott Laborok Délutánján vettünk részt 12 fővel", "intezmenyvezeto_kapcsolattarto_telefonszam1": "+36 30 306 1236", "intezmenyvezeto_kapcsolattarto_telefonszam2": "+36 30 448 5444", "mtmi_digitalis_eszkozok_megvalosul_bemutatasa": "Szinte minden teremben van kivetítésre lehetőség, így digitális tananyagok felhasználásával színesíthetjük az óráinkat. Az elérhető pályázatok révén szinte minden pedagógusnak van saját használatú laptopja, melyet napi rendszerességgel használ a tanórai felkészüléshez, ill, megtartásához.", "mtmi_digitalis_tananyagok_megvalosul_bemutatasa": "Okostankönyv -NKP , Geogebra, osztályjegyzetfüzet használata,\\nSaját készítésű forms teszt, tanári digitális tananyag használata.\\nWeb2 feladatsorok készítése, és használata: Learningapps, Redmenta, Wordwall, Kahoot, Quizlet", "mtmi_korszeru_felszereltseg_megvalosul_bemutatasa": "Különböző pályázatok segítségével bővítjük az eszközparkunkat: Nemzeti Tehetség Program . Alcoa , Howmet által meghirdetett pályázatok. Okosterem pályázat", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul": "igen", "mtmi_tovabbkepzesek_idokeret_megvalosul_bemutatasa": "A megvalósul formái: Alkalmanként részvételi lehetőség a matematikatanárok országos konferenciáján, a Rátz László vándorgyűlésen. \\nA 2025/2026. tanévben az “Okos tanterem” székesfehérvári továbbképzésén való részvétel 6 fővel. NTA program megvalósításában résztvevő vezetőtanárok számára szervezett továbbképzés új gyakorlatok, digitális anatómiai asztal megismerésére\\nA „DiabMentor - szakmai továbbképzés pedagógusoknak és kisgyermeknevelőknek a cukorbeteg gyerekek támogatásáért” című online és gyakorlati képzés.", "mtmi_tovabbkepzesi_programok_megvalosul_bemutatasa": "A POK által szervezett őszi, tavaszi pedagógiai napokon való részvétellel, műhelymunka tartásával (idei őszi \\"óra\\" címe: Élménypedagógia a biológia és kémia órákon)\\nBelső továbbképzések szervezésével.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul": "igen", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul_bemutatasa": "Számos verseny iskolai fordulójának megszervezésével, továbbá konkrét versenyekhez kapcsolódó felkészítő foglalkozások megtartásával. \\nBelső továbbképzések megtartásával,kísérlet és feladatgyűjtemények készítésével, érettségire való felkészítést segítő órák beiktatásával. ", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul_bemutatasa": "Az éves tervben szerepelnek a következő MTMI fókuszú továbbképzések: \\nA korszerű pénzügyi-gazdasági ismeretek megjelenése a földrajztanításban (1 fő), Valószínűségszámítás és statisztika, (2 fő), Fenntartható egészség a köznevelésben"}	2025-09-08 14:44:10.598439	2026-03-05 22:23:14.531315	1	1b645429-cfb6-4608-a085-7a1889fc5456_MTMI_kieg_sz_t_s.pdf	63f0cc57-e620-445a-88d8-46538001a767
762cdca1-2991-4253-9d8e-bd5abdc05e82	{"iskola_cime": "4400 Nyíregyháza, Kiss Ernő utca 8.", "iskolatipus": ["gimnazium"], "gdpr_consent": ["on"], "szulo_bevonas": "megvalosul", "mtmi_koncepcio": "igen", "telepulesforma": "megyeszekhely_varos", "mtmi_nyilt_napok": "Iskolánk kiemelt figyelmet fordít a természettudományos, műszaki, technológiai és informatikai (MTMI) pályaorientációra, ennek keretében több eseményt is szerveztünk a 2025/2026-ös tanév elején.\\nSzeptember 9-én a tanév eleji szülői értekezleten bemutattuk az iskolánk MTMI koncepcióját. Ennek keretében kijelölésre került egy MTMI célokért felelős szülői képviselő, aki évente két alkalommal egyeztet az MTMI csapat által kidolgozott éves programról. Feladata, hogy elsősorban a továbbtanulási és pályaválasztási szempontokat, valamint a szülői visszajelzéseket közvetítse, ezzel is támogatva a program sikeres megvalósítását.\\nSzeptember 11-én a városi szintű Szakmefeszten két standdal mutatkoztunk be: az egyik a természettudományos tagozatot, a másik pedig az informatikai tagozatot képviselte. Interaktív bemutatókkal, szemléltető eszközökkel és tanulói prezentációkkal igyekeztünk közelebb hozni a diákokhoz és szüleikhez az MTMI területek sokszínűségét, valamint az iskolánk által kínált lehetőségeket.\\nSzeptember 18-án a Beiskolázási Szülői Értekezleten részletesen bemutattuk az MTMI tagozatok képzési struktúráját, tantárgyi sajátosságait és továbbtanulási perspektíváit. A szülők első kézből kaptak információt a tanulmányi programokról, az alkalmazott pedagógiai módszerekről, valamint arról, hogyan támogatjuk tanulóink pályaválasztási döntéseit a természettudományos és informatikai területeken.\\nSzeptember 25-én került sor az iskolai nyílt napra, amelyen az érdeklődő diákok és szüleik MTMI tantárgyakhoz kapcsolódó bemutató órákon vehettek részt. A látogatók betekintést nyerhettek az oktatás mindennapjaiba, kipróbálhatták a tanórák interaktív elemeit, és közvetlenül tapasztalhatták meg, milyen élményt nyújtanak iskolánk innovatív és gyakorlatközpontú MTMI órái.\\n", "szulo_egyeztetes": "megvalosul", "mtmi_csapat_link1": "https://nyhvpg.hu/index.php/mtmi", "mtmi_projektnapok": "Az elmúlt tanévben a Digitális témahéten témanapot szerveztünk. Erre a napra csapatversenyt szerveztünk, amire az iskola 20 osztályából nevezhettek 3-4 fős csapatok. A csapatok plakát készítéssel nevezhettek a versenyre \\"Az informatika jövője\\" címmel 8 csapat készített plakátot, amiket arra használtunk fel, hogy kiállítást hoztunk létre belőlük az iskola aulájában és a versenyt megelőző napon a diákok szavazhattak az általuk legjobbnak tartott munkára. A csapatverseny a digitális eszközök és az AI használatában való jártasságukat vizsgálta. Volt kódfejtés, generált és valódi képek felismerése, műveltségi teszt, melyhez kereséseket is indíthattak. ", "pedprog_mtmi_link1": "https://www.nyhvpg.hu/index.php/hirek-4", "szulo_kommunikacio": "megvalosul", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "8", "palyazo_iskola_neve": "Nyíregyházi Vasvári Pál Gimnázium", "pedprog_mtmi_leiras": "Az iskolában folyó természettudományos nevelés alapvető célja:\\n•\\ta természeti világ jelenségeinek megértése,\\n•\\ta tudományos módszerek (megfigyelés, kísérlet, hipotézisalkotás, következtetés) gyakorlati alkalmazásának képessége,\\n•\\ta műszaki kompetenciákra való rávezetés, azaz a tudás gyakorlati alkalmazása a technológiák és berendezések megismerésében, működtetésében és \\nA természettudományos  és az informatikatagozat tartalmát és szerkezetét meghatározza:\\n•\\ta helyi tanterv óraszámai,\\n•\\ta választható és emelt szintű érettségi tantárgyak köre,\\n•\\tvalamint a kulcskompetenciák (különösen a természettudományos és technikai, a matematikai gondolkodási és a digitális kompetencia) definiálása.\\nA helyi óratervek – a NAT 2020-ra építve – meghatározott óraszámokkal tartalmazzák a természettudományi műveltségterület tantárgyait (pl. biológia, kémia, fizika, földrajz). A dokumentum részletes óraszám-táblázatokat közöl a biológia, fizika, kémia és a „természettudomány” tantárgyakra vonatkozóan, igazodva a tagozatos és emelt szintű oktatás szerkezetéhez. (PP.49.oldaltól)\\n3.1.8.  Pályaorientáció : Az iskolának – a tanulók életkorához igazodva és a lehetőségekhez képest – átfogó képet kell nyújtania a munka világáról. Ennek érdekében olyan feltételeket, tevékenységeket kell biztosítania, amelyek révén a diákok kipróbálhatják képességeiket, elmélyülhetnek az érdeklődésüknek megfelelő területeken, megtalálhatják hivatásukat, kiválaszthatják a nekik megfelelő foglalkozást és pályát, valamint képessé válnak arra, hogy ehhez megtegyék a szükséges erőfeszítéseket. \\n\\nÉrettségi felkészítés\\nA választható vizsgatantárgyak között szerepel:\\n•\\tbiológia, földrajz, kémia, fizika és digitális kultúra,\\n•\\tvalamint kiemelt szerepet kap a matematika.\\nAz iskola vállalja, hogy ezekből a tantárgyakból közép- és emelt szintű felkészítést nyújt, a tagozat célkitűzéseit pedig az emelt szintű érettségi követelményekhez igazítja.\\n", "mtmi_ceges_eloadasok": "igen", "mtmi_csapat_tag1_nev": "Horváth Edit", "mtmi_csapat_tag2_nev": "Hricsovinyi Dominik", "mtmi_csapat_tag3_nev": "Ignécziné Bódi Judit", "mtmi_csapat_tag4_nev": "Dósáné Grünstein Emese", "mtmi_csapat_tag5_nev": "Komoróczy Tamásné", "mtmi_csapat_tag6_nev": "Komoróczy János", "mtmi_csapat_tag7_nev": "Berencsi Valéria", "mtmi_csapat_tag8_nev": "Gódor Zoltán", "mtmi_koncepcio_link1": "https://nyhvpg.hu/images/2025/MTMI/koncepcio.pdf", "mtmi_szakkorok_szama": "2", "mtmi_szulo_kepviselo": "igen", "mtmi_alumni_programok": "igen", "mtmi_csapat_tag1_szak": ["biologia", "foldrajz"], "mtmi_csapat_tag2_szak": ["kemia"], "mtmi_csapat_tag3_szak": ["kemia", "biologia"], "mtmi_csapat_tag4_szak": ["kemia", "biologia"], "mtmi_csapat_tag5_szak": ["matematika", "digitalis_kultura"], "mtmi_csapat_tag6_szak": ["digitalis_kultura"], "mtmi_csapat_tag7_szak": ["matematika", "fizika"], "mtmi_csapat_tag8_szak": ["fizika", "digitalis_kultura"], "mtmi_koncepcio_leiras": "A Nyíregyházi Vasvári Pál Gimnázium MTMI koncepciója\\n(M: matematika, T: természettudományok, M: műszaki tudományok I: informatika)\\nBevezető: A Nyíregyházi Vasvári Pál Gimnázium hagyományos négy évfolyamos gimnázium, évfolyamonként öt párhuzamos osztállyal. Képzéseink között az emelt óraszámú nyelvi képzések vannak túlsúlyban, e mellett diákjainknak lehetősége van a természettudományos tagozaton a biológiát és a kémiát, informatika orientációjú osztályainkban pedig a digitális kultúrát emelt szinten tanulni.\\nCélunk, hogy diákjainkat érett felnőttekké neveljük, akik tudatos felelősségvállalásra képesek globalizált világunkban.\\n\\nAz MTMI csapat célja iskolánkban elsősorban:\\n•\\tfelkeltsük a természettudományos tantárgyak iránti érdeklődést\\n•\\tönálló alkotásra, kísérletezésre buzdítsuk diákjainkat\\n•\\tszorgalmazzuk a versenyeken való részvételt\\n•\\tdiákjaink kapcsolatba kerüljenek tudományos intézményekkel\\n•\\tpályaorientáció a műszaki és a természettudományos képzések területén\\n•\\tlányok ösztönzése az MTMI programban való részvételre\\nMTMI struktúra a Nyíregyházi Vasvári Pál Gimnáziumban\\nA munka sikeressége a jó kommunikáción és a csapatmunkán alapul, ehhez az isko-la tanárai több szinten hozzájárulnak. \\nLétrehoztunk egy MTMI csapatot. A csapat munkáját segítik a természettudomá-nyos tantárgyakat, matematikát és digitális kultúrát tanító tanárok a célkitűzések megvalósításában, valamint fontos támogató szerepet játszanak a nyelvtanár kollé-gák. Választottunk egy MTMI felelőst, aki a csapat koordinálását végzi.\\nAz MTMI csoportot elkötelezett szülők támogatják, akik abban segítenek, hogy diák-jaink az iskola falain kívülre, a munka világába is eljussanak, és a többi szülőt is megismertetik a programmal.\\nAz MTMI csoport rendszeresen tájékoztatja a kollégákat a továbbképzési lehetősé-gekről, a szülőket az éves programokról és az elért eredményekről.\\nAz MTMI csoport év végén értékeli az elvégzett munkát és ajánlásokat fogalmaz meg a következő év tervezéséhez.\\n", "pedprog_mtmi_tartalom": "igen", "szulo_palyaorientacio": "megvalosul", "mtmi_fakultaciok_szama": "11", "mtmi_kapcsolatok_link1": "https://www.facebook.com/search/posts/?q=ny%C3%ADregyh%C3%A1zi%20vasv%C3%A1ri%20p%C3%A1l%20gimn%C3%A1zium%20%C3%BAjrak%C3%B3doljuk", "mtmi_muzeumlatogatasok": "igen", "mtmi_nyilt_napok_link1": "https://www.facebook.com/nyhvpg/", "iskola_tanuloi_letszama": "632", "mtmi_szakkor_tantargyak": ["matematika", "digitalis_kultura"], "mtmi_szakmak_bemutatasa": "igen", "szulo_egyeztetes_szoveg": "Az MTMI csapatot és ezzel együtt a szülői támogató csoportot az idei évben hoztuk létre. Szülői értekezleten mutattuk be, hogy mit is jelent az MTMI iskola illetve beszéltük meg, hogy miben szeretnénk a szülői csapat támogatását kérni. Elkészült az iskolai weblapnak az MTMI-t bemutató oldala, ahol a szülők és a leendő szülők vizuálisan is tájékozódhatnak. Természetesen mint minden új dolog még most formálódik az együttműködés.", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "nem", "mtmi_szakmai_gyakorlatok": "A természettudományos munkaközösség a tanórák egy részét a Nyíregyházi Báthori Élményközpontban valósítja meg. Az Élményközpont korszerű, interaktív tereiben a diákok élményalapú tanulási formák keretében, gyakorlatias szemléltető eszközökkel és kísérletekkel mélyíthetik el természettudományos ismereteiket. A program jól illeszkedik munkaközösség pedagógiai célkitűzéseihez, hiszen hozzájárul a tanulói motiváció növeléséhez, a tudományos gondolkodás fejlesztéséhez, valamint az élményszerű, gyakorlatorientált oktatás erősítéséhez.", "mtmi_egyetemi_gyakorlatok": "igen", "mtmi_szakkor_diakok_szama": "13", "mtmi_szakkorok_bemutatasa": "Iskolai szakköri foglalkozások az idei tanévben: Zelei János által tartott szakkör célja a matematika iránt érdeklődő, tehetséges tanulók fejlesztése és támogatása a pályaorientációs folyamatban. \\nIskolánk jó kapcsolatban van a Nyíregyházi Digitális Tudásközponttal a 2022-2023-as tanévben nyolc tanuló „A jövő városa” címmel kötött tematikájú szakköri foglakozásokon vett részt, melyet iskolánk tanára Komoróczy Tamásné tartott. A diákok 3D nyomtatással, 3D nyomtatásra tervezéssel, microbit programozással, szereléssel és szenzorok, ledek használatával foglalkoztak. \\nA 2023-2024-es tanévben A Digitális Tudásközpontban iskolánk hat tanulója „Tervezd meg és készítsd el” megnevezésű társasjáték készítő szakkörön vett részt Komoróczy Tamásné vezetésével, ahol saját ötlet alapján készítettek táblás játékot, amihez vektorgrafikus programmal tervezték meg a játékok tábláit és lézervágóval készítették el a táblákat, 3D nyomtatással készítettek hozzá bábukat, illetve az általuk megalkotott játékszabályokat egy az iskola által biztosított tárhelyen helyezték el, s a szabályok eléréséhez QR kódot készítettek annak érdekében, hogy mobiltelefonról  játék közben gyorsan elérhető legyen.\\nA 2024-2025-ös tanévben iskolánk 38 diákja az UniCredit Nemzetközi Alapítványa által támogatott középiskolásoknak meghirdetett projektben vett részt. ÚJRAKÓDOLJUK A JÖVŐT! címmel meghirdetett szakköri foglalkozások két részből álltak, egyik részük a tanulók digitális kompetenciáit fejlesztette, másik részük a személyes és szociális készségek kialakítását és erősítését szolgálta. A program pályaorientációs kirándulással zárult, diákjaink a Bosch Innovációs Központba látogattak el. (https://www.facebook.com/nyhvpg/ május 16. bejegyzés)\\nEzek nem egész éven át tartó szakkörök voltak, hanem néhány hét alatt valósították meg a célkitűzéseket. A gimnáziumi osztályok nagyon magas óraszámai miatt ezeket tudjuk megvalósítani.", "szulo_munkakoz_ismertetes": "megvalosul", "mtmi_ceges_eloadasok_link1": "https://www.nyhvpg.hu/index.php/8-hirek/368-penz7-a-vasvariban", "mtmi_szakkor_tanarok_szama": "2", "iskola_mtmi_tanari_letszama": "6-9", "mtmi_alumni_programok_link1": "https://www.facebook.com/nyhvpg/", "mtmi_diakok_kapcsolattartas": "igen", "mtmi_egyeb_partnerprogramok": "Gimnáziumunk biológia tagozatos diákjai izgalmas látogatásokat tettek a Jósa András Oktatókorház skill laborjában, amely az orvosi és ápolói készségek fejlesztésére szolgál. A program célja, hogy a fiatalok betekintést nyerjenek az egészségügy szakmai világába, és megismerkedjenek a legmodernebb orvosi technológiákkal.\\nA látogatás során a diákok élethű szituációk segítségével tapasztalhatták meg, hogyan zajlanak a sürgősségi helyzetek, és hogyan dolgoznak együtt az egészségügyi szakemberek a betegellátásban.\\nKiemelt együttműködés zajlik a Tudományos Ismeretterjesztő Társulat (TIT) Jurányi Lajos Egyesületével, amely Szabolcs-Szatmár-Bereg vármegyében és az Észak-alföldi régióban működő, a tudományos ismeretterjesztést és természettudományos nevelést támogató szervezet. Az egyesület a 1841-ben alapított Királyi Magyar Természettudományi Társulat, valamint jogutódja, a TIT országos hálózatának megyei szervezeteként működik. A gimnázium pedagógusai és diákjai több éve aktív szerepet vállalnak a Kabay János Vármegyei Biológiaverseny és a Béres József Vármegyei Biológiaverseny megszervezésében. Az együttműködés keretében az iskola tanárai közreműködnek a versenyfeladatok kidolgozásában, a feladatlapok javításában, valamint a döntő fordulók lebonyolításában. A versenyek célja a biológia és a természettudományok iránt érdeklődő tehetséges tanulók felkutatása, motiválása és felkészítése a magasabb szintű megmérettetésekre. Az együttműködés a diákok számára lehetőséget teremt a kutatói szemlélet fejlesztésére, az önálló problémamegoldás gyakorlására. Iskolánk az OTP Fáy András Alapítvánnyal együttműködésben pénzügyi és jövőtudatosságot fejlesztő tréninget szervez 10. évfolyamos diákok számára. A projekt célja, hogy olyan gazdasági és pénzügyi tudást adjon át a középiskolásoknak, amely kiegészíti az iskolában tanultakat, illetve szükségesek a pénzügyi-gazdasági világban való eligazodáshoz, a döntésképes és pénzügyileg tudatos magatartás elsajátításához.  ", "mtmi_kapcsolatok_bemutatasa": "A 2024–2025-ös tanévben iskolánk 38 tanulója vett részt az UniCredit Nemzetközi Alapítvány által támogatott, „ÚJRAKÓDOLJUK A JÖVŐT!” című országos projektben. A program célja a diákok digitális, személyes és szociális kompetenciáinak fejlesztése volt, amely szakköri keretek között valósult meg. A foglalkozások két fő területre épültek:\\negyrészt a digitális készségek (programozás, problémamegoldás, logikus gondolkodás) fejlesztésére, másrészt a kommunikációs, együttműködési és önismereti kompetenciák erősítésére.\\n\\nA projekt záró eseményeként a résztvevők pályaorientációs céglátogatáson vettek részt a Bosch Innovációs Központban, ahol betekintést nyerhettek a kutatás-fejlesztési és mérnöki munkafolyamatokba, megismerhették a vállalat innovációs tevékenységét, valamint a termelésben alkalmazott legmodernebb MTMI technológiákat.\\nEz az együttműködés nemcsak a tanulók pályaorientációját és szakmai érdeklődését támogatta, hanem hozzájárult a digitális készségek gyakorlati alkalmazásához is. A program során a diákok valós, munkaerőpiaci környezetben ismerhették meg, hogyan működnek az ipar és az innováció kulcsterületei, ezáltal tudatosabban készülhetnek jövőbeli tanulmányaikra és karrierjük megtervezésére.\\n\\nA Bosch Innovációs Központtal kialakított kapcsolat erősíti az iskola elköteleződését az MTMI területek gyakorlatorientált oktatása és a tanulók pályaválasztásának tudatos támogatása mellett", "mtmi_online_palyaorientacio": "nem", "mtmi_rendezvenyek_reszvetel": "igen", "lanyok_mtmi_kiemelt_figyelem": "nem", "mtmi_alumni_programok_leiras": "Szitár Bence előadását kísérték figyelemmel a 9.D és 10.D osztályos tanulók. Bence aki Műszaki pedagógia - Bio- és vegyipar (MA) szakos hallgató a Budapesti Műszaki és Gazdaságtudományi Egyetemen kőolajipari kutatásairól tartott előadást és kísérleti bemutatót pályaorientációs céllal az emelt szinten biológiát és kémiát tanuló diákjainknak.  ", "mtmi_csapat_tag1_tevekenyseg": "MTMI-felelős, biológia és földrajz szakos tanár, a program koordinátora", "mtmi_csapat_tag2_tevekenyseg": "biológia és kémia szakos tanár, STEM-módszerek és digitális projektek szakértője, Nemzeti Tudósképző Akadémia kapcsolattartó, Báthori Élményközpont laborprogramok", "mtmi_csapat_tag3_tevekenyseg": "biológia és kémia szakos tanár, laborprogramok, felkészítés, pályázatírás, szertárfejlesztés", "mtmi_csapat_tag4_tevekenyseg": "biológia és kémia szakos tanár, laborprogramok és versenyfelkészítés", "mtmi_csapat_tag5_tevekenyseg": "digitális kultúra tehetséggondozás, tagozatos diákok felkészítése versenyekre, emelt szintű érettségire, projekt munkák népszerűsítése és\\ntehetséggondozás matematikából, felkészítés emelt szintű érettségire, versenyek népszerűsítése", "mtmi_csapat_tag6_tevekenyseg": "digitális kultúra tehetséggondozás, tagozatos diákok felkészítése versenyekre, emelt szintű érettségire, projekt munkák népszerűsítése", "mtmi_csapat_tag7_tevekenyseg": "fizikából tehetséggondozás, érettségi előkészítő, versenyek népszerűsítése, felkészítés versenyekre, kísérletezés népszerűsítése", "mtmi_csapat_tag8_tevekenyseg": "fizikából tehetséggondozás, érettségi előkészítő, versenyek népszerűsítése, felkészítés versenyekre, kísérletezés népszerűsítése", "mtmi_muzeumlatogatasok_link1": "https://www.facebook.com/VaciMihalyKulturalisKozpont", "mtmi_aktiv_tanulas_megvalosul": "igen", "mtmi_csapat_kozos_tevekenyseg": "Az MTMI csapat néhány hete alakult meg. Átbeszéltük, hogy az eddig is a tanítási gyakorlatunkban szereplő feladatainkat igyekszünk változatlanul színvonalasan teljesíteni. Nagyobb hangsúlyt adva a versenyeken való részvételnek, az eredmények publikálásának. A két munkaközösség eddig is igyekezett a természettudományos délutánt érdekessé és vonzóvá tenni, ez továbbra is közös feladatunk. Igyekszünk a témaheteken minél több diákot bevonni a programokba, projektekbe. Eddig ismeretlen versenyzési lehetőség volt számunkra az esszéíró pályázat MTMI témában, az idei évben ezzel iskolai szinten megpróbálkozunk.", "mtmi_fakultaciok_diakok_szama": "118", "mtmi_kiallitoterek_megvalosul": "igen", "lanyoknak_szolo_mtmi_programok": "nem", "mtmi_egyeb_tevekenysegek_szama": "1", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_laboratoriumok_latogatasa": "igen", "mtmi_otlet_esszepalyazat_szama": "1", "intezmenytipus_tanuloi_letszama": "632", "mtmi_ceges_eloadasok_bemutatasa": "A 2024. március 6-án tartott pénzügyi tudatosság workshopon közel 100 diák vett részt, amelyet a Junior Achievement Magyarország (JAM) szakmai képviselője vezetett. A JAM nemzetközi oktatási hálózatként hidat képez az iskola és a gazdasági élet szereplői között, elősegítve, hogy a fiatalok valódi vállalkozói élményt és digitális pénzügyi ismereteket szerezzenek. A diákok megismerkedhettek a felelős döntéshozás, az innovatív gondolkodás és a kockázatvállalás alapjaival, miközben mentori támogatással próbálhatták ki saját ötleteik megvalósítását is.\\n\\nAz iskola emellett minden évben bekapcsolódik az Újraélesztés Világnapja országos programsorozatába, amelyet a Magyar Egészségügyi Szakdolgozói Kamara Szabolcs-Szatmár-Bereg Vármegyei Területi Szervezete szervez. A 2025. október 16-án megvalósult interaktív foglalkozások során a diákok megtanulták az alapvető újraélesztési lépéseket, a vérvétel és segítségnyújtás helyes menetét, valamint a sürgősségi ellátás alapjait. A program célja, hogy a tanulók felismerjék a gyors reagálás, a felelősségteljes döntéshozás és az egészségügyi technológiák jelentőségét a mindennapi életben és a jövőbeli pályaválasztás során.", "mtmi_faliujsag_vitrin_reszvetel": "igen", "mtmi_palyaorientacio_megvalosul": "igen", "mtmi_faliujsag_vitrin_bemutatasa": "A szaktantermek illetve a tanári szoba mellett elhelyezett vitrinekben lehetőség van a tanulói munkák vagy a tanulók által elért eredmények bemutatására, illetve az iskola minden fontos eseményről és eredményről hírt ad az iskola facebook oldalán.", "mtmi_felelos_kapcsolattarto_neve": "Horváth Edit", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "nem", "mtmi_tanoran_kivuli_rendezvenyek": "A Jósa András Oktatókórház Skill-laborjában pályaorientációs gyakorlati foglalkozáson vesznek rendszeresen részt a Nyíregyházi Vasvári Pál Gimnázium 9-12. évfolyamos, biológiát emelt szinten tanuló diákjai. A laborban berendezett kórházi szobákban, műtőkben felkészült szakemberek irányítása mellett ismerkedhetnek meg az általános orvosi és szakorvosi eljárás alapvető módszereivel. Lehetőségük van kipróbálni a vérvételt, ultrahangvizsgálatot, laparoszkópos technológiát kockázatmentes, korszerű és magas színvonalú eszközökkel felszerelt környezetben. Szimulációs fantomokon gyakorolhatják az újraélesztést, megtudhatják milyen érzés terhesnek és idősnek lenni, felvehetik a tudatmódosítók hatását szimuláló szemüvegeket. A foglalkozás óriási élményt nyújtott a diákok számára.  A látogatás lehetőséget teremt az elmélet-gyakorlat egységének megteremtésére és skill, azaz készségszintű elsajátítására, és nem utolsó sorban segíti a döntéshozást a továbbtanulási célokkal kapcsolatban.  Másik helyszínen az érdeklődők szolárgráfokról és azok készítéséről tájékozodhattak, illetve harmadik helyszínen számítógép összeszerelési munkákat végeztek.\\n", "mtmi_tanulmányi_versenyek_link1": "https://www.facebook.com/nyhvpg/", "mtmi_tanulmányi_versenyek_szama": "8", "mtmi_egyeb_partnerprogramok_link1": "https://www.nyhvpg.hu/index.php/8-hirek/354-egy-lepes-a-jovo-orvostudomanya-fele", "mtmi_egyeb_partnerprogramok_link2": "https://www.titonline.hu/versenyek.html", "mtmi_muzeumlatogatasok_bemutatasa": "Az intézmény minden tanévben megszervezi a „Az Év Természetfotói” című országos vándorkiállítás megtekintését, amelyet a Városi Művelődési Központban rendeznek meg. A 2024-es évben a kiállítást Horváth Edit tanárnő nyitotta meg, és az eseményre a természettudományos tagozatos diákok is ellátogattak. A kiállítás évek óta az iskolai MTMI program egyik állandó eleme, amelynek célja, hogy a tanulók vizuális úton, művészeti és tudományos szempontból ismerhessék meg a természet sokszínűségét, az ökológiai rendszerek törékenységét és az emberi beavatkozás hatásait.\\n\\nA program különösen hozzájárul a biológiai és környezettudományos szemlélet formálásához, valamint a fenntarthatósági neveléshez. A kiállításlátogatást a pedagógusok tanórákhoz kapcsolódó előkészítő és feldolgozó tevékenységekkel egészítik ki: a diákok megfigyelési szempontokat kapnak, majd a látottakat reflektív beszélgetésekben és kreatív projektmunkákban dolgozzák fel.", "programban_erintett_tanulok_szama": "150", "mtmi_diakok_kapcsolattartas_leiras": "Előző tanévben: PÁLYAORIENTÁCIÓS NAP – „UTAK A VASVÁRIBÓL”\\nKözel 50 előadó érkezett  a Nyíregyházi Vasvári Pál Gimnáziumba, hogy élménybeszámolóikkal és interaktív workshopokkal segítsék a gimnazisták pályaválasztását. A diákok által választható blokkok pont olyan sokszínűek voltak, mint iskolánk képzési kínálata. A tanulók bepillantást nyerhettek a volt vasvárisok jelenlegi tanulmányaiba, foglalkozásaiba. Interaktív beszélgetésekkel olyan népszerű szakmák kerültek bemutatásra, mint az orvosi, jogi, mérnöki, műszaki, informatikai, gazdasági vagy honvédelmi és rendészeti pálya. A rendezvény színvolát a Debreceni Egyetem 7, a Miskolci Egyetem 5 Karának és a Nyíregyházi Egyetem előadóinak informatív tájékoztatása emelte. De ellátogatott hozzánk az ELTE Informatikai Kara, és bár csak online, de jártunk Dániában is.\\n", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyuttmukodes_palyaorientacio": "igen", "mtmi_felelos_kapcsolattarto_email1": "hedit1515@gamil.com", "mtmi_otlet_esszepalyazat_reszvetel": "igen", "mtmi_tanulmányi_verseny_reszvetel": "igen", "intezmenyvezeto_kapcsolattarto_neve": "Pásku Judit", "mtmi_otlet_esszepalyazat_bemutatasa": "Esszé pályázatokon eddig nem vettünk részt az iskola tanulóival, de most ebből a pályázatból ötletet merítve iskolai esszéíró pályázatot fogunk meghirdetni decemberben. A tervezett témák\\n •\\tDigitális hősök\\n•\\tBarát vagy gép?\\n•\\tHa egy videojáték világa lenne a valóság…\\nEzzel az iskolai vetélkedéssel megpróbálunk kedvet csinálni a későbbi versenyekhez.\\n", "mtmi_digitalis_tananyagok_megvalosul": "igen", "mtmi_felelos_kapcsolattarto_beosztas": "középiskolai tanár", "intezmenyvezeto_kapcsolattarto_email1": "nyhvpg@gmail.com", "mtmi_otlet_esszepalyazat_diakok_szama": "10", "mtmi_tanulmányi_verseny_diakok_szama": "40", "mtmi_tanulmányi_versenyek_bemutatasa": "Versenyek/ pályázatok / kutatások\\nAz eseményekhez tartozó posztok megjelentek az iskola facebook oldalán, elérhetőség: https://www.facebook.com/nyhvpg/ az eredményeknél megtalálható, hogy mikor lett posztolva.\\n 20. Neumann János Nemzetközi tehetségkutató Programtermék verseny CAD kategóriában Szalacsi Máté 10.D ostályos tanuló 3. helyezett lett.\\n(2024. április 9.)\\n\\nDEIK a Debreceni Egyetem Regionális programozó Csapatversenyén a VPG nevű két fős csapatunk, ( Benő-Batári Dominik 11.D és Szabó Balázs 11.D ) a 26 induló csapat közül 11. lett.\\n(2024. december 2.)\\nA Magyar Innovációs Szövetség delegáltjaként Zsigó Dalma 12.B osztályos tanuló részt vett a Taiwani International Science Fair-en, ahol „Wibraz” elnevezésű projektjével 3. díjat kapott.\\n(2025. január 29.)\\nNemes Tihamér Nemzetközi Tanulmányi versenyen programozás kategóriában a III. korcsoportban Benő-Batári Dominik a megyei fordulóban 2. helyezett lett.\\nA Vármegyei Programozó Versenyen II. helyezést szerzett Benő-Batári Dominik 11.D osztályos tanuló.\\n(2025. április 10.)\\nBéres József Vármegyei Biológiaversenyre 17 tanuló jelentkezett. Pontszámuk alapján 6 diák vehetett részt a döntőben. Batári Bálint 1., Jakab Szabolcs a 2., Balog Koppány 3., Szedlár Szabolcs 4. és  Mile Boglárka 5. helyezést ért el.\\nFodor József Országos Biológia versenyen 11 tanuló jelentkezett. Közülük Jakab Szabolcs 22., Kádár Máté 23.  míg Batári Bálint és Smid Balázs a 34. helyet értek el.", "mtmi_interdiszciplinaris_projekt_link1": "https://nyhvpg.hu/index.php/hirek?start=40", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_otlet_esszepalyazat_tanarok_szama": "1", "mtmi_rendezvenyek_reszvetel_bemutatasa": "Nem minden évben, de igyekszünk megszervezni ezt a programot", "mtmi_tanulmányi_verseny_tanarok_szama": "5", "intezmenyvezeto_kapcsolattarto_beosztas": "igazgató", "mtmi_interdiszciplinaris_projekt_leiras": "December 5-én szerveztük meg immár tizedik alkalommal a Természettudományos Délutánt, amelyet az eddigi évektől eltérően egy izgalmas és interaktív természettudományos workshop program formájában valósult meg. amely a Rejtélyek és felfedezések délutánja fantázianevet kapta. A program elején a diákok a fizikatanárok segítségével lőhettek a Holdra, majd körforgásos rendszerben hat különböző teremben járhattak a nyolcadikos tanulók, ahol izgalmas kísérletek során fedeztétek fel a tudomány rejtelmeit. Egy munkafüzetet szerkesztettünk, amely kitöltésével nemcsak a kísérletek során szerzett tapasztalatokat rögzítettétek, hanem a tudományos gondolkodásukat is fejlesztettétek a résztvevők. A délután megszervezése (plakátok, oklevelek, munkafüzet, kísérletek betanítása, technikai szervezés) hosszú előkészítő folyamatot igényelt, és a siker a munkaközösség elkötelezett tagjainak, és nem utolsó sorban a tagozatos és előkészítős diákjaink lelkes hozzáállásának köszönhető. Az előkészítő munkálatokba innovatív módon bevontuk a 9.D osztály digitális kultúra tagozatos diákjait is, akik mesterséges intelligencia segítségével tudományos témájú háttérképeket készítettek az interaktív feladatokhoz. ", "mtmi_tovabbkepzesek_idokeret_megvalosul": "igen", "mtmi_tovabbkepzesi_programok_megvalosul": "igen", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "A pedagógiai gyakorlat középpontjában az aktív tanulás és a tanulói bevonódás áll. Ennek érdekében a tanárok rendszeresen alkalmazzák a projektmódszert, a páros- és csoportmunkát, valamint a problémamegoldó és kutatói megközelítést. \\nA projektek témái gyakran az MTMI (matematika, természettudomány, műszaki és informatikai) területekhez kapcsolódnak, és valós élethelyzetek megoldására épülnek. A diákok önállóan gyűjtenek információt, kutatnak, kísérleteznek, majd prezentációk, poszterek vagy digitális bemutatók formájában mutatják be eredményeiket. Ez fejleszti az együttműködést, a kommunikációt, az önálló gondolkodást és az önreflexiót. A tanórákon kiemelt szerepet kap az interaktivitás, a digitális eszközök és az online tanulási környezetek használata, amelyek lehetővé teszik a tanulók aktív részvételét és az azonnali visszajelzést. A páros és csoportos munka során a tanulók egymástól is tanulnak, miközben fejlesztik problémamegoldó és érvelési készségeiket. \\nAz értékelési folyamatban fontos szerepet kap a tanulói önreflexió: a diákok rendszeresen értékelik saját teljesítményüket és fejlődésüket tanulási naplók, önértékelő lapok, illetve digitális felületek segítségével. A pedagógusok visszajelzése folyamatos, személyre szabott és támogató, kiemelve az egyéni fejlődést és a továbblépési lehetőségeket.\\nE komplex megközelítés célja, hogy a diákok önálló, kreatív, felelősségteljes tanulókká váljanak, akik képesek tudásukat rugalmasan alkalmazni a felsőoktatásban és a jövő munkaerőpiacán.", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 30 503 3737", "mtmi_kiallitoterek_megvalosul_bemutatasa": "Az első és a második emeleten üveges vitrines szekrényekben állítjuk ki időnként a tanulói munkákat, illetve a megszerzett eredményeket tanusító oklevelekett.", "mtmi_palyaorientacio_megvalosulas_leiras": "Debreceni EPAM cég informatikusa (egykor informatika tanár) 1-2 évente ellátogat iskolánkba azzal a céllal, hogy bemutassa miért érdemes az informatikus pályát választani, milyen munka lehetőségeket találhatnak felnőttként. Iskolai időben rendezzük meg a beszélgetést és elsősorban az informatika tagozatos diákjaink vesznek rész rajta.", "mtmi_egyuttmukodes_palyaorientacio_leiras": "Iskolai munkatervünkben minden évben szerepel a gimnázium tanulói számára megrendezett pályaorientációs nap, ami az idei tanévben 2025. november 28-án lesz. Erre a napra több helyszínen szervezzük meg a beszélgetéseket, tájékoztatókat, hogy mind a 20 osztályunk tanulói érdemi nformációkhoz jussanak. Több felsőoktatási intézményből várjuk erre a napra a képviselőiket különböző karokról és szakokról, illetve ezzel párhuzamosan a környező cégektől fogadunk munkatársakat, akik az ott folyó munkába adnak betekintést, illetve volt diákjaink közül szoktak visszajönni és beszámolni az egyetemi, vagy az idősebbek már a munkahelyi tapasztalataikról", "mtmi_laboratoriumok_latogatasa_bemutatasa": "Iskolánk diákjai heti rendszerességgel vesznek részt a Báthori Élményközpontban megvalósuló laborgyakorlatokon, ahol korszerű eszközökkel, kísérleti úton mélyíthetik el biológiai és kémiai ismereteiket. A program gyakorlatorientált módon fejleszti a diákok tudományos gondolkodását, kísérlettervezési és adatfeldolgozási készségeit.\\nIntézményünk tanulói bekapcsolódtak a Nemzeti Tudósképző Akadémia programjába is, amelynek fő célkitűzése az orvosbiológiai kutatások iránt érdeklődő tehetséges fiatalok felkarolása, tudományos munkájuk támogatása, valamint hosszabb távon Magyarországon tartása. A részvétel lehetőséget biztosít a diákok számára, hogy már középiskolás korukban betekintést nyerjenek a kutatói életpályába és kapcsolatot építsenek a felsőoktatás, valamint a tudományos szféra szereplőivel.", "intezmenyvezeto_kapcsolattarto_telefonszam1": "+3642 311920", "mtmi_digitalis_eszkozok_megvalosul_bemutatasa": "A pedagógusok folyamatos szakmai fejlődését belső és külső továbbképzések támogatják, ahol digitális tanulási módszereket sajátítanak el. Az MTMI tantárgyak tanításában rendszeresen alkalmazzák a Khan Academy, PhET, BioTéka, PurposeGames, GeoMetodika, foldrajzedu, LearningApps, Redmenta és Kahoot platformokat. Ezek az eszközök lehetővé teszik az interaktív, játékosított, önálló tanulást támogató oktatást, valamint a differenciálást és az azonnali visszajelzést. A digitális módszerek hozzájárulnak a tanulók motivációjának növeléséhez, a kompetenciaalapú tudásfejlesztéshez és a 21. századi készségek erősítéséhez.", "mtmi_digitalis_tananyagok_megvalosul_bemutatasa": "A Nyíregyházi Vasvári Pál Gimnáziumban az MTMI tantárgyak oktatásában kiemelt szerepet kapnak a digitális tananyagok, feladatlapok és online mérések, melyek a NAT 2020 irányelveihez és a Nemzeti Köznevelési Portál (NKP) tananyagaihoz illeszkednek. A pedagógusok célja, hogy a tanulók korszerű, interaktív tanulási környezetben fejlesszék tudásukat, önállóságukat és problémamegoldó készségeiket.\\nA matematika oktatásában a GeoGebra program segítségével a diákok függvényeket vizsgálnak, geometriai alakzatokat szerkesztenek és statisztikai elemzéseket végeznek. A Redmenta és LearningApps platformokat az elméleti ismeretek gyakorlására, az önálló munkák ellenőrzésére és differenciált fejlesztésre használják. A Kahoot interaktív kvízei és versenyei játékos formában mélyítik el az ismereteket. A fizika és kémia tantárgyak esetében a PhET szimulációk és a NAT online tananyagok segítik a kísérletek modellezését és a jelenségek értelmezését.\\nA biológia oktatásában és az érettségire való felkészülés során a BioTéka, a Gergely Tibor honlapja és a Bioszféra.com oldalak jelentik a legfontosabb digitális forrásokat. Ezek a portálok részletes összefoglalókat, interaktív teszteket és érettségi témakörökhöz kapcsolódó gyakorlófeladatokat tartalmaznak, amelyek támogatják a tanulók önálló felkészülését és önellenőrzését.\\nA földrajz oktatásában a GeoMetodika és a foldrajzedu oldalak térképes adatfeldolgozást és éghajlati elemzéseket tesznek lehetővé, míg a PurposeGames portált a tanulók topográfiai gyakorlásra használják, fejlesztve térbeli tájékozódási képességüket. Az érettségi adatbázisok és az NKP online feladatai biztosítják a vizsgahelyzetek digitális szimulációját és a tudás folyamatos ellenőrzését.\\nA digitális tananyagok és eszközök rendszeres alkalmazása hozzájárul a tanulói motiváció növeléséhez, az önálló tanulás erősítéséhez, valamint a 21. századi kompetenciák fejlesztéséhez az MTMI területeken.", "mtmi_korszeru_felszereltseg_megvalosul_bemutatasa": "Az iskola 25 tantermében áll rendelkezésre a tanításhoz digitális tábla vagy digitális panel. A gyengébb minőségű digitális táblákat már sikerült kicserélni. A biológia illetve kémia órák nagy része jól felszerelt előadóteremben zajlik. A gimnáziumban 3 informatika terem van ahhoz, hogy a 20 osztály informatika óráit, a tagozatosok emelt óraszámú óráit meg tudjuk tartani. A digitális mérések alkalmával még két tantermet be tudunk rendezni laptopokkal, s ilyenkor ezekbe a termekbe is ideiglenesen vezetékes hálózatot építünk ki. Vannak órák, amikor a diákok saját laptopokat hoznak, wifi elérés a legtöbb teremben jó, s ezekről tudnak dolgozni.\\n", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul": "igen", "mtmi_tovabbkepzesek_idokeret_megvalosul_bemutatasa": "Az iskola vezetése megteremti az MTMI területekhez kapcsolódó továbbképzéseken és konferenciákon való részvételhez szükséges időkeretet, ezzel is támogatva a pedagógusok szakmai fejlődését és a korszerű oktatási módszerek beépítését a tanítási gyakorlatba. Az elmúlt években a Nyíregyházi Vasvári Pál Gimnázium természettudományos munkaközössége nagy hangsúlyt fektetett a pedagógusok folyamatos módszertani megújulására és digitális kompetenciáinak fejlesztésére.\\nA kollégák rendszeresen részt vesznek a POK által szervezett továbbképzéseken és online workshopokon, amelyek a tanévre való szakmai felkészülést, a pedagógusminősítési folyamat támogatását és az oktatási gyakorlat modernizálását segítik. Emellett a tanárok aktívan bekapcsolódnak országos és regionális szakmai konferenciákba, mint például az „Így tanítom a biológiát” és az „Így tanítom a kémiát” rendezvénysorozatok, amelyeket a Nyíregyházi Egyetem szervez. Ezek a programok új szemléltetési, kísérleti és digitális módszereket mutatnak be a természettudományos tantárgyak tanításához.\\nA pedagógusok rendszeres résztvevői a Debreceni Egyetem Természettudományos tantárgyakat tanító tanárok konferenciájának ( Középiskolai Tanárok Fóruma), ahol a felsőoktatás és a köznevelés szakmai tapasztalatcseréje valósul meg. Emellett a Maxim Kiadó és a Pázmány Péter Katolikus Egyetem által szervezett szaktárgyi továbbképzések is hozzájárulnak a tanárok módszertani megújulásához biológia és kémia tantárgyakból.\\nA digitális pedagógia fejlesztését szolgálják a „STEM technikák alkalmazása a biológia tanításában” című online műhelymunka, valamint az „Okosfeladatok szerkesztése az NKP-n” workshopok, amelyek az NKP (Nemzeti Köznevelési Portál) gyakorlati alkalmazását segítik elő.\\nAz iskola vezetése és a munkaközösség együttműködése biztosítja, hogy a pedagógusok a továbbképzéseken szerzett új ismereteket beépítsék a mindennapi oktatásba, ezzel előmozdítva az MTMI tárgyak élményalapú, korszerű és innovatív tanítását.", "mtmi_tovabbkepzesi_programok_megvalosul_bemutatasa": "2024. november 21-én a biológia szakos tanárok az „Így tanítom a biológiát” konferencián, a kémia szakos pedagógusok pedig az „Így tanítom a kémiát” konferencián vettek részt, mindkét rendezvényt a Nyíregyházi Egyetem szervezte, és a legújabb módszertani megközelítéseket, kísérleti bemutatókat és jó gyakorlatokat ismertették.\\n2025 tavaszi félévben Szuhi Erika a Maxim Kiadó által szervezett biológiai (március 11.) és kémiai (március 20.) továbbképzéseken vett részt, míg Horváth Edit és Szuhi Erika március 26-án a Pázmány Péter Katolikus Egyetem középiskolai biológiatanároknak szóló szaktárgyi továbbképzésén bővítették szakmai ismereteiket.\\nÁprilis 1-jén Hricsovinyi Dominik és Horváth Edit a Kölcsey Ferenc Gimnáziumban tartott POK-bemutató órán vettek részt, míg április 5-én mind a négy pedagógus – Horváth Edit, Hricsovinyi Dominik, Ignécziné Bódi Judit és Szuhi Erika – képviselte iskolánkat a Debreceni Egyetemen megrendezett Természettudományos tantárgyakat tanító tanárok konferenciáján.\\nHricsovinyi Dominik továbbá részt vett a Tavaszi Pedagógiai Napok keretében a „STEM technikák alkalmazása a biológia tanításában” című online műhelymunkán, valamint az „Okosfeladatok szerkesztése az NKP-n I.” című workshopon is. A biológia munkacsoport – Horváth Edit, Hricsovinyi Dominik, Ignécziné Bódi Judit és Szuhi Erika – képviselte intézményünket a Természettudományos Tárgyakat Tanító Középiskolai Tanárok Fórumán Debrecenben.\\n2024 és 2025-ben az ELTE által szervezett INFOERA Konferencián Részt vett Komoróczy Tamásné.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul": "igen", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul_bemutatasa": "Horváth Edit: A Kabay János Vármegyei Biológiaverseny szakmai felelősi feladatainak ellátása.\\t\\nPályaorientáció támogatása érdekében a nevelési-tanítási év során legalább 1 Skill labor látogatás megvalósítása.\\t\\nAz intézmény szakmai fejlődésének támogatása érdekében részvétel az MTMI pályázat megírásában mint felelős kapcsolattartó.\\t\\nHricsovinyi Dominik: Szakmafeszt eseményen, diákokkal népszerűsítjük az iskola természettudományos tagozatát.\\t\\nRészt veszek egy szakmai konferencián.\\nIgnécziné Bódi Judit: Részt veszek egy szakmai konferencián. \\nDósáné Grünstein Emese: A diákjaim pályaorientációjának segítése érdekében ellátogatok a Skill laborba. \\nRészt veszek egy szakmai konferencián.\\nA teljes munkaközösség együtt valósítja meg a Természettudományos Délutánt.\\n\\nArnóczki Csaba: Vállalom az Országos Zrínyi Ilona és Bolyai matematikaversenyek intézményi koordinációját, a versenyre nevezéstől a verseny lebonyolításáig\\nBerencsi Valéria: 4 fizika előkészítős tanulóval részt veszünk a BME által szervezett XVIII: Energetikai Tanulmányi Versenyen.\\nBéres Zsolt: LEGO SPYKE készletre építve szakköri foglalkozások megtartása\\nGódor Zoltán: Az UniVerzoom program (kísérletezz...) keretében részt vett tanulókkal kirándulás az űrutazással kapcsolatos kiállítás megtekintésére (Budapest).\\nKomoróczy Tamásné: MTMI Iskolai Programba bekerüléshez a pályázat megírásában aktívan részt veszek. A SzakmaFeszten négy informatika tagozatos diákkal képviselem az iskolát a Digitális TársasHáz standon, amire előzetesen felkészítem őket.\\nKropog László: Pénz7 tematikus hét keretében 2 órát tartok pénzügyi ismeretek témában.\\nPájer István: Az űrkutatés iránti érdeklödés fokozása érdekében meghívom Tarci Patrik mélyűrfotóst, aki namíbiai kalandjairól tart képekkel illusztrált előadást.\\n", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul_bemutatasa": "Név: Ignécziné Bódi Judit\\nKépzésszám: A/13517/2025\\nKépzés neve: A kémia tantárgy tartalmi szabályozása a gimnáziumban a Natban, a kerettantervekben, és ennek megjelenése a tankönyvekben\\nKépzés típusa: Tartalmi megújító képzés\\n\\nNév: Komoróczy János\\nKépzésszám: A/13627/2025\\nKépzés neve: Algoritmizálás és programozás\\nKépzés típusa: Tartalmi megújító képzés\\n\\nNév: Tán Angéla\\nKépzésszám: A/13508/2025\\nKépzés neve: A matematika tantárgy tartalmi szabályozása a gimnáziumban a Natban, a kerettantervekben, és ennek megjelenése a tankönyvekben\\nKépzés típusa: Tartalmi megújító képzés\\n"}	2025-09-10 14:49:36.883616	2026-03-05 22:23:14.470754	1	762cdca1-2991-4253-9d8e-bd5abdc05e82_K_pek_a_tantermek_felszerelts_g_r_l__s_a_t_rol_kr_l.pdf	fc6dc512-5a6b-4e13-8072-00c8c39042a6
85f0d277-52bb-4215-903f-0295560436b4	{"iskola_cime": "4600 Kisvárda Iskola tér 2.", "iskolatipus": ["gimnazium"], "gdpr_consent": [], "szulo_bevonas": "megvalosul", "mtmi_koncepcio": "igen", "telepulesforma": "megyeszekhely_varos", "szulo_kommunikacio": "megvalosul", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "5", "palyazo_iskola_neve": "Kisvárdai Bessenyei György Gimnázium és Kollégium", "pedprog_mtmi_leiras": "pl. A tudomány, a technológia, a mérnöktudomány és a matematika (együttesen STEM) területek oktatásának fejlesztésére a későbbi karrierlehetőségek támogatása érdekében Európa-szerte számos kezdeményezés és program irányul, mivel úgy tekintenek a kapcsolódó tudásra és képességekre, mint a technológiai fejlődést megalapozó humán tényezőkre. Az utóbbi időben egyre inkább teret hódít a kutatómódszer, a projekt, a kísérleti úton szerzett tapasztalás, az élményszerű tanulás és tanítás. Ennek hátterében egyrészt az áll, hogy az Európai Unió tantárgypedagógiai ajánlásai között a kérdésfeltevésen alapuló tanulás (inquiry based learning - IBL) bevezetése szerepel. Másrészt az, hogy a tanítási munka során az egyes kompetenciaterületek fejlesztése került előtérbe, a kooperatív módszerek és az IKT eszközök használatával a hangsúly – igazodva a munkaerő-piaci igényekhez – a gyakorlatban is alkalmazható tudásra tevődik át.\\nOktató- és nevelőmunkánk során arra törekszünk, hogy fejlesszük a diákok természettudományos kompetenciáit, a megértésre alapozva érzékenyítsük őket a természettudományos munka és a természettudományos vizsgálódás felé, és felkészítsük őket arra, hogy különböző szerepekben bekapcsolódjanak a kutatás-fejlesztés-innovációs folyamatokba. Fontos számunkra, hogy maturáló diákjaink inter- és multidiszciplináris szemléletükkel és komplex világnézetükkel a társadalom kreatív, innovatív, sokoldalúan képzett és művelt tagjaivá válhassanak.\\n", "mtmi_csapat_tag1_nev": "dr. Konczné dr. Jámbrik Katalin", "mtmi_csapat_tag2_nev": "Budai Kiss Ildikó", "mtmi_csapat_tag3_nev": "Nyakóné Kántor Mária", "mtmi_csapat_tag4_nev": "Dancs Sándorné", "mtmi_csapat_tag5_nev": "Kerekes Tibor", "mtmi_szakkorok_szama": "5", "mtmi_szulo_kepviselo": "igen", "mtmi_csapat_tag1_szak": ["biologia"], "mtmi_csapat_tag2_szak": ["matematika"], "mtmi_csapat_tag3_szak": ["foldrajz"], "mtmi_csapat_tag4_szak": ["digitalis_kultura"], "mtmi_csapat_tag5_szak": ["fizika"], "mtmi_csapat_tag6_szak": [], "mtmi_csapat_tag7_szak": [], "mtmi_csapat_tag8_szak": [], "pedprog_mtmi_tartalom": "igen", "szulo_palyaorientacio": "megvalosul", "mtmi_fakultaciok_szama": "12", "iskola_tanuloi_letszama": "780", "mtmi_szakkor_tantargyak": ["matematika", "kemia", "biologia", "digitalis_kultura", "integralt_termeszettudomany"], "mtmi_szakmak_bemutatasa": "igen", "iskola_mukodo_alapitvany": "igen", "mtmi_egyetemi_gyakorlatok": "igen", "mtmi_szakkor_diakok_szama": "45", "mtmi_szakkorok_bemutatasa": "Média szakkör\\nKutató Diákok műhelye\\nVarázsvár\\nKrausz Ferenc Alapítványának matematika szakköre\\nRobotika", "szulo_munkakoz_ismertetes": "megvalosul", "mtmi_szakkor_tanarok_szama": "10", "iskola_mtmi_tanari_letszama": "10+", "mtmi_csapat_tag1_tevekenyseg": "Kutatásalapú projektek, élményszerű oktatás, tananyagfejlsztés", "mtmi_fakultaciok_diakok_szama": "300", "intezmenytipus_tanuloi_letszama": "780", "mtmi_felelos_kapcsolattarto_neve": "dr. Konczné dr. Jámbrik Katalin", "programban_erintett_tanulok_szama": "300", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyuttmukodes_palyaorientacio": "igen", "mtmi_felelos_kapcsolattarto_email1": "jambrikkatka@gmail.com", "intezmenyvezeto_kapcsolattarto_neve": "dr. Koncz Gábor", "mtmi_felelos_kapcsolattarto_beosztas": "pedagógus", "intezmenyvezeto_kapcsolattarto_email1": "konczgabo@gmail.com", "intezmenyvezeto_kapcsolattarto_beosztas": "főigazgató", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 20 445 0827", "intezmenyvezeto_kapcsolattarto_telefonszam1": "+36 30 300 1948"}	2025-10-08 07:38:12.285612	2026-03-05 22:26:12.965584	0	\N	991d3309-f5ae-4700-9f11-763d45fc7667
e1176e03-d511-49bb-82ac-86d365e266e8	{"iskola_cime": "1192 Budapest, Gutenberg krt. 6", "iskolatipus": ["gimnazium"], "gdpr_consent": ["on"], "szulo_bevonas": "megvalosul", "mtmi_koncepcio": "igen", "telepulesforma": "fovaros", "mtmi_nyilt_napok": "Az MTMI nyílt napok célja, hogy az érdeklődő diákok és szülők közvetlen, élményszerű módon ismerkedhessenek meg az iskola matematika, természettudományos, műszaki és informatikai kínálatával. Ezek az alkalmak nem csupán információátadásra szolgálnak, hanem arra is, hogy a látogatók megtapasztalják az iskola nyitott, együttműködésen alapuló légkörét, és személyesen találkozzanak azokkal a pedagógusokkal és diákokkal, akik nap mint nap formálják az intézmény szakmai és közösségi életét. \\nA program megvalósítása tantárgyi börze formájában történik, ahol az iskola szakos tanárai és diákjai közösen, tematikus termekben mutatják be az egyes tantárgyakat, szakköröket és az iskolai közösségi élet sokszínűségét. Az érdeklődők egy „tudásösvényen” haladva – állomásról állomásra – fedezhetik fel a különböző tudományterületeket. Minden állomáson interaktív bemutatók, kísérletek, játékos feladatok és digitális eszközökkel támogatott szemléltetések várják őket, így a látogatók nemcsak hallgatói, hanem aktív résztvevői is lehetnek az élménynek.\\nEz a felépítés lehetővé teszi, hogy a vendégek saját tempójukban, érdeklődésüknek megfelelően járják végig a „tudásösvényt”, miközben közvetlen kapcsolatba kerülnek az iskola diákjaival és tanáraival. A nyílt nap így nemcsak tájékoztat, hanem inspirál, közösséget épít és élményszerűen mutatja be az MTMI területek izgalmas világát.\\nAz általános iskolások számára külön élményt nyújt, hogy a Deák Laborba érkezve testközelből ismerhetik meg iskolánkat, ami növeli a kedvet a hozzánk való jelentkezéshez. Fő célunk a tanulók természettudományos tárgyak iránti motivációjának erősítése, valamint a térségi iskolák természettudományos oktatásának támogatása és színvonalának emelése.\\nAz Öveges szakkör keretében lehetőség nyílik a tehetséges tanulókkal való külön, személyre szabott foglalkozásokra is, amely tovább erősíti a tehetséggondozás és a tudományos érdeklődés fejlesztésének szerepét intézményünkben.\\n", "szulo_egyeztetes": "megvalosul", "mtmi_csapat_link1": "https://kdfg.hu/mtmi-iskola-program/", "mtmi_csapat_link2": "https://www.facebook.com/kispestideak/posts/122259852656030886?ref=embed_post", "mtmi_csapat_link3": "https://docs.google.com/spreadsheets/d/1JsZ49VDsAg5Dxb4LOPI5WC9p_1stPfZNX-cdr8_fhns/edit?usp=sharing", "mtmi_csapat_link4": "https://padlet.com/hipikangela_kdfg/mtmi-iskola-9u6te0we6s7addwc", "mtmi_csapat_link5": "https://classroom.google.com/c/Nzc0OTc3MTA1NjU1?cjc=yu26jiow", "mtmi_csapat_link6": "https://drive.google.com/drive/folders/1xFqxGdZDHNip1wJXDSrv3JSQ14_1VIk0?usp=sharing", "mtmi_csapat_link7": "https://forms.gle/qKgdFzrx3bMTmBq38", "mtmi_csapat_link8": "https://forms.gle/HAMUqDtn9n6gpEtK6", "mtmi_csapat_link9": "https://forms.gle/AoxVypBSPb4zZ9j6A", "mtmi_projektnapok": "Iskolánkban az MTMI projektnapok célja, hogy a diákok élményszerű, interaktív formában tapasztalják meg a matematika, természettudományok, műszaki tudományok és informatika összefonódását, és felfedezzék, hogy ezek a területek játékosan, kreatív módon is elsajátíthatók.\\n\\nA Deák napok keretében minden évben megrendezzük az MTMI versenyt, ahol a csapatok változatos feladatokon keresztül mérhetik össze tudásukat és kreativitásukat. A korábbi Digitális Témahét eseményei szintén az MTMI tantárgyak közötti kapcsolódásokat mutatták be. A Pí, a rejtélyes szám projektben a résztvevők a matematika „Szent Gráljának” felfedezésére indultak, keresve a választ arra, miért övezi ekkora kultusz ezt a végtelen számsort, és hogyan kapcsolódik más tudományterületekhez.\\n\\nA Zero Waste Fashion – DTH 2025 projekt tökéletes példája annak, hogy két iskola együttműködése képes nemcsak a fenntarthatóságért tenni, hanem a fiatal generációk kreativitását is új szintre emelni. A diákok betekintést nyertek a szakképzés világába, együtt fedezték fel a kémia gyakorlati oldalát, digitális kiegészítők programozását, és gazdasági mutatók figyelembevételével piaci szereplőként vettek részt egy börzén. A bevételt jótékonysági célokra fordították, erősítve a társadalmi felelősségvállalást.\\n\\nA Code Week és a Kódolás órája eseményeken mindenki megtapasztalhatja, hogy a programozás nem kiváltság, hanem játékos, bárki számára elsajátítható készség. A Pénzhét programjaink a tudatos gazdálkodást és pénzügyi ismereteket fejlesztik.\\n\\nA jövőben tervezzük a Science on Stage Deák rendezvényt, amely látványos tudomány-show formájában mutatja be az MTMI tárgyakhoz kapcsolódó tudományterületeket. Itt a diákok saját projektjeiket prezentálják majd standjaiknál, interaktív módon bevonva a látogatókat.\\n\\nKiemelt célunk, hogy az általános iskolásokat is megszólítsuk: számukra a Deák Laborban szervezünk bemutatókat, ahol testközelből ismerkedhetnek meg a kísérletezés, a felfedezés és az alkotás örömével.", "pedprog_mtmi_link1": "https://kdfg.hu/wp-content/uploads/2025/10/PP_2024_legitimacioval.pdf", "szulo_kommunikacio": "megvalosul", "iskola_honlap_link1": "https://kdfg.hu/", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "6", "palyazo_iskola_neve": "Kispesti Deák Ferenc Gimnázium", "pedprog_mtmi_leiras": "Intézményünk pedagógiai programja és helyi tanterve kiemelt figyelmet fordít a matematika, természettudományok, műszaki tudományok és informatika (MTMI) tantárgyakra. A nevelési célok között hangsúlyosan szerepel a logikus gondolkodás, a problémamegoldó képesség, a digitális kompetenciák fejlesztése, valamint a természettudományos szemlélet kialakítása. Ezek a célok szorosan összefonódnak az MTMI tantárgyak tartalmi és módszertani fejlesztésével.\\nA helyi tanterv tantárgyi struktúrája lehetőséget biztosít arra, hogy a tanulók már korai szakaszban találkozzanak az MTMI területek alapjaival. A matematika és informatika tantárgyak esetében kiemelt hangsúlyt kap az algoritmikus gondolkodás, a modellezés és a digitális eszközhasználat. A természettudományos tárgyak – fizika, kémia, biológia – tananyaga kísérletezésre, megfigyelésre és a környezettudatos gondolkodásra épül.\\nA pedagógiai program több ponton utal a pályaorientáció fontosságára, amely szorosan kapcsolódik az MTMI területek népszerűsítéséhez. Ennek érdekében az iskola szakköröket, versenyfelkészítő foglalkozásokat, projektnapokat és tematikus rendezvényeket szervez. A diákok számára lehetőséget biztosítunk arra, hogy egyetemek, kutatóintézetek és cégek előadóival találkozzanak, akik műhelyfoglalkozások és interaktív előadások keretében mutatják be saját szakterületüket.\\nA szakmai gyakorlatban az MTMI elemek nemcsak tanórai keretek között jelennek meg, hanem digitális platformokon, projektalapú tanulásban és tanórán kívüli tevékenységekben is. A pedagógusok rendszeresen részt vesznek MTMI témájú továbbképzéseken, és az iskola támogatja az innovatív oktatási módszerek alkalmazását.\\nAz MTMI tantárgyak tehát nemcsak deklarált célként, hanem aktív, élő gyakorlatként jelennek meg az iskola pedagógiai programjában és helyi tantervében, hozzájárulva a tanulók jövőorientált kompetenciáinak fejlesztéséhez.", "mtmi_ceges_eloadasok": "igen", "mtmi_csapat_tag1_nev": "Hipik Angéla", "mtmi_csapat_tag2_nev": "Selényiné Heim Judit ", "mtmi_csapat_tag3_nev": "Tugyiné Czinkotai Krisztina", "mtmi_csapat_tag4_nev": "Péretffi Erzsébet", "mtmi_csapat_tag5_nev": "Vörösmarty Balázs", "mtmi_csapat_tag6_nev": "Marics István", "mtmi_koncepcio_link1": "https://kdfg.hu/wp-content/uploads/2025/09/MTMI_iskolai_koncepcio.pdf", "mtmi_szakkorok_link1": "https://docs.google.com/document/d/1MDyOfYzluRqoLfqF9zUYjSOUoWxQxh1q/edit?usp=sharing&ouid=104440785127676894745&rtpof=true&sd=true", "mtmi_szakkorok_link2": "https://padlet.com/hipikangela_kdfg/mtmi-iskola-9u6te0we6s7addwc", "mtmi_szakkorok_link3": "https://classroom.google.com/c/Nzc0OTc3MTA1NjU1/a/ODAyNDQwMjE1Nzkx/details", "mtmi_szakkorok_szama": "8", "mtmi_szulo_kepviselo": "igen", "mtmi_alumni_programok": "igen", "mtmi_csapat_tag1_szak": ["matematika", "fizika", "digitalis_kultura"], "mtmi_csapat_tag2_szak": ["kemia", "egyeb"], "mtmi_csapat_tag3_szak": ["matematika", "fizika"], "mtmi_csapat_tag4_szak": ["matematika", "digitalis_kultura"], "mtmi_csapat_tag5_szak": ["matematika", "digitalis_kultura"], "mtmi_csapat_tag6_szak": ["digitalis_kultura", "egyeb"], "mtmi_csapat_tag7_szak": [], "mtmi_csapat_tag8_szak": [], "mtmi_koncepcio_leiras": "A Kispesti Deák Ferenc Gimnázium MTMI (matematika, természettudományok, műszaki tudományok, informatika) koncepciója arra épül, hogy ezeket a területeket intézményi szinten, tudatosan és rendszerszerűen fejlessze, szorosan illeszkedve az iskola pedagógiai céljaihoz. A megvalósítás alapja a projektalapú, interdiszciplináris tanulás, a digitális technológiák tudatos használata és az élményszerű oktatás.\\nA program sokrétű tevékenységekkel támogatja a tanulók aktív bevonását: szakkörök, versenyfelkészítők, tematikus projektnapok, pályaorientációs események, céglátogatások, egyetemi nyílt napok, MTA Alumni Program, Deák Labor működtetése, Deák Műhely, műhelyfoglalkozások. Kiemelt cél a lányok tudományos érdeklődésének ösztönzése női példaképek és célzott programok révén.\\nA pedagógusok szakmai fejlődését továbbképzések, szakmai együttműködések és jó gyakorlatok megosztása segíti. Az MTMI munkacsoport tantárgyi kötődés szerint szerveződik, és éves terv alapján koordinálja a tevékenységeket. A szülők bevonása kérdőívek, értekezletek és közös események útján történik, erősítve az iskola–család partnerséget.\\nA koncepció alapelvei:\\n•\\tRendszerszemlélet – az MTMI területek összefüggéseinek bemutatása\\n•\\tTudatosság és tervezettség – célorientált, előre megtervezett tevékenységek\\n•\\tSzemélyre szabott fejlesztés – a tanulók érdeklődéséhez és képességeihez igazodva\\n•\\tPartnerség – pedagógusok, diákok, szülők és külső partnerek együttműködése\\n•\\tLáthatóság – eredmények nyilvános kommunikálása\\n•\\tEsélyteremtés – minden tanuló számára hozzáférés biztosítása\\nA hosszú távú cél, hogy a diákok érdeklődése és elköteleződése az MTMI tantárgyak iránt erősödjön, és minél többen válasszanak ilyen irányú továbbtanulást, hozzájárulva a tudásalapú társadalom fejlődéséhez.", "pedprog_mtmi_tartalom": "igen", "szulo_palyaorientacio": "megvalosul", "mtmi_fakultaciok_szama": "10", "mtmi_kapcsolatok_link1": "https://www.facebook.com/kispestideak/posts/122225850560030886?ref=embed_post", "mtmi_kapcsolatok_link2": "https://www.facebook.com/kispestideak/posts/122161251560030886?ref=embed_post", "mtmi_kapcsolatok_link3": "https://hipikangela.blogspot.com/2025/03/zero-waste-fashion-fenntarthatosag.html", "mtmi_kapcsolatok_link4": "https://kdfg.hu/zero-waste-fashion-2/", "mtmi_kapcsolatok_link5": "https://www.facebook.com/kispestideak/posts/122225214194030886?ref=embed_post", "mtmi_kapcsolatok_link6": "https://hipikangela.blogspot.com/2025/10/kutatok-ejszakaja-biotechnologia.html", "mtmi_muzeumlatogatasok": "igen", "mtmi_nyilt_napok_link1": "https://www.facebook.com/profile/61550926599075/search/?q=bosh", "mtmi_nyilt_napok_link2": "https://www.facebook.com/kispestideak/posts/122153243084030886?ref=embed_post", "mtmi_nyilt_napok_link3": "https://www.facebook.com/kispestideak/posts/122224329122030886?ref=embed_post", "mtmi_nyilt_napok_link4": "https://www.facebook.com/kispestideak/posts/122234045432030886?ref=embed_post", "mtmi_nyilt_napok_link5": "https://padlet.com/hipikangela_kdfg/mtmi-iskola-9u6te0we6s7addwc", "mtmi_nyilt_napok_link6": "https://kdfg.hu/mtmi-iskola-program/", "mtmi_nyilt_napok_link7": "https://www.facebook.com/kispestideak/posts/122259852656030886?ref=embed_post", "mtmi_nyilt_napok_link8": "https://classroom.google.com/c/Nzc0OTc3MTA1NjU1?cjc=yu26jiow", "mtmi_nyilt_napok_link9": "https://korosikettannyelvu.hu/oveges-labor-a-deak-gimnaziumban-fizika-es-kemia-laborfoglalkozasok/", "iskola_tanuloi_letszama": "450", "mtmi_nyilt_napok_link10": "https://atanulasjovoje.hu/ptms/motInfo/80", "mtmi_szakkor_tantargyak": ["matematika", "fizika", "kemia", "biologia", "digitalis_kultura", "kornyezetismeret"], "mtmi_szakmak_bemutatasa": "igen", "szulo_egyeztetes_szoveg": "Az MTMI program céljairól való egyeztetés intézményünkben többcsatornás, rendszeres és nyitott kommunikációs formában történik. A tájékoztatás fő eszközei az e-mailes hírlevelek, az iskola honlapján létrehozott MTMI aloldal, valamint közösségi média felületeink (pl. Facebook), ahol figyelemfelkeltő bejegyzésekkel, képes beszámolókkal és regisztrációs linkekkel segítjük a szülők bevonását.\\nKiemelt alkalom a szülői értekezlet, ahol bemutatjuk a program céljait, eddigi eredményeit, és lehetőséget biztosítunk kérdések, javaslatok megfogalmazására. Itt külön figyelmet fordítunk a pályaorientációs lehetőségek ismertetésére, és ösztönözzük a szülőket, hogy szakmai tapasztalataikkal támogassák a programot.\\nA szülők bevonását kérdőívekkel is támogatjuk, amelyekkel feltérképezzük igényeiket, javaslataikat és bevonási szándékukat. A válaszok alapján célzottan tervezünk tevékenységeket, és személyre szabott lehetőségeket kínálunk. A Pályaorientációs napokon szülők és partnerek interaktív előadások és műhelyfoglalkozások formájában mutatják be szakterületüket, ezzel is segítve a diákok érdeklődésének felkeltését.\\nTovábbi gyakorlatként szakköröket indítunk, versenyekre jelentkeztetjük a diákokat, és egyetemek, cégek előadóit hívjuk meg, hogy élményszerűen mutassák be a tudományos és technológiai pályákat. A digitális faliújságot és Classroom tantermet megosztjuk a szülőkkel, hogy átláthatóan követhessék a fejlesztéseket. A közös Google Drive tárhelyen keresztül rendszerezett módon osztjuk meg a dokumentumokat, így a szülők számára is biztosított az információhoz való hozzáférés.\\nPedagógiai elvként az átláthatóságot, partnerséget és tudatos pályaorientációt tartjuk szem előtt. Célunk, hogy a szülők aktív formálói legyenek annak a tudományos szemléletnek, amelyet az MTMI program képvisel.", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "igen", "mtmi_szakmai_gyakorlatok": "Célunk, hogy a diákok az elméleti tudás mellett valós, gyakorlati tapasztalatokat is szerezzenek az MTMI (matematika, természettudományok, műszaki tudományok, informatika) területeken. Rendszeresen szervezünk szakmai gyakorlatokat, üzem- és céglátogatásokat, valamint bekapcsolódunk országos és nemzetközi programokba, amelyek közvetlen kapcsolatot teremtenek a tudományos és technológiai világ szereplőivel.\\nTanulóink jártak a Bosch budapesti telephelyén, ahol modern gyártástechnológiákat és mérnöki fejlesztéseket ismerhettek meg, a közeljövőben pedig Yettel-látogatást tervezünk. Részt veszünk a SMartiz programban, amelyet a Nők a Tudományban Egyesület szervez a Morgan Stanley-vel együttműködésben. A heti másfél órás, ingyenes, matematikafókuszú foglalkozások élmény- és felfedezésalapú módszerekkel mutatják be, miként könnyíthetik meg a mindennapokat az informatika és a matematika, valamint segítenek a pályaorientációban.\\nA Richter Gedeon Kutatók Éjszakáján diákjaink laborbemutatókon, interaktív kísérleteken és szakmai előadásokon vettek részt. Kiemelt partnerünk az MTA Alumni Program, amely személyes találkozási lehetőséget biztosít a tudományos élet kiemelkedő alakjaival.\\nTermészettudományos csoportunk számára blokkos rendszerben, gyakorlatorientáltan mutatjuk be a tudományterületeket. Ennek részeként állatkerti zoópedagógiai programon is részt vettünk, vizitúrán tapasztaltuk meg a természetközeli tanulást, valamint az Erasmus program keretében külföldi példákon keresztül ismertük meg a fenntarthatóság jó gyakorlatait.\\nEmlékezetes élmény volt a Fizikai Kísérletsorozat Härtlein Károllyal az MTA Székházban, ahol látványos, interaktív kísérletek hozták közel a fizika izgalmas világát.\\nA Deák Labor mindehhez bázist biztosít: itt a diákok saját kísérleteket végezhetnek, mérési technikákat sajátíthatnak el, és felkészülhetnek a külső szakmai programokra. A labor nyitott a térségi iskolák számára is, így hozzájárul a régió természettudományos oktatásának fejlesztéséhez.\\n", "mtmi_egyetemi_gyakorlatok": "igen", "mtmi_szakkor_diakok_szama": "40", "mtmi_szakkorok_bemutatasa": "Iskolánkban az MTMI (matematika, természettudományok, műszaki tudományok, informatika) szakkörök a tehetséggondozás, a motiváció erősítése és a pályaorientáció kiemelt eszközei. Az órarendi kereteken túl inspiráló, gyakorlatorientált közegben segítik a tudás elmélyítését, a valós problémák megoldását és a tudományterületek közötti kapcsolódások felfedezését\\nA robotika iránt érdeklődő tanulók a WRObotika szakkörön sajátíthatják el a programozás és a mérnöki gondolkodás alapjait, miközben felkészülnek a versenyre. A csapat a Prosuli versenyen 3. helyezést ért el, a WRO-n pedig bejutott az országos döntőbe. A Microbit szakkörön a diákok a programozás és az elektronika mellett okoseszközök és okosházak építésével, mesterséges intelligencia programozásával is foglalkoznak; a tavalyi évben 2. helyezést értek el egy rangos versenyen.\\nA természettudományos érdeklődésű tanulók számára több lehetőség is nyitva áll: a 10. évfolyam biológia versenyfelkészítő szakkör a kísérletezés és terepgyakorlatok révén készít fel országos és regionális megmérettetésekre; az Irinyi János Kémiaverseny felkészítő a kémiai tudás elmélyítését és kísérleti gyakorlatot kínál. A 11. és 12. évfolyam kémia fakultációi plusz órákkal segítik az emelt szintű érettségire való felkészülést, míg a 12. évfolyam fizika mérési szakköre a gyakorlati mérési technikák és adatfeldolgozás elsajátítását támogatja.\\nKiemelt szerepet tölt be a Deák Műhely, amely a környezetvédelem, a fenntarthatóság, a rendszerszemléletű gondolkodás és a társadalmi felelősségvállalás iránt elkötelezett közösség kialakítását tűzte ki célul. A program a diákok szemléletformálásán keresztül ösztönzi őket arra, hogy aktív, felelős tagjai legyenek a helyi és globális közösségnek.\\nFontos bázisunk a Deák Labor is, amely a tanulók természettudományos tárgyak iránti motivációjának erősítését, valamint a térségi iskolák természettudományos oktatásának támogatását és színvonalának javítását szolgálja.", "szulo_munkakoz_ismertetes": "megvalosul", "mtmi_ceges_eloadasok_link1": "https://www.facebook.com/kispestideak/posts/122232818696030886?ref=embed_post", "mtmi_ceges_eloadasok_link2": "https://hipikangela.blogspot.com/2025/03/zero-waste-fashion-dth-2025.html", "mtmi_szakkor_tanarok_szama": "10", "iskola_mtmi_tanari_letszama": "10+", "lanyok_mtmi_reszvetel_link1": "https://www.facebook.com/kispestideak/posts/122261937116030886?ref=embed_post", "lanyok_mtmi_reszvetel_link2": "https://www.facebook.com/kispestideak/posts/122259852656030886?ref=embed_post", "lanyok_mtmi_reszvetel_link3": "https://drive.google.com/drive/folders/1bf0v8BtLNNS9AiAXjW6rqgWLWJG-BPJe?usp=sharing", "mtmi_alumni_programok_link1": "https://kdfg.hu/alumni-eghajlatvaltozas-eloadas/", "mtmi_alumni_programok_link2": "https://www.facebook.com/kispestideak/posts/pfbid0bNW8ijT4hULSsmMHDnzDQVk9csJYgWrVkQA8vAGe5zXzrPjQkPq91LgkN69xb2nNl", "mtmi_diakok_kapcsolattartas": "igen", "mtmi_egyeb_partnerprogramok": "Intézményünk elkötelezett a tudományos szemléletformálás és az MTMI területek élményszerű bemutatása mellett, ezért folyamatosan bővítjük szakmai együttműködéseink körét.\\nRészt vettünk egy kiemelkedő MTA által szervezett programon,  a  Fizikai Kísérletsorozat Härtlein Károllyal c., amely során diákjaink látványos, interaktív bemutatókon keresztül ismerkedhettek meg a fizikai jelenségek működésével. A program célja volt, hogy a tudomány közvetlen tapasztalaton keresztül váljon érthetővé és motiválóvá a tanulók számára.\\nIntézményi kezdeményezésként működik a „Nem középiskolás fokon” című programsorozat, amelynek keretében neves professzorokat, kutatókat és egyetemi oktatókat hívunk meg. Előadásaik célja, hogy személyes példáikon, kutatási tapasztalataikon keresztül inspirálják a diákokat – különösen a fakultációs csoportokat, akik már elkötelezettebbek az MTMI területek iránt. E zen eseményünket az MTA Alumni program támogatja.\\nA Zero Waste Fashion – DTH 2025 projekt keretében szakmai kapcsolatot építettünk ki a Petrik Lajos Kéttannyelvű Technikum közösségével is, amely lehetőséget biztosított tanulóink számára, hogy betekintést nyerjenek a technikusi képzés gyakorlati oldalába és a fenntartható technológiák világába.\\nFontos számunkra, hogy a természettudományos élmények ne csak a gimnazisták számára legyenek elérhetők. Ennek érdekében általános iskolákkal is együttműködünk, és rendszeresen fogadjuk a fiatalabb korosztályt az intézményünkben működő Öveges Laborban, ahol játékos, kísérleteken alapuló foglalkozásokon keresztül ismerkedhetnek meg a fizika alapjaival.\\n", "mtmi_kapcsolatok_bemutatasa": "Iskolánk aktívan együttműködik MTMI-orientált vállalatokkal és intézményekkel, hogy tanulóink élményszerűen ismerjék meg a tudományos és technológiai világ gyakorlati oldalát.\\nA Bosch telephelyén diákjaink az ipari automatizálás, robotika és mérnöki fejlesztések működésébe nyertek betekintést. A Yettel céglátogatás során a távközlési szektor innovációit és informatikai rendszereit ismerhették meg. A Szemléletformáló és Újrahasználati Központban a fenntarthatóság és újrahasználat gyakorlati példáival találkoztak. A Morgan Stanley Smartíz programja keretében a pénzügyi szektor informatikai és matematikai alkalmazásait fedezték fel.\\nA BME Nyílt Laborok délutánján a villamosmérnöki és informatikai kutatások világába kaptak betekintést, míg az Óbudai Egyetem „Kódolás órája” programja játékos feladatokon és előadásokon keresztül hozta közelebb a műszaki pályákat.\\nA Zero Waste Fashion projektben a CNW Zrt. szakértői mentorálták a diákok fenntarthatósági vállalkozásait, és digitális platformot biztosítottak a weboldalak létrehozásához. A résztvevők megismerték a Cseriti bolthálózat működését, és a családoktól begyűjtött, fel nem használt ruhadarabokat, valamint a projekt során értékesített termékek bevételét a Cseritinek ajánlották fel jótékony célra.A projekt a környezettudatosság mellett vállalkozói szemléletet és digitális kompetenciákat is fejlesztett.\\nA Kutatók Éjszakája programon részt vevő diákok Dr. Bogsch Erik előadásán keresztül ismerkedtek meg a biotechnológia világával, majd laborlátogatáson vettek részt, ahol óriásműszerekkel végzett molekuláris vizsgálatokat láthattak.\\nA programokról készült beszámolók iskolánk közösségi oldalán is elérhetők, ezzel is erősítve a tudományos érdeklődést és a pályaorientáció láthatóságát", "mtmi_online_palyaorientacio": "nem", "mtmi_rendezvenyek_reszvetel": "igen", "lanyok_mtmi_kiemelt_figyelem": "igen", "mtmi_alumni_programok_leiras": "Iskolánk aktív kapcsolatot ápol volt diákjaival, akik MTMI területeken tevékenykednek, és rendszeresen visszatérnek előadóként, mentorként vagy példaképként. Az alumni szervezet közreműködésével olyan orientációs programokat valósítunk meg, amelyek közvetlen betekintést nyújtanak a tudományos, mérnöki, informatikai és technológiai pályák világába.\\nA „Nem középiskolás fokon” programsorozat mára hagyománnyá vált, amelyben az idén 2 diákunk is előadóként vesz részt. A tavasszal megvalósuló, tervezett Tudományos börze szintén lehetőséget teremt arra, hogy a tanulók hiteles, elérhető példákon keresztül lássák, hová vezethet a tudományos érdeklődés és elkötelezettség.\\nKiemelkedő eseményként említhető az Éghajlatváltozás témájú előadás, amelyet az ELTE Meteorológiai Tanszékének oktatója, Soósné Dr. Dezső Zsuzsanna tartott a földrajz fakultációra járó 11–12. évfolyamos tanulóknak. Bár nem iskolánk egykori tanulója, szakmai kapcsolaton keresztül meghívott előadóként járult hozzá a programhoz, és értékes tudományos ismereteket osztott meg a klímaváltozásról és a meteorológusi pálya sajátosságairól.\\nAz MTMI-témájú alumni eseményekről beszámolunk az iskola honlapján, ahol fényképes tudósítások, interjúk és programajánlók is megjelennek. A volt diákok aktivizálása érdekében kérdőíves felmérést is indítottunk. Célunk, hogy minél több egykori tanulónkat bevonjuk a jövőbeli MTMI-orientációs programokba.\\n", "mtmi_csapat_tag1_tevekenyseg": "Mestermunkáját „Digitális megoldások az iskola fejlődésében” címmel teljesíti. Ennek keretében digitális tananyagokat fejleszt, valamint olyan projekteket szervez, amelyek az élményszerű tanulást, a tantárgyközi szemléletet és a modern technológiák oktatásban való alkalmazását támogatják.\\nA 2023/2024-es tanévben a „Pí, a rejtélyes szám” című projekt záróeseményével csatlakozott az intézmény az 1848–49-es forradalom és szabadságharc rendhagyó megemlékezéséhez. A két esemény tematikus összekapcsolása érzékletesen mutatta meg, hogyan válhat a tudomány és a történelem közös tanulási élménnyé. A projekt a Digitális Témahét középiskolai kategóriájában II. helyezést ért el, és bekerült a Tanulás jövője honlap Digitális Módszertárába.\\nVezetésével valósult meg tavasszal a Deák Ferenc Gimnázium és a Budapesti Műszaki SzC Petrik Lajos Technikum közös projektje, a „Zero Waste Fashion”. A kezdeményezés a környezettudatosságot, a kreatív gondolkodást és a digitális technológiák oktatásban való alkalmazását ötvözte, miközben egyedülálló módon kapcsolta össze a közoktatás és a szakképzés szereplőit. A program lehetőséget teremtett arra, hogy a diákok közösen reflektáljanak a jövő kihívásaira, és alkotó módon keressenek válaszokat. A Digitális Témahét kiemelkedő eseményeként együttműködési díjban részesült. A projekt jól példázza, hogyan válhat két intézmény partnersége olyan innovatív tanulási térré, amely nemcsak a fenntartható szemléletet erősíti, hanem a fiatal generációk kreativitását is új szintre emeli.\\nAktívan támogatja a pedagógiai innovációk létrehozását és kipróbálását mind szűkebb, mind tágabb szakmai környezetében. Tapasztalatait rendszeresen megosztja publikációkban, webináriumokon és szakmai fórumokon, ezzel segítve pedagógustársait saját innovatív tevékenységeik megfogalmazásában és megvalósításában. Munkáját 2025-ben Ericsson-díjjal és Pécsi Eszter tanári díjjal ismerték el.", "mtmi_csapat_tag2_tevekenyseg": "Kémia–olasz nyelv szakos tanár; a Deáklabor laborvezetője. Szenvedélyesen hiszek a természettudományok integrált megközelítésében és abban, hogy a tananyagnak mindig kapcsolódnia kell a diákok mindennapjaihoz és a valós problémákhoz.\\nTanítási és tanórán kívüli foglalkozásaim középpontjában a STEAM szemlélet és a kísérletalapú megközelítés áll. Projektalapú módszertanomat a tananyaghoz igazítva alkalmazom, így a Digitális Témahét keretében is aktívan közreműködöm – legutóbb a Zero Waste Fashion projektjén dolgoztunk együtt a diákokkal.\\nErasmus-akkreditációs programunkban, amelynek központi témája a STEAM integráció, jobshadowingon vettem részt Finnországban, és diákcsoportot kísértem Spanyolországba. Tapasztalataim hozzájárultak ahhoz, hogy iskolánkban létrejöjjön az Öveges-labor; mint laborvezető koordinálom az általános iskolákkal való együttműködést és támogatást. Jelen tanévtől kezdve az iskolai pályaorientációs nap szervezőjeként koordinálom, hogy a diákok érdeklődésének megfelelő lehetőségek legyenek felkínálva a továbbtanulási és pályaválasztási céljaik tudatos és sikeres megvalósítása céljából.\\nElkötelezett vagyok a tehetséggondozás és az innovatív módszerek terjesztése iránt: feladatomnak tekintem, hogy a tankerületi általános iskolákban is bevezessük és megerősítsük a STEAM oktatást. Várom a közös projekteket és az új kihívásokat, amelyekkel tovább gazdagíthatjuk diákjaink tudását és motivációját.\\n", "mtmi_csapat_tag3_tevekenyseg": "A természettudományos munkaközösség vezetőjeként elkötelezett az iskola természettudományos oktatásának folyamatos fejlesztése iránt. Vezető szerepet vállalt az Öveges pályázat keretében létrejövő természettudományos labor szakmai munkájában: összeállította a beszerzendő eszközök listáját, magas színvonalú tanári kézikönyveket és tanulói munkafüzeteket készített. Szakmai munkájának elismeréseként 2014-ben Pro Progressio tanári díjban részesült. Azóta is aktívan részt vesz a labor működésében: immár 12 éve segíti az általános iskolás csoportok fizika foglalkozásait.\\nMunkája során kiemelten fontosnak tartja a tudás élményszerű átadását és a tanulói aktivitás erősítését. Rendszeresen tart bemutatóórákat, műhelyfoglalkozásokat a partnerintézmények pedagógusainak, munkájukat filmek, videók, animációk és szakmai anyagok megosztásával is támogatja. Matematika–fizika szakos tanárként szívügyének tekinti, hogy diákjai változatos, jó hangulatú órákon vehessenek részt, ahol a tanulás kreatív projektek, saját készítésű társasjátékok, látványos kísérletek, érdekes prezentációk és digitális feladatok révén válik élménnyé. Szakkörök megszervezésével, emelt szintű érettségire és versenyekre való felkészítéssel aktívan részt vállal a tehetséggondozásban, emellett rendszeresen szervez természettudományi tárgyakat népszerűsítő programokat és versenyeket.\\nInnovátor mestertanárként a projektalapú tanulás és a digitális eszközök tudatos alkalmazásával arra törekszik, hogy a diákok saját tapasztalataikon keresztül értsék meg a természettudományos jelenségeket, és képesek legyenek azokat más tantárgyakhoz, a mindennapi élethez és a jövő kihívásaihoz kapcsolni. Célja, hogy a matematika, fizika, műszaki tudományok és informatika területén megszerzett tudásuk mellett olyan készségeik – mint a kritikus gondolkodás, a kreativitás, a problémamegoldás és az együttműködés – is fejlődjenek, amelyek hosszú távon biztos alapot adnak számukra a továbbtanulásban és a munka világában.\\n", "mtmi_csapat_tag4_tevekenyseg": "Matematika- és informatika tanárként aktív szerepet vállalt a STEAM-szemléletű tehetséggondozás iskolai meghonosításában, elősegítve a természettudományos gondolkodás, a kreativitás és az innováció összekapcsolását a mindennapi pedagógiai gyakorlatban.\\nA Nemzeti Tehetségprogram és az „Út a tudományhoz” kutatási program keretében benyújtott sikeres pályázatai révén Lego-robotokat nyert, amelyekre alapozva robotika szakkört indított a technikai kihívások iránt érdeklődő diákok számára. A „Lego robotokkal a jövőbe” című kutatási projektben való részvétel során a tanulók a felfedezés örömét megélve szereztek tapasztalatot az élményszerű tanulásban, a kreatív együttműködésben, valamint matematikai, fizikai és programozási ismereteik gyakorlati alkalmazásában.\\nTíz éve szervez robotikával foglalkozó tehetséggondozó csoportokat, amelyek több versenyen értek el kiemelkedő eredményeket. 2024-ben a ProSuli Robotika Verseny vonalkövető gyorsasági kategóriájának országos döntőjében 3. helyezést, míg 2025-ben a World Robot Olympiad verseny országos döntőjében, senior kategóriában 10. helyezést szereztek.\\nAktívan közreműködik a Digitális Témahét projektjeinek szervezésében és lebonyolításában.\\nLegutóbb a „Zero Waste Fashion” projekt keretében a tanulócsoportokat a textíliák kreatív újrahasznosításának kutatásában, tervezésében és dokumentálásában irányította.\\nTanórai munkájában tudatosan törekszik a fenntarthatósági szemlélet és a környezettudatosság fejlesztésére. Nevelési célja, hogy meggyőzze a diákokat: érdemes szellemi energiáikat és digitális tudásukat a környezetvédelem, az erőforrásokkal való takarékos gazdálkodás, valamint a fenntartható fejlődés szolgálatába állítani.\\n", "mtmi_csapat_tag5_tevekenyseg": "Matematika-digitális kultúra tanárként folyamatosan azon dolgozik, hogy a tantárgyak közötti kapcsolódási pontokat kihasználja a tanulási-tanítási folyamatban. A tanulás élményszerűségét igyekszik központba helyezni. Mesterprogramját is ezen témakörben valósítja meg olyan digitális játék és eszközgyűjtemény összeállításával, amely változatosságával segít fenntartani a tanulási motivációt.\\nA matematika-digitális kultúra munkaközösség vezetőjeként maximálisan támogatja a tantárgyak népszerűsítése érdekében tett erőfeszítéseket.\\nTöbb alkalommal pályázott sikerrel iskolánknak a Nemzeti Tehetségprogram támogatásaira. Ezen pályázatok keretében matematikai-természettudományos szakkörök, illetve természettudományos biciklitáborok tudtak megvalósulni a Balaton, illetve a Tisza-tó körül, remek alkalmat teremtve a diákok érdeklődésének felkeltésére a fenti területek iránt.\\nIskolánk 5 éves Erasmus-akkreditációval rendelkezik, melynek egyik központi témája a STEAM-szemlélet terjesztése és minél szélesebb körű alkalmazása. Pályázati koordinátorként ennek sikeres megvalósításában vállal aktív szerepet.", "mtmi_csapat_tag6_tevekenyseg": "A szakképzésben kezdte pedagógusi pályáját. Tanulmányai során megszerzett informatikai és művészeti képesítései a STEAM szemlélet iránti elhivatottságát tükrözik (programozó matematikus, jazz - ének előadóművészi és tanári szak, számítástechnika tanári szak). Szakközépiskolai munkája során nyolc éven át gyakorlati oktatásvezető beosztásban is dolgozott. Szakvizsgája szakdolgozatához a „Szakképzés az Európai Unió országaiban” témát választotta a műszaki profilú BMSZC Trefort Ágoston Két Tanítási Nyelvű Technikum informatika tanáraként. Részt vett mentorként a Tempus Közalapítvány Világ – Nyelv / Mesterfokon / programjában és egy Comenius módszertani képzésben, amelyet a természettudományokat, matematikát, illetve műszaki tárgyakat középiskolában angolul tanító pedagógusok számára szerveztek meg (Comenius program in Colchester, UK: C.L.I.L., Methodology & Language for Teachers who teach Science or Maths or Technical Subjects “Bilingually” in English at Secondary Level). A Nemzetközi Üzleti Főiskolán (IBS) nyolc éven át tanított óraadó tanárként (Information and Communication Technology és Business Information Systems tantárgyak tanítása angol nyelven).\\nMesterpedagógusként folyamatosan részt vállal a STEAM-szemléletű tehetséggondozásban, rendszeresen indultak és indul tanítványa, akik dobogós helyezéssel végeztek, illetve végeznek budapesti, iletve a Tehetségkapun meghirdetett országos versenyen. Felkészítő tanárként több elismerő oklevelet kapott az elért eredmények kapcsán.\\n", "mtmi_muzeumlatogatasok_link1": "https://scontent-vie1-1.xx.fbcdn.net/v/t39.30808-6/558282929_24966541986274393_3128584975266293234_n.jpg?_nc_cat=107&ccb=1-7&_nc_sid=127cfc&_nc_ohc=qi1zNcvy640Q7kNvwHtusMR&_nc_oc=AdnAfev1yAKBR0IsDbLXmfpGv_eCcQcLH2F0vAtcEcmny0sVDNElqAVdf8u5jUWAjUkKgWI15BNvhRYbbr3VPwae&_nc_zt=23&_nc_ht=scontent-vie1-1.xx&_nc_gid=Cv_iI1Q5EYadL-4DIDqo5Q&oh=00_Afc2SuJ-VUX-e0jP19rJ2__rDANg9nyr_NrWU_2Zk4N4BQ&oe=68F460A8", "mtmi_muzeumlatogatasok_link2": "https://www.canva.com/design/DAG0I8hlk5w/Dd9xSujGfmzwJOoD0L_dtQ/view?utm_content=DAG0I8hlk5w&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=hfb44878b73#2", "mtmi_aktiv_tanulas_megvalosul": "igen", "mtmi_csapat_kozos_tevekenyseg": "Az MTMI csapat közös munkája az intézményen belül egy olyan szemléletváltást indított el, amely a tudományos gondolkodás, a digitális kompetenciák és az együttműködés kultúráját helyezi előtérbe. A program megismerését követően célunk lett, hogy ne csak saját magunk értsük meg az MTMI alapelveit, hanem kollégáinkkal is megosszuk, közösen értelmezzük és beépítsük a mindennapi pedagógiai gyakorlatba. Ennek érdekében belső megbeszéléseket tartottunk, ahol ötleteket gyűjtöttünk, kérdéseket vetettünk fel, és elkezdtük kialakítani az intézményi MTMI csapatot.\\n\\nA digitális eszközök tudatos használatával létrehoztuk az MTMI digitális tantermet, valamint egy digitális faliújságot, amely a programhoz kapcsolódó információkat, eseményeket és felhívásokat tartalmazza. Ezeket megosztottuk a tantestülettel, diákokkal és szülőkkel, ezzel is erősítve az átláthatóságot és a közösségi kommunikációt. A hatékony együttműködés érdekében létrehoztunk egy közös tárhelyet is, amelyben rendszerezetten tároljuk a dokumentumokat, terveket, kérdőíveket és prezentációkat.\\nA program népszerűsítése érdekében kérdőíveket készítettünk a tanárok, diákok és szülők számára, hogy feltérképezzük az igényeket, érdeklődési területeket és bevonási lehetőségeket. A szülői értekezleten is bemutattuk a programot, ahol aktív érdeklődést tapasztaltunk, és elkezdtük keresni azokat a szülőket, akik szakmai partnerként is bekapcsolódhatnak. Szakkörök indításával és versenyekre való jelentkeztetéssel célunk a tehetségek fejlesztése, motiválása és támogatása. Egyetemek és cégek képviselői műhelyfoglalkozások, interaktív bemutatók és előadások formájában ismertetik meg szakmájukat, ezzel is felkeltve diákjaink érdeklődését a tudományos és technológiai pályák iránt.\\nKapcsolatot építünk olyan szervezetekkel, mint a Yettel, Richter, Morgan Stanley, NATE, valamint a Highschool programok szervezőivel, hogy a diákok valós példákon keresztül lássák: a tudomány nem távoli, hanem elérhető és izgalmas jövő.", "mtmi_fakultaciok_diakok_szama": "125", "mtmi_kiallitoterek_megvalosul": "igen", "lanyok_mtmi_nepszerusito_link1": "https://kdfg.hu/deak-muhely/", "lanyok_mtmi_nepszerusito_link2": "https://kdfg.hu/deak-muhely-2/", "lanyok_mtmi_nepszerusito_link3": "https://kdfg.hu/wp-content/uploads/2025/03/deak_muhely_4.pdf", "lanyok_mtmi_nepszerusito_link4": "https://deaklabor.kdfg.hu/", "lanyoknak_szolo_mtmi_programok": "igen", "mtmi_egyeb_tevekenysegek_szama": "1", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_kutatási_versenyek_link1": "https://www.facebook.com/kispestideak/posts/122161251560030886?ref=embed_post", "mtmi_kutatási_versenyek_link2": "https://www.facebook.com/kispestideak/posts/122225214194030886?ref=embed_post", "mtmi_kutatási_versenyek_link3": "https://hipikangela.blogspot.com/2025/03/zero-waste-fashion-fenntarthatosag.html", "mtmi_kutatási_versenyek_szama": "5", "mtmi_laboratoriumok_latogatasa": "igen", "intezmenytipus_tanuloi_letszama": "450", "mtmi_ceges_eloadasok_bemutatasa": "Iskolánk rendszeresen szervez MTMI fókuszú előadásokat és workshopokat, melyek során vállalati szakemberek látogatnak el hozzánk, hogy a diákok közvetlenül ismerkedhessenek meg a természettudományos, műszaki, informatikai és matematikai pályák gyakorlati oldalával.\\n„A 3D nyomtatóktól a Rally-ig – a mérnök szakma bemutatása” című előadást Klem Kristóf, az AVL Hungary képviselője tartotta. A prezentáció során a diákok betekintést nyerhettek a mérnöki pálya sokszínűségébe, különös tekintettel az autóipari fejlesztésekre és a 3D nyomtatás alkalmazási lehetőségeire.\\nA Zero Waste Fashion projekt keretében a CNW Zrt. képviseletében Fekete István és kollégái netes szakértőként segítették a diákokat. Az előadás során félórás konzultációs blokkokban válaszoltak a tanulók kérdéseire, és gyakorlati tanácsokat adtak a weboldalkészítés technikai és tartalmi kihívásairól. A projekt célja öt fenntarthatósági fókuszú vállalkozás webes megjelenésének kialakítása volt, WordPress alapú oldalakkal, a Digitális Témahét keretében.\\nDévényi Tamás, a Richter Gedeon Nyrt. képviseletében tartott előadást, melyben bemutatta a mérnökök és technikusok szerepét a gyógyszeripari fejlesztésekben. A diákok átfogó képet kaptak a kutatás-fejlesztés, gyártástechnológia és minőségbiztosítás területeiről, valamint a Richterben zajló innovatív műszaki folyamatokról.\\nAz előadások célja, hogy élményszerűen és hitelesen mutassák be az MTMI pályák sokszínűségét, és támogassák a diákok pályaorientációját.\\n", "mtmi_faliujsag_vitrin_reszvetel": "nem", "mtmi_palyaorientacio_megvalosul": "igen", "lanyok_mtmi_reszvetel_bemutatasa": "Az iskola kiemelt figyelmet fordít arra, hogy a lányok érdeklődését felkeltse a MTMI (matematika, természettudomány, műszaki és informatikai) területek iránt. Ennek érdekében az alábbi konkrét programokat és együttműködéseket valósítottuk meg:\\n•\\t„Nem középiskolás fokon” rendezvény keretében női szakembereket hívtunk meg, akik saját pályájukról, tapasztalataikról és a MTMI területeken való érvényesülésről tartottak előadást.\\n•\\tPályaorientációs napokon rendszeresen szerepelnek női előadók, akik különböző MTMI szakmákban dolgoznak, és személyes példájukkal inspirálják a diákokat.\\n•\\tLányok Napja Fesztiválon való részvétel: diákjaink aktívan bekapcsolódnak az országos programsorozatba, ahol női MTMI szakemberekkel találkozhatnak, interaktív foglalkozásokon vehetnek részt.\\n•\\tSmartíz programban való részvétel, amely során a lányok játékos, kreatív formában ismerkedhetnek meg a matematikai és informatikai gondolkodással, a Morgan Stanley mentorainak vezetésével.\\n•\\tSzülők meghívása: különösen az MTMI területen dolgozó anyák kapnak lehetőséget arra, hogy bemutassák szakmájukat, ezzel is erősítve a személyes példamutatás szerepét.\\n•\\tSzoros együttműködés a Nők a Tudományban Egyesülettel - rendszeresen részt veszünk a szervezet által szervezett Tanári Napon, ahol tájékozódunk a legfrissebb MTMI programokról, lehetőségekről, és kapcsolatot építünk női példaképekkel, akiket később meghívunk iskolai rendezvényeinkre.\\nAz eseményekről rendszeresen beszámolunk az iskola honlapján, közösségi médiafelületein, valamint online és offline faliújságjainkon. A programok sikerességét és hatását fotókkal, valamint rövid összefoglalókkal dokumentáljuk, ezzel is erősítve a láthatóságot és az inspiráló példák terjedését.\\n", "mtmi_felelos_kapcsolattarto_neve": "Hipik Angéla", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "igen", "mtmi_tanoran_kivuli_rendezvenyek": "Intézményünk célja, hogy a tanulók számára valódi tudományos élményeket biztosítson, amelyek túlmutatnak a középszintű oktatáson. Ennek jegyében indítottuk el a „Nem középiskolás fokon” programsorozatot, melynek keretében elismert kutatókat, mérnököket és egyetemi oktatókat hívunk meg. Vendégeink személyes példáikkal, kutatási tapasztalataikkal motiválják a diákokat, különösen a fakultációs csoportokat.\\nKiemelt szakmai partnerünk az MTA Alumni program, amelynek előadói révén tanulóink első kézből hallhatnak a tudományos pályák kihívásairól, kutatási módszerekről és aktuális kérdésekről. A cél, hogy a tudomány élő, inspiráló közegként jelenjen meg a diákok életében.\\nKiemelkedő esemény volt, amikor Domokos Gábor, a Gömböc egyik feltalálója egyetemi hallgatókkal együtt látogatott el hozzánk. A diákok saját tudományos munkáikat is bemutatták, ezzel közvetlen kapcsolatot teremtve a középiskolai és felsőoktatási tudományos élet között.\\nFontos számunkra, hogy a tudományos élmények ne csak a gimnazisták számára legyenek elérhetők. Együttműködünk általános iskolákkal is, és örömmel fogadjuk a fiatalabb korosztályt természettudományos laborunkban. A 2025/26-os tanévben már elindultak az első foglalkozások.\\nA tanév második felében Tudományos börzét tervezünk, ahol a diákok saját projektjeiket mutathatják be. Emellett laborlátogatást szervezünk a BME VIK nyitott laborok délutánjára, és nyertes diákmunkák bemutatására is sor kerül.\\nKiemelkedő projekt volt a „Pí, a rejtélyes szám”, amelyben a 9. évfolyam tanulói mérésekkel igazolták a kör kerületének és átmérőjének hányadosát, történeti érdekességeket kutattak, rímeket faragtak, verset generáltak MI segítségével, majd szülinapi bulit szerveztek a pí tiszteletére.\\n", "mtmi_tanulmányi_versenyek_link1": "https://kdfg.hu/semmelweis-egeszsegverseny/", "mtmi_tanulmányi_versenyek_link2": "https://www.facebook.com/kispestideak/posts/iskol%C3%A1nk-tanul%C3%B3ja-berecz-panna-k%C3%B6z%C3%A9piskol%C3%A1sk%C3%A9nt-v%C3%A9gzett-kutat%C3%A1s%C3%A1nak-eredm%C3%A9ny%C3%A9t-e/122230507904030886/", "mtmi_tanulmányi_versenyek_link3": "https://wro.hu/wp-content/uploads/2025/06/wro_hu_2025_results.pdf", "mtmi_tanulmányi_versenyek_link4": "https://www.facebook.com/kispestideak/posts/122262556292030886?ref=embed_post", "mtmi_tanulmányi_versenyek_link5": "https://microbitverseny.eu/2025/06/02/microbit-programozasi-verseny-2025-vegeredmeny/", "mtmi_tanulmányi_versenyek_link6": "https://www.facebook.com/kispestideak/posts/122186549876030886?ref=embed_post", "mtmi_tanulmányi_versenyek_link7": "https://kdfg.hu/zero-waste-fashion-2/", "mtmi_tanulmányi_versenyek_link8": "https://www.facebook.com/kispestideak/posts/122216357690030886?ref=embed_post", "mtmi_tanulmányi_versenyek_szama": "12", "mtmi_egyeb_partnerprogramok_link1": "https://goliat.eik.bme.hu/~hartlein/latogato.html", "mtmi_egyeb_partnerprogramok_link2": "https://kdfg.hu/mta-alumni-program/", "mtmi_egyeb_partnerprogramok_link3": "https://deaklabor.kdfg.hu/", "mtmi_egyeb_partnerprogramok_link4": "https://www.facebook.com/kispestideak/posts/122237299718030886?ref=embed_post", "mtmi_egyeb_partnerprogramok_link5": "https://petrik.hu/zero-waste-fashion-digitalis-temahet-a-nagy-finale-%F0%9F%8C%8D%F0%9F%91%97/", "mtmi_egyeb_partnerprogramok_link6": "https://www.facebook.com/kispestideak/posts/122232818696030886?ref=embed_post", "mtmi_muzeumlatogatasok_bemutatasa": "Az iskola az MTMI területekhez kapcsolódó technikai és természettudományos múzeumlátogatásokat beépíti az éves MTMI tervezetbe, ezzel is támogatva a tanulók élményszerű ismeretszerzését és pályaorientációját. A program célja, hogy a diákok közvetlenül találkozzanak a tudományos és műszaki fejlődés történetével, eszközeivel és alkalmazásaival.\\nA 2025/26-os tanévben megvalósult a Bécsi Természetrajzi Múzeum (Naturhistorisches Museum) látogatása, ahol a tanulók interaktív módon ismerkedhettek meg a földtudományok, biológia és evolúció témaköreivel. Emellett szervezés alatt áll a Paksi Atomerőmű Látogatóközpont programja, amelynek plakátja és jelentkezési kérdőíve már elkészült. A látogatás célja, hogy a diákok betekintést nyerjenek az energetika, nukleáris technológia és környezettudatosság összefüggéseibe.\\nA múzeumlátogatások részét képezik az MTMI szemléletformálásnak, és az iskolai honlapon is dokumentálásra kerülnek, ezzel is erősítve a tudományos érdeklődést és a programok láthatóságát.\\n", "mtmi_rendezvenyek_reszvetel_link1": "https://hipikangela.blogspot.com/2025/10/kutatok-ejszakaja-biotechnologia.html", "programban_erintett_tanulok_szama": "450", "mtmi_diakok_kapcsolattartas_leiras": "Iskolánkban folyamatosan biztosított a kapcsolattartás az MTMI pályaválasztási lehetőségek iránt érdeklődő diákok számára. A pályaválasztásért felelős személy, az MTMI koordinátor és szakmai csapata személyesen, valamint elektronikus úton is elérhető. A 9–12. évfolyam tanulói számára rendszeres konzultációs lehetőséget biztosítunk, amely során egyéni tanácsadással, projektmentorálással, eseményajánlással és versenyfelkészítéssel támogatjuk őket.\\nA kapcsolattartás nemcsak tanórai keretek között, hanem országos és intézményi programokon keresztül is megvalósul. Diákjaink részt vesznek a Kutatók Éjszakája, a Lányok Napja Fesztivál, valamint a „Build the Future – Girls in STEM” rendezvényeken, ahol inspiráló előadások, interaktív kódolási és robotikai foglalkozások, valamint női mérnök szerepmodellek segítik a pályaválasztást. Bekapcsolódtunk a STEAM Kiválóság Programba, valamint a Fizikai Kísérletsorozatba Härtlein Károllyal az MTA Székházban. Diákjaink a Kapu Tibor űrbéli kísérleteinek megismétlésében is részt vettek, melynek oktatási részét szintén Härtlein Károly (BME) koordinálta.\\nA közeljövőben nyertes tudományos diákmunkát írt tanulóink is bemutatják eredményeiket a diáktársaiknak, ezzel is erősítve az MTMI iránti érdeklődést és a tudományos közösséghez való kapcsolódást.\\nPedagógusaink is aktívan részt vesznek a pályaorientációs támogatás fejlesztésében: jelen vagyunk a Yettel és a Nők a Tudományban Alapítvány által szervezett Tanári Napokon, valamint csatlakoztunk a Stream IT Inspirációs Hub - hoz, hogy első kézből kapjunk információkat pld. a Morgan Stanley Elemző Kft. és más szakmai partnerek diákoknak szóló projektjeiről és pályaorientációs lehetőségeiről.\\n", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyeb_tovabbkepzesi_programok": "Intézményünk pedagógusai több, a fentiekben nem említett, MTMI fókuszú szakmai programon is részt vettek, amelyek hozzájárultak az innovatív szemlélet elmélyítéséhez és a tantárgyi fejlesztésekhez.\\n•\\tTanári napok a Yettelnél: A program során a résztvevő pedagógusok betekintést nyerhettek a digitális technológiák vállalati alkalmazásába, valamint inspirációt kaptak a mobilkommunikáció és az adatbiztonság oktatásba integrálásához.\\n•\\tNők a Tudományban Egyesület szakmai programjai: Kollégáink olyan eseményeken és workshopokon vettek részt, amelyek célja a természettudományos pályák népszerűsítése, a lányok MTMI területeken való részvételének ösztönzése, valamint a nemi sztereotípiák lebontása az oktatásban.\\n•\\tLányok Napja Fesztivál: Az esemény nemcsak a diákok számára kínál inspiráló programokat, hanem a pedagógusok számára is szervez tudásmegosztó előadásokat, amelyek az MTMI területekhez kapcsolódó módszertani és szemléleti fejlesztéseket támogatják.\\n•\\tIKK Nonprofit Zrt. által szervezett képzések: Több pedagógus bekapcsolódott az IKK által kínált MTMI témájú webináriumokba és továbbképzésekbe, különösen az értékelési módszerek és a digitális eszközök tanórai alkalmazásának területén.\\nEzek a lehetőségek kiegészítik az intézményi továbbképzési programot, és hozzájárulnak ahhoz, hogy a pedagógusok naprakész, gyakorlatorientált tudással támogassák az MTMI program megvalósítását.\\n", "mtmi_egyuttmukodes_palyaorientacio": "igen", "mtmi_felelos_kapcsolattarto_email1": "hipik.angela@kdfg.info", "mtmi_felelos_kapcsolattarto_email2": "hipik.angela@gmail.com", "mtmi_otlet_esszepalyazat_reszvetel": "nem", "mtmi_tanulmányi_verseny_reszvetel": "igen", "mtmi_tovabbkepzesi_programok_link1": "https://youtu.be/7YBjATykq58?si=nt6BC7c5QXkyHANv", "mtmi_tovabbkepzesi_programok_link2": "https://youtu.be/l0xQyYWyuRA?si=SyqIt1lb8sx3VS_X", "mtmi_tovabbkepzesi_programok_link3": "https://youtu.be/SWDHfCwRPvE?si=vIzf12wDePJXpCP5", "mtmi_tovabbkepzesi_programok_link4": "https://youtu.be/9VxlaXgX-ek?si=GtaBeLA9-KLGY_sf", "mtmi_tovabbkepzesi_programok_link5": "https://www.canva.com/design/DAGxYLm5uss/bV9iR-I_UH16SP0jCs4VTA/view?utm_content=DAGxYLm5uss&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=hbb1f9748a8", "intezmenyvezeto_kapcsolattarto_neve": "Lázár András", "lanyok_mtmi_nepszerusito_bemutatasa": "Iskolánk elkötelezett az MTMI (matematika, természettudomány, műszaki és informatikai) területek népszerűsítése mellett, különös figyelmet fordítva arra, hogy a lányok számára is vonzó és elérhető legyen a tudományos pálya. Ennek érdekében minden tanévben többféle, célzott programot és szakkört kínálunk.\\nA jelenleg működő programok közül kiemelkednek:\\n•\\tRobotika szakkör – LEGO és Micro:bit alapú foglalkozások, ahol a diákok játékos formában sajátíthatják el a programozás, algoritmikus gondolkodás és mérnöki tervezés alapjait.\\n•\\tBiológia szakkör – kísérletezős, kutatásalapú foglalkozások, amelyek a természettudományos gondolkodás fejlesztését és a tudományos módszertan elsajátítását célozzák.\\n•\\tMatematika szakkör – kreatív problémamegoldás, logikai játékok és versenyfelkészítés révén segíti a lányokat a matematikai gondolkodás elmélyítésében.\\n•\\tDeák Műhely – a tavalyi tanévben indult kezdeményezés célja egy olyan közösség kialakítása, amelynek tagjai elkötelezettek a környezet- és természetvédelem, a rendszerszemléletű gondolkodás, a fenntarthatóság és a társadalmi igazságosság iránt.\\n•\\tDeák Labor – az Öveges Program (TÁMOP-3.1.3-11/1) keretében létrehozott természettudományos laboratórium, amelyet több feladatellátási hely közösen használ. A labor célja a természettudományos oktatás módszertanának és eszközrendszerének megújítása a közoktatásban. A laborban korszerű pedagógiai módszerek – mint a tanulók kísérletezésbe történő bevonása, kooperatív tanulás és tömbösített óraszervezés – valósulnak meg. Az iskola rendszeresen megnyitja kapuit az általános iskolások előtt is, lehetőséget biztosítva számukra a laboratóriumi munka kipróbálására és a természettudományos élményszerzésre.\\nEzek a tevékenységek nemcsak tudást adnak, hanem közösséget is építenek, ahol a lányok támogatást, inspirációt és lehetőséget kapnak arra, hogy bátran kibontakoztassák tudományos érdeklődésüket. Az iskola honlapján rendszeresen beszámolunk a programok eseményeiről és a diákok eredményeiről.\\n", "mtmi_kiallitoterek_megvalosul_link1": "https://padlet.com/hipikangela/nem-hagyom-nyos-megeml-kez-s-2024-j8obb0oe00za", "mtmi_kiallitoterek_megvalosul_link2": "https://padlet.com/hipikangela/zero-waste-fashion-letk-pek-cinbtt19lyes", "mtmi_kiallitoterek_megvalosul_link3": "https://padlet.com/hipikangela_kdfg/mtmi-iskola-9u6te0we6s7addwc", "mtmi_kiallitoterek_megvalosul_link4": "https://www.instagram.com/explore/locations/11075322/kispesti-deak-ferenc-gimnazium/", "mtmi_kiallitoterek_megvalosul_link5": "https://www.youtube.com/@DeakMediaTV", "mtmi_kutatási_verseny_diakok_szama": "20", "mtmi_kutatási_versenyek_bemutatasa": "Energetikai tanulmányi verseny\\nProsuli robotika verseny\\nWRO robotika verseny\\nMicro:bit robotika verseny\\nCurie Kémia Emlékverseny\\n", "mtmi_digitalis_tananyagok_megvalosul": "igen", "mtmi_felelos_kapcsolattarto_beosztas": "matematika, digitális kultúra tanár", "mtmi_kutatási_verseny_tanarok_szama": "4", "mtmi_laboratoriumok_latogatasa_link1": "https://microbitverseny.eu/2025/06/02/microbit-programozasi-verseny-2025-vegeredmeny/", "mtmi_laboratoriumok_latogatasa_link2": "https://www.facebook.com/kispestideak/posts/122216042756030886?ref=embed_post", "mtmi_laboratoriumok_latogatasa_link3": "https://www.facebook.com/kispestideak/posts/122145091334030886?ref=embed_post", "intezmenyvezeto_kapcsolattarto_email1": "aslazar@kdfg.info", "intezmenyvezeto_kapcsolattarto_email2": "kdfg@kdfg.info", "mtmi_egyeb_palyaorientacios_programok": "Iskolánkban többféle formában valósulnak meg pályaorientációs programok, amelyek célja, hogy a diákok minél szélesebb körben ismerhessék meg a továbbtanulási és szakmai lehetőségeket, különös tekintettel az MTMI területekre.\\n•\\tPályaorientációs nap: Évek óta hagyományosan megrendezésre kerül, ahol külső előadók, egyetemi képviselők, szakemberek és volt diákok tartanak interaktív előadásokat, workshopokat. A program célzottan segíti a 10–12. évfolyam tanulóit a pályaválasztásban, de az érdeklődő fiatalabb évfolyamok számára is nyitott.\\n•\\tOrszágos rendezvényekhez való csatlakozás:\\no\\tKutatók Éjszakája: Diákjaink rendszeresen részt vesznek egyetemi és kutatóintézeti programokon, ahol laborbemutatók, előadások és interaktív foglalkozások révén ismerkedhetnek meg a kutatói pálya lehetőségeivel.\\no\\tGyárak Éjszakája: Lehetőséget biztosítunk arra, hogy tanulóink ipari környezetben, működő gyártóüzemekben lássanak bele a mérnöki és technológiai munkafolyamatokba.\\no\\tEgyetemek nyílt napjai: Szervezetten támogatjuk a részvételt a felsőoktatási intézmények nyílt napjain, különösen a műszaki, természettudományos és informatikai karokon.\\no\\tLaborok délutánja: Diákcsoportjaink számára rendszeresen szervezünk látogatásokat egyetemi laborokba, például a BME VIK nyitott laborprogramjába, ahol közvetlen élményeken keresztül ismerhetik meg a kutatási és fejlesztési tevékenységeket.\\no\\tKódolás órája (Hour of Code): Az informatikai pálya iránt érdeklődő tanulók számára minden évben megrendezzük a nemzetközi kezdeményezéshez kapcsolódó programot, amely játékos formában vezeti be őket az algoritmikus gondolkodás és programozás világába.\\nEzek a programok szervesen kiegészítik az iskolai pályaorientációs stratégiát, és lehetőséget teremtenek arra, hogy a tanulók saját érdeklődésük mentén, élményszerűen kapcsolódjanak a jövőbeli szakmai irányokhoz.\\n", "mtmi_tanulmányi_verseny_diakok_szama": "38", "mtmi_tanulmányi_versenyek_bemutatasa": "Semmelweis Egyetem által 10. alkalommal meghirdetett egészségverseny 5. helyezés\\nBerecz Panna középiskolásként végzett kutatásának eredményét előadhatta a Semmelweis Egyetem Tudományos Diákkori Konferenciájának Szülészet-Nőgyógyászat kategóriájában. Az előadást a zsűri különdíjban részesítette! Absztraktját publikálta az Orvosképzés folyóiratban. A kutatás anyagát feldolgozó előadását a TUDOK (Tudományos Diákörök Országos Konferenciáján) zsűrije Egészségtudomány-farmakológia szekcióban Magyarország legjobb kilenc előadása közé választották és előadásra érdemesnek ítélték.\\nWRO Nemzeti Döntő robotika verseny. A srácok, Csuport Gergely, Csizmadia Márk és  Danóczy Réka, a Robobmission Senior kategóriában 10.helyezést értek el.\\nMicro:bit Programozási Verseny 2. helyezés\\nFővárosi Középiskolai Alkalmazói verseny 6. helyezett\\nPí a rejtélyes szám c. projekt DTH 2024 II. helyezés;\\nZero Waste Fashion projekt DTH 2025 együttműködési díj\\nCode Week 2024 Micro:bit különdíj\\n\\n\\n", "mtmi_interdiszciplinaris_projekt_link1": "https://kdfg.hu/digitalis-temahet-2024/", "mtmi_interdiszciplinaris_projekt_link2": "https://hipikangela.blogspot.com/2024/03/pi-rejtelyes-szam.html", "mtmi_interdiszciplinaris_projekt_link3": "https://atanulasjovoje.hu/a_digitalis_pedagogus_es_oktatoi_dij_dijazottjai/pi-a-rejtelyes-szam-matematika-jatekosan-", "mtmi_interdiszciplinaris_projekt_link4": "https://youtu.be/mJ_sR6e8PKY?si=zHeg3r1iR26kn7XZ", "mtmi_interdiszciplinaris_projekt_link5": "https://hipikangela.blogspot.com/2025/03/zero-waste-fashion-fenntarthatosag.html", "mtmi_interdiszciplinaris_projekt_link6": "https://petrik.hu/elindult-a-digitalis-temahet-iskolankban-ez-a-zero-waste-fashion-elso-2-napja%E2%9C%A8%F0%9F%8C%BF/", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_rendezvenyek_reszvetel_bemutatasa": "Intézményünk elkötelezett a tudományos szemléletformálás és a pályaorientáció élményalapú támogatása mellett, ezért aktívan bekapcsolódott a Kutatók Éjszakája országos programsorozatba. A rendezvény keretében tanulóink részt vettek a „A biotechnológia rejtelmei” című szakmai előadáson, amelyet Dr. Bogsch Erik, a Richter Gedeon Nyrt. biotechnológiai üzletágvezetője tartott.\\nAz előadás során a diákok átfogó képet kaptak a biotechnológia alapfogalmairól, gyakorlati alkalmazásairól és a gyógyszerfejlesztés aktuális kihívásairól. A program nemcsak ismeretbővítést szolgált, hanem motivációs szerepet is betöltött, különösen a természettudományos érdeklődésű tanulók körében.\\nA program második részében a „Óriásműszerekkel apró molekulák nyomában” című laborlátogatásra került sor, ahol a résztvevők közvetlenül megismerhették a kutatási infrastruktúrát, a molekuláris vizsgálatok eszközeit és a laboratóriumi munka mindennapi gyakorlatát. A látogatás során a kutatói pálya technológiai és emberi oldala egyaránt kézzelfoghatóvá vált.\\nA program hozzájárult a tudományos pályák iránti érdeklődés erősítéséhez, és jól illeszkedett az intézmény MTMI fókuszú pályaorientációs törekvéseihez. \\n", "mtmi_tanulmányi_verseny_tanarok_szama": "6", "intezmenyvezeto_kapcsolattarto_beosztas": "igazgató helyettes", "mtmi_interdiszciplinaris_projekt_leiras": "A Kispesti Deák Ferenc Gimnáziumban az MTMI szemlélet nemcsak tantárgyi keretek között jelenik meg, hanem komplex, interdiszciplináris projektek formájában is. A „Pí, a rejtélyes szám” című projektben a 9. évfolyam két osztálya négy csoportban dolgozva indult el a matematika „Szent Gráljának” felfedezésére. Mérésekkel igazolták a kör kerületének és átmérőjének állandó hányadosát, kutatásokat végeztek a pí történeti kultuszáról, mesterséges intelligenciával képeket, verseket generáltak, majd a Canva felületén összeállított bemutatóikat a Deák Pí Napon mutatták be. A cél az volt, hogy a digitális eszközökkel támogatott élményszerű tanulás révén a diákok kritikusan és magabiztosan használják az információs társadalom technológiáit, miközben felfedezik a matematika kapcsolatát a természettel, művészetekkel és az épített környezettel.\\nA „Zero Waste Fashion” projekt intézményünk és a Budapesti Műszaki SzC Petrik Lajos Technikum együttműködésében valósult meg. A fenntarthatóságot, kreativitást és modern technológiákat ötvöző programban diákcégek alakultak, amelyek környezettudatos háztartási termékeket fejlesztettek (öblítő, mosógél, mosószappan, fürdőbomba), valamint szőttes kiegészítőket, magbonbonokat és újrahasznosított csomagolóeszközöket készítettek. Weboldalt fejlesztettek, micro:bit kiegészítőkkel tették egyedivé kollekciójukat, amelyet a zárónapon mutattak be. A projekt erősítette a vállalkozói szemléletet és az MTMI kompetenciák gyakorlati alkalmazását, a produktumokat néma aukció keretében értékesítették.\\nEbben a tanévben ismét megrendeztük a „Nem középiskolás fokon” című eseményt, mellyel csatlakoztunk a Magyar Tudományos Akadémia Alumni Programjához. A kezdeményezés célja, hogy a középiskolás korosztály körében népszerűsítse a tudományos és kreatív gondolkodást. Neves előadók – köztük Domokos Gábor és tanítványai – idén is izgalmas témákkal várták diákjainkat, erősítve a tudomány iránti érdeklődést és motivációt.", "mtmi_palyaorientacio_megvalosulas_link1": "https://www.facebook.com/kispestideak/posts/122210294210030886?ref=embed_post", "mtmi_tovabbkepzesek_idokeret_megvalosul": "igen", "mtmi_tovabbkepzesi_programok_megvalosul": "igen", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "Intézményünkben kiemelt cél, hogy a tanulók aktív, cselekvő részesei legyenek saját tanulási folyamatuknak. Ennek érdekében a pedagógusok rendszeresen alkalmazzák a projektmódszert, a páros- és csoportmunkát, valamint a problémamegoldó és interaktív tanulási technikákat, amelyek fejlesztik a diákok együttműködési készségét, kreativitását és önállóságát.\\nAz értékelés során hangsúlyt kap a tanulói önreflexió, valamint a pedagógusok által nyújtott folyamatos, támogató visszajelzés, amely segíti a tanulók fejlődését és motivációját.\\nAz aktív tanulás ösztönzését célzó intézményi kampányok is megvalósulnak, például az idei ősszel szervezett program, amely a diákok, pedagógusok és szülők bevonására irányult. A kampány során versenyek, interaktív foglalkozások és egyéb programok kínálata segítette a tanulók érdeklődésének felkeltését az MTMI területek iránt.\\nAz iskola saját programokat hoz létre, amelyek lehetőséget adnak a tanulók kezdeményezéseinek megvalósítására, és támogatják az élményszerű tanulást. A Google Classroom rendszerben kialakított dedikált tanterem segíti a tanulók közötti együttműködést, a digitális tartalmak megosztását és a tanulási folyamat dokumentálását.\\nA tanulók személyes megszólítása is fontos szerepet kap: az osztályfőnöki órákon, valamint a pedagógus értekezleteken rendszeresen történik tájékoztatás, motiválás és közös ötletelés, amely elősegíti az aktív részvételt és a tanulói autonómia erősítését.\\nEzek a gyakorlatok hozzájárulnak ahhoz, hogy a tanulás ne csupán ismeretszerzés, hanem közösségi, kreatív és személyes fejlődési folyamat legyen.\\n", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 20 493 8183", "mtmi_kiallitoterek_megvalosul_bemutatasa": "Intézményünk kiemelt figyelmet fordít a tanulói munkák és MTMI projektek láthatóvá tételére, ezért több formában is biztosítunk bemutatkozási lehetőséget. A 3. emeleti folyosó, ahol az Öveges Labor is helyet kapott, folyamatosan működő közösségi térként szolgál az MTMI tantárgyakhoz kapcsolódó projektek számára. Itt tematikus faliújságok állnak rendelkezésre, amelyek lehetőséget adnak a tantárgyi eredmények, kreatív munkák és kutatási projektek vizuális bemutatására.\\nA tanulói munkák gyakran installációk formájában is megjelennek, így a látogatók számára élményszerűen és szemléletesen válik láthatóvá a diákok tevékenysége. Az iskola közösségi médiafelületein is rendszeresen bemutatjuk a kiemelkedő projekteket, ezzel is erősítve az MTMI területek iránti érdeklődést és elismerést.\\nAz iskola falai emellett különböző programok plakátjainak is helyet adnak, így a tanulók munkái nemcsak tantárgyi, hanem rendezvényi kontextusban is megjelennek. A Google Classroom rendszerben egy dedikált MTMI tanterem is rendelkezésre áll, amely digitális kiállítótérként szolgál a tanulói anyagok megosztására és archiválására.\\nEzek a fizikai és digitális bemutatkozási formák hozzájárulnak a tanulói önbizalom növeléséhez, a tudományos érdeklődés elmélyítéséhez, és az MTMI program közösségi beágyazottságának erősítéséhez.\\n", "mtmi_palyaorientacio_megvalosulas_leiras": "A pályaorientációs nap programjai évfolyamonként differenciáltan valósulnak meg, igazodva a tanulók életkorához és érdeklődési köréhez. A bejövő nyelvi osztályok és a média tagozatosok önismereti tréningen vesznek részt, amely segíti őket saját képességeik és motivációik feltérképezésében. A 9. évfolyam tanulói külső helyszínen, ebben az évben a Yettel Székházában kapnak pályaorientációs foglalkozásokat, ahol interaktív formában ismerkedhetnek meg a munka világával. A 10. évfolyam számára fakultációs tájékoztatást tartunk, hogy megalapozott döntést hozhassanak a továbbtanulás irányairól. A 11. és 12. évfolyam tanulói meghívott szakemberek előadásain keresztül kapnak betekintést különböző hivatásokba, ezzel is támogatva őket a pályaválasztásban. Az előadók különböző tudományterületekhez kapcsolódó szakmákat, valamint hazai és nemzetközi egyetemek oktatási rendszerét mutatják be – kiemelten az MTMI (matematika, természettudomány, műszaki és informatikai) területeket –, hogy a diákok szélesebb perspektívából tekinthessenek a jövőbeli lehetőségeikre.", "lanyoknak_szolo_mtmi_programok_bemutatasa": "IIskolánk büszkén számol be arról, hogy a Nők a Tudományban Egyesület Smartíz programjába idén ismét két 10. évfolyamos diáklányunk jutott be a 22 kiválasztott középiskolás közé – akárcsak két évvel ezelőtt. A program célja, hogy élményalapú, kreatív módon hozza közelebb a matematikát és az informatikát a lányokhoz.\\nA Smartíz heti másfél órás, ingyenes foglalkozásain játékos, felfedezésalapú módszerekkel mutatják meg, hogyan válhat a matek és az informatika a mindennapok hasznos eszközévé – és hogyan segíthet a pályaválasztásban.\\nA 10.C és 11.B osztály lányai jövő héten részt vesznek a Lányok Napja Fesztiválon, ahol az ország leginspirálóbb vállalatai, kutatóintézetei és egyetemei nyitják meg kapuikat a tudomány iránt érdeklődő fiatalok előtt. Egy nap, amikor a kémcsövek, robotok, precíziós műszerek és titokzatos laborok világa kézzelfoghatóvá válik – és a jövő hirtelen sokkal közelebb kerül.\\nA Nem középiskolás fokon egy helyi rendezvény, amely lehetőséget biztosít diákjainknak arra, hogy saját kutatásaikat, projektjeiket és eredményeiket diáktársaik előtt mutassák be. A program különlegessége, hogy a résztvevő diáklányok olyan tudományos témákban végeznek kutatómunkát, amelyek túlmutatnak a középiskolai tananyag keretein – valódi kutatói szemlélettel közelítve a választott kérdéskörhöz.\\nAz idei évben Berecz Panna mutatja be kutatásának eredményeit, amely középiskolásként készült, és absztraktja megjelent az Orvosképzés folyóiratban. Előadását a TUDOK (Tudományos Diákörök Országos Konferenciája) zsűrije az Egészségtudomány–farmakológia szekcióban Magyarország legjobb kilenc előadása közé választotta.\\nTovábbi lehetőségek a közeljövőben\\nSteam Powered Program – ahol a tudomány, technológia, mérnöki tudományok, művészet és matematika találkoznak kreatív, interdiszciplináris projektekben.\\nOrszágos Középiskolai Diákprojektverseny – ahol diákcsapatok saját ötleteik megvalósításával teremtenek értéket a közösségük számára. ", "mtmi_egyuttmukodes_palyaorientacio_leiras": "A tanév során rendszeresen szervezünk céglátogatásokat, valamint támogatjuk a tanulók részvételét MTMI-fókuszú karrierbemutatókon, egyetemi nyílt napokon, nyílt laborok délutánján, szakmai táborokon és nyári gyakorlatokon. Ezek a programok lehetőséget teremtenek arra, hogy diákjaink közvetlen tapasztalatot szerezzenek a munka világáról, és személyes kapcsolatba kerüljenek a pályaválasztásban érdekelt szereplőkkel – vállalatokkal, kamarákkal, felsőoktatási intézményekkel, alumnikkal és szülőkkel.\\nKiemelkedő példa volt, amikor két osztályunk látogatást tett a Bosch-nál, ahol a tanulók testközelből ismerkedhettek meg a műszaki pályák gyakorlati oldalával, valamint a vállalati működés különböző területeivel.\\nSzintén emlékezetes esemény volt a tavalyi tanévben, amikor Domokos Gábor, a BME professzora, valamint tanítványai – Nagy Klaudia és Almádi Gergő építészmérnök hallgatók – tartottak előadást a matematika iránt érdeklődő diákjainknak. A poliéderek és falak különleges geometriai tulajdonságain keresztül mutatták be, hogyan kapcsolódik a tudományos gondolkodás a mérnöki gyakorlatokhoz, ezzel is erősítve az MTMI területek iránti érdeklődést.\\nKövetkező kiemelt eseményünk október 20-án lesz, a Nem középiskolás fokon sorozat keretében. Ezen a napon Almádi Gergő tart előadást A talpraállás geometriájáról. Gergő idén védte meg diplomamunkáját a BME Építészmérnöki Karán, amelynek központi eleme a Bille nevű szerkezet. A bemutatás napján a világhírű Quanta Magazine vezércikkben számolt be a felfedezésről.\\nDomokos Gábor akadémikus, a BME kutatóprofesszora, ugyanezen a napon a természetes mintázatokról tart előadást, bemutatva a tudomány és mérnöki kreativitás lenyűgöző kapcsolatát.\\nTovábbi témák lesznek még Mit csinál egy űrmérnök?, Gyermek szívsebészet szívvel-lélekkel, Infláció hatása a családra, Hegyi mentés, Űrutazás pszichológiája, Molekuláris bűnjelek.\\n", "mtmi_laboratoriumok_latogatasa_bemutatasa": "Iskolánk részt vesz a Budapesti Műszaki és Gazdaságtudományi Egyetem (BME) Villamosmérnöki és Informatikai Karának által szervezett Nyílt Laborok Délutánja programon. A rendezvény célja, hogy középiskolás diákok közvetlen tapasztalatot szerezzenek a műszaki és informatikai kutatások világáról, és betekintést nyerjenek az egyetemi laboratóriumok működésébe.\\nA program során a tanulók előre meghatározott beosztás szerint, csoportosan látogatnak meg négy különböző labort, ahol megismerkedhetnek a legmodernebb technológiákkal, kutatási eszközökkel és fejlesztési irányokkal. A látogatás hozzájárul a pályaorientációhoz, a tudományos érdeklődés elmélyítéséhez, és élményszerű módon hozza közelebb a diákokat az MTMI területekhez.\\nLaborlátogatásra versenyek alkalmával is sor kerül. Az ELTE Micro:bit versenyét egyetemi bemutatkozással kötötték össze, a verseny az ELTE egyik laborjában zajlott, így a résztvevők közvetlenül ismerkedhettek meg az egyetemi kutatási környezettel. Az Óbudai Egyetem „Kódolás órája” programja szintén lehetőséget biztosít laborlátogatásra: a középiskolás diákok játékos feladatokon keresztül ismerkednek a programozás alapjaival, miközben megtekinthetik az egyetem informatikai és műszaki laborjait. \\n", "intezmenyvezeto_kapcsolattarto_telefonszam1": "+36 1 347 9040", "mtmi_egyeb_palyaorientacios_programok_link1": "https://www.facebook.com/kispestideak/posts/122225850560030886?ref=embed_post", "mtmi_egyeb_palyaorientacios_programok_link2": "https://www.facebook.com/kispestideak/posts/122153243084030886?ref=embed_post", "mtmi_egyeb_palyaorientacios_programok_link3": "https://kdfg.hu/mta-alumni-program/", "mtmi_egyeb_palyaorientacios_programok_link4": "https://www.facebook.com/kispestideak/posts/122225764586030886?ref=embed_post", "mtmi_digitalis_eszkozok_megvalosul_bemutatasa": "Intézményünkben a digitális eszközök és módszerek alkalmazása szerves része az MTMI tantárgyak oktatásának. A pedagógusok rendszeresen használják az interaktív táblákat, tanulói laptopokat, valamint olyan platformokat, mint a GeoGebra, PhET, Tinkercad, Micro:bit, Canva és Padlet.\\nA tanórákon kiemelt szerepet kapnak a vizuális és algoritmikus gondolkodást fejlesztő digitális eszközök, a tanulói visszajelzést támogató alkalmazások (pl. Kahoot, Mentimeter, Wooclap, Redmenta), valamint a tanulásmenedzsment rendszerek (pl. Google Classroom), amelyek lehetővé teszik a differenciált hozzáférést, a tanulási folyamat nyomon követését, és támogatják a pedagógusok közötti digitális tartalommegosztást is.\\nA szemléltetést és az elmélyítést YouTube és Zanza.tv videók segítik, emellett egyre több pedagógus alkalmaz AI-alapú oktatástámogatást, például a Magic School AI-t feladatgenerálásra, differenciálásra és vizuális tartalomfejlesztésre.\\nA pedagógusok aktívan részt vesznek tudásmegosztó szakmai eseményeken, mint a POK Pedagógiai Napok, a Code Week és a Digitális Témahét (DTH) keretében szervezett webináriumok. Többen előadóként is közreműködnek ezeken a rendezvényeken, saját jó gyakorlataik bemutatásával.\\nAz intézmény támogatja az egymás óráinak látogatását, amely lehetőséget teremt a módszertani inspirációra és a digitális eszközök pedagógiai alkalmazásának közvetlen megfigyelésére.\\nA pedagógusok szakmai fejlődését nemzetközi szinten is támogatjuk: az Erasmus+ projekt keretében kollégáink külföldi intézményekben ismerkedhetnek meg innovatív oktatási gyakorlatokkal, különösen a digitális pedagógia, a STEAM szemlélet és a fenntarthatóság területén. Az itt szerzett tapasztalatok beépülnek az intézményi gyakorlatba, gazdagítva az MTMI program megvalósítását.", "mtmi_digitalis_tananyagok_megvalosul_bemutatasa": "Intézményünkben az MTMI program megvalósítását folyamatos belső konzultációk kísérik, amelyek során a pedagógusok közösen értékelik a tapasztalatokat, visszajelzéseket, és megosztják egymással a fejlesztési lehetőségeket. Az intézményen belül működő MTMI munkacsoport főként az őszi időszakban találkozik rendszeresen, amikor a program új szakaszai indulnak. Ezeken az alkalmakon ötletelés, tervezés és a pedagógusok számára elérhető továbbképzési lehetőségek megosztása történik, amely elősegíti a szakmai fejlődést és a program eredményeinek tudatos nyomon követését.\\nIskolánk aktívan részt vesz az MTMI iskolahálózat szakmai közösségi életében, rendszeresen képviseltetjük magunkat az országos találkozókon, ahol lehetőség nyílik a tapasztalatok megosztására, jó gyakorlatok megismerésére és a program hatásainak közös értékelésére.\\nTagjai vagyunk a STEAM Inspirációs HUB szakmai közösségnek is, amely együttműködési platformként támogatja az innovatív pedagógiai szemlélet elmélyítését és a módszertani fejlődést. A tantestület tagjai rendszeresen részt vesznek webináriumokon, szakmai műhelyeken, valamint olyan országos programokban, mint a Digitális Témahét (DTH) és a Code Week, amelyek keretében nemcsak új inspirációkat szereznek, hanem saját tapasztalataikat is megosztják.\\nEzek a konzultációs és együttműködési formák hozzájárulnak ahhoz, hogy az MTMI program megvalósítása reflektív, közösségileg támogatott és folyamatosan fejlődő módon történjen.\\n", "mtmi_korszeru_felszereltseg_megvalosul_bemutatasa": "Intézményünkben a digitális eszközpark fejlesztése folyamatos, célja az MTMI tantárgyak élményszerű és korszerű oktatásának támogatása. Minden tanteremben rendelkezésre áll kivetítő, egy teremben pedig LED kijelző segíti a vizuális szemléltetést. Két tanteremben tanulói laptopok állnak rendelkezésre, amelyekhez laptop töltő és tároló szekrény is tartozik a biztonságos és hatékony használat érdekében.\\nAz Öveges Laborban szintén laptopok támogatják a kísérletező, interaktív tanulást. Digitális eszköztárunk 3D nyomtatókkal és Micro:bit eszközökkel is bővült, melyeket részben pályázati forrásból, részben a Code Week és a Digitális Témahét keretében elnyert támogatások révén szereztünk be.\\nA digitális infrastruktúra fejlesztése hozzájárul ahhoz, hogy a tanulók korszerű eszközökkel, motiváló környezetben sajátíthassák el az MTMI területekhez kapcsolódó ismereteket.", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul": "igen", "mtmi_tovabbkepzesek_idokeret_megvalosul_bemutatasa": "Intézményünkben az MTMI program megvalósítását folyamatos belső konzultációk kísérik, amelyek során a pedagógusok közösen értékelik a tapasztalatokat, visszajelzéseket, és megosztják egymással a fejlesztési lehetőségeket. Az intézményen belül működő MTMI munkacsoport főként az őszi időszakban találkozik rendszeresen, amikor a program új szakaszai indulnak. Ezeken az alkalmakon ötletelés, tervezés és a pedagógusok számára elérhető továbbképzési lehetőségek megosztása történik, amely elősegíti a szakmai fejlődést és a program eredményeinek tudatos nyomon követését.\\nIskolánk aktívan részt vesz az MTMI iskolahálózat szakmai közösségi életében, rendszeresen képviseltetjük magunkat az országos találkozókon, ahol lehetőség nyílik a tapasztalatok megosztására, jó gyakorlatok megismerésére és a program hatásainak közös értékelésére.\\nTagjai vagyunk a STEAM Inspirációs HUB szakmai közösségnek is, amely együttműködési platformként támogatja az innovatív pedagógiai szemlélet elmélyítését és a módszertani fejlődést. A tantestület tagjai rendszeresen részt vesznek webináriumokon, szakmai műhelyeken, valamint olyan országos programokban, mint a Digitális Témahét (DTH) és a Code Week, amelyek keretében nemcsak új inspirációkat szereznek, hanem saját tapasztalataikat is megosztják.\\nEzek a konzultációs és együttműködési formák hozzájárulnak ahhoz, hogy az MTMI program megvalósítása reflektív, közösségileg támogatott és folyamatosan fejlődő módon történjen.\\n", "mtmi_tovabbkepzesi_programok_megvalosul_bemutatasa": "Intézményünk elkötelezett a pedagógusok szakmai fejlődésének támogatása mellett, különösen az MTMI területeken. A tantestület tagjai rendszeresen részt vesznek iskolán belüli és regionális továbbképzéseken, amelyek az MTMI szemlélet elmélyítését, a digitális eszközök pedagógiai alkalmazását és a természettudományos gondolkodás fejlesztését célozzák.\\nAz iskolában belső műhelymunkák és tapasztalatmegosztó alkalmak is megvalósulnak, ahol a kollégák bemutatják saját jó gyakorlataikat, kipróbált módszereiket, valamint az MTMI programhoz kapcsolódó tanórai megoldásaikat. Több pedagógus előadóként is közreműködik témahetekhez kötődő szakmai napokon, például a Digitális Témahét (DTH), a Code Week, a POK Pedagógiai Napok, valamint a High Tech Suli konferencia keretében szervezett eseményeken, ahol intézményi szinten is bemutatásra kerülnek az innovatív oktatási gyakorlatok.\\n2023 októberében egyik kollégánk előadóként vett részt az IKK Nonprofit Zrt. által szervezett webinárium-sorozatban, amely az értékelési módszerekre, különösen az online értékelési lehetőségekre fókuszált. A megszerzett tapasztalatokat azóta is beépítjük a tanórai gyakorlatba és a belső tudásmegosztásba.\\nA továbbképzési lehetőségek megosztása az intézményi MTMI munkacsoport találkozóin történik, ahol a pedagógusok közösen választják ki azokat a programokat, amelyek leginkább illeszkednek az intézményi célokhoz és a tantárgyi fejlesztésekhez.\\nEzek a formák hozzájárulnak ahhoz, hogy az MTMI program megvalósítása szakmailag megalapozott, innovatív és közösségileg támogatott módon történjen.\\n\\n\\n", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul": "igen", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul_bemutatasa": "Intézményünkben az MTMI tantárgyakat tanító pedagógusok egyéni teljesítményértékelési célkitűzéseiben is megjelennek az MTMI programhoz kapcsolódó fejlesztési irányok. A MTMI munkacsoport tagjai egyéni célként jelölték meg az MTMI terület népszerűsítését, a program megvalósításának támogatását, valamint az innovatív pedagógiai gyakorlatok kidolgozását.\\n\\nTöbb kolléga célként határozta meg a pályázatokban való aktív részvételt, azok előkészítését és lebonyolítását, illetve az MTMI programhoz kapcsolódó projektekben való közreműködést. Az egyéni célok között szerepel továbbá a digitális eszközök tudatos alkalmazása, a tanulói aktivitás növelése, valamint a tudásmegosztás intézményi szinten.\\n\\nEzek a célkitűzések nemcsak az egyéni fejlődést szolgálják, hanem hozzájárulnak az intézményi MTMI program eredményes és fenntartható megvalósításához is.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul_bemutatasa": "Intézményünk kiemelten támogatja a pedagógusok szakmai fejlődését, különösen az MTMI területekhez kapcsolódó továbbképzések esetében. Az éves továbbképzési terv összeállításakor figyelembe vesszük a Nemzeti Közszolgálati Egyetem és az Oktatási Hivatal által kínált MTMI témájú képzéseket, és ösztönözzük a kollégákat ezekben való részvételre.\\nA részvétel nemcsak egyéni fejlődést szolgál, hanem intézményi szinten is hozzájárul az MTMI program megvalósításához. A képzéseken szerzett ismereteket a pedagógusok beépítik a tanórai gyakorlatba, megosztják az intézményi munkacsoportokban, és alkalmazzák a digitális eszközök, projektmódszerek, valamint a természettudományos szemlélet fejlesztésében.\\nA vezetőség támogatja a részvételt mind időkeret, mind adminisztratív háttér biztosításával, és a képzéseken való részvételről szóló beszámolók, reflexiók beépülnek az intézményi tudásmegosztás rendszerébe. Ezáltal a továbbképzések nemcsak egyéni, hanem közösségi szinten is erősítik az MTMI szemléletet."}	2025-09-05 17:56:28.572121	2026-03-05 22:23:14.597622	1	e1176e03-d511-49bb-82ac-86d365e266e8_MTMI_kepekben_Deak_palyazat.pdf	24968a6a-456c-45e4-b66e-fffcd0463f00
2ca4b3f4-74d4-4dfc-956b-86329d8425ca	{"iskola_cime": "1204 Budapest Ady Endre utca 142.", "iskolatipus": ["gimnazium"], "gdpr_consent": ["on"], "szulo_bevonas": "megvalosul", "mtmi_koncepcio": "reszben", "telepulesforma": "fovaros", "szulo_egyeztetes": "megvalosul", "mtmi_csapat_link1": "https://www.klgbp.hu/", "mtmi_csapat_link2": "https://sites.google.com/dt.klgbp.hu/mtmi/f%C5%91oldal", "mtmi_projektnapok": "Codeweek\\n\\nPénzhét, digitális témahét, fenntarthatósági témahét – idén is szeretnék csatlakozni (Finna Imola). Tavaly mindhármon részt vettünk.\\n\\nKutatók Éjszakája: évek óta rendszeresen részt vesznek diákcsoportok tanárokkal különböző egyetemi, laboratóriumi, illetve céges látogatásokon ezen alkalomkor. \\n\\nPályaorientációs Projektnap MTMI fókuszú előadásai, egyetemek előadásai", "pedprog_mtmi_link1": "https://www.klgbp.hu/media/2024-2025/Dokumentumok/PP_2005_01.pdf", "szulo_kommunikacio": "megvalosul", "iskola_honlap_link1": "https://www.klgbp.hu/", "mtmi_ceglatogatasok": "igen", "mtmi_csapat_letszam": "8", "palyazo_iskola_neve": "Budapest XX. Kerületi Kossuth Lajos Gimnázium", "pedprog_mtmi_leiras": "12-13. oldal összefoglalása:\\nIskolánk A osztályos tanulóit érinti ez a változás, mely már három éve működőképes és a tendencia azt mutatja, hogy egyre több diák választja a \\"reál\\"-t. Először 11 diákkal kezdtünk, ez a következő évben és utána 20 körülire nőtt, a jelenlegi 11.A-sok pedig -an vannak jelen a \\"reál\\" órákon. \\nItt 11.-ben kapnak pluszban egy matematika órát, ahol emelt szintű tananyaggal foglalkoznak, és az \\"Arduinos\\" órát, aminek a koncepciója egy-egy továbbképzésen felbuzdulva jött létre, szerettünk volna egy olyan interdiszciplináris képzést a diákoknak, ahol mind digitális kultúra (programozás), mind természettudományos szemléletüket fejlesztjük és segítjük őket az ilyen irányú pályaválasztásban. \\nEz persze magával vonz egy infrastrukturális fejlesztést, amelyhez az erőforrásaink végesek.\\n\\n12.-ben ez a tárgy két matematika órára módosul, ekkor az egyik foglalkozáson továbbra is emelt szintű feladatokat oldanak meg, a másikon pedig alkalmazott matematikát tanulnak, ahol pénzügyi, gazdasági ismereteket dolgoznak fel, s létrehozzák egy vállalkozás projekttervét, majd egymásnak előadják ötleteiket és reflektálnak is rá.\\n\\nAz 52. oldalon olvasható az egészségnevelés és környezeti nevelés is fontos szerepet játszik iskolánkban. ", "mtmi_ceges_eloadasok": "igen", "mtmi_csapat_tag1_nev": "Csizmadia-Csapp Orsolya", "mtmi_csapat_tag2_nev": "Némethyné Mihályi Mária", "mtmi_csapat_tag3_nev": "Finna Imola", "mtmi_csapat_tag4_nev": "Cselényi Luca", "mtmi_csapat_tag5_nev": "Antalics Petra", "mtmi_csapat_tag6_nev": "Debnár János", "mtmi_csapat_tag7_nev": "Kirchner Balázs", "mtmi_csapat_tag8_nev": "Tóth Fruzsina", "mtmi_koncepcio_link1": "https://www.klgbp.hu/", "mtmi_koncepcio_link2": "https://sites.google.com/dt.klgbp.hu/mtmi/f%C5%91oldal", "mtmi_szakkorok_szama": "7", "mtmi_szulo_kepviselo": "nem", "mtmi_alumni_programok": "nem", "mtmi_csapat_tag1_szak": ["matematika", "fizika"], "mtmi_csapat_tag2_szak": ["matematika"], "mtmi_csapat_tag3_szak": ["matematika"], "mtmi_csapat_tag4_szak": ["matematika", "digitalis_kultura"], "mtmi_csapat_tag5_szak": ["digitalis_kultura"], "mtmi_csapat_tag6_szak": ["kemia", "biologia"], "mtmi_csapat_tag7_szak": ["matematika", "fizika"], "mtmi_csapat_tag8_szak": ["foldrajz", "egyeb"], "mtmi_koncepcio_leiras": "Az idei Kossuth-napok témája: Magyar feltalálók és tudósok. Az idei diáknapunk alkalmával magyar tudósok előtt tisztelgünk azzal, hogy minden osztály feldolgozza a témát, melyben az MTMI csapat aktívan segíteni fog az osztályoknak. \\n\\nEzen felül a 11.A osztály Arduino segítségével tanul programozni, ez egy interdiszciplináris projekt egész tanévben, hiszen Csizmadia-Csapp Orsolya vezetésével ötvözik a digitális kultúra és természettudományok (főként fizika) világát, megtanulják “kicsiben”, hogy zajlik egy mérnök munkája. \\n\\nAhogy a Pedagógiai Programunkban is szerepel az egészségnevelés és környezeti nevelés időről időre visszatérő téma mind biológiaórán, mind osztályfőnöki órákon, ehhez hatalmas segítséget kapunk iskolánk pszichológusától és az iskola szociális segítőjétől, voltak már nálunk a SOTE-ról is egészséges étkezéssel kapcsolatos felmérés miatt, illetve tavaly hallgathatott az egyik osztály előadást az evészavarokról. \\n\\nA bővebb koncepciót és közös célokat azokon kívül, amit felsoroltam a pályázatban az MTMI Iskola-Budapest XX. Kerületi Kossuth Lajos Gimnázium honlapjának főoldalán összegeztük.  ", "pedprog_mtmi_tartalom": "igen", "szulo_palyaorientacio": "megvalosul", "mtmi_fakultaciok_szama": "12", "mtmi_muzeumlatogatasok": "nem", "mtmi_nyilt_napok_link1": "https://www.klgbp.hu/", "mtmi_nyilt_napok_link2": "https://sites.google.com/dt.klgbp.hu/mtmi/f%C5%91oldal", "iskola_tanuloi_letszama": "440", "mtmi_szakkor_tantargyak": ["matematika", "fizika", "kemia", "biologia", "digitalis_kultura"], "mtmi_szakmak_bemutatasa": "igen", "szulo_egyeztetes_szoveg": "Jelenleg még nem rendelkezünk szülői felelőssel, azoban a Szülői Munkaközösség (SzMK) elnöke mindenben támogatja a munkánkat, így a későbbiekben tervezzük ebbe őt és a szülőket is bevonni. \\nAz Igazgató Úr évente legalább kétszer (a szülői értekezletek és a fogadóórák alkalmával; lásd: Tanév rendje [https://www.klgbp.hu/A-tanev-rendje.html]) tart SzMK megbeszélést, ahol a fontos iskolai dolgokat vitatják meg a szülőkkel, itt később igyekszünk hangsúlyt fektetni majd az iskola MTMI céljaira is.  \\nA honlapon/Facebook-oldalon történő kommunikációval, információmegosztással nincs probléma a gimnáziumban. ", "iskola_mukodo_alapitvany": "igen", "lanyok_mtmi_nepszerusito": "igen", "mtmi_egyetemi_gyakorlatok": "igen", "mtmi_szakkor_diakok_szama": "103", "mtmi_szakkorok_bemutatasa": "Kémia tehetésggondozás 11. és 12. évfolyam\\nBiológia tehetséggondozás 11. és 12. évfolyam\\n\\nA kémia és biológia szakkörökön Debnár János szervezésében emelt szintű érettségi feladatokat, témaköröket dolgoznak fel, elmélyítik, kiegészítik a meglévő tudást heti 1-1 plusz órában. \\n\\nMatematika érettségi tréning (12. évfolyam)\\n\\nAz érettségi tréningen az írásbeli érettségiig Némethy Tanárnővel emelt szintű feladatokat beszélnek meg, kiegészítik az alapórai és fakultációs tudást, elméletet is. Az írásbeli érettségik lezajlása után együtt készülnek az iskolában a szóbeli érettségire. \\n\\n\\nFizika tehetséggondozás (9-10.évfolyam)\\nFizika versenyfeladatokat beszélnek meg Kirchner Tanárúrral az érdeklődők, terveik szerint idén több fizikaversenyen szeretnének indulni a német nyelvű fizikaverseny és a megszokott Vermes Miklós Fizikaversenyen való induláson kívül. \\n\\nMicrobit szakkör (inkább kicsik, de vegyesen bárki mehet)\\n\\nMegtanulnak microbit segítségével programozni, különböző projektek mentén, készítettek például fizikatanár bevonásával okoshàzat is.", "szulo_munkakoz_ismertetes": "nem", "mtmi_szakkor_tanarok_szama": "4", "iskola_mtmi_tanari_letszama": "6-9", "lanyok_mtmi_reszvetel_link1": "https://klgbp.hu", "mtmi_diakok_kapcsolattartas": "igen", "mtmi_kapcsolatok_bemutatasa": "Rendszeres céglátogatások:\\n\\nOTP Fáy Alapítvány - minden évben legalább 1-2 osztály ellátogat az alapítványhoz Finna Imola Tanárnő szervezésében. Szeretnénk őket idővel elhívni a Pályaorientációs Napunkra is, illetve utolsó napi projektnap alkalmával tavaly és tavalyelőtt több osztály is ellátogatott hozzájuk. \\n\\nRégen rendszeres volt, idén megpróbáljuk újra rendszeressé tenni/beindítani a hagyományt: Paksi Atomerőmű \\n\\nPesterzsébeti szennyvíztisztító - a 11.-es természettudományos tantárgy keretében az osztályok tavaly és tavalyelőtt ellátogattak ide. Idén is tervezik. \\n\\nKözösségi szolgálati partnerünk a Svábhegyi csillagvizsgáló, több diák is el szokott hozzájuk látogatni közösségi szolgálati órákat végezni. \\n\\nSzemétszedés a Kiserdőben - tavaly és tavalyelőtt Finna Imola Tanárnő szervezésében Pesterzsébeten a Kiserdőben szemetet szedett a 11.A osztály, melyet nagyon élveztek, így jövőre is részt fognak venni rajta. ", "mtmi_online_palyaorientacio": "igen", "mtmi_rendezvenyek_reszvetel": "igen", "lanyok_mtmi_kiemelt_figyelem": "igen", "mtmi_csapat_tag1_tevekenyseg": "Jelenleg végzős osztályfőnökként vagyok az osztályfőnöki munkaközösség vezetője, matematika-fizikatanárként. 12.-es fizika fakultáció mellett Némethyné Mihályi Máriával ketten tartjuk az iskolában a német nyelvű matematika órákat a kéttannyelvű (C) osztályokban. Emellett immáron negyedik éve a 11.A osztály reál tagozatos csoportjának tartom az órák egyik részét, melyen Arduino segítségével tanulnak a diákok programozni illetve folytatnak fizika méréseket.\\nNémet nyelvű matematika-és fizikaversenyekre is készítünk fel diákokat, illetve aktívan részt veszek (évente két továbbképzés és versenyek szervezésében való segédkezés) a DePhyMa munkájában.", "mtmi_csapat_tag2_tevekenyseg": "Az iskolánk egyik igazgatóhelyettese, aki jelenleg német nyelvű matematika órákat tart a kéttannyelvű osztályokban, emellett szervező a DePhyMa csoportban, szervezi a német nyelvű matematikaversenyeket. A végzős fakultációk kiegészítő szakköreként érettségi tréninget tart a diákoknak. Az írásbeli érettségiig emelt szintű matematikafeladatokat oldanak, beszélnek meg az órán, az írásbeli érettségik után pedig a tételek megbeszélésével, majd pórbafeleléssel gyakorolnak a szóbeli érettségire.\\nAz Éjszaka az Iskolában rendezvényen a Puzzle Szoba házigazdája.", "mtmi_csapat_tag3_tevekenyseg": "Gimnáziumunk egyik matematikatanára, a reál munkaközösség vezetője. Az OTP Fáy Alapítvány és az iskola kapcsolattartója, aki minden tanévben több osztályt elvisz az alapítványhoz különféle programokra. A 11. osztályos reál tagozatosok matematika óráit ő tartja, itt emelt szintű matematika feladatokat oldanak meg a gyerekekkel. Idén Fáy alapítványos projektnappal tervezi bővíteni ezt az órát. 12.-ben mindkét órát ő tartja a “reálosoknak”, az egyik óra szintén emelt szintű matematikafeladatok megoldása, a másik viszont pénzügyi matematika, ahol miután a gyerekek megismerkednek a pénzügyi alapokkal saját vállalkozási tervet gyártanak és dolgoznak ki, bemutatják egymásnak és reflektálnak is egymás projektötleteire. ", "mtmi_csapat_tag4_tevekenyseg": "Cselényi Luca matematikát és digitális kultúrát tanít gimnáziumunkban. Aktívan részt vesz a matematika-illetve digitális kultúra házi versenyek szervezésében és lebonyolításában. Minden tanévben örömmel irányítja az Éjszaka az Iskolában rendezvényen a matekos munkacsoport által készített szabaulószobát. Idén a diákok által készített honlapok egyik fő zsűrije. Az iskola rendszergazdájával szorosan együttműködve felelős az iskola informatikai infrastruktúrájáért, tavaly elkezdték (s idén is folytatják) a fizika, biológia-kémia, informatika szaktantermek digitális fejlesztését, illetve az egész iskola megfelelő internetelláttásért is hálásak vagyunk nekik. Ők végzik (rendszergazda, Cselényi Luca és Antalics Petra) az iskolai számítógépek telepítését, karbantartását. Luca a PISA felmérés iskolai koordinátora.", "mtmi_csapat_tag5_tevekenyseg": "Antalics Petra Tanárnő részfoglalkozású az iskolánkban, a fő munkahelye az EvoSoft cég, mellyel ennek köszönhetően aktív kapcsolatot ápol gimnáziumunk, voltak már itt például Kutatók Éjszakáján is gyerekek, illetve minden Pályaorientációs Napon örömmel mesél nekünk a digitális kultúra világáról. Ő felelős a micro:bit szakkörrért, vele kooperálva készítettünk például okosházat, és tanulnak meg a diákok robotokat programozni. Immáron rendszeresen fő szervezője a CodeWeek-nek.", "mtmi_csapat_tag6_tevekenyseg": "Debnár János az iskola egyik biológia-kémiatanára, az összes fakultációt ő tartja jelenleg a gimnáziumban, melyeket mindkét tantárgyból mindkét évfolyamon plusz 1-1 óra tehetséggondozó szakkörrel is kiegészít évek óta, ahol elmélyítik, rendszerezik az emelt szintű tananyagot, melyhez saját honlapját is előszeretettel használja. A szünetekben (még nyári szünetben is) tart külön foglalkozást a gimnázium érdeklődő diákjainak, ezzel is elősegítve a sikeres érettségiket. A tanórákon és szakkörökön kívül kirándulásra is viszi a diákokat, tavaly a szennyvíztisztítóban és az állatkertben volt a diákokkal.\\nDebnár János vezetésével idén Semmelweis versenyen is fognak indulni a 11.A és 11.B osztályos tanulók.", "mtmi_csapat_tag7_tevekenyseg": "Gimnáziumunk egyik matematika-fizikatanára, iskolánk KDK felelőse, aki jelenleg az alapórái mellett a 11.-es fizikafakultáció tanára, illetve tehetséggondozó szakkört is tart 9-10. évfolyamos érdeklődő diákoknak, ahol emelt szintű és versenyfeladatokat oldanak meg, célja, hogy minél változatosabb versenyeken vegyenek részt a tehetséges diákok. Idén a Vermes Miklós Fizikaversenyen szeretnénk csapatokat indítani Balázzsal, ahol iskolánk tavaly második helyezést ért el. Balázs felelős az Éjszaka az Iskolában rendezvényen a sakkversenyért, imád sakkozni és volt rá példa, hogy egész éjszaka (egészen reggel 6-ig) sakkjátszmák voltak az iskola aulájában ezen a napon. \\n\\nTavaly indultak a diákok vezetésével a Nemzetközi Vízdíj verseny, idén is terveink között szerepel ennek folytatása. ", "mtmi_csapat_tag8_tevekenyseg": "Tóth Fruzsina Tanárnő iskolánk egyetlen földrajz-rajztanára, ő tartja tehát az összes 11-12. fakultációt, diákjait sikerrel felkészíti az érettségikre. Tavaly is és tervei szerint idén is több csapatot indított a Jakucs Földrajz Versenyen, tavaly voltak az egyik osztállyal a Köszolgálati Egyetem Fenntarthatósági Témahetén, idén is tervezik ezt folytatni. Kihasználva másik tantárgyát is a diákokkal szokott a jeles napokra plakátokat, projekteket készíteni/előkészíteni (Víz Nap; Föld Világnapja,...).", "mtmi_aktiv_tanulas_megvalosul": "reszben", "mtmi_csapat_kozos_tevekenyseg": "Közös célunk a tehetséggondozás, mely egy közös intézményi cél is. A gyerekeket versenyekre készítjük fel, különböző tehetséggondozó szakköröket tartunk.  \\n\\nAz MTMI csapat aktív résztvevője számos iskolai és országos programnak, amelyek az élményszerű tanulást és a tudományos érdeklődést erősítik:\\n\\t•\\tKutatók éjszakája – természettudományos és informatikai előadások, kísérletek (Antalics Petra, Debnár János, Kirchner Balázs, Finna Imola)\\n\\t•\\tCodeWeek – programozási és robotikai bemutatók, meghívott előadók (Antalics Petra, Cselényi Luca)\\n\\t•\\tÉjszaka a Kossuthban – szabadulószoba, micro:bit foglalkozások, puzzle és sakk játékok, tudományos kísérletek (Finna Imola, Némethy Mária, Kirchner Balázs, Tóth Fruzsina)\\n\\t•\\tKossuth-nap – természettudományos és informatikai témájú feladatok szervezése —> az egész iskola ezen témákban készít majd a diáknapra feladatokat, a reál munkaközösség célja a tanulók érdeklődésének felkeltése/megtartása\\n\\t•\\tPénzhét, Digitális témahét, Fenntarthatósági témahét – minden évben bekapcsolódunk az országos programsorozatba\\n\\t•\\tAtomerőmű-látogatás (Paks) és állatkerti terepgyakorlatok – a természettudományos ismeretek gyakorlati alkalmazásának támogatására\\n\\nA csapat a rendszergazdával közösen igyekszik fejleszteni a gimnázium informatikai infrastruktúráját. \\n\\nA közös MTMI-tevékenységek mindegyike a tehetséggondozást, a tudomány iránti érdeklődés felkeltését és a modern, digitális szemléletű oktatást szolgálja.\\nFontosnak tartjuk, hogy a diákok aktív szereplői legyenek a tanulási folyamatnak, élményekhez és sikerélményhez jussanak a matematika, a természettudományok és az informatika területén.\\n\\n", "mtmi_fakultaciok_diakok_szama": "150", "mtmi_kiallitoterek_megvalosul": "igen", "lanyok_mtmi_nepszerusito_link1": "https://sites.google.com/dt.klgbp.hu/mtmi/programnapt%C3%A1r-20252026", "lanyoknak_szolo_mtmi_programok": "igen", "mtmi_egyeb_tevekenysegek_szama": "2", "mtmi_kapcsolatok_egyuttmukodes": "igen", "mtmi_kutatási_versenyek_szama": "1", "mtmi_laboratoriumok_latogatasa": "igen", "intezmenytipus_tanuloi_letszama": "440", "mtmi_ceges_eloadasok_bemutatasa": "A Pályaorientációs napra időről időre érkeznek nagyobb cégek képviselői előadást tartani. ", "mtmi_faliujsag_vitrin_reszvetel": "nem", "mtmi_palyaorientacio_megvalosul": "igen", "lanyok_mtmi_reszvetel_bemutatasa": "A legfontosabb platformja ennek az évente megrendezésre kerülő Pályaorientációs Nap, melyben minden évfolyam valamilyen formában (felmenő rendszerben) részt vesz. A 9-10. osztályok osztályfőnöki foglalkozások (pályaorientáció, önéletrajz, motivációs levél, pontszámítási útmutató) mellett részt vehetnek a meghívott előadók előadásain egy megadott idősávban. A 11.-es tanulók kettő, míg a végzős diákok mindhárom egyórás idősávban előadásokon vehetnek részt, melyeket a honlapon meghirdetett terv alapján ők választanak. Idén még több MTMI fókuszra lesz szükség, hiszen az év eleji felmérésem alapján erre van nagy igény. A Pályaorientációs Napra vendégelőadókat hívunk, ők iskolánk korábbi diákjai vagy jelenlegi diákok szülei szoktak lenni általában, akik vállalják, hogy bemutatják nekünk korábbi tanulmányaikat/jelenlegi munkájukat. Ezen felül egyetemeket is meg szoktunk kérni, hogy jöjjenek el iskolánkba bemutatni, hogy náluk mely szakokon milyen diplomát szerezhetnek a diákok. \\n\\nMindig különös hangsúlyt fektetünk a nemek arányára is, egyetemek részéről is szoktak jönni női előadók, de ebben még azért szerintem fejlődnünk kell.\\n\\nTerveink szerint idén csatlakozni szeretnénk a \\"Lányok és Nők a Tudományban\\" világnaphoz, mely az ENSZ szervezésében immáron 11. éve február 11-én kerül megrendezésre, célja, hogy felhívja a figyelmet a tudományban, technológiában, a mérnöki és az informatikai pályákon részt vevő nők és lányok fontosságára. Tervünk, hogy az aulában (iskola kiállítótereként használt tér) plakátokat helyezzünk ki ezen a napon,  illetve egy Filmklubbal (pl. Számolás joga), vagy vendégelőadó meghívásával népszerűsítsük a tudományterületet a diáklányoknak.", "mtmi_felelos_kapcsolattarto_neve": "Csizmadia-Csapp Orsolya", "mtmi_interdiszciplinaris_projekt": "igen", "mtmi_kutatási_verseny_reszvetel": "igen", "mtmi_tanoran_kivuli_rendezvenyek": "Jeles napokra plakátok, versenyek – Tóth Fruzsina (pl. víz világnapja, Föld napja)\\n\\nIdei Kossuth-napok, ahol jeles magyar tudósok és munkásságuk lesz az összes osztály témája, s ehhez kapcsolódó elódásokkal, feladatokkal kell készülniük. \\n\\nTervezünk még természettudomány rendezvényt, melynek koncepcióját a tanév során fogjuk összeállítani. ", "mtmi_tanulmányi_versenyek_link1": "https://klgbp.hu", "mtmi_tanulmányi_versenyek_link2": "https://sites.google.com/dt.klgbp.hu/mtmi/f%C5%91oldal", "mtmi_tanulmányi_versenyek_szama": "7", "mtmi_online_palyaorientacio_link1": "https://www.klgbp.hu/Palyavalasztasi-Projektnap", "programban_erintett_tanulok_szama": "200", "mtmi_diakok_kapcsolattartas_leiras": "Az iskolának nincs külön pályaválasztásért felelős személye, én (Csizmadia-Csapp Orsolya) vagyok a pályaorientációs nap szervezéséért felelős, természetesen bármikor megkereshetnek a diákok akár e-mailben, akár személyesen az iskolában, de gyakorlatilag bárkihez bármivel fordulhatnak az iskolában (osztályfőnök, szaktanár, vezetőség), mindenki szívesen segít. \\n\\nMint korábban említettem, év elején, szeptember elsején az osztályfőnökök kitöltettek a diákokkal egy kérdőívet, melyben felmértük pályaorientációs igényeiket. ", "mtmi_digitalis_eszkozok_megvalosul": "igen", "mtmi_egyuttmukodes_palyaorientacio": "igen", "mtmi_felelos_kapcsolattarto_email1": "csapporsi@gmail.com", "mtmi_online_palyaorientacio_leiras": "A Pályaorientációs napon vagy osztályfőnöki órákon is használjuk az online kérdőíveket (pl. Személyiségtesztek), illetve szakmák bemutató videóját is meg szoktuk nézni a diákokkal, kiértékeljük, reflektál reflektálunk rá. ", "mtmi_otlet_esszepalyazat_reszvetel": "nem", "mtmi_tanulmányi_verseny_reszvetel": "igen", "intezmenyvezeto_kapcsolattarto_neve": "Némethyné Mihályi Mária", "lanyok_mtmi_nepszerusito_bemutatasa": "Terveink szerint idén csatlakozni szeretnénk a \\"Lányok és Nők a Tudományban\\" világnaphoz, mely az ENSZ szervezésében immáron 11. éve február 11-én kerül megrendezésre, célja, hogy felhívja a figyelmet a tudományban, technológiában, a mérnöki és az informatikai pályákon részt vevő nők és lányok fontosságára. Tervünk, hogy az aulában (iskola kiállítótereként használt tér) plakátokat helyezzünk ki ezen a napon,  illetve egy Filmklubbal (pl. Számolás joga), vagy vendégelőadó meghívásával népszerűsítsük a tudományterületet a diáklányoknak.\\n\\nEzen felül próbálunk kooperálni az Evosoft Hungary Kft.-vel és szervezni hozzájuk egy céglátogatást női résztvevőkkel.", "mtmi_kutatási_versenyek_bemutatasa": "Stockholmi Ifjúsági Vízdíj Verseny \\n\\n2024-ben és 2025-ben is indultak ezen a versenyen diákjaink.\\n2024-ben például két 10.a osztályos tanuló részt vett a nemzetközi versenyen, amelynek országos fordulójába továbbjutottak. Projektjükben azt vizsgálták, hogy a vízzel kapcsolatos fenntarthatósági problémák mennyire érdeklik a Z generáció tagjait (kb. 1995-2010 között születettek). ", "mtmi_digitalis_tananyagok_megvalosul": "reszben", "mtmi_felelos_kapcsolattarto_beosztas": "matematika-fizikatanár és osztályfőnöki munkaközösség-vezető", "mtmi_kutatási_verseny_tanarok_szama": "1", "intezmenyvezeto_kapcsolattarto_email1": "nemethym@hotmail.com", "mtmi_tanulmányi_verseny_diakok_szama": "30", "mtmi_tanulmányi_versenyek_bemutatasa": "Továbbra is részt veszünk a kéttannyelvű német matematika és fizika versenyen, itt sikereket is el szoktunk érni minden évben. Felkészítők: Némethy Mária és Csizmadia-Csapp Orsolya\\n\\nMinden évben megrendezzük a matematika háziversenyt. Nagyon sok (közel 100) diákot le tudunk ültetni erre a csapatversenyre. (Finna Imola)\\n\\nInformatikából is tervezünk programozóversenyt, a tavalyi évtől eltérően most több fordulós lesz.\\n\\n\\nVermes Miklós fizika versenyen minden évben elindulunk, és sikereket is el szoktunk érni. (Kirchner Balázs, Csizmadia-Csapp Orsolya)\\n\\nFöldrajzból a Jakucs László Nemzetközi Versenyen indítunk diákokat. (Tóth Fruzsina)\\n\\nTöbb természettudományos programot tervezünk, de ezeket később fogjuk finomítani.\\n\\nPénzügyi versenyeken való részvétel (Finna Imola)\\n\\nÁllatkerti látogatás\\n\\nLányok Napja: tervezünk rajta idén részt venni, egy lány minden évben részt vett rajta eddig és nagyon élvezte, ezért is szeretnénk iskolai szintű rendezvényre kiterjeszteni.\\n\\nAmin tavaly indultak diákok, és reméljük idén is lesz résztvevő:\\n\\nNemzetközi Ifjúsági Vízdíj\\nKeBa Tőzsdeverseny\\n\\nTerveinkben szerepel még egyetemi laboratóriumlátogatás is", "mtmi_interdiszciplinaris_projekt_link1": "https://sites.google.com/dt.klgbp.hu/mtmi/aktu%C3%A1lis-h%C3%ADreink", "mtmi_interdiszciplinaris_projekt_link2": "https://klgbp.hu", "mtmi_korszeru_felszereltseg_megvalosul": "igen", "mtmi_rendezvenyek_reszvetel_bemutatasa": "Codeweek\\n\\nPénzhét, digitális témahét, fenntarthatósági témahét – idén is szeretnék csatlakozni (Finna Imola). Tavaly mindhármon részt vettünk.\\n\\nKutatók Éjszakája: évek óta rendszeresen részt vesznek diákcsoportok tanárokkal különböző egyetemi, laboratóriumi, illetve céges látogatásokon ezen alkalomkor. \\n\\nPályaorientációs Projektnap MTMI fókuszú előadásai, egyetemek előadásai\\n\\nEvosoft Hungary Kft.", "mtmi_tanulmányi_verseny_tanarok_szama": "7", "intezmenyvezeto_kapcsolattarto_beosztas": "igazgatóhelyettes", "mtmi_interdiszciplinaris_projekt_leiras": "Az idei Kossuth-napok témája: Magyar feltalálók és tudósok. Az idei diáknapunk alkalmával magyar tudósok előtt tisztelgünk azzal, hogy minden osztály feldolgozza a témát, melyben az MTMI csapat aktívan segíteni fog az osztályoknak. \\n\\nEzen felül a 11.A osztály Arduino segítségével tanul programozni, ez egy interdiszciplináris projekt egész tanévben, hiszen Csizmadia-Csapp Orsolya vezetésével ötvözik a digitális kultúra és természettudományok (főként fizika) világát, megtanulják “kicsiben”, hogy zajlik egy mérnök munkája. \\n\\nAhogy a Pedagógiai Programunkban is szerepel az egészségnevelés és környezeti nevelés időről időre visszatérő téma mind biológiaórán, mind osztályfőnöki órákon, ehhez hatalmas segítséget kapunk iskolánk pszichológusától és az iskola szociális segítőjétől, voltak már nálunk a SOTE-ról is egészséges étkezéssel kapcsolatos felmérés miatt, illetve tavaly hallgathatott az egyik osztály előadást az evészavarokról. ", "mtmi_palyaorientacio_megvalosulas_link1": "https://klgbp.hu", "mtmi_palyaorientacio_megvalosulas_link2": "https://sites.google.com/dt.klgbp.hu/mtmi/f%C5%91oldal", "mtmi_tovabbkepzesek_idokeret_megvalosul": "igen", "mtmi_tovabbkepzesi_programok_megvalosul": "igen", "mtmi_aktiv_tanulas_megvalosul_bemutatasa": "Mindenki igyekszik egyensúlyt tartani a hagyományos tanórák és az \\"izgalmasabb\\" online tananyagokkal tűzdelt órák között. Szerintem tantárgya válogatja, hogy mennyire tudunk digitális feladatlapokkal készülni a diákoknak, de például a biológia-kémia-fizika órákon fakultációkon is megvalósul ez. \\n\\nA komplex természettudományok tantárgy során még inkább lehetőség nyílik csoportmunkára, sokszor fizikaórán is a diákok csoportban készítenek előadásokat, bemutatókat, otthoni kísérletek. Iskolai szinten is részt vettünk már kutatás alapú oktatási kísérletben, ahol a diákoknak egy adott, választott témához kellett fizikaórán/otthon önszorgalomból kutatási naplót készíteni.", "mtmi_felelos_kapcsolattarto_telefonszam1": "+36 30 190 5410", "mtmi_kiallitoterek_megvalosul_bemutatasa": "Az iskola aulájában szoktuk bemutatni a tanulói munkákat, projekteket, itt állítjuk ki a jeles napokra készített plakátokat, mindenki itt megy el napközben (tanórára, tornateremhez, büfébe, ebédlőbe), így megcsodálhatják egymás munkáit.", "mtmi_palyaorientacio_megvalosulas_leiras": "A legfontosabb platformja ennek az évente megrendezésre kerülő Pályaorientációs Nap, melyben minden évfolyam valamilyen formában (felmenő rendszerben) részt vesz. A 9-10. osztályok osztályfőnöki foglalkozások (pályaorientáció, önéletrajz, motivációs levél, pontszámítási útmutató) mellett részt vehetnek a meghívott előadók előadásain egy megadott idősávban. A 11.-es tanulók kettő, míg a végzős diákok mindhárom egyórás idősávban előadásokon vehetnek részt, melyeket a honlapon meghirdetett terv alapján ők választanak. Idén még több MTMI fókuszra lesz szükség, hiszen az év eleji felmérésem alapján erre van nagy igény. A Pályaorientációs Napra vendégelőadókat hívunk, ők iskolánk korábbi diákjai vagy jelenlegi diákok szülei szoktak lenni általában, akik vállalják, hogy bemutatják nekünk korábbi tanulmányaikat/jelenlegi munkájukat. Ezen felül egyetemeket is meg szoktunk kérni, hogy jöjjenek el iskolánkba bemutatni, hogy náluk mely szakokon milyen diplomát szerezhetnek a diákok. ", "lanyoknak_szolo_mtmi_programok_bemutatasa": "Ebben ténylegesen fejlődnünk kell, az osztályomból az egyik diáklány eddig minden évben részt vett a BME-n a Lányok Napján, a beszámolói nyomán úgy tervezem, hogy idén iskolai szinten meghirdetnénk az eseményt és elkísérnénk a lányokat a Lányok Napja és/vagy a TechCsajok rendezvényekre", "mtmi_egyuttmukodes_palyaorientacio_leiras": "A legfontosabb platformja ennek az évente megrendezésre kerülő Pályaorientációs Nap, melyben minden évfolyam valamilyen formában (felmenő rendszerben) részt vesz. A 9-10. osztályok osztályfőnöki foglalkozások (pályaorientáció, önéletrajz, motivációs levél, pontszámítási útmutató) mellett részt vehetnek a meghívott előadók előadásain egy megadott idősávban. A 11.-es tanulók kettő, míg a végzős diákok mindhárom egyórás idősávban előadásokon vehetnek részt, melyeket a honlapon meghirdetett terv alapján ők választanak. Idén még több MTMI fókuszra lesz szükség, hiszen az év eleji felmérésem alapján erre van nagy igény. A Pályaorientációs Napra vendégelőadókat hívunk, ők iskolánk korábbi diákjai vagy jelenlegi diákok szülei szoktak lenni általában, akik vállalják, hogy bemutatják nekünk korábbi tanulmányaikat/jelenlegi munkájukat. Ezen felül egyetemeket is meg szoktunk kérni, hogy jöjjenek el iskolánkba bemutatni, hogy náluk mely szakokon milyen diplomát szerezhetnek a diákok. ", "mtmi_laboratoriumok_latogatasa_bemutatasa": "Idén tervezünk egyetemi, iskolai laboratóriumi látogatásokat is, a német nyelvű fizikaversenyen, mely az ELTE-n kerül megrendezésre, minden évben mennek a versenyzők egyetemi laborlátogatásokra, voltak már többek között anyagfizikai laborban, csillagvizsgálóban, és nagyon élvezték ezeket a látogatásokat. Szeretnénk ezt fejleszteni és kiterjeszteni más egyetemekre és laboratóriumokra is. ", "mtmi_egyeb_palyaorientacios_programok_link1": "https://klgbp.hu", "mtmi_egyeb_palyaorientacios_programok_link2": "https://sites.google.com/dt.klgbp.hu/mtmi/f%C5%91oldal", "mtmi_digitalis_eszkozok_megvalosul_bemutatasa": "Mindenki igyekszik egyensúlyt tartani a hagyományos tanórák és az \\"izgalmasabb\\" online tananyagokkal tűzdelt órák között. Szerintem tantárgya válogatja, hogy mennyire tudunk digitális feladatlapokkal készülni a diákoknak, de például a biológia-kémia-fizika órákon fakultációkon is megvalósul ez. ", "mtmi_digitalis_tananyagok_megvalosul_bemutatasa": "Mindenki igyekszik egyensúlyt tartani a hagyományos tanórák és az \\"izgalmasabb\\" online tananyagokkal tűzdelt órák között. Szerintem tantárgya válogatja, hogy mennyire tudunk digitális feladatlapokkal készülni a diákoknak, de például a biológia-kémia-fizika órákon fakultációkon is megvalósul ez. ", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul": "igen", "mtmi_tovabbkepzesek_idokeret_megvalosul_bemutatasa": "Antalics Petra jelenleg a gimnáziumi digitális kultúra tanári képzést végzi az egyetemen, hogy taníthasson nálunk, pedig valójában mérnök és az Evosoft Hungary Kft.-nél dolgozik. \\nDebnár János részt vett mindkét tantárgyából (biológia és kémia), Némethyné Mihályi Mária pedig matematikából 5-5 órás szaktárgyi továbbképzésen, közösen Máriával részt vettünk az egyik Tagung keretében Arduino-s továbbbképzésen az ELTE-n Schnider Dorottya vezetésével, illetve mi ketten minden évben kétszer részt veszünk a DePhyMa továbbképzésein, ahol a német nyelvű versenyfeladatokat készítjük elő közösen az országból, és jó gyakorlatokat (Arduino, AI használata tanórán,...) tanulunk egymástól.\\nFinna Imola pedig jelenleg a pedagógus szakvizsgáját végzi az ELTE-n pénzügy modullal.", "mtmi_tovabbkepzesi_programok_megvalosul_bemutatasa": "Antalics Petra jelenleg a gimnáziumi digitális kultúra tanári képzést végzi az egyetemen, hogy taníthasson nálunk, pedig valójában mérnök és az Evosoft Hungary Kft.-nél dolgozik. \\nDebnár János részt vett mindkét tantárgyából (biológia és kémia), Némethyné Mihályi Mária pedig matematikából 5-5 órás szaktárgyi továbbképzésen, közösen Máriával részt vettünk az egyik Tagung keretében Arduino-s továbbbképzésen az ELTE-n Schnider Dorottya vezetésével, illetve mi ketten minden évben kétszer részt veszünk a DePhyMa továbbképzésein, ahol a német nyelvű versenyfeladatokat készítjük elő közösen az országból, és jó gyakorlatokat (Arduino, AI használata tanórán,...) tanulunk egymástól.\\nFinna Imola pedig jelenleg a pedagógus szakvizsgáját végzi az ELTE-n pénzügy modullal.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul": "igen", "mtmi_pedagogusok_teljesitmenyertekeles_megvalosul_bemutatasa": "Mivel a legtöbb MTMI csapattag osztályfőnök is egyben, ezért nyilván megjelennek osztályfőnöki, közösségépítési egyéni célok is, de mindenkinél szerepelnek szaktárgyi TÉR vállalások, a fentebb említett versenyeken való indulás, kirándulások szervezése, tananyagok korszerűsítése, digitalizálása. Közös intézményi célunk ebben a tanévben, ahogy tavaly is, a tehetséggondozás, tehát ezzel szimbiózisban abszolút beleillik az MTMI Iskola Programja, reméljük, sikerülni fog az együttműdködés és szerencsére a vezetőség részéről is teljesen támogatást kapunk.", "mtmi_egyetem_oktatasi_hivatal_tovabbkepzesek_megvalosul_bemutatasa": "Minden továbbképzési lehetőségről e-mailben értesülünk, mindenki tud egyénileg jelentkezni továbbképzésre, illetve egymásnak is szoktunk ajánlani jó, hasznos, izgalmas továbbképzéseket."}	2025-10-24 19:14:21.787415	2026-03-15 06:56:07.984941	0	\N	1a4039ac-ecab-4f5a-8544-d01732c8f95c
\.


--
-- Data for Name: schools; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schools (id, name, email, password_hash, form_id, created_at, updated_at) FROM stdin;
382360ca-29eb-4b2f-8416-10d57bfd83b5	Hőgyes Endre Gimnázium	\N	\N	b67ab677-54ed-4785-a143-2ad257bee4ec	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
f2b0771b-def1-49ff-981f-71f8a5ea659a	J	\N	\N	d8ea5036-0aab-4e1f-88d8-8f111eac8264	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
5671aa3e-6607-4567-ba23-9af9c45501b5	Zentai Úti Általános Iskola	\N	\N	d95ea7dd-e982-4b17-8c9c-7d246fa65169	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
d6c5af31-43a2-4d7a-bf3b-d3245087e930	Budapesti Műszaki SZC Petrik Lajos Két Tanítási Nyelvű Technikum	\N	\N	a1046309-82d9-47df-815f-6bc946eb6fbf	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
b6abbfc3-1299-4b68-a1e4-15cd97b0df9a	ELTE Bolyai János Gyakorló Általános Iskola és Gimnázium	\N	\N	94c2c4fe-faa6-4bf8-97e2-f7aa5473c849	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
09b64906-2bca-4bd8-b4d2-12d6ffe1fe00	Gyömrői Weöres Sándor Általános Iskola és Alapfokú Művészeti Iskola	\N	\N	62e4f5d4-41f5-4665-8070-44d65712e7ac	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
6813a421-8116-42e5-a9bd-15c493ef5b11	Székesfehérvári Széna Téri Általános Iskola	\N	\N	008c0533-8474-4af1-90e9-8408a60c0c47	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
85f0bad2-ade9-4f9d-9d50-7ba0c484dde7	Kaposvári Táncsics Mihály Gimnázium	\N	\N	6fb006f4-1cc4-4b75-a7e3-a89d531854ea	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
2cc199b5-d2c5-4ca4-9373-9fad51866cd1	Lánczos Kornél Gimnázium	\N	\N	8199a4f5-45bf-4c2e-8dd5-bf7a3e7984e2	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
63f0cc57-e620-445a-88d8-46538001a767	Székesfehérvári Teleki Blanka Gimnázium és Általános Iskola	\N	\N	1b645429-cfb6-4608-a085-7a1889fc5456	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
fc6dc512-5a6b-4e13-8072-00c8c39042a6	Nyíregyházi Vasvári Pál Gimnázium	\N	\N	762cdca1-2991-4253-9d8e-bd5abdc05e82	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
991d3309-f5ae-4700-9f11-763d45fc7667	Kisvárdai Bessenyei György Gimnázium és Kollégium	\N	\N	85f0d277-52bb-4215-903f-0295560436b4	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
24968a6a-456c-45e4-b66e-fffcd0463f00	Kispesti Deák Ferenc Gimnázium	\N	\N	e1176e03-d511-49bb-82ac-86d365e266e8	2026-03-05 21:43:26.119882	2026-03-05 21:43:26.119882
4167fe85-5bfa-4756-b33c-bf3c599b2edf	Belavolgyi	a@a.hu	$2b$12$nVlgE4esAYk7mkt0VjAyUOmEPJeTBOrgdm2..0jH5q7Is9F8f0r62	e44cfee3-99d3-4ac2-8214-6c31f8ab2413	2026-03-05 21:47:56.275439	2026-03-05 22:14:51.55628
1a4039ac-ecab-4f5a-8544-d01732c8f95c	Budapest XX. Kerületi Kossuth Lajos Gimnázium	teszt@teszt.hu	$2b$12$jJxoSa.s8PhlJPNbAgqtd.1q0LNkG4fuK3wL2AiMZv0GgDu/BLtN.	6fb006f4-1cc4-4b75-a7e3-a89d531854ea	2026-03-05 21:43:26.119882	2026-03-15 09:33:23.861424
5f8de127-9879-4d1a-b2bb-b1dacc4cdbb1	ViktorSuli	viktor@viktor.hu	\N	\N	2026-03-30 17:40:32.330571	2026-03-30 17:40:32.330571
b452bcfe-6004-4a2f-bf8e-f0e37295d61e	Gábor Iskolája	gabor@gabor.hu	\N	\N	2026-03-30 17:41:07.147574	2026-03-30 17:41:07.147574
e3186695-d9f1-43ef-a9dd-ca7e596cbd96	Zita Sulija	zita@zita.hu	\N	\N	2026-03-30 17:41:36.079769	2026-03-30 17:41:36.079769
959363b9-a0c0-48ae-ae08-fb6464b2571c	Imre Összevont Iskolája	imre@imre.hu	\N	\N	2026-03-30 17:44:15.935691	2026-03-30 17:44:15.935691
80db2b71-00f8-46cf-8074-7fdbc44b7ee6	Misitesztje Suli	misi@misi.hu	\N	\N	2026-03-30 17:44:56.903682	2026-03-30 17:44:56.903682
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.schema_migrations (version, inserted_at) FROM stdin;
20211116024918	2025-07-16 20:23:37
20211116045059	2025-07-16 20:23:40
20211116050929	2025-07-16 20:23:41
20211116051442	2025-07-16 20:23:43
20211116212300	2025-07-16 20:23:45
20211116213355	2025-07-16 20:23:46
20211116213934	2025-07-16 20:23:48
20211116214523	2025-07-16 20:23:50
20211122062447	2025-07-16 20:23:52
20211124070109	2025-07-16 20:23:53
20211202204204	2025-07-16 20:23:55
20211202204605	2025-07-16 20:23:56
20211210212804	2025-07-16 20:24:02
20211228014915	2025-07-16 20:24:03
20220107221237	2025-07-16 20:24:05
20220228202821	2025-07-16 20:24:06
20220312004840	2025-07-16 20:24:08
20220603231003	2025-07-16 20:24:10
20220603232444	2025-07-16 20:24:12
20220615214548	2025-07-16 20:24:14
20220712093339	2025-07-16 20:24:15
20220908172859	2025-07-16 20:24:17
20220916233421	2025-07-16 20:24:19
20230119133233	2025-07-16 20:24:20
20230128025114	2025-07-16 20:24:22
20230128025212	2025-07-16 20:24:24
20230227211149	2025-07-16 20:24:26
20230228184745	2025-07-16 20:24:27
20230308225145	2025-07-16 20:24:29
20230328144023	2025-07-16 20:24:30
20231018144023	2025-07-16 20:24:32
20231204144023	2025-07-16 20:24:35
20231204144024	2025-07-16 20:24:36
20231204144025	2025-07-16 20:24:38
20240108234812	2025-07-16 20:24:40
20240109165339	2025-07-16 20:24:41
20240227174441	2025-07-16 20:24:44
20240311171622	2025-07-16 20:24:46
20240321100241	2025-07-16 20:24:50
20240401105812	2025-07-16 20:24:54
20240418121054	2025-07-16 20:24:56
20240523004032	2025-07-16 20:25:02
20240618124746	2025-07-16 20:25:04
20240801235015	2025-07-16 20:25:05
20240805133720	2025-07-16 20:25:07
20240827160934	2025-07-16 20:25:08
20240919163303	2025-07-16 20:25:11
20240919163305	2025-07-16 20:25:12
20241019105805	2025-07-16 20:25:14
20241030150047	2025-07-16 20:25:20
20241108114728	2025-07-16 20:25:22
20241121104152	2025-07-16 20:25:24
20241130184212	2025-07-16 20:25:25
20241220035512	2025-07-16 20:25:27
20241220123912	2025-07-16 20:25:29
20241224161212	2025-07-16 20:25:30
20250107150512	2025-07-16 20:25:32
20250110162412	2025-07-16 20:25:33
20250123174212	2025-07-16 20:25:35
20250128220012	2025-07-16 20:25:36
20250506224012	2025-07-16 20:25:38
20250523164012	2025-07-16 20:25:39
20250714121412	2025-08-02 19:47:27
20250905041441	2025-10-30 16:18:37
20251103001201	2025-11-27 11:32:47
20251120212548	2026-02-04 12:29:17
20251120215549	2026-02-04 12:29:17
20260218120000	2026-03-04 19:05:56
\.


--
-- Data for Name: subscription; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.subscription (id, subscription_id, entity, filters, claims, created_at, action_filter) FROM stdin;
\.


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets (id, name, owner, created_at, updated_at, public, avif_autodetection, file_size_limit, allowed_mime_types, owner_id, type) FROM stdin;
\.


--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_analytics (name, type, format, created_at, updated_at, id, deleted_at) FROM stdin;
\.


--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_vectors (id, type, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.migrations (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	e18db593bcde2aca2a408c4d1100f6abba2195df	2025-07-16 20:23:35.234274
1	initialmigration	6ab16121fbaa08bbd11b712d05f358f9b555d777	2025-07-16 20:23:35.241223
3	pathtoken-column	2cb1b0004b817b29d5b0a971af16bafeede4b70d	2025-07-16 20:23:35.266395
4	add-migrations-rls	427c5b63fe1c5937495d9c635c263ee7a5905058	2025-07-16 20:23:35.279582
5	add-size-functions	79e081a1455b63666c1294a440f8ad4b1e6a7f84	2025-07-16 20:23:35.285228
7	add-rls-to-buckets	e7e7f86adbc51049f341dfe8d30256c1abca17aa	2025-07-16 20:23:35.297185
8	add-public-to-buckets	fd670db39ed65f9d08b01db09d6202503ca2bab3	2025-07-16 20:23:35.302324
11	add-trigger-to-auto-update-updated_at-column	7425bdb14366d1739fa8a18c83100636d74dcaa2	2025-07-16 20:23:35.338341
12	add-automatic-avif-detection-flag	8e92e1266eb29518b6a4c5313ab8f29dd0d08df9	2025-07-16 20:23:35.347081
13	add-bucket-custom-limits	cce962054138135cd9a8c4bcd531598684b25e7d	2025-07-16 20:23:35.353194
14	use-bytes-for-max-size	941c41b346f9802b411f06f30e972ad4744dad27	2025-07-16 20:23:35.359358
15	add-can-insert-object-function	934146bc38ead475f4ef4b555c524ee5d66799e5	2025-07-16 20:23:35.378026
16	add-version	76debf38d3fd07dcfc747ca49096457d95b1221b	2025-07-16 20:23:35.384065
17	drop-owner-foreign-key	f1cbb288f1b7a4c1eb8c38504b80ae2a0153d101	2025-07-16 20:23:35.389802
18	add_owner_id_column_deprecate_owner	e7a511b379110b08e2f214be852c35414749fe66	2025-07-16 20:23:35.395828
19	alter-default-value-objects-id	02e5e22a78626187e00d173dc45f58fa66a4f043	2025-07-16 20:23:35.403014
20	list-objects-with-delimiter	cd694ae708e51ba82bf012bba00caf4f3b6393b7	2025-07-16 20:23:35.408553
21	s3-multipart-uploads	8c804d4a566c40cd1e4cc5b3725a664a9303657f	2025-07-16 20:23:35.416406
22	s3-multipart-uploads-big-ints	9737dc258d2397953c9953d9b86920b8be0cdb73	2025-07-16 20:23:35.42962
23	optimize-search-function	9d7e604cddc4b56a5422dc68c9313f4a1b6f132c	2025-07-16 20:23:35.441725
24	operation-function	8312e37c2bf9e76bbe841aa5fda889206d2bf8aa	2025-07-16 20:23:35.449088
25	custom-metadata	d974c6057c3db1c1f847afa0e291e6165693b990	2025-07-16 20:23:35.455567
37	add-bucket-name-length-trigger	3944135b4e3e8b22d6d4cbb568fe3b0b51df15c1	2025-10-30 16:18:39.696181
44	vector-bucket-type	99c20c0ffd52bb1ff1f32fb992f3b351e3ef8fb3	2025-11-22 20:00:51.344162
45	vector-buckets	049e27196d77a7cb76497a85afae669d8b230953	2025-11-22 20:00:51.368036
46	buckets-objects-grants	fedeb96d60fefd8e02ab3ded9fbde05632f84aed	2025-11-22 20:00:51.430666
47	iceberg-table-metadata	649df56855c24d8b36dd4cc1aeb8251aa9ad42c2	2025-11-22 20:00:51.435447
49	buckets-objects-grants-postgres	072b1195d0d5a2f888af6b2302a1938dd94b8b3d	2025-12-28 17:21:47.826952
2	storage-schema	f6a1fa2c93cbcd16d4e487b362e45fca157a8dbd	2025-07-16 20:23:35.24643
6	change-column-name-in-get-size	ded78e2f1b5d7e616117897e6443a925965b30d2	2025-07-16 20:23:35.291663
9	fix-search-function	af597a1b590c70519b464a4ab3be54490712796b	2025-07-16 20:23:35.310024
10	search-files-search-function	b595f05e92f7e91211af1bbfe9c6a13bb3391e16	2025-07-16 20:23:35.321516
26	objects-prefixes	215cabcb7f78121892a5a2037a09fedf9a1ae322	2025-10-30 16:18:39.527888
27	search-v2	859ba38092ac96eb3964d83bf53ccc0b141663a6	2025-10-30 16:18:39.618081
28	object-bucket-name-sorting	c73a2b5b5d4041e39705814fd3a1b95502d38ce4	2025-10-30 16:18:39.628431
29	create-prefixes	ad2c1207f76703d11a9f9007f821620017a66c21	2025-10-30 16:18:39.639186
30	update-object-levels	2be814ff05c8252fdfdc7cfb4b7f5c7e17f0bed6	2025-10-30 16:18:39.645177
31	objects-level-index	b40367c14c3440ec75f19bbce2d71e914ddd3da0	2025-10-30 16:18:39.651466
32	backward-compatible-index-on-objects	e0c37182b0f7aee3efd823298fb3c76f1042c0f7	2025-10-30 16:18:39.658005
33	backward-compatible-index-on-prefixes	b480e99ed951e0900f033ec4eb34b5bdcb4e3d49	2025-10-30 16:18:39.664398
34	optimize-search-function-v1	ca80a3dc7bfef894df17108785ce29a7fc8ee456	2025-10-30 16:18:39.666476
35	add-insert-trigger-prefixes	458fe0ffd07ec53f5e3ce9df51bfdf4861929ccc	2025-10-30 16:18:39.67468
36	optimise-existing-functions	6ae5fca6af5c55abe95369cd4f93985d1814ca8f	2025-10-30 16:18:39.679035
38	iceberg-catalog-flag-on-buckets	02716b81ceec9705aed84aa1501657095b32e5c5	2025-10-30 16:18:39.700927
39	add-search-v2-sort-support	6706c5f2928846abee18461279799ad12b279b78	2025-10-30 16:18:39.729399
40	fix-prefix-race-conditions-optimized	7ad69982ae2d372b21f48fc4829ae9752c518f6b	2025-10-30 16:18:39.735489
41	add-object-level-update-trigger	07fcf1a22165849b7a029deed059ffcde08d1ae0	2025-10-30 16:18:39.74737
42	rollback-prefix-triggers	771479077764adc09e2ea2043eb627503c034cd4	2025-10-30 16:18:39.753378
43	fix-object-level	84b35d6caca9d937478ad8a797491f38b8c2979f	2025-10-30 16:18:39.759898
48	iceberg-catalog-ids	e0e8b460c609b9999ccd0df9ad14294613eed939	2025-11-22 20:00:51.44736
50	search-v2-optimised	6323ac4f850aa14e7387eb32102869578b5bd478	2026-02-24 22:39:45.383975
51	index-backward-compatible-search	2ee395d433f76e38bcd3856debaf6e0e5b674011	2026-02-24 22:39:45.43302
52	drop-not-used-indexes-and-functions	5cc44c8696749ac11dd0dc37f2a3802075f3a171	2026-02-24 22:39:45.435082
53	drop-index-lower-name	d0cb18777d9e2a98ebe0bc5cc7a42e57ebe41854	2026-02-24 22:39:45.455563
54	drop-index-object-level	6289e048b1472da17c31a7eba1ded625a6457e67	2026-02-24 22:39:45.457602
55	prevent-direct-deletes	262a4798d5e0f2e7c8970232e03ce8be695d5819	2026-02-24 22:39:45.459233
56	fix-optimized-search-function	cb58526ebc23048049fd5bf2fd148d18b04a2073	2026-02-24 22:39:45.466258
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, version, owner_id, user_metadata) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads (id, in_progress_size, upload_signature, bucket_id, key, version, owner_id, created_at, user_metadata) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads_parts (id, upload_id, size, part_number, bucket_id, key, etag, owner_id, version, created_at) FROM stdin;
\.


--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.vector_indexes (id, name, bucket_id, data_type, dimension, distance_metric, metadata_configuration, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: secrets; Type: TABLE DATA; Schema: vault; Owner: -
--

COPY vault.secrets (id, name, description, secret, key_id, nonce, created_at, updated_at) FROM stdin;
\.


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: -
--

SELECT pg_catalog.setval('auth.refresh_tokens_id_seq', 1, false);


--
-- Name: subscription_id_seq; Type: SEQUENCE SET; Schema: realtime; Owner: -
--

SELECT pg_catalog.setval('realtime.subscription_id_seq', 1, false);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: custom_oauth_providers custom_oauth_providers_identifier_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_identifier_key UNIQUE (identifier);


--
-- Name: custom_oauth_providers custom_oauth_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_client_states
    ADD CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webauthn_challenges webauthn_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_pkey PRIMARY KEY (id);


--
-- Name: webauthn_credentials webauthn_credentials_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_pkey PRIMARY KEY (id);


--
-- Name: app_settings app_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_settings
    ADD CONSTRAINT app_settings_pkey PRIMARY KEY (id);


--
-- Name: forms forms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forms
    ADD CONSTRAINT forms_pkey PRIMARY KEY (id);


--
-- Name: schools schools_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools
    ADD CONSTRAINT schools_email_key UNIQUE (email);


--
-- Name: schools schools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools
    ADD CONSTRAINT schools_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: subscription pk_subscription; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.subscription
    ADD CONSTRAINT pk_subscription PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: buckets_analytics buckets_analytics_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_analytics
    ADD CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id);


--
-- Name: buckets buckets_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets
    ADD CONSTRAINT buckets_pkey PRIMARY KEY (id);


--
-- Name: buckets_vectors buckets_vectors_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_vectors
    ADD CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_name_key; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_name_key UNIQUE (name);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id);


--
-- Name: vector_indexes vector_indexes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_pkey PRIMARY KEY (id);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: custom_oauth_providers_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_created_at_idx ON auth.custom_oauth_providers USING btree (created_at);


--
-- Name: custom_oauth_providers_enabled_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_enabled_idx ON auth.custom_oauth_providers USING btree (enabled);


--
-- Name: custom_oauth_providers_identifier_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_identifier_idx ON auth.custom_oauth_providers USING btree (identifier);


--
-- Name: custom_oauth_providers_provider_type_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_provider_type_idx ON auth.custom_oauth_providers USING btree (provider_type);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: INDEX identities_email_idx; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: INDEX users_email_partial_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


--
-- Name: webauthn_challenges_expires_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_expires_at_idx ON auth.webauthn_challenges USING btree (expires_at);


--
-- Name: webauthn_challenges_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_user_id_idx ON auth.webauthn_challenges USING btree (user_id);


--
-- Name: webauthn_credentials_credential_id_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX webauthn_credentials_credential_id_key ON auth.webauthn_credentials USING btree (credential_id);


--
-- Name: webauthn_credentials_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_credentials_user_id_idx ON auth.webauthn_credentials USING btree (user_id);


--
-- Name: ix_realtime_subscription_entity; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX ix_realtime_subscription_entity ON realtime.subscription USING btree (entity);


--
-- Name: messages_inserted_at_topic_index; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_inserted_at_topic_index ON ONLY realtime.messages USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: subscription_subscription_id_entity_filters_action_filter_key; Type: INDEX; Schema: realtime; Owner: -
--

CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_action_filter_key ON realtime.subscription USING btree (subscription_id, entity, filters, action_filter);


--
-- Name: bname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);


--
-- Name: bucketid_objname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);


--
-- Name: buckets_analytics_unique_name_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: idx_multipart_uploads_list; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);


--
-- Name: idx_objects_bucket_id_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");


--
-- Name: idx_objects_bucket_id_name_lower; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name_lower ON storage.objects USING btree (bucket_id, lower(name) COLLATE "C");


--
-- Name: name_prefix_search; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);


--
-- Name: vector_indexes_name_bucket_id_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);


--
-- Name: subscription tr_check_filters; Type: TRIGGER; Schema: realtime; Owner: -
--

CREATE TRIGGER tr_check_filters BEFORE INSERT OR UPDATE ON realtime.subscription FOR EACH ROW EXECUTE FUNCTION realtime.subscription_check_filters();


--
-- Name: buckets enforce_bucket_name_length_trigger; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();


--
-- Name: buckets protect_buckets_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_buckets_delete BEFORE DELETE ON storage.buckets FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects protect_objects_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_objects_delete BEFORE DELETE ON storage.objects FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects update_objects_updated_at; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: webauthn_challenges webauthn_challenges_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: webauthn_credentials webauthn_credentials_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: objects objects_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_upload_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id) ON DELETE CASCADE;


--
-- Name: vector_indexes vector_indexes_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id);


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_analytics; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_analytics ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_vectors; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_vectors ENABLE ROW LEVEL SECURITY;

--
-- Name: migrations; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: objects; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads_parts; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_indexes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.vector_indexes ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION extensions.set_graphql_placeholder();


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_cron_access();


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end
         WHEN TAG IN ('CREATE FUNCTION')
   EXECUTE FUNCTION extensions.grant_pg_graphql_access();


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_net_access();


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_ddl_watch ON ddl_command_end
   EXECUTE FUNCTION extensions.pgrst_ddl_watch();


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_drop_watch ON sql_drop
   EXECUTE FUNCTION extensions.pgrst_drop_watch();


--
-- PostgreSQL database dump complete
--


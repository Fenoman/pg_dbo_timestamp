SET search_path = public, pg_catalog;

CREATE OR REPLACE FUNCTION dbots_on_ddl_event () RETURNS event_trigger
    SET search_path = public, pg_catalog
    LANGUAGE plpgsql
AS
$$
DECLARE
    r        record;
    _exstate text;
    _exmsg   text;
    _exctx   text;
BEGIN
    FOR r IN SELECT
                 *
             FROM pg_catalog.pg_event_trigger_ddl_commands()
    LOOP
        IF r.command_tag NOT LIKE 'ALTER % OWNER TO %'
        THEN
            IF r.classid IS NOT NULL AND r.objid IS NOT NULL
            THEN
                IF EXISTS (
                              SELECT
                                  1
                              FROM dbots_event_data
                              WHERE classid = r.classid
                                AND objid = r.objid
                          )
                THEN
                    UPDATE dbots_event_data
                    SET
                        last_modified = DEFAULT,
                        cur_user      = DEFAULT,
                        ses_user      = DEFAULT,
                        ip_address    = DEFAULT
                    WHERE classid = r.classid
                      AND objid = r.objid;
                ELSE
                    INSERT INTO dbots_event_data
                    (
                        classid,
                        objid
                    )
                    SELECT
                        r.classid,
                        r.objid;
                END IF;
            ELSE
                RAISE NOTICE 'DDL unsupported by pg_dbo_timestamp';
            END IF;
        END IF;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN GET STACKED DIAGNOSTICS _exstate = RETURNED_SQLSTATE, _exmsg = MESSAGE_TEXT, _exctx = PG_EXCEPTION_CONTEXT;
    RAISE WARNING 'Error in pg_dbo_timestamp event trigger function. state: %, message: %, context: %', _exstate, _exmsg, _exctx;
END;
$$;

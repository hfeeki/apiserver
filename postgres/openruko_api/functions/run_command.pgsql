CREATE OR REPLACE FUNCTION run_command
(p_app_id integer, p_app_name text, p_api_key text, p_command text)
-- TODO p_app_name not used
-- TODO p_api_key not used
RETURNS SETOF provision_job AS 
$BODY$
DECLARE
  v_mounts hstore;
  v_env_vars hstore;
  v_dyno_id text;
  v_rez_id text;
  v_job_id integer;
  v_command text;
  v_command_args text[];
  v_command_parts text[];
  v_last_release release%rowtype;
BEGIN

  SELECT * FROM release WHERE app_id = p_app_id ORDER BY id
    DESC LIMIT 1 INTO v_last_release;

  v_mounts = hstore('/app','s3get://{{S3_BUCKET}}/slugs/' || p_app_id ||
    '_' || v_last_release.slug_id || '.tgz');

  v_dyno_id = generate_uuid();
  v_rez_id = generate_uuid();
  
  v_command_parts = regexp_split_to_array(p_command, E'\\s+');
  v_command = v_command_parts[1];
  v_command_args = v_command_parts[2:999];

  v_env_vars = v_last_release.env;

  INSERT INTO provision_job 
    (template, name, dyno_id, rez_id, env_vars, attached, pty, 
      command, command_args, mounts, created_at, next_action)
    VALUES ('run','run',
    v_dyno_id, v_rez_id,
    v_env_vars, true, 
    true, v_command,
    v_command_args, v_mounts, NOW(), 'start')
    RETURNING id INTO v_job_id;

  RETURN QUERY SELECT * FROM provision_job WHERE id = v_job_id LIMIT 1;

END;
$BODY$
LANGUAGE plpgsql VOLATILE
-- vim: set filetype=pgsql :

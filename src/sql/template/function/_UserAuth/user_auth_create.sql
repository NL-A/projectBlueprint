-- создание профиля пользователя в авторизационном сервисе
-- параметры:
-- last_name        type: string
-- first_name       type: string
-- avatar           type: string
-- username         type: string
-- auth_provider    type:string
-- auth_provider_id type:string
-- auth_token       type:string
-- email            type:string
-- password         type:string

DROP FUNCTION IF EXISTS user_auth_create(params JSONB );
CREATE OR REPLACE FUNCTION user_auth_create(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  userAuthRow user_auth%ROWTYPE;
  userRow     "user"%ROWTYPE;
  checkMsg    TEXT;
  roleArr     TEXT [] := '{student}';
  result      JSONB;
BEGIN

  -- проверка наличия обязательных параметров
  checkMsg = check_required_params_with_func_name('user_auth_create', params,
                                                  ARRAY ['auth_provider', 'auth_provider_id', 'auth_token']);
  IF checkMsg IS NOT NULL
  THEN
    RETURN checkMsg;
  END IF;

  EXECUTE 'SELECT * FROM user_auth WHERE auth_provider=$1 AND auth_provider_id=$2'
  INTO userAuthRow
  USING params ->> 'auth_provider', params ->> 'auth_provider_id';

  -- если уже есть такая авторизация, то ищем пользователя
  IF userAuthRow.id NOTNULL
  THEN
    SELECT *
    INTO userRow
    FROM "user"
    WHERE id = userAuthRow.user_id;
    IF userRow ISNULL
    THEN
      RETURN jsonb_build_object('ok', FALSE, 'message', 'not found user for this provider auth data');
    END IF;
  END IF;

  -- новая авторизация. Создаем запись об авторизации и создаем нового пользователя.
  IF userAuthRow.id ISNULL
  THEN
    -- перед созданием нового пользователя проверяем, что если уже есть пользователь с таким email, то считаем что новый user_auth относится к существующему пользователю
    IF params ->> 'email' NOTNULL AND length(params ->> 'email') > 0
    THEN
      SELECT *
      INTO userRow
      FROM "user"
      WHERE email = params ->> 'email' AND length(email) > 0;
    END IF;

    -- проверяем что пользователь не найден (могли найти по email) и если нет, то создаем нового
    IF userRow.id ISNULL
    THEN
      -- вначале создаем нового пользователя на базе данных из авторизационного сервиса. Затем уже создаем запись об авторизации и туда записываем id вновь созданного пользователя
      IF params -> 'role' NOTNULL
      THEN
        roleArr = text_array_from_json(params -> 'role');
      END IF;
      EXECUTE ('INSERT INTO "user" (last_name, first_name, avatar, email, role, options) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *;')
      INTO userRow
      USING
        params ->> 'last_name',
        params ->> 'first_name',
        params ->> 'avatar',
        COALESCE((params ->> 'email') :: TEXT, NULL),
        roleArr,
        COALESCE((params -> 'options') :: JSONB, NULL);
    END IF;

    -- после того как создали запись о новом пользователе, создаем запись об авторизации и проставляем в ней id вновь созданного пользователя
    EXECUTE ('INSERT INTO user_auth (user_id, auth_provider, auth_provider_id, last_name, first_name, username, avatar, auth_token, email, options, password) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING *;')
    INTO userAuthRow
    USING
      userRow.id,
      params ->> 'auth_provider',
      params ->> 'auth_provider_id',
      params ->> 'last_name',
      params ->> 'first_name',
      params ->> 'username',
      params ->> 'avatar',
      COALESCE((params ->> 'auth_token') :: TEXT, NULL),
      COALESCE((params ->> 'email') :: TEXT, NULL),
      COALESCE((params -> 'options') :: JSONB, NULL),
      (params ->> 'password') :: TEXT;
  END IF;

  result = (row_to_json(userRow) :: JSONB - 'created_at' - 'updated_at' - 'password');
  -- добавляем auth_token
  result = result || jsonb_build_object('auth_token', userAuthRow.auth_token);

  RETURN jsonb_build_object('ok', TRUE, 'result', result);

END

$function$;


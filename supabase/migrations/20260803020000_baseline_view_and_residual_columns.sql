-- CR30 part 5: the last two objects production has and the ledger never creates.
--
--   * `public.user_details`, a VIEW -- the gap was never only tables and
--     columns. A table-level parity check would have reported success here.
--   * `entitlements.created_at`.
--
-- Idempotent, so this is a no-op against production.

alter table public.entitlements
  add column if not exists created_at timestamp with time zone default now();

create or replace view public.user_details as
 SELECT u.id,
    u.auth0_id,
    u.email,
    u.email_verified,
    u.name,
    u.nickname,
    u.picture,
    u.created_at,
    u.updated_at,
    u.last_login,
    u.login_count,
    u.blocked,
    u.metadata AS user_metadata,
    p.phone_number,
    p.address,
    p.city,
    p.state,
    p.zip_code,
    p.country,
    p.timezone,
    p.locale,
    p.preferences,
    COALESCE(json_agg(json_build_object('id', r.id, 'name', r.name, 'permissions', r.permissions)) FILTER (WHERE r.id IS NOT NULL), '[]'::json) AS roles
   FROM users u
     LEFT JOIN user_profiles p ON u.id = p.user_id
     LEFT JOIN user_roles ur ON u.id = ur.user_id
     LEFT JOIN roles r ON ur.role_id = r.id
  GROUP BY u.id, p.phone_number, p.address, p.city, p.state, p.zip_code, p.country, p.timezone, p.locale, p.preferences;

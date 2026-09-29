-- An API key can be switched off and back on: 'inactive' is a reversible suspension, where
-- 'revoked' stays permanent (revoked_at set, KV record deleted). Set by the
-- api-keys-set-status edge function, which also mirrors the status into the key's AUTH KV
-- record. The gateway already refuses every status but 'active' (workers/lib/api-keys.ts).
alter type public.api_key_status add value if not exists 'inactive';

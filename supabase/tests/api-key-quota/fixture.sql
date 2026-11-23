-- Fixture for the api-key-quota migration test: the api-key-requests fixture, plus the
-- migration that created create_api_key_for_request, which this one replaces.
\ir ../api-key-requests/fixture.sql
\ir ../../migrations/20261010000000_api_key_requests.sql

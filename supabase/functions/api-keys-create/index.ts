import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { createApiKeysCreateHandler } from "./handler.ts";

// The logic lives in handler.ts with its I/O injected, so it can be tested against an
// in-memory backend (supabase/tests/edge-functions). This file only binds it to the edge runtime.
Deno.serve(createApiKeysCreateHandler({
  env: (name) => Deno.env.get(name),
  fetch: (input, init) => fetch(input, init),
  createClient,
}));

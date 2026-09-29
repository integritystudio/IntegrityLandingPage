import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { createApiKeysSetStatusHandler } from "./handler.ts";

// Logic and its tests live in handler.ts and supabase/tests/edge-functions; this file only
// binds the handler to the edge runtime.
Deno.serve(createApiKeysSetStatusHandler({
  env: (name) => Deno.env.get(name),
  fetch: (input, init) => fetch(input, init),
  createClient,
}));

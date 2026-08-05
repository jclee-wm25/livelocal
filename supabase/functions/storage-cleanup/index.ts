import { createClient } from "npm:@supabase/supabase-js@2.112.0";

type CleanupJob = {
  id: string;
  bucket_id: string;
  source_path: string;
  action: "delete" | "rehome";
  destination_path: string | null;
  stage:
    | "delete_object"
    | "rehome_copy"
    | "rehome_remove"
    | "rehome_discard";
  lock_token: string;
};

const jsonHeaders = { "content-type": "application/json; charset=utf-8" };

function secretsMatch(provided: string | null, expected: string): boolean {
  if (provided === null || provided.length !== expected.length) return false;
  let difference = 0;
  for (let index = 0; index < expected.length; index += 1) {
    difference |= provided.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return difference === 0;
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message.slice(0, 1000);
  return String(error).slice(0, 1000);
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: jsonHeaders,
    });
  }

  const projectUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const cleanupSecret = Deno.env.get("STORAGE_CLEANUP_CRON_SECRET");
  if (!projectUrl || !serviceRoleKey || !cleanupSecret) {
    return new Response(
      JSON.stringify({ error: "Storage cleanup worker is not configured" }),
      { status: 503, headers: jsonHeaders },
    );
  }
  if (!secretsMatch(request.headers.get("x-cleanup-secret"), cleanupSecret)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const client = createClient(projectUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  let processed = 0;
  let failed = 0;
  const failures: string[] = [];

  try {
    // The first pass identifies due accounts and queues their objects. A
    // second pass below completes accounts whose object jobs finish now.
    const { error: initialFinalizerError } = await client.rpc(
      "finalize_due_account_deletions",
    );
    if (initialFinalizerError) throw initialFinalizerError;

    const { data, error } = await client.rpc("claim_storage_cleanup_jobs", {
      p_limit: 50,
    });
    if (error) throw error;

    for (const job of (data ?? []) as CleanupJob[]) {
      try {
        const bucket = client.storage.from(job.bucket_id);
        if (job.action === "rehome" && job.stage === "rehome_copy") {
          if (!job.destination_path) {
            throw new Error("Rehome destination is missing");
          }
          const { error: copyError } = await bucket.copy(
            job.source_path,
            job.destination_path,
          );
          // A previous timed-out attempt may already have copied the
          // immutable destination. Job UUID paths make another collision
          // practically impossible.
          if (copyError && String(copyError.statusCode) !== "409") {
            throw copyError;
          }
          const { data: retained, error: activateError } = await client.rpc(
            "activate_storage_rehome_job",
            { p_job_id: job.id, p_lock_token: job.lock_token },
          );
          if (activateError) throw activateError;
          if (retained !== true) {
            const { error: destinationDeleteError } = await bucket.remove([
              job.destination_path,
            ]);
            if (destinationDeleteError) throw destinationDeleteError;
          }
        } else if (
          job.action === "rehome" &&
          job.stage === "rehome_discard" &&
          job.destination_path
        ) {
          const { error: destinationDeleteError } = await bucket.remove([
            job.destination_path,
          ]);
          if (destinationDeleteError) throw destinationDeleteError;
        }

        const { error: removeError } = await bucket.remove([job.source_path]);
        if (removeError) throw removeError;
        const { error: completeError } = await client.rpc(
          "complete_storage_cleanup_job",
          { p_job_id: job.id, p_lock_token: job.lock_token },
        );
        if (completeError) throw completeError;
        processed += 1;
      } catch (jobError) {
        failed += 1;
        failures.push(job.id);
        const { error: recordError } = await client.rpc(
          "fail_storage_cleanup_job",
          {
            p_job_id: job.id,
            p_lock_token: job.lock_token,
            p_error: errorMessage(jobError),
          },
        );
        if (recordError) throw recordError;
      }
    }

    const { data: finalized, error: finalizerError } = await client.rpc(
      "finalize_due_account_deletions",
    );
    if (finalizerError) throw finalizerError;

    return new Response(
      JSON.stringify({ processed, failed, finalized, failures }),
      { status: failed === 0 ? 200 : 500, headers: jsonHeaders },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: "Storage cleanup run failed",
        detail: errorMessage(error),
        processed,
        failed,
        failures,
      }),
      { status: 500, headers: jsonHeaders },
    );
  }
});

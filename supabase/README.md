# Local Supabase foundation

The files in this directory are the reproducible source of truth for the
LiveLocal backend. They have not been applied to a production project.

Prerequisites are the Supabase CLI and a Docker-compatible local runtime.

```sh
supabase start
supabase db reset
supabase test db
```

`db reset` is destructive to the local Supabase database only. Never link this
workspace to a production project when running local reset commands.

The first migration establishes identity, server-owned roles and account access
state. Feature tables are added by their vertical slices; a planned table must
not be assumed to exist until its migration is present.

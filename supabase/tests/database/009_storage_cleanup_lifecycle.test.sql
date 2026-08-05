begin;

create extension if not exists pgtap with schema extensions;
select plan(25);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  'a0000000-0000-4000-8000-000000000001',
  'authenticated', 'authenticated', 'cleanup-owner@example.test',
  crypt('test-password', gen_salt('bf')), clock_timestamp(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"Cleanup Owner"}'::jsonb,
  clock_timestamp(), clock_timestamp()
);

insert into storage.objects (bucket_id, name, owner, owner_id)
values
  (
    'avatars',
    'a0000000-0000-4000-8000-000000000001/avatar.jpg',
    'a0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001'
  ),
  (
    'spot-images',
    'a0000000-0000-4000-8000-000000000001/draft.jpg',
    'a0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001'
  ),
  (
    'spot-images',
    'a0000000-0000-4000-8000-000000000001/public.jpg',
    'a0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001'
  );

update public.profiles
set avatar_path = 'a0000000-0000-4000-8000-000000000001/avatar.jpg'
where id = 'a0000000-0000-4000-8000-000000000001';
update public.account_access
set status = 'restricted', ends_at = clock_timestamp() + interval '1 hour'
where user_id = 'a0000000-0000-4000-8000-000000000001';

select set_config(
  'request.jwt.claims',
  '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select ok(
  not has_table_privilege(
    'authenticated', 'private.storage_cleanup_jobs', 'select'
  ),
  'mobile roles cannot inspect private cleanup jobs'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.claim_storage_cleanup_jobs(integer)', 'execute'
  ),
  'mobile roles cannot claim privileged cleanup work'
);
select throws_ok(
  $$delete from storage.objects
    where bucket_id = 'avatars'
      and name = 'a0000000-0000-4000-8000-000000000001/avatar.jpg'$$,
  '42501',
  'Direct deletion from storage tables is not allowed. Use the Storage API instead.',
  'a stale restricted session cannot bypass the Storage delete policy'
);
select is(
  (select count(*) from storage.objects
    where bucket_id = 'spot-images'
      and name = 'a0000000-0000-4000-8000-000000000001/draft.jpg'),
  0::bigint,
  'a restricted session cannot read an unpublished owner object'
);

reset role;
select is(
  (select count(*) from storage.objects
    where bucket_id = 'avatars'
      and name = 'a0000000-0000-4000-8000-000000000001/avatar.jpg'),
  1::bigint,
  'restricted-account Storage object remains intact'
);
update public.account_access
set status = 'active', ends_at = null
where user_id = 'a0000000-0000-4000-8000-000000000001';
select set_config(
  'request.jwt.claims',
  '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner, owner_id)
    values (
      'avatars',
      'a0000000-0000-4000-8000-000000000001/nested/avatar.png',
      'a0000000-0000-4000-8000-000000000001',
      'a0000000-0000-4000-8000-000000000001'
    )$$,
  '42501', null,
  'avatar policy rejects nested object paths'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner, owner_id)
    values (
      'spot-images',
      'a0000000-0000-4000-8000-000000000099/foreign.png',
      'a0000000-0000-4000-8000-000000000001',
      'a0000000-0000-4000-8000-000000000001'
    )$$,
  '42501', null,
  'spot media policy rejects a foreign ownership path'
);
select lives_ok(
  $$select public.create_spot_draft(
    'Temporary Cleanup Garden', 'Park',
    'A sufficiently detailed draft used to verify supported object cleanup.',
    'Penang', 'George Town', '12 Cleanup Test Road', '$',
    'Morning', 'Walk through the temporary garden',
    'a0000000-0000-4000-8000-000000000001/draft.jpg',
    5.4141, 100.3288
  )$$,
  'owner creates a draft with an uploaded object'
);
select lives_ok(
  $$select public.delete_spot_draft(
    (select current_revision_id from public.spots where owner_id = auth.uid())
  )$$,
  'owner discards the draft through the application RPC'
);

reset role;
select is(
  (select count(*) from storage.objects
    where bucket_id = 'spot-images'
      and name = 'a0000000-0000-4000-8000-000000000001/draft.jpg'),
  1::bigint,
  'draft discard does not directly mutate Storage metadata'
);
select is(
  (select count(*) from private.storage_cleanup_jobs
    where source_path = 'a0000000-0000-4000-8000-000000000001/draft.jpg'
      and action = 'delete' and status = 'pending'),
  1::bigint,
  'draft discard queues supported Storage API deletion'
);

insert into public.spots (
  id, owner_id
) values (
  'a1000000-0000-4000-8000-000000000001',
  'a0000000-0000-4000-8000-000000000001'
);
insert into public.spot_revisions (
  id, spot_id, revision_number, author_id, status, name, category,
  description, state, city, address, price_range, best_time, things_to_do,
  image_path, latitude, longitude, image_rights_confirmed_at
) values (
  'a2000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001', 1,
  'a0000000-0000-4000-8000-000000000001', 'approved',
  'Retained Public Garden', 'Park',
  'A verified public garden retained after its submitter deletes an account.',
  'Penang', 'George Town', '14 Cleanup Test Road', '$', 'Morning',
  'Walk through the retained public garden',
  'a0000000-0000-4000-8000-000000000001/public.jpg',
  5.4142, 100.3289, clock_timestamp()
);
update public.spots set
  current_revision_id = 'a2000000-0000-4000-8000-000000000001',
  approved_revision_id = 'a2000000-0000-4000-8000-000000000001'
where id = 'a1000000-0000-4000-8000-000000000001';
insert into public.published_spots (
  id, revision_id, name, category, description, state, city, address,
  price_range, best_time, things_to_do, image_path, latitude, longitude
) values (
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'Retained Public Garden', 'Park',
  'A verified public garden retained after its submitter deletes an account.',
  'Penang', 'George Town', '14 Cleanup Test Road', '$', 'Morning',
  'Walk through the retained public garden',
  'a0000000-0000-4000-8000-000000000001/public.jpg',
  5.4142, 100.3289
);

update public.account_access set status = 'deletion_pending',
  deletion_scheduled_for = clock_timestamp() - interval '1 minute'
where user_id = 'a0000000-0000-4000-8000-000000000001';
insert into public.account_deletion_requests (
  user_id, status, scheduled_for
) values (
  'a0000000-0000-4000-8000-000000000001', 'pending',
  clock_timestamp() - interval '1 minute'
);

select is(
  public.finalize_due_account_deletions(),
  0,
  'account finalization pauses while Storage API work is outstanding'
);
select is(
  (select count(*) from auth.users
    where id = 'a0000000-0000-4000-8000-000000000001'),
  1::bigint,
  'Auth identity remains until owned objects are removed or re-homed'
);
select is(
  (select count(*) from private.storage_cleanup_jobs
    where owner_id = 'a0000000-0000-4000-8000-000000000001'
      and status = 'pending'),
  3::bigint,
  'avatar, discarded draft, and retained public image have cleanup jobs'
);
select is(
  (select action from private.storage_cleanup_jobs
    where source_path = 'a0000000-0000-4000-8000-000000000001/public.jpg'),
  'rehome',
  'approved public media is re-homed instead of deleted'
);
select is(
  (select count(*) from public.claim_storage_cleanup_jobs(50)),
  3::bigint,
  'service worker atomically claims all outstanding jobs'
);

-- These direct metadata changes are test fixtures simulating successful
-- Storage API copy/remove responses. Production code never performs them.
insert into storage.objects (bucket_id, name, owner, owner_id)
select bucket_id, destination_path, null, null
from private.storage_cleanup_jobs
where action = 'rehome' and status = 'processing';
select lives_ok(
  $$select public.activate_storage_rehome_job(id, lock_token)
    from private.storage_cleanup_jobs
    where action = 'rehome' and status = 'processing'$$,
  'service worker activates the retained copy before deleting the source'
);
select ok(
  (select image_path not like
      'a0000000-0000-4000-8000-000000000001%'
    from public.published_spots
    where id = 'a1000000-0000-4000-8000-000000000001'),
  'public retained media path no longer contains the deleted user identifier'
);

select throws_ok(
  $$select public.complete_storage_cleanup_job(id, lock_token)
    from private.storage_cleanup_jobs
    where status = 'processing'
    order by created_at
    limit 1$$,
  '22023',
  'Source object still exists',
  'worker cannot acknowledge cleanup while the Storage object still exists'
);
select lives_ok(
  $$select public.fail_storage_cleanup_job(
      id, lock_token, 'Synthetic Storage API failure'
    )
    from private.storage_cleanup_jobs
    where status = 'processing'
    order by created_at
    limit 1$$,
  'worker can record a retryable Storage API failure'
);
select is(
  (select count(*) from private.storage_cleanup_jobs
    where status = 'failed' and lock_token is null and locked_at is null),
  1::bigint,
  'failed cleanup releases its worker lock for a later retry'
);
select is(
  public.finalize_due_account_deletions(),
  0,
  'account finalization remains paused while Storage cleanup is incomplete'
);
select is(
  (select count(*) from auth.users
    where id = 'a0000000-0000-4000-8000-000000000001'),
  1::bigint,
  'Auth identity remains while Storage cleanup is incomplete'
);
select is(
  (select count(*) from public.published_spots
    where id = 'a1000000-0000-4000-8000-000000000001'),
  1::bigint,
  'approved public spot remains available while cleanup is retried'
);
select is(
  (select count(*) from private.storage_cleanup_jobs
    where owner_id = 'a0000000-0000-4000-8000-000000000001'
      and status in ('processing', 'failed')),
  3::bigint,
  'all incomplete per-user cleanup jobs remain auditable and retryable'
);

select * from finish();
rollback;

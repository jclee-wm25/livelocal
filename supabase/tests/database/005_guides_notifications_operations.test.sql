begin;

create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '60000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'operations-admin@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Operations Admin"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '60000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'content-owner@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Content Owner"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '60000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'unrelated-user@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Unrelated User"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  );

update public.user_roles
set revoked_at = clock_timestamp(),
    revoked_by = '60000000-0000-0000-0000-000000000001'
where user_id = '60000000-0000-0000-0000-000000000001'
  and revoked_at is null;
insert into public.user_roles (user_id, role, granted_by)
values (
  '60000000-0000-0000-0000-000000000001', 'admin',
  '60000000-0000-0000-0000-000000000001'
);

insert into storage.objects (bucket_id, name, owner, owner_id)
values (
  'spot-images',
  '60000000-0000-0000-0000-000000000002/notification-test.jpg',
  '60000000-0000-0000-0000-000000000002',
  '60000000-0000-0000-0000-000000000002'
);

set local role anon;
select is(
  (select count(*) from public.published_guides),
  0::bigint,
  'guest initially sees no published guides'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"60000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$select public.admin_save_guide_draft(
    null, 'Unauthorized guide', 'George Town', 'Penang',
    'A complete but unauthorized guide overview for testing.',
    '["First stop"]'::jsonb, '["Walk to the first stop"]'::jsonb,
    '2 hours', null
  )$$,
  '42501', 'Admin permission required',
  'tourist cannot create a guide draft'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"60000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.admin_save_guide_draft(
    null, 'George Town morning walk', 'George Town', 'Penang',
    'A calm route through public heritage streets and local food stops.',
    '["Heritage square","Morning market"]'::jsonb,
    '["Start at the heritage square","Walk east to the morning market"]'::jsonb,
    '3 hours', null
  )$$,
  'admin creates a versioned guide draft'
);
select lives_ok(
  $$select public.admin_publish_guide_revision(
    (select current_revision_id from public.guides limit 1),
    'Route details and public locations verified.', 1
  )$$,
  'admin publishes the guide with a reason and expected version'
);

reset role;
set local role anon;
select is(
  (select count(*) from public.published_guides),
  1::bigint,
  'guest can browse the published guide projection'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"60000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.create_spot_draft(
    'Notification Test Garden', 'Park',
    'A detailed public garden description for notification testing.',
    'Penang', 'George Town', '2 Notification Test Road', '$',
    'Morning', 'Walk through the garden',
    '60000000-0000-0000-0000-000000000002/notification-test.jpg',
    5.4141, 100.3288
  )$$,
  'content owner creates a spot draft'
);
select lives_ok(
  $$select public.confirm_spot_image_rights(
    (select current_revision_id from public.spots where owner_id = auth.uid())
  )$$,
  'content owner confirms image rights before submission'
);
select public.accept_current_ugc_rules();
select lives_ok(
  $$select public.submit_spot_revision(
    (select current_revision_id from public.spots where owner_id = auth.uid()),
    null
  )$$,
  'content owner submits the spot'
);
select throws_ok(
  $$insert into public.notifications (user_id, type, title, body)
    values (auth.uid(), 'fake', 'Fake notification', 'Not permitted')$$,
  '42501', null,
  'client cannot manufacture notifications'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"60000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.admin_moderate_spot_revision(
    (select id from public.spot_revisions where status = 'submitted'),
    'approved', 'Location and description verified.', 1
  )$$,
  'admin approval creates the owner notification transactionally'
);
select lives_ok(
  $$select public.admin_platform_statistics()$$,
  'admin can load server-calculated platform statistics'
);
select ok(
  jsonb_array_length(public.admin_list_audit_events(50, null)) >= 1,
  'admin can load paginated audit history'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"60000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*) from public.notifications where read_at is null),
  1::bigint,
  'content owner sees one unread approval notification'
);
select lives_ok(
  $$select public.mark_notifications_read(null)$$,
  'owner can mark their notifications read'
);
select is(
  (select count(*) from public.notifications where read_at is null),
  0::bigint,
  'mark-all-read updates the owner notification history'
);
select throws_ok(
  $$select public.admin_platform_statistics()$$,
  '42501', 'Admin permission required',
  'tourist cannot read admin statistics'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"60000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*) from public.notifications),
  0::bigint,
  'another user cannot read the owner notifications'
);
select throws_ok(
  $$select public.admin_list_audit_events(50, null)$$,
  '42501', 'Admin permission required',
  'non-admin cannot read audit history'
);

reset role;
update public.account_access set status = 'deletion_pending',
  deletion_scheduled_for = clock_timestamp() - interval '1 minute'
where user_id = '60000000-0000-0000-0000-000000000002';
insert into public.account_deletion_requests (
  user_id, status, scheduled_for
) values (
  '60000000-0000-0000-0000-000000000002', 'pending',
  clock_timestamp() - interval '1 minute'
);
select is(
  public.finalize_due_account_deletions(),
  0,
  'account finalization pauses until the Storage API worker completes'
);
select is(
  (select count(*) from auth.users
    where id = '60000000-0000-0000-0000-000000000002'),
  1::bigint,
  'Auth identity remains while owned Storage objects exist'
);
select is(
  (select count(*) from public.published_spots),
  1::bigint,
  'approved public spot remains available while cleanup is pending'
);
select is(
  (select count(*) from private.storage_cleanup_jobs
    where owner_id = '60000000-0000-0000-0000-000000000002'
      and action = 'rehome' and status = 'pending'),
  1::bigint,
  'due deletion queues retained public media for Storage API re-homing'
);

select * from finish();
rollback;

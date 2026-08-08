begin;

create extension if not exists pgtap with schema extensions;
select plan(38);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '90000000-0000-0000-0000-000000000001', 'authenticated',
    'authenticated', 'revision-admin@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Revision Admin"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '90000000-0000-0000-0000-000000000002', 'authenticated',
    'authenticated', 'spot-owner@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Spot Owner"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '90000000-0000-0000-0000-000000000003', 'authenticated',
    'authenticated', 'restaurant-owner@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Restaurant Owner"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '90000000-0000-0000-0000-000000000004', 'authenticated',
    'authenticated', 'unrelated-owner@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Unrelated Account"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  );

update public.user_roles
set revoked_at = clock_timestamp(),
    revoked_by = '90000000-0000-0000-0000-000000000001'
where user_id in (
  '90000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000003'
) and revoked_at is null;
insert into public.user_roles (user_id, role, granted_by)
values
  (
    '90000000-0000-0000-0000-000000000001', 'admin',
    '90000000-0000-0000-0000-000000000001'
  ),
  (
    '90000000-0000-0000-0000-000000000003', 'influencer',
    '90000000-0000-0000-0000-000000000001'
  );

insert into storage.objects (bucket_id, name, owner)
values
  (
    'spot-images',
    '90000000-0000-0000-0000-000000000002/original-spot.jpg',
    '90000000-0000-0000-0000-000000000002'
  ),
  (
    'spot-images',
    '90000000-0000-0000-0000-000000000002/revised-spot.jpg',
    '90000000-0000-0000-0000-000000000002'
  ),
  (
    'restaurant-images',
    '90000000-0000-0000-0000-000000000003/original-restaurant.jpg',
    '90000000-0000-0000-0000-000000000003'
  ),
  (
    'restaurant-images',
    '90000000-0000-0000-0000-000000000003/revised-restaurant.jpg',
    '90000000-0000-0000-0000-000000000003'
  );

select set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.create_spot_draft(
    'Original Revision Garden', 'Park / Walkway',
    'A detailed original description for owner revision testing.',
    'Penang', 'George Town', '90 Revision Test Road', '$',
    'Morning', 'Walk through the original garden',
    '90000000-0000-0000-0000-000000000002/original-spot.jpg',
    5.4141, 100.3288
  )$$,
  'spot owner creates the original draft'
);
select lives_ok(
  $$select public.confirm_spot_image_rights(
    (select current_revision_id from public.spots where owner_id = auth.uid())
  )$$,
  'spot owner confirms original image rights'
);
select public.accept_current_ugc_rules();
select lives_ok(
  $$select public.submit_spot_revision(
    (select current_revision_id from public.spots where owner_id = auth.uid()),
    null
  )$$,
  'spot owner submits the original revision'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.admin_moderate_spot_revision(
    (select current_revision_id from public.spots limit 1),
    'approved', 'Original spot details verified.', 1
  )$$,
  'admin approves the original spot revision'
);

reset role;
set local role anon;
select is(
  (select name from public.published_spots limit 1),
  'Original Revision Garden',
  'the original spot is public'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*) from public.list_my_spot_submissions()),
  1::bigint,
  'owner can list only their current spot submissions'
);
select lives_ok(
  $$select public.save_spot_revision_draft(
    (select current_revision_id from public.spots where owner_id = auth.uid()),
    'Revised Revision Garden', 'Park / Walkway',
    'A detailed revised description that requires another decision.',
    'Penang', 'George Town', '90 Revision Test Road', '$',
    'Late morning', 'Walk through the revised garden',
    '90000000-0000-0000-0000-000000000002/revised-spot.jpg',
    5.4141, 100.3288
  )$$,
  'owner creates a draft revision from approved content'
);
select is(
  (select status::text from public.list_my_spot_submissions()),
  'draft',
  'the owner list shows the new draft'
);
select is(
  (select name from public.published_spots limit 1),
  'Original Revision Garden',
  'the prior approved spot stays public while revision is draft'
);
select lives_ok(
  $$select public.confirm_spot_image_rights(
    (select current_revision_id from public.spots where owner_id = auth.uid())
  )$$,
  'owner confirms rights for the revised image'
);
select lives_ok(
  $$select public.submit_spot_revision(
    (select current_revision_id from public.spots where owner_id = auth.uid()),
    null
  )$$,
  'owner submits the revised spot'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$select public.save_spot_revision_draft(
    (select current_revision_id from public.spots limit 1),
    'Hijacked Garden', 'Park / Walkway',
    'An unrelated account must not be able to revise this content.',
    'Penang', 'George Town', '90 Revision Test Road', '$',
    'Morning', 'Attempt an unauthorized edit', null, 5.4141, 100.3288
  )$$,
  'P0002', 'Current owned spot revision not found',
  'an unrelated user cannot revise another owner spot'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.admin_moderate_spot_revision(
    (select current_revision_id from public.spots limit 1),
    'approved', 'Revised spot details verified.', 2
  )$$,
  'admin approves the revised spot using the current version'
);
select is(
  (select name from public.published_spots limit 1),
  'Revised Revision Garden',
  'the approved revision replaces the public spot projection'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $sql$select public.create_restaurant_draft(
    'Original Revision Kitchen', '91 Revision Test Road', 'Penang',
    'George Town', 'Malaysian', '$$', 'Noodles and local coffee',
    'https://www.instagram.com/revision-kitchen',
    '90000000-0000-0000-0000-000000000003/original-restaurant.jpg',
    5.4142, 100.3289
  )$sql$,
  'creator creates the original restaurant draft'
);
select lives_ok(
  $$select public.submit_restaurant_revision(
    (select current_revision_id from public.restaurants where owner_id = auth.uid()),
    null
  )$$,
  'creator submits the original restaurant revision'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.admin_moderate_restaurant_revision(
    (select current_revision_id from public.restaurants limit 1),
    'approved', 'Original restaurant details verified.', 1
  )$$,
  'admin approves the original restaurant revision'
);
select is(
  (select name from public.published_restaurants limit 1),
  'Original Revision Kitchen',
  'the original restaurant is public'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $sql$select public.save_restaurant_revision_draft(
    (select current_revision_id from public.restaurants where owner_id = auth.uid()),
    'Revised Revision Kitchen', '91 Revision Test Road', 'Penang',
    'George Town', 'Malaysian', '$$', 'Revised noodles and coffee',
    'https://www.instagram.com/revision-kitchen',
    '90000000-0000-0000-0000-000000000003/revised-restaurant.jpg',
    5.4142, 100.3289
  )$sql$,
  'creator creates a draft revision from an approved restaurant'
);
select is(
  (select name from public.published_restaurants limit 1),
  'Original Revision Kitchen',
  'the prior approved restaurant remains public while editing'
);
select lives_ok(
  $$select public.submit_restaurant_revision(
    (select current_revision_id from public.restaurants where owner_id = auth.uid()),
    null
  )$$,
  'creator submits the revised restaurant'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.admin_moderate_restaurant_revision(
    (select current_revision_id from public.restaurants limit 1),
    'approved', 'Revised restaurant details verified.', 2
  )$$,
  'admin approves the revised restaurant using the current version'
);
select is(
  (select name from public.published_restaurants limit 1),
  'Revised Revision Kitchen',
  'the approved revision replaces the public restaurant projection'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $sql$select public.save_restaurant_revision_draft(
    (select current_revision_id from public.restaurants where owner_id = auth.uid()),
    'Discarded Restaurant Draft', '91 Revision Test Road', 'Penang',
    'George Town', 'Malaysian', '$$', 'Temporary edit for discard testing',
    'https://www.instagram.com/revision-kitchen', null, 5.4142, 100.3289
  )$sql$,
  'creator starts another restaurant revision'
);
select lives_ok(
  $$select public.submit_restaurant_revision(
    (select current_revision_id from public.restaurants where owner_id = auth.uid())
  )$$,
  'creator submits the revision that will be withdrawn'
);
select lives_ok(
  $$select public.withdraw_my_restaurant_revision(
    (select current_revision_id from public.restaurants where owner_id = auth.uid())
  )$$,
  'creator withdraws a restaurant revision awaiting review'
);
select is(
  (
    select entity.current_revision_id = entity.approved_revision_id
    from public.restaurants entity where entity.owner_id = auth.uid()
  ),
  true,
  'withdraw restores the approved restaurant as current'
);
select lives_ok(
  $sql$select public.save_restaurant_revision_draft(
    (select current_revision_id from public.restaurants where owner_id = auth.uid()),
    'Discarded Restaurant Draft', '91 Revision Test Road', 'Penang',
    'George Town', 'Malaysian', '$$', 'Another temporary discard edit',
    'https://www.instagram.com/revision-kitchen', null, 5.4142, 100.3289
  )$sql$,
  'creator starts a new restaurant draft for discard testing'
);
select lives_ok(
  $$select public.delete_restaurant_draft(
    (select current_revision_id from public.restaurants where owner_id = auth.uid())
  )$$,
  'creator discards the current restaurant draft'
);
select is(
  (
    select entity.current_revision_id = entity.approved_revision_id
    from public.restaurants entity where entity.owner_id = auth.uid()
  ),
  true,
  'discard restores the approved restaurant as current'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.save_spot_revision_draft(
    (select current_revision_id from public.spots where owner_id = auth.uid()),
    'Discarded Spot Draft', 'Park / Walkway',
    'A temporary detailed edit created only for discard testing.',
    'Penang', 'George Town', '90 Revision Test Road', '$',
    'Morning', 'Discard this temporary edit', null, 5.4141, 100.3288
  )$$,
  'spot owner starts another revision'
);
select lives_ok(
  $$select public.confirm_spot_image_rights(
    (select current_revision_id from public.spots where owner_id = auth.uid())
  )$$,
  'spot owner renews image-rights confirmation for the new revision'
);
select lives_ok(
  $$select public.submit_spot_revision(
    (select current_revision_id from public.spots where owner_id = auth.uid())
  )$$,
  'spot owner submits the revision that will be withdrawn'
);
select lives_ok(
  $$select public.withdraw_my_spot_revision(
    (select current_revision_id from public.spots where owner_id = auth.uid())
  )$$,
  'spot owner withdraws a revision awaiting review'
);
select is(
  (
    select entity.current_revision_id = entity.approved_revision_id
    from public.spots entity where entity.owner_id = auth.uid()
  ),
  true,
  'withdraw restores the approved spot as current'
);
select lives_ok(
  $$select public.save_spot_revision_draft(
    (select current_revision_id from public.spots where owner_id = auth.uid()),
    'Discarded Spot Draft', 'Park / Walkway',
    'Another temporary detailed edit created only for discard testing.',
    'Penang', 'George Town', '90 Revision Test Road', '$',
    'Morning', 'Discard this temporary edit again', null, 5.4141, 100.3288
  )$$,
  'spot owner starts a new draft for discard testing'
);
select lives_ok(
  $$select public.delete_spot_draft(
    (select current_revision_id from public.spots where owner_id = auth.uid())
  )$$,
  'spot owner discards the current revision draft'
);
select is(
  (
    select entity.current_revision_id = entity.approved_revision_id
    from public.spots entity where entity.owner_id = auth.uid()
  ),
  true,
  'discard restores the approved spot as current'
);

select * from finish();
rollback;

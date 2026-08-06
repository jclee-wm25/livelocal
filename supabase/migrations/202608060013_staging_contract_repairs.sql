begin;

-- PostgreSQL standard-conforming strings treat a doubled backslash as a
-- literal backslash. The earlier validators therefore rejected normal HTTPS
-- hosts and object names ending in .jpg/.png/.webp.
create or replace function private.is_supported_social_url(
  p_url text,
  p_platform text default null
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select p_url ~* '^https://(www\.)?(tiktok\.com|instagram\.com)(/|$)'
    and (
      p_platform is null
      or (p_platform = 'tiktok' and p_url ~* '^https://(www\.)?tiktok\.com(/|$)')
      or (p_platform = 'instagram' and p_url ~* '^https://(www\.)?instagram\.com(/|$)')
    );
$$;

revoke all on function private.is_supported_social_url(text, text)
  from public, anon, authenticated, service_role;

create or replace function public.create_spot_draft(
  p_name text,
  p_category text,
  p_description text,
  p_state text,
  p_city text,
  p_address text,
  p_price_range text,
  p_best_time text,
  p_things_to_do text,
  p_image_path text default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  created_spot_id uuid;
  created_revision_id uuid;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501',
      message = 'Account cannot create spot drafts';
  end if;
  if p_image_path is not null
      and p_image_path !~ (
        '^' || actor::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$'
      ) then
    raise exception using errcode = '22023',
      message = 'Invalid spot image path';
  end if;

  insert into public.spots (owner_id)
  values (actor)
  returning id into created_spot_id;

  insert into public.spot_revisions (
    spot_id, revision_number, author_id, name, category, description,
    state, city, address, price_range, best_time, things_to_do,
    image_path, latitude, longitude
  ) values (
    created_spot_id, 1, actor, btrim(p_name), btrim(p_category),
    btrim(p_description), btrim(p_state), btrim(p_city), btrim(p_address),
    p_price_range, btrim(p_best_time), btrim(p_things_to_do),
    p_image_path, p_latitude, p_longitude
  ) returning id into created_revision_id;

  update public.spots
  set current_revision_id = created_revision_id
  where id = created_spot_id;

  return jsonb_build_object(
    'spot_id', created_spot_id,
    'revision_id', created_revision_id,
    'image_path', p_image_path,
    'status', 'draft',
    'probable_duplicates', private.probable_spot_duplicates(
      p_name, p_address, p_latitude, p_longitude, created_spot_id
    )
  );
end;
$$;

create or replace function public.create_restaurant_draft(
  p_name text,
  p_address text,
  p_state text,
  p_city text,
  p_cuisine_type text,
  p_price_range text,
  p_reviewed_dishes text,
  p_social_media_url text,
  p_cover_image_path text default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  created_id uuid;
  revision_id uuid;
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'influencer' then
    raise exception using errcode = '42501',
      message = 'Approved creator role required';
  end if;
  if not private.is_supported_social_url(p_social_media_url, null) then
    raise exception using errcode = '22023',
      message = 'Unsupported social URL';
  end if;
  if p_cover_image_path is not null
      and p_cover_image_path !~ (
        '^' || auth.uid()::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$'
      ) then
    raise exception using errcode = '22023',
      message = 'Invalid restaurant image path';
  end if;

  insert into public.restaurants (owner_id)
  values (auth.uid())
  returning id into created_id;

  insert into public.restaurant_revisions (
    restaurant_id, revision_number, author_id, name, address, state, city,
    cuisine_type, price_range, reviewed_dishes, social_media_url,
    cover_image_path, latitude, longitude
  ) values (
    created_id, 1, auth.uid(), btrim(p_name), btrim(p_address), btrim(p_state),
    btrim(p_city), btrim(p_cuisine_type), p_price_range,
    btrim(p_reviewed_dishes), btrim(p_social_media_url), p_cover_image_path,
    p_latitude, p_longitude
  ) returning id into revision_id;

  update public.restaurants
  set current_revision_id = revision_id
  where id = created_id;

  return jsonb_build_object(
    'restaurant_id', created_id,
    'revision_id', revision_id,
    'image_path', p_cover_image_path,
    'status', 'draft',
    'probable_duplicates', private.probable_restaurant_duplicates(
      p_name, p_address, p_latitude, p_longitude, created_id
    )
  );
end;
$$;

-- Storage policies need a role predicate, but exposing current_role(uuid)
-- would let mobile clients probe arbitrary users. This helper can answer only
-- for auth.uid().
create or replace function private.current_user_has_role(
  expected_role public.app_role
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.user_roles role_assignment
    where role_assignment.user_id = auth.uid()
      and role_assignment.role = expected_role
      and role_assignment.revoked_at is null
  );
$$;

revoke all on function private.current_user_has_role(public.app_role)
  from public, anon, authenticated, service_role;
grant execute on function private.current_user_has_role(public.app_role)
  to authenticated;

-- Permanent platform bans must prevent a fresh GoTrue password session, not
-- merely rely on the Flutter session gate. Temporary restrictions still allow
-- sign-in so the user can see the decision and submit an appeal; every write
-- remains blocked by can_use_protected_features().
create or replace function private.sync_auth_ban_state()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, auth
as $$
begin
  update auth.users
  set banned_until = case
        when new.status = 'banned'
          then clock_timestamp() + interval '100 years'
        else null
      end,
      updated_at = clock_timestamp()
  where id = new.user_id;
  return new;
end;
$$;

revoke all on function private.sync_auth_ban_state()
  from public, anon, authenticated, service_role;

drop trigger if exists account_access_sync_auth_ban
  on public.account_access;
create trigger account_access_sync_auth_ban
after insert or update of status on public.account_access
for each row execute function private.sync_auth_ban_state();

drop policy if exists avatar_insert_own on storage.objects;
create policy avatar_insert_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and owner_id = auth.uid()::text
    and name ~ (
      '^' || auth.uid()::text || '/avatar\.(jpg|png|webp)$'
    )
    and private.can_use_protected_features()
  );

drop policy if exists avatar_update_own on storage.objects;
create policy avatar_update_own
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and owner_id = auth.uid()::text
    and name ~ (
      '^' || auth.uid()::text || '/avatar\.(jpg|png|webp)$'
    )
    and private.can_use_protected_features()
  )
  with check (
    bucket_id = 'avatars'
    and owner_id = auth.uid()::text
    and name ~ (
      '^' || auth.uid()::text || '/avatar\.(jpg|png|webp)$'
    )
    and private.can_use_protected_features()
  );

drop policy if exists avatar_delete_own on storage.objects;
create policy avatar_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and owner_id = auth.uid()::text
    and name ~ (
      '^' || auth.uid()::text || '/avatar\.(jpg|png|webp)$'
    )
    and private.can_use_protected_features()
  );

drop policy if exists spot_image_insert_owner on storage.objects;
create policy spot_image_insert_owner
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'spot-images'
    and owner_id = auth.uid()::text
    and name ~ (
      '^' || auth.uid()::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$'
    )
    and private.can_use_protected_features()
  );

drop policy if exists spot_image_update_owner on storage.objects;
create policy spot_image_update_owner
  on storage.objects for update to authenticated
  using (
    bucket_id = 'spot-images'
    and owner_id = auth.uid()::text
    and name ~ (
      '^' || auth.uid()::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$'
    )
    and private.can_use_protected_features()
  )
  with check (
    bucket_id = 'spot-images'
    and owner_id = auth.uid()::text
    and name ~ (
      '^' || auth.uid()::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$'
    )
    and private.can_use_protected_features()
  );

drop policy if exists spot_image_delete_owner on storage.objects;
create policy spot_image_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'spot-images'
    and owner_id = auth.uid()::text
    and name ~ (
      '^' || auth.uid()::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$'
    )
    and private.can_use_protected_features()
  );

drop policy if exists spot_image_select_owner_admin on storage.objects;
create policy spot_image_select_owner_admin
  on storage.objects for select to authenticated
  using (
    bucket_id = 'spot-images'
    and (
      (
        owner_id = auth.uid()::text
        and name ~ (
          '^' || auth.uid()::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$'
        )
        and private.can_use_protected_features()
      )
      or private.is_admin()
    )
  );

drop policy if exists restaurant_image_insert_owner on storage.objects;
create policy restaurant_image_insert_owner
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'restaurant-images'
    and owner_id = auth.uid()::text
    and name ~ (
      '^' || auth.uid()::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$'
    )
    and private.can_use_protected_features()
    and private.current_user_has_role('influencer')
  );

drop policy if exists restaurant_image_delete_owner on storage.objects;
create policy restaurant_image_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'restaurant-images'
    and owner_id = auth.uid()::text
    and name ~ (
      '^' || auth.uid()::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$'
    )
    and private.can_use_protected_features()
    and private.current_user_has_role('influencer')
  );

drop policy if exists restaurant_image_select_owner_admin on storage.objects;
create policy restaurant_image_select_owner_admin
  on storage.objects for select to authenticated
  using (
    bucket_id = 'restaurant-images'
    and (
      (
        owner_id = auth.uid()::text
        and name ~ (
          '^' || auth.uid()::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$'
        )
        and private.can_use_protected_features()
        and private.current_user_has_role('influencer')
      )
      or private.is_admin()
    )
  );

-- Supabase applies explicit API-role grants when public functions are created.
-- Replace those broad defaults with the application RPC allowlist.
revoke execute on all functions in schema public
  from public, anon, authenticated, service_role;

grant execute on function public.list_active_discounts(uuid)
  to anon, authenticated;

grant execute on function public.get_my_account() to authenticated;
grant execute on function public.update_my_profile(text) to authenticated;
grant execute on function public.update_my_avatar(text) to authenticated;
grant execute on function public.request_account_deletion() to authenticated;
grant execute on function public.cancel_account_deletion() to authenticated;
grant execute on function public.submit_account_appeal(uuid, text, text)
  to authenticated;
grant execute on function public.admin_set_account_access(
  uuid, public.account_access_status, text, text, timestamptz, integer
) to authenticated;

grant execute on function public.create_spot_draft(
  text, text, text, text, text, text, text, text, text, text,
  double precision, double precision
) to authenticated;
grant execute on function public.submit_spot_revision(uuid, text)
  to authenticated;
grant execute on function public.delete_spot_draft(uuid) to authenticated;
grant execute on function public.revise_spot(uuid) to authenticated;
grant execute on function public.confirm_spot_image_rights(uuid)
  to authenticated;
grant execute on function public.list_my_spot_submissions() to authenticated;
grant execute on function public.withdraw_my_spot_revision(uuid)
  to authenticated;
grant execute on function public.save_spot_revision_draft(
  uuid, text, text, text, text, text, text, text, text, text, text,
  double precision, double precision
) to authenticated;
grant execute on function public.admin_moderate_spot_revision(
  uuid, text, text, integer
) to authenticated;

grant execute on function public.upsert_review(
  text, uuid, integer, text, integer
) to authenticated;
grant execute on function public.delete_my_review(uuid, integer)
  to authenticated;
grant execute on function public.report_content(
  text, uuid, text, text, boolean
) to authenticated;
grant execute on function public.admin_decide_review_report(
  uuid, text, text, integer
) to authenticated;
grant execute on function public.admin_decide_content_report(
  uuid, text, text, integer
) to authenticated;

grant execute on function public.save_influencer_application_draft(
  uuid, text, text, text, integer, text, text, boolean, integer
) to authenticated;
grant execute on function public.submit_influencer_application(uuid, integer)
  to authenticated;
grant execute on function public.withdraw_influencer_application(uuid, integer)
  to authenticated;
grant execute on function public.admin_decide_influencer_application(
  uuid, text, text, integer
) to authenticated;

grant execute on function public.create_restaurant_draft(
  text, text, text, text, text, text, text, text, text,
  double precision, double precision
) to authenticated;
grant execute on function public.submit_restaurant_revision(uuid, text)
  to authenticated;
grant execute on function public.delete_restaurant_draft(uuid)
  to authenticated;
grant execute on function public.list_my_restaurant_submissions()
  to authenticated;
grant execute on function public.withdraw_my_restaurant_revision(uuid)
  to authenticated;
grant execute on function public.save_restaurant_revision_draft(
  uuid, text, text, text, text, text, text, text, text, text,
  double precision, double precision
) to authenticated;
grant execute on function public.admin_moderate_restaurant_revision(
  uuid, text, text, integer
) to authenticated;
grant execute on function public.create_discount_draft(
  uuid, text, text, text, timestamptz, timestamptz
) to authenticated;
grant execute on function public.transition_discount(uuid, text, integer)
  to authenticated;
grant execute on function public.list_my_discounts() to authenticated;

grant execute on function public.set_saved_place(text, uuid, boolean)
  to authenticated;
grant execute on function public.update_my_discovery_location(
  text, text, text, double precision, double precision, integer
) to authenticated;
grant execute on function public.create_itinerary_from_saved(
  text, text, double precision, double precision, jsonb
) to authenticated;
grant execute on function public.replace_itinerary_order(uuid, jsonb, integer)
  to authenticated;
grant execute on function public.archive_itinerary(uuid, integer)
  to authenticated;

grant execute on function public.admin_save_guide_draft(
  uuid, text, text, text, text, jsonb, jsonb, text, integer
) to authenticated;
grant execute on function public.admin_publish_guide_revision(
  uuid, text, integer
) to authenticated;
grant execute on function public.admin_archive_guide(uuid, text, integer)
  to authenticated;
grant execute on function public.mark_notifications_read(uuid)
  to authenticated;

grant execute on function public.admin_list_accounts() to authenticated;
grant execute on function public.admin_list_moderation_cases()
  to authenticated;
grant execute on function public.admin_list_audit_events(integer)
  to authenticated;
grant execute on function public.admin_list_audit_events(
  integer, timestamptz
) to authenticated;
grant execute on function public.admin_platform_statistics()
  to authenticated;
grant execute on function public.admin_list_account_appeals()
  to authenticated;
grant execute on function public.admin_decide_account_appeal(
  uuid, text, text, integer
) to authenticated;

grant execute on function public.block_content_author(text, uuid)
  to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.list_my_blocked_users() to authenticated;

grant execute on function public.purge_expired_moderation_evidence()
  to service_role;
grant execute on function public.finalize_due_account_deletions()
  to service_role;
grant execute on function public.claim_storage_cleanup_jobs(integer)
  to service_role;
grant execute on function public.activate_storage_rehome_job(uuid, uuid)
  to service_role;
grant execute on function public.complete_storage_cleanup_job(uuid, uuid)
  to service_role;
grant execute on function public.fail_storage_cleanup_job(uuid, uuid, text)
  to service_role;

commit;

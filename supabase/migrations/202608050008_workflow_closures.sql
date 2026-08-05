begin;

-- Appeals are versioned so two administrators cannot decide the same case.
alter table public.account_appeals
  add column version integer not null default 1 check (version > 0);

-- Broken links are moderated independently from the public business record.
-- The validated historical URL remains in the revision for restricted audit
-- purposes while the public projection stops exposing it.
alter table public.published_restaurants
  add column social_link_status text not null default 'active'
    check (social_link_status in ('active', 'removed'));

alter table public.published_guides
  add column guide_version integer not null default 1 check (guide_version > 0);
update public.published_guides projection set guide_version = guide.version
from public.guides guide where guide.id = projection.id;

create or replace function private.sync_published_guide_version()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  new.guide_version := (
    select guide.version from public.guides guide where guide.id = new.id
  );
  return new;
end;
$$;

create trigger published_guide_version_sync
before insert or update on public.published_guides
for each row execute function private.sync_published_guide_version();

revoke all on function private.sync_published_guide_version() from public;

alter table public.moderation_cases
  drop constraint moderation_cases_reason_check;
alter table public.moderation_cases
  add constraint moderation_cases_reason_check check (
    reason in (
      'spam', 'harassment', 'hate', 'dangerous', 'misleading', 'privacy',
      'broken_link', 'closed', 'other'
    )
  );

create or replace function public.report_content(
  p_target_type text,
  p_target_id uuid,
  p_reason text,
  p_explanation text default null,
  p_hide_for_me boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare created public.moderation_cases;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot report content';
  end if;
  if p_reason not in (
      'spam', 'harassment', 'hate', 'dangerous', 'misleading', 'privacy',
      'broken_link', 'closed', 'other'
    ) then
    raise exception using errcode = '22023', message = 'Invalid report reason';
  end if;
  if p_target_type not in ('review', 'spot', 'restaurant', 'guide') then
    raise exception using errcode = '22023', message = 'Invalid report target';
  end if;
  if p_reason = 'broken_link' and p_target_type <> 'restaurant' then
    raise exception using errcode = '22023', message = 'Broken link target must be a restaurant';
  end if;
  if (
    select count(*) from public.moderation_cases mc
    where mc.reporter_id = auth.uid()
      and mc.created_at >= clock_timestamp() - interval '1 hour'
  ) >= 10 then
    raise exception using errcode = 'P0001', message = 'Report rate limit exceeded';
  end if;
  if (p_target_type = 'review' and not exists (
        select 1 from public.public_reviews where id = p_target_id
      )) or (p_target_type = 'spot' and not exists (
        select 1 from public.published_spots where id = p_target_id
      )) or (p_target_type = 'restaurant' and not exists (
        select 1 from public.published_restaurants where id = p_target_id
      )) or (p_target_type = 'guide' and not exists (
        select 1 from public.published_guides where id = p_target_id
      )) then
    raise exception using errcode = '23503', message = 'Report target is unavailable';
  end if;
  if (p_target_type = 'review' and exists (
        select 1 from public.reviews
        where id = p_target_id and user_id = auth.uid()
      )) or (p_target_type = 'spot' and exists (
        select 1 from public.spots
        where id = p_target_id and owner_id = auth.uid()
      )) or (p_target_type = 'restaurant' and exists (
        select 1 from public.restaurants
        where id = p_target_id and owner_id = auth.uid()
      )) or (p_target_type = 'guide' and exists (
        select 1 from public.guides
        where id = p_target_id and creator_id = auth.uid()
      )) then
    raise exception using errcode = '22023', message = 'Users cannot report their own content';
  end if;

  insert into public.moderation_cases (
    reporter_id, target_type, target_id, reason, explanation
  ) values (
    auth.uid(), p_target_type, p_target_id, p_reason,
    nullif(btrim(p_explanation), '')
  ) returning * into created;

  if p_hide_for_me then
    insert into public.hidden_content (user_id, target_type, target_id)
    values (auth.uid(), p_target_type, p_target_id)
    on conflict do nothing;
  end if;

  return jsonb_build_object(
    'id', created.id, 'status', created.status, 'version', created.version,
    'created_at', created.created_at
  );
end;
$$;

create or replace function public.admin_list_moderation_cases()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', mc.id,
      'reporter_id', mc.reporter_id,
      'target_type', mc.target_type,
      'target_id', mc.target_id,
      'reason', mc.reason,
      'explanation', mc.explanation,
      'status', mc.status,
      'version', mc.version,
      'created_at', mc.created_at,
      'target_preview', case
        when mc.target_type = 'review' then coalesce(pr.body, '[Review unavailable]')
        when mc.target_type = 'spot' then coalesce(ps.name, '[Spot unavailable]')
        when mc.target_type = 'restaurant' then coalesce(pe.name, '[Restaurant unavailable]')
        when mc.target_type = 'guide' then coalesce(pg.title, '[Guide unavailable]')
        else '[Preview unavailable]'
      end
    ) order by mc.created_at)
    from public.moderation_cases mc
    left join public.public_reviews pr
      on mc.target_type = 'review' and pr.id = mc.target_id
    left join public.published_spots ps
      on mc.target_type = 'spot' and ps.id = mc.target_id
    left join public.published_restaurants pe
      on mc.target_type = 'restaurant' and pe.id = mc.target_id
    left join public.published_guides pg
      on mc.target_type = 'guide' and pg.id = mc.target_id
    where mc.status in ('pending', 'under_review', 'escalated')
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_decide_content_report(
  p_case_id uuid,
  p_decision text,
  p_reason text,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare moderation_case public.moderation_cases;
declare target_review public.reviews;
declare next_version integer;
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  if p_decision not in ('upheld', 'dismissed', 'escalated')
      or char_length(btrim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'Invalid moderation decision';
  end if;
  select * into moderation_case from public.moderation_cases
  where id = p_case_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Moderation case not found';
  end if;
  if moderation_case.status not in ('pending', 'under_review', 'escalated') then
    raise exception using errcode = '22023', message = 'Report is already decided';
  end if;
  if moderation_case.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Report changed concurrently';
  end if;
  next_version := p_expected_version + 1;

  update public.moderation_cases set
    status = p_decision::public.moderation_case_status,
    version = next_version,
    decision_reason = btrim(p_reason),
    decided_by = case when p_decision = 'escalated' then null else auth.uid() end,
    decided_at = case when p_decision = 'escalated' then null else clock_timestamp() end,
    updated_at = clock_timestamp()
  where id = moderation_case.id;
  insert into public.moderation_decisions (
    case_id, decision, reason, actor_id, case_version
  ) values (
    moderation_case.id, p_decision::public.moderation_case_status,
    btrim(p_reason), auth.uid(), next_version
  );

  if p_decision = 'upheld' then
    if moderation_case.target_type = 'review' then
      select * into target_review from public.reviews
      where id = moderation_case.target_id for update;
      if found and target_review.status = 'published' then
        update public.reviews set status = 'removed_by_moderation',
          removed_at = clock_timestamp(), version = version + 1,
          updated_at = clock_timestamp() where id = target_review.id;
        delete from public.public_reviews where id = target_review.id;
        perform private.recalculate_target_rating(
          target_review.target_type, target_review.target_id
        );
      end if;
    elsif moderation_case.target_type = 'restaurant'
        and moderation_case.reason = 'broken_link' then
      update public.published_restaurants set social_link_status = 'removed',
        updated_at = clock_timestamp() where id = moderation_case.target_id;
    elsif moderation_case.target_type = 'spot' then
      delete from public.published_spots where id = moderation_case.target_id;
      update public.spots set archived_at = clock_timestamp()
      where id = moderation_case.target_id;
    elsif moderation_case.target_type = 'restaurant' then
      delete from public.published_restaurants where id = moderation_case.target_id;
      update public.restaurants set archived_at = clock_timestamp()
      where id = moderation_case.target_id;
    elsif moderation_case.target_type = 'guide' then
      delete from public.published_guides where id = moderation_case.target_id;
      update public.guides set archived_at = clock_timestamp()
      where id = moderation_case.target_id;
    end if;
  end if;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason, metadata
  ) values (
    auth.uid(), 'admin.content_report_' || p_decision, 'moderation_case',
    moderation_case.id, btrim(p_reason), jsonb_build_object(
      'version', next_version,
      'content_type', moderation_case.target_type,
      'content_id', moderation_case.target_id,
      'report_reason', moderation_case.reason
    )
  );
  return jsonb_build_object(
    'case_id', moderation_case.id, 'status', p_decision,
    'version', next_version
  );
end;
$$;

create or replace function public.admin_list_account_appeals()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', appeal.id,
      'user_id', appeal.user_id,
      'display_name', profile.display_name,
      'email', auth_user.email,
      'related_decision_id', appeal.related_decision_id,
      'access_status', access_decision.status,
      'public_message', access_decision.public_message,
      'reason', appeal.reason,
      'explanation', appeal.explanation,
      'status', appeal.status,
      'version', appeal.version,
      'created_at', appeal.created_at
    ) order by appeal.created_at)
    from public.account_appeals appeal
    join public.profiles profile on profile.id = appeal.user_id
    join auth.users auth_user on auth_user.id = appeal.user_id
    join public.account_access_decisions access_decision
      on access_decision.id = appeal.related_decision_id
    where appeal.status in ('submitted', 'under_review')
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_decide_account_appeal(
  p_appeal_id uuid,
  p_decision text,
  p_reason text,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare appeal public.account_appeals;
declare access_record public.account_access;
declare next_version integer;
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  if p_decision not in ('upheld', 'dismissed')
      or char_length(btrim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'Invalid appeal decision';
  end if;
  select * into appeal from public.account_appeals
  where id = p_appeal_id for update;
  if not found or appeal.status not in ('submitted', 'under_review') then
    raise exception using errcode = 'P0002', message = 'Active appeal not found';
  end if;
  if appeal.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Appeal changed concurrently';
  end if;
  select * into access_record from public.account_access
  where user_id = appeal.user_id for update;
  next_version := appeal.version + 1;

  if p_decision = 'upheld' then
    perform public.admin_set_account_access(
      appeal.user_id, 'active', null, btrim(p_reason), null,
      access_record.version
    );
  end if;
  update public.account_appeals set status = p_decision::public.account_appeal_status,
    outcome_reason = btrim(p_reason), decided_by = auth.uid(),
    decided_at = clock_timestamp(), updated_at = clock_timestamp(),
    version = next_version where id = appeal.id;
  perform private.create_notification(
    appeal.user_id, 'account_appeal_' || p_decision,
    'Appeal decision recorded',
    case when p_decision = 'upheld'
      then 'Your appeal was accepted and account access was restored.'
      else 'Your appeal was reviewed. Open account status for the decision.' end,
    'account_appeal', appeal.id
  );
  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason, metadata
  ) values (
    auth.uid(), 'admin.account_appeal_' || p_decision, 'account_appeal',
    appeal.id, btrim(p_reason), jsonb_build_object(
      'version', next_version, 'target_user_id', appeal.user_id
    )
  );
  return jsonb_build_object(
    'appeal_id', appeal.id, 'status', p_decision,
    'version', next_version
  );
end;
$$;

create or replace function public.list_my_discounts()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'influencer' then
    raise exception using errcode = '42501', message = 'Approved creator role required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', code.id,
      'restaurant_id', code.restaurant_id,
      'restaurant_name', published.name,
      'code', code.code,
      'description', code.description,
      'redemption_terms', code.redemption_terms,
      'starts_at', code.starts_at,
      'expires_at', code.expires_at,
      'status', case
        when code.status in ('scheduled', 'active')
          and code.expires_at <= clock_timestamp() then 'expired'
        else code.status::text
      end,
      'version', code.version
    ) order by code.updated_at desc)
    from public.discount_codes code
    join public.restaurants restaurant on restaurant.id = code.restaurant_id
    left join public.published_restaurants published on published.id = code.restaurant_id
    where code.owner_id = auth.uid() and restaurant.archived_at is null
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_archive_guide(
  p_guide_id uuid,
  p_reason text,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare entity public.guides;
declare next_version integer;
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  if char_length(btrim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'Archive reason required';
  end if;
  select * into entity from public.guides where id = p_guide_id for update;
  if not found or entity.archived_at is not null
      or entity.published_revision_id is null then
    raise exception using errcode = 'P0002', message = 'Published guide not found';
  end if;
  if entity.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Guide changed concurrently';
  end if;
  next_version := entity.version + 1;
  update public.guides set archived_at = clock_timestamp(),
    version = next_version where id = entity.id;
  delete from public.published_guides where id = entity.id;
  insert into public.guide_publication_decisions (
    guide_id, revision_id, decision, reason, actor_id, guide_version
  ) values (
    entity.id, entity.published_revision_id, 'archived', btrim(p_reason),
    auth.uid(), next_version
  );
  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason, metadata
  ) values (
    auth.uid(), 'admin.guide_archived', 'guide', entity.id, btrim(p_reason),
    jsonb_build_object('version', next_version)
  );
  return jsonb_build_object(
    'guide_id', entity.id, 'status', 'archived', 'version', next_version
  );
end;
$$;

revoke all on function public.admin_decide_content_report(uuid, text, text, integer)
  from public;
revoke all on function public.admin_list_account_appeals() from public;
revoke all on function public.admin_decide_account_appeal(uuid, text, text, integer)
  from public;
revoke all on function public.list_my_discounts() from public;
revoke all on function public.admin_archive_guide(uuid, text, integer) from public;

grant execute on function public.admin_decide_content_report(uuid, text, text, integer)
  to authenticated;
grant execute on function public.admin_list_account_appeals() to authenticated;
grant execute on function public.admin_decide_account_appeal(uuid, text, text, integer)
  to authenticated;
grant execute on function public.list_my_discounts() to authenticated;
grant execute on function public.admin_archive_guide(uuid, text, integer)
  to authenticated;

commit;

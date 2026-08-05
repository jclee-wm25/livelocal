begin;

create or replace function public.admin_list_accounts()
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
    select jsonb_agg(
      jsonb_build_object(
        'id', u.id,
        'email', u.email,
        'display_name', p.display_name,
        'role', private.current_role(u.id),
        'access_status', private.effective_account_status(u.id),
        'access_message', aa.public_message,
        'access_ends_at', aa.ends_at,
        'access_version', aa.version,
        'created_at', u.created_at
      ) order by u.created_at desc
    )
    from auth.users u
    join public.profiles p on p.id = u.id
    join public.account_access aa on aa.user_id = u.id
  ), '[]'::jsonb);
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
    select jsonb_agg(
      jsonb_build_object(
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
          else '[Preview unavailable]'
        end
      ) order by mc.created_at
    )
    from public.moderation_cases mc
    left join public.public_reviews pr
      on mc.target_type = 'review' and pr.id = mc.target_id
    left join public.published_spots ps
      on mc.target_type = 'spot' and ps.id = mc.target_id
    where mc.status in ('pending', 'under_review', 'escalated')
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_list_audit_events(p_limit integer default 100)
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
  if p_limit not between 1 and 500 then
    raise exception using errcode = '22023', message = 'Invalid audit limit';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(history) order by history.occurred_at desc)
    from (
      select ae.id, ae.actor_id, ae.action, ae.target_type, ae.target_id,
             ae.reason, ae.metadata, ae.occurred_at
      from public.audit_events ae
      order by ae.occurred_at desc
      limit p_limit
    ) history
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_list_accounts() from public;
revoke all on function public.admin_list_moderation_cases() from public;
revoke all on function public.admin_list_audit_events(integer) from public;
grant execute on function public.admin_list_accounts() to authenticated;
grant execute on function public.admin_list_moderation_cases() to authenticated;
grant execute on function public.admin_list_audit_events(integer) to authenticated;

commit;

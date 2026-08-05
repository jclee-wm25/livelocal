begin;

-- Blocking is a private viewer preference. The client identifies public
-- content; the database derives its author so callers cannot submit an
-- arbitrary account ID or discover private ownership metadata.
create table public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default clock_timestamp(),
  primary key (blocker_id, blocked_user_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_user_id)
);

create index user_blocks_blocked_user_lookup
  on public.user_blocks(blocked_user_id);

create or replace function private.is_content_author_blocked(
  p_target_type text,
  p_target_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null and exists (
    select 1
    from public.user_blocks user_block
    where user_block.blocker_id = auth.uid()
      and user_block.blocked_user_id = case p_target_type
        when 'review' then (
          select review.user_id from public.reviews review
          where review.id = p_target_id
        )
        when 'spot' then (
          select spot.owner_id from public.spots spot
          where spot.id = p_target_id
        )
        when 'restaurant' then (
          select restaurant.owner_id from public.restaurants restaurant
          where restaurant.id = p_target_id
        )
        else null
      end
  );
$$;

create or replace function public.block_content_author(
  p_target_type text,
  p_target_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  target_author uuid;
  target_name text;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot block users';
  end if;

  if p_target_type = 'review' then
    select review.user_id into target_author
    from public.reviews review
    join public.public_reviews projection on projection.id = review.id
    where review.id = p_target_id;
  elsif p_target_type = 'spot' then
    select spot.owner_id into target_author
    from public.spots spot
    join public.published_spots projection on projection.id = spot.id
    where spot.id = p_target_id;
  elsif p_target_type = 'restaurant' then
    select restaurant.owner_id into target_author
    from public.restaurants restaurant
    join public.published_restaurants projection on projection.id = restaurant.id
    where restaurant.id = p_target_id;
  else
    raise exception using errcode = '22023', message = 'Unsupported block target';
  end if;

  if target_author is null then
    raise exception using
      errcode = 'P0002',
      message = 'No account can be blocked for this content';
  end if;
  if target_author = auth.uid() then
    raise exception using errcode = '22023', message = 'Users cannot block themselves';
  end if;

  insert into public.user_blocks (blocker_id, blocked_user_id)
  values (auth.uid(), target_author)
  on conflict do nothing;

  select profile.display_name into target_name
  from public.profiles profile where profile.id = target_author;

  return jsonb_build_object(
    'blocked_user_id', target_author,
    'display_name', coalesce(target_name, 'Blocked user')
  );
end;
$$;

create or replace function public.unblock_user(p_blocked_user_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot manage blocks';
  end if;
  delete from public.user_blocks
  where blocker_id = auth.uid() and blocked_user_id = p_blocked_user_id;
end;
$$;

create or replace function public.list_my_blocked_users()
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', user_block.blocked_user_id,
    'display_name', coalesce(profile.display_name, 'Blocked user'),
    'blocked_at', user_block.created_at
  ) order by user_block.created_at desc), '[]'::jsonb)
  from public.user_blocks user_block
  left join public.profiles profile on profile.id = user_block.blocked_user_id
  where user_block.blocker_id = auth.uid();
$$;

alter table public.user_blocks enable row level security;

create policy user_blocks_select_self on public.user_blocks
  for select to authenticated using (blocker_id = auth.uid());

revoke all on table public.user_blocks from anon, authenticated;
grant select on table public.user_blocks to authenticated;

drop policy published_spots_public_read on public.published_spots;
create policy published_spots_public_read on public.published_spots
  for select to anon, authenticated using (
    not private.is_content_hidden('spot', id)
    and not private.is_content_author_blocked('spot', id)
  );

drop policy public_reviews_public_read on public.public_reviews;
create policy public_reviews_public_read on public.public_reviews
  for select to anon, authenticated using (
    not private.is_content_hidden('review', id)
    and not private.is_content_author_blocked('review', id)
  );

drop policy published_restaurants_public on public.published_restaurants;
create policy published_restaurants_public on public.published_restaurants
  for select to anon, authenticated using (
    not private.is_content_hidden('restaurant', id)
    and not private.is_content_author_blocked('restaurant', id)
  );

revoke all on function private.is_content_author_blocked(text, uuid) from public;
grant execute on function private.is_content_author_blocked(text, uuid)
  to anon, authenticated;
revoke all on function public.block_content_author(text, uuid) from public;
revoke all on function public.unblock_user(uuid) from public;
revoke all on function public.list_my_blocked_users() from public;
grant execute on function public.block_content_author(text, uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.list_my_blocked_users() to authenticated;

commit;

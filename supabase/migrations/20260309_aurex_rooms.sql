create extension if not exists pgcrypto;

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  host_user_id uuid not null references auth.users(id) on delete cascade,
  is_active boolean not null default true,
  max_users integer not null default 25 check (max_users between 2 and 25),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.room_members (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null default 'listener' check (role in ('host', 'listener')),
  joined_at timestamptz not null default timezone('utc', now()),
  left_at timestamptz
);

create unique index if not exists room_members_active_idx
  on public.room_members (room_id, user_id)
  where left_at is null;

create table if not exists public.room_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  message text not null check (char_length(message) between 1 and 500),
  kind text not null default 'message' check (kind in ('message', 'system')),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.room_playback_states (
  room_id uuid primary key references public.rooms(id) on delete cascade,
  host_user_id uuid not null references auth.users(id) on delete cascade,
  track_json jsonb,
  queue_json jsonb not null default '[]'::jsonb,
  queue_index integer not null default 0,
  position_ms integer not null default 0,
  is_playing boolean not null default false,
  sequence integer not null default 0,
  updated_at timestamptz not null default timezone('utc', now())
);

create or replace function public.generate_room_code()
returns text
language plpgsql
as $$
declare
  candidate text;
begin
  loop
    candidate := upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));
    exit when not exists (select 1 from public.rooms where code = candidate);
  end loop;
  return candidate;
end;
$$;

create or replace function public.set_room_defaults()
returns trigger
language plpgsql
as $$
begin
  if new.code is null or new.code = '' then
    new.code := public.generate_room_code();
  end if;
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_set_room_defaults on public.rooms;
create trigger trg_set_room_defaults
before insert or update on public.rooms
for each row execute function public.set_room_defaults();

create or replace function public.create_room(p_name text)
returns public.rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.rooms;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  insert into public.rooms (name, code, host_user_id)
  values (coalesce(nullif(trim(p_name), ''), 'Aurex Room'), public.generate_room_code(), v_user_id)
  returning * into v_room;

  insert into public.room_members (room_id, user_id, display_name, role)
  values (
    v_room.id,
    v_user_id,
    coalesce(auth.jwt() ->> 'email', 'Aurex Host'),
    'host'
  );

  return v_room;
end;
$$;

create or replace function public.join_room(p_code text)
returns public.rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.rooms;
  v_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select * into v_room
  from public.rooms
  where code = upper(trim(p_code))
    and is_active = true
  limit 1;

  if v_room.id is null then
    raise exception 'Room not found';
  end if;

  select count(*)
  into v_count
  from public.room_members
  where room_id = v_room.id
    and left_at is null;

  if v_count >= v_room.max_users then
    raise exception 'Room is full';
  end if;

  if exists (
    select 1
    from public.room_members
    where room_id = v_room.id
      and user_id = v_user_id
      and left_at is null
  ) then
    return v_room;
  end if;

  update public.room_members
  set left_at = null,
      joined_at = timezone('utc', now()),
      display_name = coalesce(auth.jwt() ->> 'email', display_name),
      role = case when v_room.host_user_id = v_user_id then 'host' else 'listener' end
  where room_id = v_room.id
    and user_id = v_user_id
    and left_at is not null;

  if not found then
    insert into public.room_members (room_id, user_id, display_name, role)
    values (
      v_room.id,
      v_user_id,
      coalesce(auth.jwt() ->> 'email', 'Aurex Listener'),
      case when v_room.host_user_id = v_user_id then 'host' else 'listener' end
    );
  end if;

  insert into public.room_messages (room_id, user_id, display_name, message, kind)
  values (
    v_room.id,
    v_user_id,
    coalesce(auth.jwt() ->> 'email', 'Aurex Listener'),
    'joined the room',
    'system'
  );

  return v_room;
end;
$$;

create or replace function public.leave_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_next_host uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  update public.room_members
  set left_at = timezone('utc', now()),
      role = 'listener'
  where room_id = p_room_id
    and user_id = v_user_id
    and left_at is null;

  insert into public.room_messages (room_id, user_id, display_name, message, kind)
  values (
    p_room_id,
    v_user_id,
    coalesce(auth.jwt() ->> 'email', 'Aurex Listener'),
    'left the room',
    'system'
  );

  if exists (
    select 1 from public.rooms
    where id = p_room_id and host_user_id = v_user_id
  ) then
    select user_id
    into v_next_host
    from public.room_members
    where room_id = p_room_id
      and left_at is null
    order by joined_at asc
    limit 1;

    if v_next_host is null then
      update public.rooms
      set is_active = false,
          updated_at = timezone('utc', now())
      where id = p_room_id;
    else
      update public.rooms
      set host_user_id = v_next_host,
          updated_at = timezone('utc', now())
      where id = p_room_id;

      update public.room_members
      set role = case when user_id = v_next_host then 'host' else 'listener' end
      where room_id = p_room_id
        and left_at is null;
    end if;
  end if;
end;
$$;

create or replace function public.transfer_room_host(
  p_room_id uuid,
  p_new_host_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.rooms
    where id = p_room_id
      and host_user_id = v_user_id
  ) then
    raise exception 'Only the host can transfer host privileges';
  end if;

  if not exists (
    select 1 from public.room_members
    where room_id = p_room_id
      and user_id = p_new_host_user_id
      and left_at is null
  ) then
    raise exception 'New host must be an active room member';
  end if;

  update public.rooms
  set host_user_id = p_new_host_user_id,
      updated_at = timezone('utc', now())
  where id = p_room_id;

  update public.room_members
  set role = case when user_id = p_new_host_user_id then 'host' else 'listener' end
  where room_id = p_room_id
    and left_at is null;

  insert into public.room_messages (room_id, user_id, display_name, message, kind)
  values (
    p_room_id,
    v_user_id,
    coalesce(auth.jwt() ->> 'email', 'Aurex Host'),
    'transferred host privileges',
    'system'
  );
end;
$$;

alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.room_messages enable row level security;
alter table public.room_playback_states enable row level security;

drop policy if exists "rooms_select_for_members" on public.rooms;
create policy "rooms_select_for_members"
on public.rooms
for select
using (
  exists (
    select 1
    from public.room_members
    where room_members.room_id = rooms.id
      and room_members.user_id = auth.uid()
      and room_members.left_at is null
  )
);

drop policy if exists "members_select_for_members" on public.room_members;
create policy "members_select_for_members"
on public.room_members
for select
using (
  exists (
    select 1
    from public.room_members as active_members
    where active_members.room_id = room_members.room_id
      and active_members.user_id = auth.uid()
      and active_members.left_at is null
  )
);

drop policy if exists "messages_select_for_members" on public.room_messages;
create policy "messages_select_for_members"
on public.room_messages
for select
using (
  exists (
    select 1
    from public.room_members
    where room_members.room_id = room_messages.room_id
      and room_members.user_id = auth.uid()
      and room_members.left_at is null
  )
);

drop policy if exists "messages_insert_for_members" on public.room_messages;
create policy "messages_insert_for_members"
on public.room_messages
for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.room_members
    where room_members.room_id = room_messages.room_id
      and room_members.user_id = auth.uid()
      and room_members.left_at is null
  )
);

drop policy if exists "playback_select_for_members" on public.room_playback_states;
create policy "playback_select_for_members"
on public.room_playback_states
for select
using (
  exists (
    select 1
    from public.room_members
    where room_members.room_id = room_playback_states.room_id
      and room_members.user_id = auth.uid()
      and room_members.left_at is null
  )
);

drop policy if exists "playback_upsert_for_hosts" on public.room_playback_states;
create policy "playback_upsert_for_hosts"
on public.room_playback_states
for all
using (
  exists (
    select 1
    from public.rooms
    where rooms.id = room_playback_states.room_id
      and rooms.host_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.rooms
    where rooms.id = room_playback_states.room_id
      and rooms.host_user_id = auth.uid()
  )
);

alter publication supabase_realtime add table public.rooms;
alter publication supabase_realtime add table public.room_members;
alter publication supabase_realtime add table public.room_messages;
alter publication supabase_realtime add table public.room_playback_states;

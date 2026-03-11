create or replace function public.is_active_room_member(
  p_room_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.room_members
    where room_id = p_room_id
      and user_id = p_user_id
      and left_at is null
  );
$$;

grant execute on function public.is_active_room_member(uuid, uuid)
to anon, authenticated;

drop policy if exists "rooms_select_for_members" on public.rooms;
create policy "rooms_select_for_members"
on public.rooms
for select
using (public.is_active_room_member(id));

drop policy if exists "members_select_for_members" on public.room_members;
create policy "members_select_for_members"
on public.room_members
for select
using (public.is_active_room_member(room_id));

drop policy if exists "messages_select_for_members" on public.room_messages;
create policy "messages_select_for_members"
on public.room_messages
for select
using (public.is_active_room_member(room_id));

drop policy if exists "messages_insert_for_members" on public.room_messages;
create policy "messages_insert_for_members"
on public.room_messages
for insert
with check (
  auth.uid() = user_id
  and public.is_active_room_member(room_id)
);

drop policy if exists "playback_select_for_members" on public.room_playback_states;
create policy "playback_select_for_members"
on public.room_playback_states
for select
using (public.is_active_room_member(room_id));

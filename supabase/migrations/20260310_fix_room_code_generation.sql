create or replace function public.generate_room_code()
returns text
language plpgsql
as $$
declare
  candidate text;
begin
  loop
    candidate := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    exit when not exists (select 1 from public.rooms where code = candidate);
  end loop;
  return candidate;
end;
$$;

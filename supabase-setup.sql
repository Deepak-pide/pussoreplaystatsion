create extension if not exists pgcrypto;

create table if not exists public.slots (
  id uuid primary key default gen_random_uuid(),
  start_at timestamptz not null,
  price_per_person numeric(10, 2) not null check (price_per_person >= 0),
  status text not null default 'available' check (status in ('available', 'booked')),
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  slot_id uuid not null unique references public.slots(id) on delete restrict,
  customer_name text not null check (char_length(trim(customer_name)) between 1 and 120),
  phone_number text,
  people integer not null check (people > 0),
  created_at timestamptz not null default now()
);

alter table public.bookings add column if not exists phone_number text;

alter table public.slots enable row level security;
alter table public.bookings enable row level security;

grant select on public.slots to anon, authenticated;
grant insert, update, delete on public.slots to authenticated;
grant select on public.bookings to authenticated;

drop policy if exists "Anyone can view sessions" on public.slots;
create policy "Anyone can view sessions"
  on public.slots for select
  to anon, authenticated
  using (true);

drop policy if exists "Admin can manage sessions" on public.slots;
create policy "Admin can manage sessions"
  on public.slots for all
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'dg3667610@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'dg3667610@gmail.com');

drop policy if exists "Admin can view bookings" on public.bookings;
create policy "Admin can view bookings"
  on public.bookings for select
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'dg3667610@gmail.com');

drop function if exists public.book_slot(uuid, text, integer);

create or replace function public.book_slot(
  p_slot_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_people integer
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking_id uuid;
begin
  if char_length(trim(coalesce(p_customer_name, ''))) not between 1 and 120 then
    raise exception 'Enter a name between 1 and 120 characters.';
  end if;
  if char_length(trim(coalesce(p_customer_phone, ''))) not between 7 and 24
    or trim(p_customer_phone) !~ '^[0-9+(). -]+$'
    or char_length(regexp_replace(p_customer_phone, '[^0-9]', '', 'g')) not between 7 and 15 then
    raise exception 'Enter a valid phone number.';
  end if;
  if p_people is null or p_people < 1 then
    raise exception 'Number of people must be at least one.';
  end if;

  update public.slots
  set status = 'booked'
  where id = p_slot_id and status = 'available';

  if not found then
    raise exception 'This session is no longer available.';
  end if;

  insert into public.bookings (slot_id, customer_name, phone_number, people)
  values (p_slot_id, trim(p_customer_name), trim(p_customer_phone), p_people)
  returning id into v_booking_id;

  return v_booking_id;
end;
$$;

create or replace function public.cancel_booking(p_slot_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'dg3667610@gmail.com' then
    raise exception 'Only the administrator can cancel bookings.';
  end if;

  delete from public.bookings where slot_id = p_slot_id;
  if not found then
    raise exception 'No booking was found for this session.';
  end if;

  update public.slots set status = 'available' where id = p_slot_id;
end;
$$;

revoke all on function public.book_slot(uuid, text, text, integer) from public;
grant execute on function public.book_slot(uuid, text, text, integer) to anon, authenticated;
revoke all on function public.cancel_booking(uuid) from public;
grant execute on function public.cancel_booking(uuid) to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'slots'
  ) then
    alter publication supabase_realtime add table public.slots;
  end if;
end;
$$;

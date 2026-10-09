-- Casa Yannuga · database schema
-- Paste all of this into the Supabase SQL Editor and run it once.
-- Safe to re-run: it only adds what is missing.

-- ───────────────────────── tables ─────────────────────────
create table if not exists bookings (
  id          text primary key,
  hh          text not null,
  checkin     date not null,
  checkout    date not null,
  kind        text not null default 'share',   -- 'share' (credits) or 'whole' (cash)
  beds        jsonb not null default '[]'::jsonb,
  note        text default '',
  guest_name  text,
  amount      numeric default 0,               -- cash, for whole-house nights and guests
  made_at     timestamptz default now(),       -- when the booking was made
  created_at  timestamptz default now()
);

-- bookings made before the bed model: add the new columns, keep the old rows
alter table bookings add column if not exists kind    text  not null default 'share';
alter table bookings add column if not exists beds    jsonb not null default '[]'::jsonb;
alter table bookings add column if not exists made_at timestamptz default now();
-- one cota per person: who sleeps in a bed booking, each paying their own credits
alter table bookings add column if not exists ppl     jsonb not null default '[]'::jsonb;

create table if not exists expenses (
  id          text primary key,
  descr       text not null,
  amount      numeric not null default 0,
  date        date not null,
  created_at  timestamptz default now()
);
-- the house's Splitwise: who paid (a person's code, or 'bank' for the house account),
-- who it is split between (empty = everyone), and payments between people ('pay')
alter table expenses add column if not exists kind       text  not null default 'expense';
alter table expenses add column if not exists paid_by    text  not null default 'bank';
alter table expenses add column if not exists to_id      text;
alter table expenses add column if not exists split      jsonb not null default '[]'::jsonb;
alter table expenses add column if not exists created_by text;

-- the open history: every booking, cancellation, credit purchase and whole-house night
create table if not exists log (
  id          text primary key,
  ty          text not null,                   -- book | cancel | buy | deny
  hh          text,
  nm          text,
  checkin     date,
  checkout    date,
  kind        text,
  beds        jsonb not null default '[]'::jsonb,
  n           int     default 0,               -- credits bought
  cr          int     default 0,               -- credits the booking cost
  amt         numeric default 0,               -- cash
  at          timestamptz default now()
);
-- who slept, what each paid, and whether the cancellation came under 24h (credits kept)
alter table log add column if not exists ppl  jsonb   not null default '[]'::jsonb;
alter table log add column if not exists pc   int     default 0;
alter table log add column if not exists late boolean not null default false;

-- extra credits bought at $20 each; the money goes to the aporte
create table if not exists buys (
  id          text primary key,
  hh          text not null,
  n           int     not null default 0,
  amount      numeric not null default 0,
  at          timestamptz default now()
);

-- payments and holiday sign-offs, each in a single document
create table if not exists app_state (
  key         text primary key,
  value       jsonb not null default '{}'::jsonb,
  updated_at  timestamptz default now()
);

insert into app_state (key, value) values ('paid','{}'::jsonb), ('consent','{}'::jsonb)
  on conflict (key) do nothing;

-- links each Supabase user to a member
create table if not exists profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  hh         text not null,          -- pj, nc, dj, bc, n5, vt
  admin      boolean not null default false,
  terms_at   timestamptz,            -- when they agreed to the cotas and the rules
  created_at timestamptz default now()
);
alter table profiles add column if not exists terms_at timestamptz;

-- ───────────────────────── realtime ─────────────────────────
do $$
begin
  begin alter publication supabase_realtime add table bookings;  exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table expenses;  exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table log;       exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table buys;      exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table app_state; exception when duplicate_object then null; end;
end $$;

-- ───────────────────── access: signed in only ─────────────────────
alter table bookings  enable row level security;
alter table expenses  enable row level security;
alter table log       enable row level security;
alter table buys      enable row level security;
alter table app_state enable row level security;
alter table profiles  enable row level security;

drop policy if exists p_bookings  on bookings;
drop policy if exists p_expenses  on expenses;
drop policy if exists p_log       on log;
drop policy if exists p_log_read   on log;
drop policy if exists p_log_insert on log;
drop policy if exists p_buys      on buys;
drop policy if exists p_app_state on app_state;
drop policy if exists p_profiles  on profiles;

create policy p_bookings  on bookings  for all
  using (auth.uid() is not null) with check (auth.uid() is not null);
create policy p_expenses  on expenses  for all
  using (auth.uid() is not null) with check (auth.uid() is not null);
create policy p_buys      on buys      for all
  using (auth.uid() is not null) with check (auth.uid() is not null);
create policy p_app_state on app_state for all
  using (auth.uid() is not null) with check (auth.uid() is not null);

-- the history is readable and appendable by everyone, and nobody can rewrite it
create policy p_log_read   on log for select using (auth.uid() is not null);
create policy p_log_insert on log for insert with check (auth.uid() is not null);

-- everyone reads their own profile; admins read all of them.
-- is_admin() runs as its owner, so it reads profiles without going back
-- through this policy (a subquery here would recurse forever).
create or replace function is_admin() returns boolean
  language sql stable security definer set search_path = public as $$
  select coalesce((select admin from profiles where user_id = auth.uid()), false)
$$;

create policy p_profiles on profiles for select
  using (user_id = auth.uid() or is_admin());

-- each person records their own acceptance of the terms, nothing else
drop policy if exists p_profiles_terms on profiles;
create policy p_profiles_terms on profiles for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ─────────────── after creating the users ───────────────
-- One account per person. Authentication → Users → Add user (tick "Auto Confirm User").
-- Then copy each UUID and run (codes match the DEF array in index.html):
--
-- insert into profiles (user_id, hh, admin) values
--   ('pedro-uuid',  'pe', true),
--   ('julia-uuid',  'ju', false),
--   ('niklas-uuid', 'ni', true),
--   ('carol-uuid',  'ca', false),
--   ('du-uuid',     'du', false),
--   ('john-uuid',   'jo', false),
--   ('bruna-uuid',  'br', false),
--   ('caio-uuid',   'cc', false),
--   ('victor-uuid', 'c9', false)
-- on conflict (user_id) do update set hh = excluded.hh, admin = excluded.admin;
--
-- Victor Hugo took cota 9 and kept its code, c9. Cotas 10 to 12 are c10, c11, c12 once someone takes them.

-- ─────────────── from couples to people (run once) ───────────────
-- Old couple codes become the first person of the couple; the app maps them too.
update profiles set hh = case hh when 'pj' then 'pe' when 'nc' then 'ni'
  when 'dj' then 'du' when 'bc' then 'br' else hh end where hh in ('pj','nc','dj','bc');
update bookings set hh = case hh when 'pj' then 'pe' when 'nc' then 'ni'
  when 'dj' then 'du' when 'bc' then 'br' else hh end where hh in ('pj','nc','dj','bc');
update buys set hh = case hh when 'pj' then 'pe' when 'nc' then 'ni'
  when 'dj' then 'du' when 'bc' then 'br' else hh end where hh in ('pj','nc','dj','bc');

-- ─────────────── the album: photos people add, private to signed-in members ───────────────
insert into storage.buckets (id, name, public) values ('album', 'album', false)
  on conflict (id) do nothing;
create table if not exists album (
  id       text primary key,
  path     text not null,                 -- file path inside the 'album' bucket
  hh       text,                          -- who added it
  caption  text default '',
  at       timestamptz default now()
);
alter table album enable row level security;
drop policy if exists p_album on album;
create policy p_album on album for all
  using (auth.uid() is not null) with check (auth.uid() is not null);
do $$ begin
  begin alter publication supabase_realtime add table album; exception when duplicate_object then null; end;
end $$;
drop policy if exists "album read"   on storage.objects;
drop policy if exists "album add"    on storage.objects;
drop policy if exists "album remove" on storage.objects;
create policy "album read"   on storage.objects for select to authenticated using (bucket_id = 'album');
create policy "album add"    on storage.objects for insert to authenticated with check (bucket_id = 'album');
create policy "album remove" on storage.objects for delete to authenticated using (bucket_id = 'album');

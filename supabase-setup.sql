-- ============================================================================
-- Earth Sweet Earth — Supabase database setup
-- ----------------------------------------------------------------------------
-- HOW TO RUN: in your Supabase project, open  SQL Editor → New query,
-- paste this whole file, and click  Run.
--
-- WHAT IT DOES: creates a "profiles" table (one row per user, holding their
-- username + role) and locks it down with security rules so nobody can give
-- themselves powers they shouldn't have.
--
-- ABOUT PASSWORDS: you never store passwords here. Supabase Auth handles
-- sign-up, login, and password hashing safely. This table only holds a
-- username and a role.
-- ============================================================================


-- 1) The profiles table (linked to Supabase's built-in auth users) ------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  username   text,
  role       text not null default 'member'
             check (role in ('owner','admin','moderator','member')),
  created_at timestamptz not null default now()
);

-- keep the signed-up email here too, so the Owner can search members by email
-- (the browser can't read auth.users directly). Safe to re-run.
alter table public.profiles add column if not exists email text;

-- optional member country, used for the "X people across Y countries" stat on the About page. Safe to re-run.
alter table public.profiles add column if not exists country text;


-- 2) Auto-create a profile whenever someone signs up --------------------------
--    (username comes from the sign-up form; everyone starts as 'member')
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, role, email, country)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    'member',
    new.email,
    nullif(new.raw_user_meta_data->>'country','')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- backfill emails for anyone who signed up before this column existed
update public.profiles p set email = u.email
  from auth.users u where u.id = p.id and p.email is null;


-- 3) Helper: is the current user an admin or owner? ---------------------------
--    (SECURITY DEFINER lets it read roles without causing rule loops)
create or replace function public.is_admin()
returns boolean
language sql
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('owner','admin')
  );
$$;


-- 4) Safety guard: a normal member CANNOT change their own role ---------------
--    (this is what stops someone sneaking themselves up to 'owner').
--    Admins and owners can still change roles.
create or replace function public.guard_role_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- Only restrict a REAL signed-in user from changing roles. The SQL editor and
  -- server-side (service-role) contexts have no auth.uid() and are trusted — this
  -- is what lets you bootstrap the very first Owner (see the ONE-TIME block below).
  if new.role is distinct from old.role
     and auth.uid() is not null
     and not public.is_admin() then
    new.role := old.role;   -- quietly keep the old role
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_guard_role on public.profiles;
create trigger profiles_guard_role
  before update on public.profiles
  for each row execute function public.guard_role_change();


-- 5) Row-Level Security: nothing is readable/writable until a rule allows it ---
alter table public.profiles enable row level security;

-- READ: you can read your own profile; admins can read everyone's.
drop policy if exists "read own profile"     on public.profiles;
drop policy if exists "admins read profiles" on public.profiles;
create policy "read own profile"     on public.profiles for select using (auth.uid() = id);
create policy "admins read profiles" on public.profiles for select using (public.is_admin());

-- UPDATE: you can edit your own row (role change blocked by the guard above);
--         admins can edit anyone's row, including roles.
drop policy if exists "update own profile"     on public.profiles;
drop policy if exists "admins update profiles" on public.profiles;
create policy "update own profile"     on public.profiles for update using (auth.uid() = id);
create policy "admins update profiles" on public.profiles for update using (public.is_admin());


-- ============================================================================
-- ONE-TIME: make yourself the Owner
-- ----------------------------------------------------------------------------
-- After you've signed up ONCE through the website, run the line below
-- (swap in the email you signed up with) to give yourself full control:
--
--   update public.profiles set role = 'owner'
--   where id = (select id from auth.users where email = 'you@example.com');
--
-- To promote someone else later, do the same with 'admin' or 'moderator'
-- and their email address.
-- ============================================================================


-- ============================================================================
-- SITE CONTENT (mission statement, home subtitle, Discord link)
-- ----------------------------------------------------------------------------
-- A single shared row (id = 1) holding editable homepage text as JSON.
-- Anyone can READ it (so the public sees your edits); only Owner/Admin can WRITE.
-- Run this block once, the same way you ran the setup above.
-- ============================================================================
create table if not exists public.site_content (
  id   int primary key default 1,
  data jsonb not null default '{}'::jsonb,
  constraint site_content_singleton check (id = 1)
);

alter table public.site_content enable row level security;

drop policy if exists "anyone reads site content"  on public.site_content;
drop policy if exists "admins insert site content" on public.site_content;
drop policy if exists "admins update site content" on public.site_content;

create policy "anyone reads site content"  on public.site_content for select using (true);
create policy "admins insert site content" on public.site_content for insert with check (public.is_admin());
create policy "admins update site content" on public.site_content for update using (public.is_admin());

-- seed the single row so the site has something to read on first load
insert into public.site_content (id, data) values (1, '{}'::jsonb)
on conflict (id) do nothing;

-- REALTIME: let already-open tabs update instantly when an owner/admin saves.
-- Adds site_content to the realtime publication. Safe to re-run (no-op if the
-- table isn't there yet or is already published).
do $$
begin
  if to_regclass('public.site_content') is not null
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename  = 'site_content'
     ) then
    alter publication supabase_realtime add table public.site_content;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Chapter applications (submitted from the "Start a chapter" form).
-- Anyone (including logged-out visitors) may SUBMIT one; only owner/admin may READ them.
-- ---------------------------------------------------------------------------
create table if not exists public.chapter_applications (
  id uuid primary key default gen_random_uuid(),
  data jsonb not null,
  created_at timestamptz default now()
);
alter table public.chapter_applications enable row level security;

drop policy if exists "anyone can submit an application" on public.chapter_applications;
create policy "anyone can submit an application" on public.chapter_applications
  for insert with check (true);

drop policy if exists "admins can read applications" on public.chapter_applications;
create policy "admins can read applications" on public.chapter_applications
  for select using (public.is_admin());


-- ============================================================================
-- PUBLIC STAT: "X people across Y countries" for the About page
-- ----------------------------------------------------------------------------
-- Returns only aggregate counts (no personal data), so it is safe to expose to
-- everyone, including logged-out visitors. Safe to re-run.
-- ============================================================================
create or replace function public.ese_stats()
returns json
language sql
security definer set search_path = public
stable
as $$
  select json_build_object(
    'people',    (select count(*) from public.profiles),
    'countries', (select count(distinct nullif(btrim(country),'')) from public.profiles)
  );
$$;
grant execute on function public.ese_stats() to anon, authenticated;


-- ============================================================================
-- YOUTH LEADERSHIP APPLICATIONS (submitted by the youth-leadership form)
-- ----------------------------------------------------------------------------
-- Anyone may submit one; only admins/owner can read them. Safe to re-run.
-- ============================================================================
create table if not exists public.youth_applications (
  id         uuid primary key default gen_random_uuid(),
  data       jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.youth_applications enable row level security;
drop policy if exists "anyone submit youth app" on public.youth_applications;
drop policy if exists "admins read youth apps"  on public.youth_applications;
create policy "anyone submit youth app" on public.youth_applications for insert with check (true);
create policy "admins read youth apps"  on public.youth_applications for select using (public.is_admin());


-- ============================================================================
-- INSTALLMENT 7: username uniqueness, application review state, traffic
-- ----------------------------------------------------------------------------
-- All safe to re-run.
-- ============================================================================

-- Usernames must be unique (case-insensitive). The app also validates that they
-- are letters/numbers only, and pre-checks availability via username_available().
create unique index if not exists profiles_username_lower_key
  on public.profiles (lower(username)) where username is not null;

-- Public check the sign-up form uses (returns only true/false, no data leaked).
create or replace function public.username_available(name text)
returns boolean language sql security definer set search_path = public stable as $$
  select not exists (select 1 from public.profiles where lower(username) = lower(btrim(name)));
$$;
grant execute on function public.username_available(text) to anon, authenticated;

-- Mark applications reviewed (drives the "needs review" list + red dots).
alter table public.chapter_applications add column if not exists reviewed boolean not null default false;
alter table public.youth_applications  add column if not exists reviewed boolean not null default false;
drop policy if exists "admins update chapter apps" on public.chapter_applications;
create policy "admins update chapter apps" on public.chapter_applications for update using (public.is_admin());
drop policy if exists "admins update youth apps" on public.youth_applications;
create policy "admins update youth apps" on public.youth_applications for update using (public.is_admin());

-- Simple traffic: log a row per page view; only admins can read them.
create table if not exists public.page_views (
  id         bigint generated always as identity primary key,
  path       text,
  created_at timestamptz not null default now()
);
alter table public.page_views enable row level security;
drop policy if exists "anyone logs a view" on public.page_views;
drop policy if exists "admins read views"  on public.page_views;
create policy "anyone logs a view" on public.page_views for insert with check (true);
create policy "admins read views"  on public.page_views for select using (public.is_admin());

-- Aggregated traffic for the Analytics tab (total, this week, last 7 days).
create or replace function public.ese_traffic()
returns json language sql security definer set search_path = public stable as $$
  select json_build_object(
    'total', (select count(*) from public.page_views),
    'week',  (select count(*) from public.page_views where created_at >= current_date - 6),
    'last7', (select coalesce(json_agg(json_build_object('d', to_char(g.d,'Mon DD'), 'n', coalesce(c.n,0)) order by g.d), '[]'::json)
              from generate_series((current_date-6)::timestamp, current_date::timestamp, interval '1 day') g(d)
              left join (select date_trunc('day', created_at) dd, count(*) n
                         from public.page_views where created_at >= current_date - 6 group by 1) c
                on c.dd = date_trunc('day', g.d))
  );
$$;
grant execute on function public.ese_traffic() to authenticated;


-- ============================================================================
-- REVISION: "X people across Y countries" — count countries from BOTH member
-- profiles and chapter countries (a chapter's country is captured on the form).
-- Also stores a member avatar. All safe to re-run.
-- ============================================================================
alter table public.profiles add column if not exists avatar text;

create or replace function public.ese_stats()
returns json language sql security definer set search_path = public stable as $$
  select json_build_object(
    'people', (select count(*) from public.profiles),
    'countries', (
      select count(distinct btrim(c))
      from (
        select country as c from public.profiles
        union all
        select elem->>'country'
          from public.site_content sc,
               lateral jsonb_array_elements(coalesce(sc.data->'chapters', '[]'::jsonb)) elem
         where sc.id = 1
      ) src
      where nullif(btrim(coalesce(c,'')), '') is not null
    )
  );
$$;
grant execute on function public.ese_stats() to anon, authenticated;


-- ============================================================================
-- EVENT PARTICIPATION ("I'm in!") — who signed up for which event.
-- ----------------------------------------------------------------------------
-- Privacy: a member can only see (and add/remove) their OWN row. Everyone can
-- see anonymous COUNTS via ese_event_counts(). Only owner/admin can read the
-- actual list of people — that's what the Owner Analytics tab uses to hand out
-- prizes. Safe to re-run.
-- ============================================================================
create table if not exists public.event_participants (
  id         bigint generated always as identity primary key,
  event_id   text not null,
  user_id    uuid not null references auth.users(id) on delete cascade,
  username   text,
  email      text,
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);
alter table public.event_participants enable row level security;

drop policy if exists "join an event"          on public.event_participants;
drop policy if exists "leave an event"         on public.event_participants;
drop policy if exists "see own participation"  on public.event_participants;
drop policy if exists "admins read participants" on public.event_participants;
create policy "join an event"           on public.event_participants for insert with check (auth.uid() = user_id);
create policy "leave an event"          on public.event_participants for delete using      (auth.uid() = user_id);
create policy "see own participation"   on public.event_participants for select using      (auth.uid() = user_id);
create policy "admins read participants" on public.event_participants for select using     (public.is_admin());

-- Anonymous head-count per event, so anyone viewing the calendar sees "N going".
create or replace function public.ese_event_counts()
returns json language sql security definer set search_path = public stable as $$
  select coalesce(json_object_agg(event_id, n), '{}'::json)
  from (select event_id, count(*) as n from public.event_participants group by event_id) t;
$$;
grant execute on function public.ese_event_counts() to anon, authenticated;


-- ============================================================================
-- CHAPTERS & CHAPTER LEADERS
-- ----------------------------------------------------------------------------
-- Chapters and their events get their OWN tables (not site_content), because a
-- chapter leader must be able to manage their own chapter WITHOUT being able to
-- write the whole site (roles, permissions, etc). Each leader can only touch
-- their own chapter's row and its events. Safe to re-run.
-- ============================================================================

-- Roles are now dynamic (Chapter Leader + any custom role the owner creates),
-- so the old fixed list of allowed roles has to go.
alter table public.profiles drop constraint if exists profiles_role_check;

create table if not exists public.chapters (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  country    text,
  continent  text,
  leader_id  uuid references auth.users(id) on delete set null,
  gcal_id    text,
  created_at timestamptz not null default now()
);
alter table public.chapters enable row level security;
drop policy if exists "anyone reads chapters"  on public.chapters;
drop policy if exists "leader creates chapter" on public.chapters;
drop policy if exists "leader updates chapter" on public.chapters;
drop policy if exists "leader deletes chapter" on public.chapters;
create policy "anyone reads chapters"  on public.chapters for select using (true);
create policy "leader creates chapter" on public.chapters for insert with check (auth.uid() = leader_id or public.is_admin());
create policy "leader updates chapter" on public.chapters for update using      (auth.uid() = leader_id or public.is_admin());
create policy "leader deletes chapter" on public.chapters for delete using      (auth.uid() = leader_id or public.is_admin());

-- Which chapter a member belongs to (optional at sign-up, editable in the profile).
alter table public.profiles add column if not exists chapter uuid references public.chapters(id) on delete set null;

create table if not exists public.chapter_events (
  id         uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references public.chapters(id) on delete cascade,
  name       text not null,
  date       date,
  time       text,
  link       text,
  color      text default 'Green',
  details    text,
  created_at timestamptz not null default now()
);
alter table public.chapter_events enable row level security;
drop policy if exists "anyone reads chapter events" on public.chapter_events;
drop policy if exists "leader writes chapter events" on public.chapter_events;
create policy "anyone reads chapter events" on public.chapter_events for select using (true);
create policy "leader writes chapter events" on public.chapter_events for all
  using       (public.is_admin() or exists (select 1 from public.chapters c where c.id = chapter_id and c.leader_id = auth.uid()))
  with check  (public.is_admin() or exists (select 1 from public.chapters c where c.id = chapter_id and c.leader_id = auth.uid()));

-- Countries now come from member profiles + the chapters table.
create or replace function public.ese_stats()
returns json language sql security definer set search_path = public stable as $$
  select json_build_object(
    'people', (select count(*) from public.profiles),
    'countries', (
      select count(distinct btrim(c))
      from (
        select country as c from public.profiles
        union all
        select country     from public.chapters
      ) src
      where nullif(btrim(coalesce(c,'')), '') is not null
    )
  );
$$;
grant execute on function public.ese_stats() to anon, authenticated;

-- Carry the optional sign-up chapter through to the new profile.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, role, email, country, chapter)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    'member',
    new.email,
    nullif(new.raw_user_meta_data->>'country',''),
    nullif(new.raw_user_meta_data->>'chapter','')::uuid
  );
  return new;
end;
$$;


-- ============================================================================
-- DISCORD VERIFICATION — store the linked Discord account on the profile.
-- The website-role <-> Discord-role mapping itself lives in site_content
-- (owner-editable in Owner Settings). Role changes are applied by the
-- discord-verify Edge Function using the service role, so nobody can promote
-- themselves from the browser. Safe to re-run.
-- ============================================================================
alter table public.profiles add column if not exists discord_id       text;
alter table public.profiles add column if not exists discord_username text;
create unique index if not exists profiles_discord_id_key
  on public.profiles (discord_id) where discord_id is not null;


-- ============================================================================
-- TRANSLATIONS + LANGUAGE VIEWS (worldwide languages)
-- ----------------------------------------------------------------------------
-- We never store copies of the site per language. The `translate` Edge Function
-- translates text on demand and CACHES each (target, source_text) pair here, so
-- every translation is identical every time and only ever fetched once.
-- Safe to re-run.
-- ============================================================================
create table if not exists public.translations (
  id          bigint generated always as identity primary key,
  target      text not null,
  source_text text not null,
  translated  text not null,
  created_at  timestamptz not null default now(),
  unique (target, source_text)
);
alter table public.translations enable row level security;
drop policy if exists "anyone reads translations" on public.translations;
create policy "anyone reads translations" on public.translations for select using (true);
-- writes happen only via the translate Edge Function (service role), so nobody
-- can poison the cache from the browser.

-- One row per "someone viewed the site in language X", for Owner Analytics.
create table if not exists public.lang_views (
  id         bigint generated always as identity primary key,
  lang       text not null,
  created_at timestamptz not null default now()
);
alter table public.lang_views enable row level security;
drop policy if exists "anyone logs a lang view" on public.lang_views;
drop policy if exists "admins read lang views"  on public.lang_views;
create policy "anyone logs a lang view" on public.lang_views for insert with check (true);
create policy "admins read lang views"  on public.lang_views for select using (public.is_admin());

create or replace function public.ese_lang_stats()
returns json language sql security definer set search_path = public stable as $$
  select coalesce(json_object_agg(lang, json_build_object('total', total, 'week', week)), '{}'::json)
  from (
    select lang, count(*) as total,
           count(*) filter (where created_at >= current_date - 6) as week
    from public.lang_views group by lang
  ) t;
$$;
grant execute on function public.ese_lang_stats() to authenticated;
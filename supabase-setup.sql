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


-- 2) Auto-create a profile whenever someone signs up --------------------------
--    (username comes from the sign-up form; everyone starts as 'member')
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    'member'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


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
  -- is what lets you bootstrap the very first Owner below.
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
-- REALTIME: let already-open tabs update instantly when an owner/admin saves
-- ----------------------------------------------------------------------------
-- The website subscribes to changes on public.site_content and re-renders live
-- (including for logged-out visitors), so permission/content changes appear
-- without a manual refresh. That requires the table to be in Supabase's
-- realtime publication. Safe to run more than once; does nothing if the
-- site_content table doesn't exist yet.
-- ============================================================================
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
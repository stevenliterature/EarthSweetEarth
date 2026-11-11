-- ============================================================
-- Earth Sweet Earth 2.8 — Supabase backend setup (v2)
-- Paste the WHOLE script into Supabase → SQL Editor → Run.
-- Safe to re-run: everything is "create if not exists / replace".
--
-- Order matters: tables first, then functions, triggers,
-- policies, RPCs, grants. (The previous version failed because
-- helper functions were created before the profiles table.)
-- ============================================================

-- ------------------------------------------------------------
-- 1) TABLES
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  username         text not null unique,
  email            text,
  role             text not null default 'member',
  is_developer     boolean not null default false,
  name_color       text,
  country          text,
  chapter          uuid,
  avatar           text,
  discord_username text,
  last_seen        timestamptz,
  created_at       timestamptz not null default now()
);
-- safety: if an older profiles table exists, make sure the 2.8 columns are there
alter table public.profiles add column if not exists is_developer      boolean not null default false;
alter table public.profiles add column if not exists name_color        text;
alter table public.profiles add column if not exists email             text;
alter table public.profiles add column if not exists discord_username text;
alter table public.profiles add column if not exists last_seen         timestamptz;
alter table public.profiles drop constraint if exists profiles_role_chk;
alter table public.profiles add constraint profiles_role_chk
  check (role in ('member','chapter_leader','moderator','admin','owner'));
alter table public.profiles drop constraint if exists profiles_name_color_chk;
alter table public.profiles add constraint profiles_name_color_chk
  check (name_color is null or name_color in
    ('black','blue','red','purple','turquoise','darkred','green','darkorange',
     'pink','magenta','rose','orange','gold','lime','cyan','skyblue','navy','indigo','brown','gray'));
create index if not exists profiles_username_lc on public.profiles (lower(username));
create index if not exists profiles_last_seen on public.profiles (last_seen);

create table if not exists public.leader_messages (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null,
  username   text not null,
  name_color text,
  body       text not null,
  created_at timestamptz not null default now()
);
create index if not exists leader_messages_created on public.leader_messages (created_at);
-- 2.8: reply support in the leader chat
alter table public.leader_messages add column if not exists reply_to uuid;
alter table public.leader_messages add column if not exists reply_to_name text;

-- 2.8: reactions on leader chat messages (one emoji per user per message)
create table if not exists public.leader_msg_reactions (
  message_id uuid not null references public.leader_messages(id) on delete cascade,
  user_id    uuid not null,
  emoji      text,
  primary key (message_id, user_id)
);

create table if not exists public.site_announcements (
  id         uuid primary key default gen_random_uuid(),
  body       text not null,
  active     boolean not null default true,
  created_by uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.site_content (
  id   int primary key,
  data jsonb not null default '{}'::jsonb
);

create table if not exists public.chapters (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  country    text,
  continent  text,
  leader_id  uuid,
  gcal_id    text,
  created_at timestamptz not null default now()
);

create table if not exists public.chapter_events (
  id         uuid primary key default gen_random_uuid(),
  chapter_id uuid references public.chapters(id) on delete cascade,
  name       text,
  date       date,
  time       text,
  link       text,
  color      text default 'Green',
  details    text,
  created_at timestamptz not null default now()
);

create table if not exists public.event_participants (
  event_id   text not null,
  user_id    uuid not null,
  username   text,
  email      text,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
-- same normalization as reactions: right columns, no duplicates, right key
alter table public.event_participants add column if not exists event_id   text;
alter table public.event_participants add column if not exists user_id    uuid;
alter table public.event_participants add column if not exists username   text;
alter table public.event_participants add column if not exists email      text;
alter table public.event_participants add column if not exists created_at timestamptz;
delete from public.event_participants where event_id is null or user_id is null;
delete from public.event_participants a using public.event_participants b
  where a.event_id = b.event_id and a.user_id = b.user_id and a.ctid < b.ctid;
do $$
begin
  alter table public.event_participants drop constraint if exists event_participants_pkey;
  alter table public.event_participants add primary key (event_id, user_id);
exception when others then null;
end $$;

create table if not exists public.chapter_applications (
  id         uuid primary key default gen_random_uuid(),
  data       jsonb,
  reviewed   boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.youth_applications (
  id         uuid primary key default gen_random_uuid(),
  data       jsonb,
  reviewed   boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.chapter_applications add column if not exists reviewed boolean not null default false;
alter table public.youth_applications  add column if not exists reviewed boolean not null default false;

create table if not exists public.post_comments (
  id         text primary key,
  post_id    text not null,
  user_id    uuid not null,
  username   text not null,
  avatar     text,
  name_color text,
  body       text not null,
  parent_id  text,
  created_at timestamptz not null default now(),
  edited_at  timestamptz
);
-- the app creates comment ids like 'c_1731...' (text, never uuids).
-- if an earlier run of this script made id/parent_id uuid columns, convert them:
alter table public.post_comments add column if not exists name_color text;
alter table public.post_comments add column if not exists parent_id  text;
alter table public.post_comments add column if not exists edited_at  timestamptz;
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'post_comments'
               and column_name = 'id' and data_type <> 'text') then
    alter table public.post_comments alter column id type text using id::text;
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'post_comments'
               and column_name = 'parent_id' and data_type <> 'text') then
    alter table public.post_comments alter column parent_id type text using parent_id::text;
  end if;
end $$;
create index if not exists post_comments_post on public.post_comments (post_id);
create index if not exists post_comments_user on public.post_comments (user_id);

create table if not exists public.post_reactions (
  target_id  text not null,
  user_id    uuid not null,
  emoji      text,
  created_at timestamptz not null default now(),
  primary key (target_id, user_id)
);
-- the app upserts reactions on (target_id, user_id): make sure older
-- tables have the right columns, no duplicates, and exactly that key
alter table public.post_reactions add column if not exists target_id  text;
alter table public.post_reactions add column if not exists user_id    uuid;
alter table public.post_reactions add column if not exists emoji      text;
alter table public.post_reactions add column if not exists created_at timestamptz;
delete from public.post_reactions where target_id is null or user_id is null;
delete from public.post_reactions a using public.post_reactions b
  where a.target_id = b.target_id and a.user_id = b.user_id and a.ctid < b.ctid;
do $$
begin
  alter table public.post_reactions drop constraint if exists post_reactions_pkey;
  alter table public.post_reactions add primary key (target_id, user_id);
exception when others then null;   -- if a column is missing/nullable the PK can't be forced; the add-column lines above usually fix the next run
end $$;

create table if not exists public.page_views (
  id         bigint generated by default as identity primary key,
  path       text,
  created_at timestamptz not null default now()
);
create index if not exists page_views_created on public.page_views (created_at);

create table if not exists public.lang_views (
  id         bigint generated by default as identity primary key,
  lang       text,
  created_at timestamptz not null default now()
);
create index if not exists lang_views_lang on public.lang_views (lang);

create table if not exists public.translations (
  source_text text,
  translated  text,
  target      text,
  primary key (source_text, target)
);

-- ------------------------------------------------------------
-- 2) PURE HELPERS (no table dependencies)
-- ------------------------------------------------------------
create or replace function public.role_rank(r text) returns int
language sql immutable as
$$ select case r
  when 'member'         then 1
  when 'chapter_leader' then 2
  when 'moderator'      then 3
  when 'admin'          then 4
  when 'owner'          then 5
  when 'developer'      then 6
  else 0 end $$;

-- default (highest) name color per role
create or replace function public.default_color(r text) returns text
language sql immutable as
$$ select case r
  when 'member'         then 'black'
  when 'chapter_leader' then 'blue'
  when 'moderator'      then 'red'
  when 'admin'          then 'purple'
  when 'owner'          then 'green'
  when 'developer'      then 'darkorange'
  else 'black' end $$;

-- which name colors a role may choose
create or replace function public.color_allowed(r text, c text) returns boolean
language sql immutable as
$$ select c is not null and c = any (case r
  when 'member'         then array['black']
  when 'chapter_leader' then array['black','blue']
  when 'moderator'      then array['black','blue','red']
  when 'admin'          then array['black','blue','red','darkred','purple','turquoise']
  when 'owner'          then array['black','blue','red','darkred','purple','turquoise','green',
                               'pink','magenta','rose','orange','gold','lime','cyan','skyblue','navy','indigo','brown','gray']
  when 'developer'      then array['black','blue','red','darkred','purple','turquoise','green','darkorange',
                               'pink','magenta','rose','orange','gold','lime','cyan','skyblue','navy','indigo','brown','gray']
  else array['black'] end) $$;

-- ------------------------------------------------------------
-- 3) ROLE HELPERS (need public.profiles, created above)
-- ------------------------------------------------------------
-- effective role: 'developer' wins over the stored base role
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as
$$ select case
  when coalesce((select is_developer from public.profiles where id = auth.uid()), false) then 'developer'
  else coalesce((select role from public.profiles where id = auth.uid()), 'member')
end $$;

create or replace function public.my_rank() returns int
language sql stable security definer set search_path = public as
$$ select public.role_rank(public.my_role()) $$;

create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public as
$$ select public.my_rank() >= 5 $$;

-- leaders = moderator and up (used by the Leader chat)
create or replace function public.is_leader() returns boolean
language sql stable security definer set search_path = public as
$$ select public.my_rank() >= 3 $$;

-- ------------------------------------------------------------
-- 4) PROFILE TRIGGERS
-- ------------------------------------------------------------
-- auto-create a profile whenever someone signs up
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare base text; nm text; i int := 0;
begin
  nm := coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1));
  nm := regexp_replace(nm, '[^A-Za-z0-9_]', '', 'g');
  if nm = '' or nm is null then nm := 'member'; end if;
  base := left(nm, 15);   -- usernames can be up to 15 letters now
  while exists (select 1 from public.profiles where lower(username) = lower(base)) loop
    i := i + 1;
    base := left(base, 12) || i::text;   -- keeps the name + suffix within 15
    exit when i > 50;
  end loop;
  insert into public.profiles (id, username, email, role, name_color, last_seen)
  values (new.id, base, new.email, 'member', 'black', now())
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- protect role / developer flag / username / name color on every update
create or replace function public.guard_profile_update() returns trigger
language plpgsql security definer set search_path = public as $$
declare changer_rank int; changer_is_dev boolean;
begin
  -- runs from the SQL editor / service role: allow
  if auth.uid() is null then return new; end if;

  select coalesce(is_developer, false),
         public.role_rank(case when is_developer then 'developer' else role end)
    into changer_is_dev, changer_rank
    from public.profiles where id = auth.uid();
  if changer_rank is null then raise exception 'No profile for this account'; end if;

  -- usernames never change (only owner/developer level can fix one)
  if new.username is distinct from old.username and changer_rank < 5 then
    raise exception 'Usernames can''t be changed';
  end if;
  -- email lives in auth.users; keep the copy as-is here
  new.email := old.email;

  -- only DEVELOPERS may change their own role; anyone else's role
  -- is changed by the owner or a developer
  if new.role is distinct from old.role then
    if new.id = auth.uid() and not changer_is_dev then
      raise exception 'You can''t change your own role';
    end if;
    if new.id <> auth.uid() and changer_rank < 5 then
      raise exception 'Only the owner or a developer can change roles';
    end if;
  end if;

  -- only developers appoint or remove developers (never on themselves)
  if new.is_developer is distinct from old.is_developer then
    if new.id = auth.uid() then
      raise exception 'You can''t change your own developer flag';
    end if;
    if not changer_is_dev and changer_rank < 5 then
      raise exception 'Only the owner or a developer can appoint developers';
    end if;
  end if;

  -- name color must be one the (new) role is allowed to wear
  if new.role is distinct from old.role
     or new.is_developer is distinct from old.is_developer
     or new.name_color is distinct from old.name_color then
    if not public.color_allowed(
         case when new.is_developer then 'developer' else new.role end,
         new.name_color) then
      new.name_color := public.default_color(
        case when new.is_developer then 'developer' else new.role end);
    end if;
  end if;

  return new;
end $$;
drop trigger if exists profiles_guard on public.profiles;
create trigger profiles_guard
  before update on public.profiles
  for each row execute function public.guard_profile_update();

-- when someone changes their name color, repaint ALL their old
-- comments and leader-chat messages, not just the new ones
create or replace function public.sync_name_colors() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.name_color is distinct from old.name_color then
    update public.post_comments  set name_color = new.name_color where user_id = new.id;
    update public.leader_messages set name_color = new.name_color where user_id = new.id;
  end if;
  return null;
end $$;
drop trigger if exists sync_name_colors on public.profiles;
create trigger sync_name_colors
  after update on public.profiles
  for each row execute function public.sync_name_colors();

-- leader chat: keep only the newest 30 messages
create or replace function public.cap_leader_chat() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from public.leader_messages
  where id in (select id from public.leader_messages
               order by created_at desc, id desc offset 30);
  return null;
end $$;
drop trigger if exists cap_leader on public.leader_messages;
create trigger cap_leader
  after insert on public.leader_messages
  for each statement execute function public.cap_leader_chat();

-- only the owner can REMOVE developer powers (runs from the SQL editor / service role freely)
create or replace function public.guard_dev_powers() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and old.is_developer and not coalesce(new.is_developer, false)
     and coalesce(public.my_rank(), 0) < 5 then
    raise exception 'Only the owner can remove developer powers';
  end if;
  return new;
end $$;
drop trigger if exists guard_dev_powers on public.profiles;
create trigger guard_dev_powers
  before update on public.profiles
  for each row when (old.is_developer is distinct from new.is_developer)
  execute function public.guard_dev_powers();

-- ------------------------------------------------------------
-- 5) ROW LEVEL SECURITY
-- ------------------------------------------------------------
alter table public.profiles enable row level security;
drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles
  for select using (true);
drop policy if exists "profiles update" on public.profiles;
create policy "profiles update" on public.profiles
  for update using (id = auth.uid() or public.my_rank() >= 5)
  with check (id = auth.uid() or public.my_rank() >= 5);
-- insert happens through the handle_new_user trigger; delete through close_account()

alter table public.leader_messages enable row level security;
drop policy if exists "leaders read chat" on public.leader_messages;
create policy "leaders read chat" on public.leader_messages
  for select using (public.is_leader());
drop policy if exists "leaders write chat" on public.leader_messages;
create policy "leaders write chat" on public.leader_messages
  for insert with check (public.is_leader() and user_id = auth.uid());
-- 2.8: leaders can delete their OWN messages; developers can delete any
drop policy if exists "leaders delete own chat" on public.leader_messages;
create policy "leaders delete own chat" on public.leader_messages
  for delete using (user_id = auth.uid() or public.my_rank() >= 6);
-- 2.8: allow editing your own chat messages (e.g. fixing a typo)
drop policy if exists "leaders update own chat" on public.leader_messages;
create policy "leaders update own chat" on public.leader_messages
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.leader_msg_reactions enable row level security;
drop policy if exists "leaders read reactions" on public.leader_msg_reactions;
create policy "leaders read reactions" on public.leader_msg_reactions
  for select using (public.is_leader());
drop policy if exists "leaders write reactions" on public.leader_msg_reactions;
create policy "leaders write reactions" on public.leader_msg_reactions
  for insert with check (public.is_leader() and user_id = auth.uid());
drop policy if exists "leaders delete own reactions" on public.leader_msg_reactions;
create policy "leaders delete own reactions" on public.leader_msg_reactions
  for delete using (user_id = auth.uid());
drop policy if exists "leaders update own reactions" on public.leader_msg_reactions;
create policy "leaders update own reactions" on public.leader_msg_reactions
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.site_announcements enable row level security;
drop policy if exists "ann read" on public.site_announcements;
create policy "ann read" on public.site_announcements
  for select using (true);
drop policy if exists "ann insert" on public.site_announcements;
create policy "ann insert" on public.site_announcements
  for insert with check (public.my_rank() >= 5);
drop policy if exists "ann update" on public.site_announcements;
create policy "ann update" on public.site_announcements
  for update using (public.my_rank() >= 5) with check (public.my_rank() >= 5);

alter table public.site_content enable row level security;
drop policy if exists "content read" on public.site_content;
create policy "content read" on public.site_content
  for select using (true);
drop policy if exists "content insert" on public.site_content;
create policy "content insert" on public.site_content
  for insert with check (public.my_rank() >= 4);
drop policy if exists "content update" on public.site_content;
create policy "content update" on public.site_content
  for update using (public.my_rank() >= 4) with check (public.my_rank() >= 4);

alter table public.chapters enable row level security;
drop policy if exists "chapters read" on public.chapters;
create policy "chapters read" on public.chapters
  for select using (true);
drop policy if exists "chapters insert" on public.chapters;
create policy "chapters insert" on public.chapters
  for insert with check (auth.uid() is not null);
drop policy if exists "chapters update" on public.chapters;
create policy "chapters update" on public.chapters
  for update using (leader_id = auth.uid() or public.my_rank() >= 5)
  with check (leader_id = auth.uid() or public.my_rank() >= 5);
drop policy if exists "chapters delete" on public.chapters;
create policy "chapters delete" on public.chapters
  for delete using (public.my_rank() >= 5);

alter table public.chapter_events enable row level security;
drop policy if exists "events read" on public.chapter_events;
create policy "events read" on public.chapter_events
  for select using (true);
drop policy if exists "events insert" on public.chapter_events;
create policy "events insert" on public.chapter_events
  for insert with check (
    exists (select 1 from public.chapters c where c.id = chapter_id and c.leader_id = auth.uid())
    or public.my_rank() >= 5);
drop policy if exists "events update" on public.chapter_events;
create policy "events update" on public.chapter_events
  for update using (
    exists (select 1 from public.chapters c where c.id = chapter_id and c.leader_id = auth.uid())
    or public.my_rank() >= 5)
  with check (
    exists (select 1 from public.chapters c where c.id = chapter_id and c.leader_id = auth.uid())
    or public.my_rank() >= 5);
drop policy if exists "events delete" on public.chapter_events;
create policy "events delete" on public.chapter_events
  for delete using (
    exists (select 1 from public.chapters c where c.id = chapter_id and c.leader_id = auth.uid())
    or public.my_rank() >= 5);

alter table public.event_participants enable row level security;
drop policy if exists "participants read" on public.event_participants;
create policy "participants read" on public.event_participants
  for select to authenticated using (true);
drop policy if exists "participants join" on public.event_participants;
create policy "participants join" on public.event_participants
  for insert with check (user_id = auth.uid());
drop policy if exists "participants leave" on public.event_participants;
create policy "participants leave" on public.event_participants
  for delete using (user_id = auth.uid() or public.my_rank() >= 5);

alter table public.chapter_applications enable row level security;
alter table public.youth_applications enable row level security;
drop policy if exists "chapps insert" on public.chapter_applications;
create policy "chapps insert" on public.chapter_applications
  for insert with check (true);
drop policy if exists "chapps read" on public.chapter_applications;
create policy "chapps read" on public.chapter_applications
  for select using (public.my_rank() >= 5);
drop policy if exists "chapps update" on public.chapter_applications;
create policy "chapps update" on public.chapter_applications
  for update using (public.my_rank() >= 5) with check (public.my_rank() >= 5);
drop policy if exists "chapps delete" on public.chapter_applications;
create policy "chapps delete" on public.chapter_applications
  for delete using (public.my_rank() >= 5);
drop policy if exists "ylapps insert" on public.youth_applications;
create policy "ylapps insert" on public.youth_applications
  for insert with check (true);
drop policy if exists "ylapps read" on public.youth_applications;
create policy "ylapps read" on public.youth_applications
  for select using (public.my_rank() >= 5);
drop policy if exists "ylapps update" on public.youth_applications;
create policy "ylapps update" on public.youth_applications
  for update using (public.my_rank() >= 5) with check (public.my_rank() >= 5);
drop policy if exists "ylapps delete" on public.youth_applications;
create policy "ylapps delete" on public.youth_applications
  for delete using (public.my_rank() >= 5);

alter table public.post_comments enable row level security;
drop policy if exists "comments read" on public.post_comments;
create policy "comments read" on public.post_comments
  for select using (true);
drop policy if exists "comments insert" on public.post_comments;
create policy "comments insert" on public.post_comments
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "comments update" on public.post_comments;
create policy "comments update" on public.post_comments
  for update using (user_id = auth.uid() or public.my_rank() >= 3)
  with check (user_id = auth.uid() or public.my_rank() >= 3);
drop policy if exists "comments delete" on public.post_comments;
create policy "comments delete" on public.post_comments
  for delete using (user_id = auth.uid() or public.my_rank() >= 3);

alter table public.post_reactions enable row level security;
drop policy if exists "reactions read" on public.post_reactions;
create policy "reactions read" on public.post_reactions
  for select using (true);
drop policy if exists "reactions write" on public.post_reactions;
create policy "reactions write" on public.post_reactions
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "reactions update" on public.post_reactions;
create policy "reactions update" on public.post_reactions
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "reactions delete" on public.post_reactions;
create policy "reactions delete" on public.post_reactions
  for delete to authenticated using (user_id = auth.uid());

alter table public.page_views enable row level security;
drop policy if exists "page views insert" on public.page_views;
create policy "page views insert" on public.page_views
  for insert with check (true);

alter table public.lang_views enable row level security;
drop policy if exists "lang views insert" on public.lang_views;
create policy "lang views insert" on public.lang_views
  for insert with check (true);

alter table public.translations enable row level security;
drop policy if exists "translations read" on public.translations;
create policy "translations read" on public.translations
  for select using (true);
drop policy if exists "translations write" on public.translations;
create policy "translations write" on public.translations
  for insert to authenticated with check (public.my_rank() >= 5);
drop policy if exists "translations update" on public.translations;
create policy "translations update" on public.translations
  for update to authenticated using (public.my_rank() >= 5) with check (public.my_rank() >= 5);

-- ------------------------------------------------------------
-- 6) SIGN-UP CHECKS, PRESENCE, PROFILES, ACCOUNT CLOSURE
-- ------------------------------------------------------------
create or replace function public.email_taken(p_email text) returns boolean
language sql stable security definer set search_path = public, auth as
$$ select exists (select 1 from auth.users where lower(email) = lower(p_email)) $$;

create or replace function public.username_available(name text) returns boolean
language sql stable security definer set search_path = public as
$$ select not exists (select 1 from public.profiles where lower(username) = lower(name)) $$;

create or replace function public.touch_profile() returns void
language sql security definer set search_path = public as
$$ update public.profiles set last_seen = now() where id = auth.uid() $$;

create or replace function public.get_member_profile(p_uid uuid) returns json
language sql stable security definer set search_path = public as $$
  select coalesce((
    select json_build_object(
      'username',     p.username,
      'role',         p.role,
      'is_developer', p.is_developer,
      'name_color',   coalesce(p.name_color,
                       public.default_color(case when p.is_developer then 'developer' else p.role end)),
      'country',      p.country,
      'avatar',       p.avatar,
      'chapter',      p.chapter,
      'joined',       p.created_at,
      'online',       (p.last_seen is not null and p.last_seen > now() - interval '2 minutes'),
      'comments',     (select count(*) from public.post_comments c where c.user_id = p.id)
    ) from public.profiles p where p.id = p_uid), '{}'::json)
$$;

create or replace function public.close_account() returns void
language plpgsql security definer set search_path = public, auth as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Not signed in'; end if;
  delete from public.post_reactions      where user_id = uid;
  delete from public.post_comments      where user_id = uid;
  delete from public.event_participants where user_id = uid;
  delete from public.leader_messages    where user_id = uid;
  delete from public.profiles           where id      = uid;
  delete from auth.users                where id      = uid;
end $$;

-- ------------------------------------------------------------
-- 7) ANALYTICS RPCs (shapes match the frontend exactly)
-- ------------------------------------------------------------
create or replace function public.ese_stats() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'people',    (select count(*) from public.profiles),
    'countries', (select count(*) from (
      select distinct country from public.profiles
      where country is not null and btrim(country) <> '') c))
$$;

-- text[] of country names (frontend sorts them itself)
create or replace function public.ese_country_list() returns text[]
language sql stable security definer set search_path = public as $$
  select coalesce(array(
    select distinct c from (
      select country as c from public.profiles
        where country is not null and btrim(country) <> ''
      union
      select country as c from public.chapters
        where country is not null and btrim(country) <> ''
    ) s order by c), '{}'::text[])
$$;

-- { total, week, last7: [{ d: 'Mon', n: count }] }
create or replace function public.ese_traffic() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'total', (select count(*) from public.page_views),
    'week',  (select count(*) from public.page_views
               where created_at > now() - interval '7 days'),
    'last7', coalesce((select json_agg(x) from (
      select to_char(day, 'Dy') as d, n from
        (select date_trunc('day', created_at) as day, count(*) as n
         from public.page_views
         where created_at > now() - interval '7 days'
         group by 1) t
      order by day asc) x), '[]'::json))
$$;

-- { lang: { all_time, week } }
create or replace function public.ese_lang_stats() returns json
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(lang,
    json_build_object('all_time', all_time, 'week', week)), '{}'::jsonb)::json
  from (select lang, count(*) as all_time,
        count(*) filter (where created_at > now() - interval '7 days') as week
        from public.lang_views group by lang) t
$$;

-- { event_id: participant_count }
create or replace function public.ese_event_counts() returns json
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(event_id, cnt), '{}'::jsonb)::json
  from (select event_id, count(*) as cnt
        from public.event_participants group by event_id) t
$$;

create or replace function public.ese_clear_lang_views() returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_rank() < 5 then raise exception 'Owner or developer only'; end if;
  delete from public.lang_views;
end $$;

create or replace function public.ese_clear_lang_view(p_lang text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_rank() < 5 then raise exception 'Owner or developer only'; end if;
  delete from public.lang_views where lang = p_lang;
end $$;

-- ------------------------------------------------------------
-- 8) DEVELOPER DASHBOARD
-- ------------------------------------------------------------
create or replace function public.dev_dashboard() returns json
language plpgsql stable security definer set search_path = public as $$
begin
  if public.my_rank() < 6 then raise exception 'Developers only'; end if;
  return json_build_object(
    'today',   (select count(*) from public.page_views
                where created_at >= date_trunc('day', now())),
    'week',    (select count(*) from public.page_views
                where created_at > now() - interval '7 days'),
    'total',   (select count(*) from public.page_views),
    'traffic', coalesce((select json_agg(x) from (
      select to_char(day, 'Mon DD') as day, n from
        (select date_trunc('day', created_at) as day, count(*) as n
         from public.page_views
         where created_at > now() - interval '7 days'
         group by 1) t
      order by day asc) x), '[]'::json),
    'people',     (select count(*) from public.profiles),
    'online',     (select count(*) from public.profiles
                   where last_seen > now() - interval '2 minutes'),
    'comments',   (select count(*) from public.post_comments),
    'leaderMsgs', (select count(*) from public.leader_messages),
    'anns',       (select count(*) from public.site_announcements where active),
    'apps',       (select (select count(*) from public.chapter_applications)
                        + (select count(*) from public.youth_applications)),
    'recent',     coalesce((select json_agg(x) from (
      select username, role, to_char(created_at, 'Mon YYYY') as joined
      from public.profiles order by created_at desc limit 5) x), '[]'::json)
  );
end $$;

-- ------------------------------------------------------------
-- 9) GRANTS
-- ------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on
  public.profiles, public.leader_messages, public.leader_msg_reactions,
  public.site_announcements, public.site_content, public.chapters, public.chapter_events,
  public.event_participants, public.chapter_applications,
  public.youth_applications, public.post_comments, public.post_reactions,
  public.page_views, public.lang_views, public.translations
to anon, authenticated;

revoke execute on function public.dev_dashboard() from public, anon;
revoke execute on function public.close_account() from public, anon;
grant execute on function public.dev_dashboard() to authenticated;
grant execute on function public.close_account() to authenticated;

grant execute on function
  public.email_taken(text), public.username_available(text),
  public.touch_profile(), public.get_member_profile(uuid), public.ese_stats(),
  public.ese_country_list(), public.ese_traffic(), public.ese_lang_stats(),
  public.ese_event_counts(), public.ese_clear_lang_views(),
  public.ese_clear_lang_view(text), public.my_role(), public.my_rank(),
  public.is_owner(), public.is_leader(), public.role_rank(text),
  public.default_color(text), public.color_allowed(text, text)
to anon, authenticated;

-- ------------------------------------------------------------
-- 10) ONE-TIME SETUP
-- No developer is pre-set. The OWNER is the top authority and manages every role
-- (including appointing/removing developers) from Owner Settings. If you ever want to
-- grant the optional "developer" flair to a specific account by hand, an owner can run:
--   update public.profiles set is_developer = true where username = 'THE_USERNAME';
-- (Run it from the SQL Editor; the guard triggers block API self-promotion.)
# Turning on real accounts (Supabase setup)

Your site works right now in **preview mode** (fake accounts, so you can click around). This guide switches it to **real accounts** — real sign-up, login, and roles, backed by a real database. It's free, and it takes about 30–45 minutes.

You don't run a server. Supabase is the "backend" — your site just talks to it. It still deploys on GitHub Pages exactly the same way.

> 🧒 **Grab your adult partner for this part.** Real accounts mean you'll be collecting people's emails and passwords, and running a space for a mostly-young community. An adult should be in the loop on privacy and safety (there's a short checklist at the end).

---

## What you'll end up with
- People can **sign up** (email + username + password) and **log in** for real.
- Everyone starts as a **Member**. You can promote people to **Moderator**, **Admin**, or **Owner**.
- Passwords are handled securely by Supabase — they're never stored in your own tables.

---

## Step 1 — Make a free Supabase project
1. Go to **supabase.com** and sign up (you can sign in with GitHub).
2. Click **New project**.
3. Give it a name (e.g. `earth-sweet-earth`), and set a **database password** — *save it somewhere safe*.
4. Pick the region closest to you, then **Create**. Wait ~2 minutes for it to finish.

## Step 2 — Create the database tables
1. In your project, open **SQL Editor** (left sidebar) → **New query**.
2. Open the file **`supabase-setup.sql`** (in your repo), copy **everything**, paste it in.
3. Click **Run**. You should see "Success". This builds your `profiles` table and its security rules.

## Step 3 — Get your two keys
1. Go to **Project Settings** (gear icon) → **API**.
2. Copy the **Project URL** (looks like `https://abcd1234.supabase.co`).
3. Copy the **anon public** key (newer projects may call it the **Publishable** key — the long one that says *public*).

> ⚠️ There's also a **service_role** / **secret** key. **Never** put that one in your website — it can bypass all security. Only the anon/public key goes in the browser.

## Step 4 — Paste the keys into your site
1. Open **`index.html`** and find the **CONFIG block** near the top of the script (search for `SUPABASE_URL`).
2. Paste your values:
   ```js
   const SUPABASE_URL      = "https://abcd1234.supabase.co";
   const SUPABASE_ANON_KEY = "your-long-anon-public-key";
   ```
3. Save, commit, and push to GitHub. The moment those keys are filled in, the "Preview as" bar disappears and Sign Up / Log In become real.

## Step 5 — Tell Supabase your website address
1. In Supabase: **Authentication** → **URL Configuration**.
2. Set **Site URL** to `https://earthsweetearth.org`.
3. Add `http://localhost:8000` to **Redirect URLs** too, so testing on your own computer works.

## Step 6 — (For easy testing) turn off email confirmation for now
By default, Supabase emails people a confirmation link before they can log in. While you're testing, you can skip it:
1. **Authentication** → **Sign In / Providers** (or **Settings**) → find **Confirm email** and turn it **off**.
2. Turn it back **on** before real people use the site (it stops fake sign-ups).

## Step 7 — Test it, then make yourself Owner
1. Open your site and **Sign up** with your own email. You should get logged in (or, if confirmation is on, check your email first).
2. Go back to Supabase → **SQL Editor** and run (with your email):
   ```sql
   update public.profiles set role = 'owner'
   where id = (select id from auth.users where email = 'you@example.com');
   ```
3. Log out and back in on your site. You should now see the **Admin Settings** tab. 🎉

To promote a friend later, do the same with `'admin'` or `'moderator'` and their email.

---

## A few honest things to know

**Free-tier quirks.** Free Supabase projects **pause after 7 days with no activity** (one click un-pauses them, ~30 seconds), and the free plan has **no automatic backups**. Fine for getting started; worth revisiting before you depend on it.

**Security check before real users join:**
- Test that a **Member can't change their own role**. Sign up a test member, and confirm they can't become admin. (The database guard blocks it — good to verify.)
- Keep the **anon/public key** in the site (that's fine); never expose the **service_role/secret** key.
- Have an adult or an experienced person **look over the setup** before opening it to the public — I wrote standard, safe rules, but a second set of eyes is always smart for anything holding people's info.

**Privacy & safety for a youth community (do this with your adult partner):**
- Write a short, plain **privacy note**: what you collect (email, username) and why. Put a link to it in the footer.
- **Collect as little as possible** — you don't need real names, addresses, or birthdays to start.
- Plan basic **moderation** for the Discord (a couple of trusted people, simple rules).

---

## What's real now, and what's next
✅ **Real now:** sign-up, login, logout, staying logged in, each person's role deciding what they see, and changing your own username/password.

🔜 **Next steps (say the word and I'll help):**
1. Wire the **Admin Settings → Members** table to real users, so you can change roles by clicking instead of running SQL.
2. Move **newsletter posts**, **gallery photos**, **calendar events**, and **chapters** into the database so they save for everyone (right now those pages are structure/placeholders).

We'll do these one at a time, after accounts are working — that's the calm way to build it.
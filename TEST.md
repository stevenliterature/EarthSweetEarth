# Earth Sweet Earth — Test Checklist

A running, checkbox-style list of things to test, from simple to complex.
Tick `[x]` when verified. Add new cases at the bottom of any section as you find them.

Legend: **(preview)** = works without Supabase keys · **(live)** = needs Supabase · **(server)** = needs the `delete-user` Edge Function deployed.

---

## 1. Accounts & login
- [ ] Sign up with a new email → lands logged in, appears in `profiles` **(live)**
- [ ] Log out → returns to a signed-out view
- [ ] Log back in with correct password → works
- [ ] Log in with a **wrong password** → shows an error (not a crash)
- [ ] Log in with an email that has **no account** → message says to sign up **(live)**
- [ ] Sign up with an **already-registered** email → sensible error
- [ ] Refresh the page while logged in → still logged in (session persists) **(live)**
- [ ] Sign up, delete the account, then sign up again with the same email → allowed **(server)**
- [ ] Invalid email format at sign up / login → blocked with a message
- [ ] Very long email / unicode email → handled

## 2. Roles & permissions (the recent bug)
- [ ] Toggle a permission for a role → **reload the page** → the toggle is still set **(live)**
- [ ] Create a new role with a specific toggle config → reload → role + config still there **(live)**
- [ ] Give a role `view_chapters` (etc.) → that tab appears for that role; reload keeps it **(live)**
- [ ] Owner row is locked (can't be unchecked) and always has every permission
- [ ] After loading saved roles, Owner still shows all-on + locked
- [ ] "Save changes" button in Owner Settings persists everything **(live)**
- [ ] Two people editing roles → last save wins (no crash)

## 3. Owner Settings (owner-only)
- [ ] Only the **owner** can open Owner Settings; admins cannot; members cannot
- [ ] "Viewing & filling out placeholders" toggle OFF → all ✎/＋ buttons disappear site-wide
- [ ] Toggle ON → edit buttons come back
- [ ] Member list is **empty until a search is entered**
- [ ] Search by email returns matching members **(live)**
- [ ] Change a member's role → **Save** persists it to `profiles` **(live)**
- [ ] Save button is disabled until a role is actually changed
- [ ] Delete account → confirm popup shows the right email + reason field **(server)**
- [ ] Delete with a reason → account gone, person emailed the reason **(server)**
- [ ] Add-member button is gone (new sign-ups appear automatically)

## 4. Content editing (as owner, edit mode ON)
- [ ] Edit mission / tagline / Discord link → saves; visible to a logged-out visitor after reload **(live)**
- [ ] Add **more than one** social account → all persist; the ＋ button stays **(live)**
- [ ] Add **more than one** affiliation → all persist **(live)**
- [ ] Remove a social/affiliation → gone for everyone **(live)**
- [ ] Socials show in the Contact sentence and the footer
- [ ] Empty states (no mission/socials/etc.) read cleanly for visitors
- [ ] Paste a script tag / HTML into a field → shown as text, not executed (no XSS)
- [ ] Very long mission text → wraps, doesn't break layout

## 5. Chapters
- [ ] "Start your own chapter" button → prompts to join / opens the (future) form
- [ ] Owner/admin "＋ Add a chapter" → continent dropdown + country + name
- [ ] Country names in other languages/scripts (日本, México, Кения, 中文) accepted
- [ ] Emoji / symbols in a chapter name accepted
- [ ] Chapters group by continent → then by country, **sorted by unicode**
- [ ] Multiple chapters in one country list under that country
- [ ] Chapters persist for visitors after reload **(live)**
- [ ] Only `chapters_add` roles see the add UI

## 6. Navigation & routing
- [ ] All tabs open the right page
- [ ] Gated tabs (chapters/gallery/calendar/owner) hidden/blocked per role
- [ ] Deep link (paste `…/#/programs`) loads that page
- [ ] Unknown hash → falls back to Home
- [ ] Switching model / reloading mid-session keeps you where expected

## 7. Home animation — light mode
- [ ] Scrolling **pins the scene** and phases spring→summer→autumn→winter before content
- [ ] Scrolling back up reverses through the seasons, then reveals the top
- [ ] Sun starts low on the **right**, arcs over, sets low on the **left**
- [ ] Sky is warm at sunrise/sunset, blue at midday
- [ ] Sun + glow stay **behind** hills/trees/clouds
- [ ] Tree shadows shift **opposite** the sun and lengthen near sunrise/sunset
- [ ] Leaves fall from **random** parts of the tree (not a sweeping bar)
- [ ] A leaf falls, rests on/just below the dark-green ground, then fades after ~1s
- [ ] The pile sits **on** the ground (not floating above it)
- [ ] Trees are **bare with no leaves exactly when snow is fully opaque**
- [ ] Ground shapes recolour green→white together (shapes match, no white overlay seams)
- [ ] Snow flakes stop at the ground (don't fall visibly below it)
- [ ] Wind swirls are rounded (not pointed); at most 2 at once; spawn in the bottom 2/3
- [ ] A breeze crossing a tree picks up **one** leaf and carries it off-screen, rotating, in front
- [ ] Wind + carried leaves render in **front** of everything
- [ ] Birds: at most 2 groups, in different lanes, calm frequency; **none at night**
- [ ] Clouds are in front of the sun

## 8. Home animation — dark mode
- [ ] Scene pins and phases while scrolling (like light mode)
- [ ] Moon runs through phases over the scroll; craters are spaced (not overlapping)
- [ ] Milky Way: brown/gold core + subtle blue/purple regions (not overly bright)
- [ ] No stars sit at/below the ground line
- [ ] Constellations light up as you scroll; a line traces and the stars enlarge
- [ ] **Deterministic mode** (`CONSTELLATION_MODE='all'`): all 20 light up in order across a scroll
- [ ] Switching to `'random5'` shows 5 random ones; a full scroll goes through those 5
- [ ] Southern constellations present (e.g., Southern Cross)
- [ ] Sleep **z's** rise diagonally (left→up-right, right→up-left), grow + fade, alternate tilt
- [ ] No birds, no sun, no falling leaves at night

## 9. Theme toggle
- [ ] Toggle switches day/night; scene rebuilds correctly
- [ ] Toggling mid-scroll keeps the season/phase position
- [ ] Top bar, footer, buttons all invert correctly (yellow-brown ↔ dark)
- [ ] Dark-mode toggle button is solid with a white icon

## 10. Responsive / environment
- [ ] Narrow mobile width: layout holds; trees/sun/ground still sensible
- [ ] Resize the window mid-scene → sun arc + constellations re-measure
- [ ] `prefers-reduced-motion` on → scene still changes with scroll, without frantic motion
- [ ] Incognito / memory off → no personalization errors
- [ ] Slow connection: page renders before Supabase resolves (falls back gracefully)

## 11. Supabase / infra
- [ ] `supabase-setup.sql` runs clean on a fresh project
- [ ] Re-running the SQL is safe (idempotent) — email column + backfill included
- [ ] RLS: a member cannot read others' profiles or self-promote
- [ ] Owner can read/search all profiles and update roles
- [ ] `site_content` row readable by anyone, writable only by owner/admin
- [ ] `delete-user` function rejects non-admin callers **(server)**

## 12. Pop-ups / modals (dismissal)
- [ ] Open any modal (Log in / Sign up / Profile / an editor / a confirm) then click the **×** → closes
- [ ] Open a modal then click the **dark backdrop** (outside the card) → closes
- [ ] Open a modal then press **Escape** → closes
- [ ] Open the **Profile** modal, click **Log out** → the modal closes (doesn't linger) and you're logged out
- [ ] With a modal open, click a **nav tab** (Home/Newsletter/…) → the modal closes and the page changes
- [ ] Log in from the Log in modal → modal closes on success
- [ ] Sign up (no email confirmation needed) → modal closes; (confirmation needed) → shows the "check your email" popup, which itself closes on × / Got it
- [ ] Owner deletes a member from the confirm modal → modal closes after the action
- [ ] Editor: open, make a change, Save → modal closes and the change shows
- [ ] Editor: open, then Escape/backdrop → closes without saving
- [ ] No "ghost" modal ever stays on screen after an action completes

## 13. Owner adds content — end-to-end save (theory check)
Prerequisites on Supabase (do once): run `supabase-setup.sql` (creates `profiles`, `site_content`, `is_admin()`, triggers, RLS), then promote your account with `update public.profiles set role='owner' where id='<your-user-id>';`.
- [ ] `site_content` row id=1 exists after running the SQL (seeded as `{}`)
- [ ] `is_admin()` returns true for your owner account (it matches role in owner/admin)
- [ ] Owner edits mission/tagline/Discord → toast "Saved for everyone" (not an error)
- [ ] Owner adds a social/affiliation/chapter → silently saved (no error toast); reload → still there
- [ ] Log in as a **member** (or open in a logged-out browser) → the owner's saved content appears
- [ ] If the SQL wasn't run, saving shows a clear error ("…is the site_content table set up?") rather than failing silently
- [ ] A member attempting the same write is rejected by RLS (only owner/admin can write)
- [ ] Roles/permission toggles persist through the same `site_content` row (see §2)

---

### Notes / found issues
- (add anything that fails here, with steps to reproduce)
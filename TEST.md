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

---

## 14. Header, branding & theming (installment 1)
- [ ] Top-left shows the **butterfly logo** (not text), left-justified, square, within the nav height (not spilling above/below)
- [ ] Logo has a transparent background — looks right in **both** light (yellow) and dark (brown) headers
- [ ] Browser tab shows the real **favicon** (requires favicon.ico, favicon-16/32, apple-touch-icon, android-chrome-192/512, site.webmanifest committed to the repo root next to index.html)
- [ ] Center nav **scrolls horizontally** when tabs don't all fit — on every width, phone through desktop
- [ ] When tabs *do* fit, they're **centered**; when they don't, you can still reach the leftmost tab (not clipped under the logo)
- [ ] Logo (left) and the toggle+Log In group (right) never overlap the center tabs
- [ ] Dark mode: header + footer are the lighter brown (#80471c), not the old near-black brown; text stays readable
- [ ] Top-right is a **single "Log In"** button (no separate Sign up); the login modal has a "Create an account" link
- [ ] Signed-in **account button** has a visible blue outline at rest; on hover the interior tints (not the outline)
- [ ] Left/right **page padding** present on all pages (text no longer runs to the screen edge)

## 15. Home hero (installment 1 — quick wins)
- [ ] Tagline reads "If not us, who?" / "If not now, when?" on **two lines**
- [ ] Buttons are **See Our Activities** (→ Activities) and **Start a Chapter** (→ Chapters)
- [ ] The "scroll ↓" hint is gone
- [ ] Sun is a warmer **yellow**; its glow is **yellowish** (never a dark halo)
- [ ] Mission box is editable in owner mode (✎ Edit mission)
- [ ] Equal spacing: mission box ↔ Discord box ↔ yellow footer

## 15b. Home hero (installment 2 — clouds + proportional scaling)
- [ ] Each word — Earth / Sweet / Earth — sits on its own **distinct white cloud**; the blue "Sweet" is clearly readable against the sky (no squinting)
- [ ] Word-clouds fully contain each word and never touch the tagline below
- [ ] Word-clouds disappear in **dark mode** (night sky needs no white puffs behind white text)
- [ ] No drifting cloud has a **flat vertical edge** — all are fully rounded
- [ ] On a **laptop** (~1280px+) the scene looks exactly as before (full size)
- [ ] On **iPad / phone widths** the sun, trees, clouds, birds, leaf pile, and their spacing all **scale down proportionally** — nothing looks oversized/too close
- [ ] Trees stay **planted at the grass line** at every width (crown visible above the hills; they don't sink behind the front hill)
- [ ] Trunk stays a **fixed distance from the screen edge** as trees scale
- [ ] Fallen-leaf pile lands on the grass (not floating/behind the hill) at small sizes; wind still plucks leaves from the (scaled) canopy
- [ ] Resize the window slowly across sizes — everything rescales smoothly with no misalignment

## 16. Chapters / Gallery text (installment 1)
- [ ] Chapters heading reads "Flip the page. **Take** the pen. Start *your* chapter today." and **scales to fit one line** at any width
- [ ] Chapter application: the "shown as an image on purpose" line is gone; the 5-member Discord note now says they must be ESE members + have (or make) a Discord, or use a parent's if under 13
- [ ] Gallery heading reads "An Impact You Can *See*" with no subtext

---

## 17. Under Construction, Privacy/Terms, Activities redesign (installment 3)

### Under Construction
- [ ] Category "Explore" buttons that aren't built (Speakers, Contests, Fundraising) land on the **Under Construction page**
- [ ] The page has the 🚧 art, a friendly message, and a Back to Home button
- [ ] A "dead" button (e.g., MyGreenSchools "Coming soon") shows the **hover tooltip** "Under construction — coming soon!" and a popup on click

### Privacy & Terms
- [ ] Footer shows **Privacy Policy · Terms & Conditions** on every page
- [ ] Each opens its own page (hidden from the nav bar) and reads cleanly
- [ ] Both mention: minors/under-13 + parent consent, media release, and that **ESE is not affiliated with Discord**
- [ ] ⚠️ These are drafts — an adult/attorney should review before relying on them

### Activities (was Programs)
- [ ] Nav tab is **Activities**; the URL is `#/activities`; the old `#/programs` is retired
- [ ] "See Our Activities" (home) lands on the new Activities page
- [ ] **Featured** section at top shows one activity with a Read more/less toggle
- [ ] Owner sees "✎ Edit featured"; editing name/description/image saves and persists after reload **(live)**
- [ ] **Category grid** (2×2, 1-wide on mobile): Speakers / Challenges / Contests / Fundraising, each a distinct color, laid out name → image → description → button
- [ ] **Challenges** "Explore" opens the Challenges page; the others open Under Construction
- [ ] Challenges page shows placeholder challenge cards (Read more/less) + **MyGreenSchools** (coming soon)
- [ ] Read more/less expands and re-collapses each card's description

---

## 18. About page, Youth Leadership form, signup country (installment 4)

### Signup / profile country
- [ ] Sign-up form has an optional **Country** dropdown (can be left blank)
- [ ] Country saves to the profile and shows preselected when you reopen your profile **(live)**
- [ ] Country is editable later from the profile **(live)**
- [ ] Run the updated `supabase-setup.sql` (adds the `country` column + `ese_stats()` function)

### About page
- [ ] "About" appears in the nav; opens the About page
- [ ] Intro shows the live "**X people across Y countries**" stat (needs `ese_stats()`; falls back to friendly text otherwise)
- [ ] Three sections in order: Board of Directors, Advisory Council, Youth Leadership Team
- [ ] Each section: a note, then a button, then a gallery of profile cards (circular pic + text), **1-wide on mobile**, multi-column on desktop
- [ ] Board & Advisory buttons = "Interested? Reach out!" → opens email to hello@earthsweetearth.org
- [ ] Youth button = "Apply for a Position" → opens the youth application form
- [ ] Placeholder cards show when a section is empty; owner can add/edit/remove real people (persists) **(live)**

### Youth Leadership application
- [ ] Reachable from About (not shown in the nav)
- [ ] Collects name, Discord, email, grade, school, country (+ conditional state/province), like the chapter form
- [ ] "I'm under 13" checkbox reveals the parent-email note
- [ ] Role checkboxes (President / VP / Treasurer / Secretary); picking one **reveals its responsibilities & qualifications**
- [ ] Discord **reputation threshold** shows; only the **owner** sees an Edit button, and it persists **(live)**
- [ ] Two 500-word essays + one 150-word nomination, each with a live word counter that flags going over
- [ ] reCAPTCHA stand-in (real one when a site key is added)
- [ ] Submit validates, stores to `youth_applications`, and shows a success modal **(live)**
- [ ] ⚠️ Emailing submissions to hello@earthsweetearth.org still needs an Edge Function/trigger (pairs with Owner Analytics) — not wired yet

---

## 19. Gallery redesign (installment 5)
- [ ] Heading "An Impact You Can *See*"; intro line; **~25 placeholder tiles** show for testing when the gallery is empty
- [ ] **Featured** section at top; "More moments" grid below
- [ ] Grid is responsive squares: **1 per row on mobile**, 3–5 columns on desktop
- [ ] **Reactions (LinkedIn-style):** top-3 emojis show clustered; on hover they spread apart and reveal counts; your own reaction is highlighted
- [ ] "Add reaction" (🙂+) opens a floating **emoji picker**; picking one sets your reaction (one per photo per account); clicking it again removes it
- [ ] Reacting/commenting while logged out prompts you to log in
- [ ] **Comments** open in a modal (so the grid never shifts): avatar + username + body + time, chronological
- [ ] Each comment is **reactable** with its own mini reaction bar
- [ ] Logged-in members can post a comment; the tile's comment count updates
- [ ] Owner (edit mode) sees per-tile **Feature/Unfeature, Edit, ×** and a top "**+ Add a photo**"; featuring moves a tile into the Featured section
- [ ] Bottom "**Submit yours on Discord**" button shows the under-construction tooltip on hover (not clickable)
- [ ] ⚠️ Reactions/comments are in-memory for now (reset on reload); durable per-account persistence + photo storage (Supabase Storage) is the backend follow-up

---

## 20. Newsletter list + Calendar (installment 6)

### Newsletter
- [ ] Posts are full-width rounded cards, **newest first**, each showing a **timestamp + title**
- [ ] Ships with 4 seed posts (2 short, 2 long) for testing
- [ ] Clicking a **short** post expands it in place (with a "Show less" collapse); the arrow flips
- [ ] Clicking a **long** post opens its **own page** (▾ vs ↗ arrow signals which)
- [ ] Owner can Publish (adds to top with the current time), Edit, and Delete posts
- [ ] The post page has a Back-to-Newsletter link and the full body

### Calendar
- [ ] Owner can **Connect a calendar** (paste a Google Calendar ID/email); it embeds the live Google Calendar (month view)
- [ ] Without an ID, a friendly placeholder shows (owner sees how to add it)
- [ ] Meeting link still works (owner add/edit)
- [ ] **Upcoming events** list is color-coded (Green/Blue/Amber/Rose/Purple/Gray), sorted by date
- [ ] An event with a link opens it on click (↗); one without opens its details
- [ ] Owner can Add / Edit / Delete events, including color + optional link
- [ ] Ships with 3 seed events for testing
- [ ] ⚠️ Newsletter posts + events are in-memory for now (seeded each load); the Google Calendar ID does persist

---

## 21. Owner Analytics + backend (installment 7)

### Sign-up validation
- [ ] Username with spaces/symbols → clear "letters and numbers only" error
- [ ] Username already taken → "already taken, pick another" (pre-checked via `username_available`) **(live)**
- [ ] Email already registered → "account exists, log in instead?" with a link **(live)**

### Owner Analytics (owner-only tab)
- [ ] "Owner Analytics" tab shows only for the owner (blue, like Owner Settings)
- [ ] Stat cards: members, countries, chapter & leadership applications (total + how many need review), chapters, posts, events, gallery
- [ ] **Needs review** lists each unreviewed application with a **red dot**; clicking one opens its details and clears the dot; "Mark reviewed" also clears it **(live)**
- [ ] A **red dot appears on the Owner Analytics tab** whenever anything needs review, and clears once everything is reviewed
- [ ] Traffic: total views, views this week, and a 7-day bar chart (needs `ese_traffic` + page_views) **(live)**

### Emailing
- [ ] After a chapter/leadership application is submitted, a summary emails to hello@earthsweetearth.org — **needs the `notify-application` Edge Function deployed + a Resend API key**

### Database
- [ ] Re-run `supabase-setup.sql` (adds: username unique index, `username_available()`, `reviewed` columns, `page_views` table, `ese_traffic()`)

### Still pending (final backend piece)
- [ ] Durable per-account persistence for **gallery reactions/comments**, **newsletter posts**, and **calendar events** (needs member-writable tables + Supabase Storage for images/avatars) — currently in-memory/seeded
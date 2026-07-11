# Setting up Discord verification

The website side is **already built**. This is the configuration that has to happen
outside the code — in Discord and in Supabase. Nothing on the site breaks if you
skip this: Discord verification simply stays switched off until you turn it on.

There are three pieces:

| Piece | What it gives you | Needed for |
|---|---|---|
| 1. Discord developer app | "Continue with Discord" login | Linking accounts |
| 2. Supabase provider + manual linking | Lets a logged-in member attach Discord | Linking accounts |
| 3. Discord bot + Edge Function secrets | Reading someone's Discord **roles** | Role mapping |

You can do 1 + 2 and stop there: members get linked and their Discord username is
saved. You need 3 as well if you want Discord roles to grant website roles.

---

## 1. Create a Discord application

1. Go to <https://discord.com/developers/applications> → **New Application** → name it
   `Earth Sweet Earth`.
2. Open **OAuth2** in the sidebar. Copy the **Client ID** and **Client Secret**
   (click *Reset Secret* if it's hidden). Keep these private.
3. Under **Redirects**, add your Supabase callback URL:

   ```
   https://najuadikmuiojsmnylya.supabase.co/auth/v1/callback
   ```

   Save.

## 2. Turn it on in Supabase

1. Supabase dashboard → **Authentication → Providers → Discord**.
2. Enable it, paste the **Client ID** and **Client Secret** from step 1, and save.
3. Supabase dashboard → **Authentication → Settings** (or *Sign In / Providers*) →
   turn on **Manual linking**. This is what allows a member who signed up with email
   to *attach* Discord to that same account, instead of creating a second one.

At this point: log in on the site → the Discord popup appears → **Continue with
Discord** → the account links and the username is saved. ✅

## 3. (For role mapping) Add a bot and deploy the function

Reading a member's **roles** needs a bot, because Discord will only tell you someone's
roles if you ask as the server itself.

1. Same Discord application → **Bot** → **Add Bot**. Copy the **Bot Token**.
2. **OAuth2 → URL Generator**: tick scope `bot`, then invite the bot to the Earth
   Sweet Earth server with the generated URL. It needs no special permissions —
   just being in the server is enough to read roles.
3. Get your **server ID**: in Discord, enable *Settings → Advanced → Developer Mode*,
   then right-click the server icon → **Copy Server ID**.
4. Deploy the function and give it the secrets:

   ```bash
   supabase functions deploy discord-verify
   supabase secrets set DISCORD_BOT_TOKEN=your_bot_token
   supabase secrets set DISCORD_GUILD_ID=your_server_id
   ```

## 4. Set up the mapping

On the site: **Owner Settings → Discord**.

- Turn on **"Ask people to verify with Discord when they log in."**
- Optionally turn on **"Make it required"** (someone who declines gets logged back out).
- Add mappings: left = the website role, right = the **exact** Discord role name.

```
Owner           ->  Owner
Admin           ->  Admin
Chapter Leader  ->  Chapter Leader
Moderator       ->  Moderator
```

Two things to remember:

- **The Discord role name must match exactly** — capitals, spaces and all. `Chapter Leader`
  is not the same as `chapter leader`.
- **The first match wins**, so put the highest role at the top. If someone has both
  `Admin` and `Moderator` in Discord, and Admin is listed first, they get Admin.

---

## How the security works (worth understanding)

The browser **never** sets anyone's role. When a member verifies:

1. The site calls the `discord-verify` Edge Function.
2. The function checks who is *actually* calling (from their login token — it ignores
   any id the browser sends).
3. It asks Discord, using the bot, which roles that person really has.
4. It reads your mapping from the database.
5. It updates their role using the service key, server-side.

If any of that ran in the browser, a member could edit the page and make themselves
Owner. This is why the bot token and service key live in Supabase secrets and are
never in `index.html`.

## Under-13 note

Discord requires users to be at least 13. The verification popup says so, and tells
younger members to use a parent or guardian's account — same rule as the chapter and
leadership forms.

## Troubleshooting

| What you see | What it usually means |
|---|---|
| "Discord sign-in isn't switched on yet" | Step 2 isn't done (provider off, or manual linking off) |
| "You're not in the Earth Sweet Earth Discord server yet" | The member linked fine but hasn't joined the server |
| "Discord refused the request" | Bad bot token / server ID, or the bot isn't in the server |
| Linked, but no role applied | No mapping matches their Discord roles — check the exact spelling |
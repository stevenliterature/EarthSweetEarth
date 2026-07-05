# Earth Sweet Earth 🌍

A youth-led environmental project growing a greener, kinder planet — one neighborhood at a time.

**Website:** [earthsweetearth.org](https://earthsweetearth.org) · **Repo:** https://github.com/stevenliterature/EarthSweetEarth
**Status:** In formation (2026) — website is **live** ✅ · **Based in:** Syosset, NY (Nassau County, Long Island)

This repo holds the Earth Sweet Earth website. This README is the general info doc — what the project is, how to run and deploy the site, and the roadmap for becoming a real organization. For a running record of what's already been set up, see `SETUP-LOG.md`. If you're an AI coding assistant (Claude Code), read `CLAUDE.md` instead.

> **Note on the numbers below:** prices, fees, and legal rules are current as of 2026 and are for the U.S., New York State. Syosset is in Nassau County, but nonprofit filings happen at the **New York State + federal** level — there's no separate county nonprofit registration to worry about. Always check the official source before spending money or filing anything.

---

## ⚠️ Read this first: the founder is under 18

This project is founded and run by a middle-school student. In the U.S., people under 18 generally can't sign legally binding contracts, and many states (New York included) restrict minors from serving as nonprofit directors/officers. **This is normal and fixable:** a trusted adult (usually a parent or guardian) acts as the *signatory* — they sign contracts, hold the on-file officer titles, and handle payments. The founder still leads the project and does the work.

**Step zero for anything involving money or paperwork:** get a parent/guardian on board as a partner.

---

## The website

Right now it's a single static page (`index.html`) — plain HTML/CSS, no build step. But it's **built to grow**: we plan to add media (photos, video) and more pages, and we can move to a build step or framework later (see [Growing the site](#growing-the-site)). "Static" today doesn't mean plain or permanent — it's just the simplest starting point.

### Run it locally
Open `index.html` in a browser, or serve it:
```bash
python3 -m http.server 8000
# then open http://localhost:8000
```

### Edit the content
Everything you should change is marked `<!-- CHANGE THIS -->` in `index.html`: the name, mission, focus areas, and contact email. It's just a text file — edit it in any editor.

### Adding media as we grow
- **Images:** fine to keep in the repo, but **optimize them first** (export as WebP or AVIF, keep them a reasonable size). Big unoptimized images slow the site and bloat the repo.
- **Video:** don't store video files in the repo. **Embed** from YouTube or Vimeo (free) — it saves bandwidth, storage, and money, and it just works.
- **Bandwidth:** if we ever self-host lots of media, **Cloudflare Pages** has no bandwidth cap on its free tier (the others cap at ~100 GB/month), which is the best fit for media-heavy sites.

### What actually costs money
Just the **domain** (~$11–15/year, already purchased on Namecheap). Hosting stays **free**, and media can stay free too by embedding video and using free image/CDN tiers. You'd only pay later if you self-host large media at scale or want a premium tool.

---

## Domain & DNS: connect Namecheap to GitHub Pages

The domain (`earthsweetearth.org`) is registered at **Namecheap**; the site is published free from this GitHub repo using **GitHub Pages**.

> ✅ **This is already set up and live** (July 4, 2026). The steps below are kept as a reference for how it was done — and how to redo it if anything ever breaks. See `SETUP-LOG.md` for the full record.

Here's the exact setup. *(Verified against GitHub's official docs, 2026.)*

### Step 1 — Turn on GitHub Pages
In the repo: **Settings → Pages**. Under **Build and deployment → Source**, choose **Deploy from a branch**, set branch to `main` and folder to `/ (root)`, then **Save**. (Later, if we add a framework/build step, switch this to **GitHub Actions** — see [Growing the site](#growing-the-site).)

### Step 2 — Set the custom domain in the repo
Still in **Settings → Pages**, under **Custom domain**, enter `earthsweetearth.org` and **Save**. GitHub adds a `CNAME` file to the repo (keep it — don't delete it).

### Step 3 — Point Namecheap's DNS at GitHub
In Namecheap: **Domain List → Manage** (next to earthsweetearth.org). First, on the **Domain** tab, make sure **Nameservers** is set to **Namecheap BasicDNS** (otherwise the records below won't apply). Then open the **Advanced DNS** tab → **Host Records**.

**Delete Namecheap's default records first** — it usually pre-adds a `CNAME www → parkingpage.com` and/or a URL Redirect on `@`. Those will conflict, so remove them.

Then **Add New Record** for each of these:

| Type | Host | Value | TTL |
|---|---|---|---|
| A Record | `@` | `185.199.108.153` | Automatic |
| A Record | `@` | `185.199.109.153` | Automatic |
| A Record | `@` | `185.199.110.153` | Automatic |
| A Record | `@` | `185.199.111.153` | Automatic |
| CNAME Record | `www` | `stevenliterature.github.io.` | Automatic |

*(Optional — IPv6 support: also add four `AAAA` records on host `@` with values `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`.)*

Click **Save All Changes**.

### Step 4 — Turn on HTTPS and confirm
DNS changes take anywhere from a few minutes to a couple hours (occasionally up to 24). Once it propagates, GitHub issues a free SSL certificate; then go back to **Settings → Pages** and tick **Enforce HTTPS**.

Check it's working from a terminal:
```bash
dig earthsweetearth.org +noall +answer          # should list the four 185.199.108–111.153 IPs
dig www.earthsweetearth.org +noall +answer      # should show CNAME → stevenliterature.github.io
```
Then open `https://earthsweetearth.org`. 🎉

### Email (free forwarding)
`hello@earthsweetearth.org` and `info@earthsweetearth.org` forward to a real inbox using **Namecheap's free email forwarding** (Domain tab → *Redirect Email*) — no paid mailbox needed. The site's contact link uses `hello@`.

### Growing beyond GitHub Pages
GitHub Pages can serve a React/Astro site too (build it with **GitHub Actions** and deploy the output), so it's not a static-only dead end. Its one real limit is no server-side/serverless functions — for contact forms or newsletter signups, use a free service like **Formspree**. If we later need serverless functions, form handling, or heavier media, connect this same repo to **Netlify** or **Cloudflare Pages** instead; each gives you its own DNS values to swap into Namecheap (Cloudflare Pages is easiest if we move the domain's nameservers to Cloudflare, and has unlimited bandwidth for media).

### DNS gotchas
- Nameservers **must** be Namecheap BasicDNS (not "Custom DNS"), or Advanced DNS records are ignored.
- Remove leftover Namecheap **parking/redirect** records on `@` and `www`.
- The `www` CNAME points to `stevenliterature.github.io` — **without** the repo name.
- If we switch to a static-site generator that force-pushes, make sure the build **keeps the `CNAME` file**, or the custom domain breaks.

---

## What makes a good nonprofit site
Answer three questions fast: **What is this? Why care? What can I do?**
- Clear name + one-sentence mission at the top
- A short, honest "why we exist" in your own voice
- Concrete focus areas (be specific: "monthly park clean-ups," not "we help the environment")
- A way to get involved / contact you
- Real photos of activities as you do them (nothing builds trust faster)

Being "just getting started" is charming, not a weakness.

---

## Cost & time summary

| Item | Cost | Time | When |
|---|---|---|---|
| Domain (earthsweetearth.org) | ~$11–15/yr (✅ purchased) | — | Done |
| Website hosting (GitHub Pages) | **Free** | ✅ done | Done |
| Email forwarding (hello@, info@) | **Free** (Namecheap) | ✅ done | Done |
| Media (images optimized, video embedded) | **Free** at this scale | — | As you grow |
| Fiscal sponsorship | 0% setup at some sponsors; ~1–15% of donations | Days | When accepting donations |
| EIN (federal tax ID) | Free | Minutes | If/when you incorporate |
| NY Certificate of Incorporation | $75 | Weeks | When becoming a real nonprofit |
| 501(c)(3) — Form 1023-EZ | $275 | ~2–4 weeks | If eligible & ready |
| 501(c)(3) — Form 1023 (full) | $600 | ~3–9 months | If larger/complex |

---

## Corrected priority order
The "website first" instinct is good — it's cheap, doesn't require being a nonprofit, and builds credibility. Refined order:

1. **Get a parent/guardian partner** (signatory) — step zero.
2. **Nail the mission** in 1–2 sentences.
3. **Put the website up** ← ✅ done — live at [earthsweetearth.org](https://earthsweetearth.org).
4. **Learn the basic regulations** *before* recruiting a board (so you know what you're asking of people).
5. **Recruit a board** — after deciding fiscal sponsorship vs. your own nonprofit.

**Key idea:** a website is *not* the same as being a legal nonprofit. The site goes up now; the legal stuff is a separate, slower, optional decision.

---

## Board of directors
- **How many:** New York requires a minimum of **3** directors. Start with 3, grow to 5–7. Odd numbers avoid tie votes.
- **Expertise to aim for:** the mission/environment, money/finance (a treasurer), legal/nonprofit know-how, fundraising & communications, and — importantly — trusted adults who can be signatories.
- **Rules:** board members are **not paid** for board service. Starting with family is fine, but add non-family members over time for independence and credibility.

---

## Regulations & the smart shortcut

**Becoming a legal nonprofit** normally means: incorporate in your state → get an EIN (free) → apply to the IRS for 501(c)(3) status → register with the state charity regulator before fundraising. New York specifics (these apply in Syosset just like anywhere in the state): the Certificate of Incorporation ($75) may need extra agency sign-off for some types (e.g., education nonprofits need State Education Department approval), and you must register with the **NY Attorney General's Charities Bureau (CHAR500)** *before* soliciting donations. NY enforces this strictly.

**The shortcut — fiscal sponsorship (recommended to start):** an existing charity lets your project run under *their* tax-exempt umbrella, so donations become tax-deductible **without** you forming your own 501(c)(3). It's fast (days), low-overhead, and perfect for test-driving the idea. Sponsors typically charge ~1–15% of what you raise; some have no setup fee or minimums. Trade-off: no separate sales-tax exemption or nonprofit discounts. Most founders "graduate" to their own 501(c)(3) later once they're bigger.

If you *do* form your own later, you'll likely qualify for **Form 1023-EZ** ($275) if you expect ≤ $50,000/year in gross receipts and ≤ $250,000 in assets.

---

## Common pitfalls
- **Becoming a legal nonprofit too early** — it adds ongoing homework (annual IRS Form 990, NY CHAR500, biennial statement). Missing Form 990 for 3 years = automatic loss of tax-exempt status. Fiscal sponsorship avoids this while small.
- **Fundraising before registering** to solicit (especially in NY).
- **Getting political with a tax-exempt org** — endorsing candidates can risk your status. Advocate for the *cause*, not candidates.
- **Buying too much too early** — you only need a domain + free host.
- **Letting the domain lapse** — recovery is expensive; use auto-renew.
- **All-family board / tangled finances** — keep clean records, add non-family members over time.
- **Burnout** — do one thing well, then build.

---

## Going forward
- **Prove it small:** run one real activity (a clean-up, a talk), photograph it, put it on the site.
- **Decide the money question** with your adult partner — look into a fiscal sponsor first; have an adult review any agreement.
- **Build the board** to fill skill gaps once you know your structure.
- **Keep clean records** from day one (even a simple spreadsheet).
- **Form your own 501(c)(3)** only when you've outgrown the sponsor.

---

## License
Content © Earth Sweet Earth, 2026.
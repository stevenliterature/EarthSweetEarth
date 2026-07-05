# CLAUDE.md

Instructions for Claude Code working in this repo. Read `README.md` for the full human-facing project background, and `SETUP-LOG.md` for what's already been set up.

## Project

Earth Sweet Earth — the website for a youth-led environmental nonprofit **in formation**, based in Syosset, NY (Nassau County, Long Island). It is founded and run by a **middle-school student who is still learning to code**, so keep everything approachable, well-commented, and explained in plain language.

- **Repo:** https://github.com/stevenliterature/EarthSweetEarth
- **Domain:** `earthsweetearth.org` (registered at Namecheap)
- **The founder is under 18.** Anything involving contracts, payments, domain purchases, or legal/nonprofit filings is handled by a trusted adult, not by Claude Code. Don't take real-world actions that spend money or make commitments — build and explain instead.

## Stack (today) and direction

- **Today:** a single static page, `index.html` — vanilla **HTML + CSS**, styles in a `<style>` block, Google Fonts, inline **SVG**, and **CSS custom properties** (design tokens) in `:root`. It has a top nav, hero, mission, a numbered "what we do" list, a founder's note, a photo strip, get-involved, and footer — plus an inline SVG favicon, Open Graph/Twitter meta, and a `prefers-reduced-motion`-safe scroll reveal. No framework, no build step, no backend yet.
- **Direction:** this is expected to **grow** — more pages, photos/video, and possibly a build step, a framework, a CMS, or a form/serverless service later. The founder knows some **React**. Do **not** treat "static" as permanent.

## Commands

- Preview: open `index.html`, or run `python3 -m http.server 8000` → `http://localhost:8000`.
- No build/lint/test yet. **If you add a framework or build step, document the exact install/build/deploy commands here and in `README.md`.**

## Deployment

- **Live at https://earthsweetearth.org** (since July 4, 2026) via **GitHub Pages**. The repo is **public**; Pages is set to **Deploy from a branch**, `main` / root. Custom domain connected through **Namecheap DNS** (four `A` records on `@` → GitHub IPs, `www` CNAME → `stevenliterature.github.io`). Full how-to in `README.md`; full record in `SETUP-LOG.md`.
- **Shipping a change:** edit → commit → push to `main`; the live site updates in about a minute.
- The homepage file must stay named **`index.html`**, and the repo's **`CNAME` file must be preserved** — deleting or overwriting it breaks the custom domain.
- **Enforce HTTPS is on**; `http://` and `www` redirect to `https://earthsweetearth.org`.
- **Email:** `hello@` and `info@earthsweetearth.org` forward to a real inbox via Namecheap forwarding (the site's contact link uses `hello@`).

## Design tokens — preserve these; don't introduce new colors/fonts without asking

```
--pine:       #14312a   /* deep forest green: hero bg + headings */
--forest:     #2f5d4a
--moss:       #6a9a6f
--honey:      #f0b24a   /* warm accent (the "sweet") */
--honey-deep: #d9932a
--cream:      #f9f6ee   /* light section bg */
--paper:      #fffdf8   /* cards */
--ink:        #23342d   /* body text on light */
--mist:       #dcebe2
```
Display font: **Fraunces**. Body font: **Inter**.

## Design direction — keep it bespoke, not "templated"

The founder rejected an earlier version for looking **"too AI-like."** That's a *design* problem, not a tooling one — so the fix is craft, not a new framework.

- **Stay vanilla HTML + CSS, no build step.** Do **not** reach for **Tailwind** or **shadcn/ui** — shadcn especially is the signature look of AI-generated sites, and its cool, techy style fights this warm, earthy brand. (A framework/Tailwind is only worth discussing if the site grows to many pages — see "Growing the site.")
- **Make it read as hand-made and editorial:** expressive Fraunces display type, the pine/honey/cream palette used boldly, organic motifs (the sunrise-behind-hills, leaves, a faint paper grain), asymmetric layouts (e.g. a numbered list rather than three identical icon-cards), and a genuine first-person founder's voice.
- **Avoid the generic tells:** everything centered, three identical feature cards, pill-badges everywhere, cool-gray palettes, and filler copy.

## Growing the site — don't over-build, but don't box us into static-only

- **Don't add frameworks, build tooling, or a backend preemptively.** Simplicity is a feature while the founder is learning.
- **But the project will grow.** When a real need appears, propose the **simplest option that fits** and discuss trade-offs before adding it:
  - More pages / a blog → a static-site framework like **Astro** or **Vite + React** (the founder knows React). Still free to host; switch GitHub Pages to the **GitHub Actions** build source and keep the `CNAME` file in the output.
  - Contact form / newsletter → a hosted service like **Formspree** rather than a custom backend.
  - Only reach for an actual backend/database if a feature genuinely can't be done with static + a third-party service — and talk it through first.
- **Media guidance:** optimize images (**WebP/AVIF**, sensible sizes). **Embed large video** from YouTube/Vimeo or a CDN instead of committing big binary files (keeps the repo light and hosting free). If large files are unavoidable, use **Git LFS** or an external asset host.

## Rules

- **Keep the `<!-- CHANGE THIS -->` comments** in `index.html` — they show the founder what content is safe to edit.
- **Keep the accessibility floor:** semantic HTML, visible keyboard focus, responsive down to mobile, respect `prefers-reduced-motion`. Keep animation subtle.
- **No analytics, tracking pixels, or third-party scripts** without explicitly asking first (youth project — privacy matters).
- **Never commit secrets, API keys, or personal info** (real home address, phone number).
- **When restructuring** (splitting files, adding a build), update `README.md` and this file, and preserve the `CNAME` file so the domain keeps working.

## Writing style (for any copy you add)

Warm, honest, plain language. Sentence case. Active voice. No filler or hype. Say what things do in words a beginner and a general visitor both understand.

## How to work with this founder

- **Explain your changes in simple terms** — the founder is learning. Prefer teaching over jargon.
- **When unsure between two approaches, show both and let the founder choose** rather than deciding architecture for them.
- **Make minimal, focused changes** — don't refactor unrelated code.
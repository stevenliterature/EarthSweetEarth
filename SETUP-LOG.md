# Setup log

A running record of the basic setup for the Earth Sweet Earth website — what's done and what's next, newest first. For *how* the site works, see `README.md`; for AI-assistant instructions, see `CLAUDE.md`.

---

## July 4, 2026 — the site is live 🌱

The website is built, deployed, and reachable at **https://earthsweetearth.org** over HTTPS.

### Website
- Built `index.html`: a single static page in vanilla HTML + CSS, no build step. Sections: top nav, hero, mission, a numbered "what we do" list, a founder's note, a photo strip, "get involved," and footer.
- Uses the project design tokens (Fraunces + Inter; the pine/honey/cream palette) with organic touches — a sunrise-behind-hills scene, drifting leaves, and a faint paper texture — so it reads as hand-made rather than templated.
- Accessibility floor: skip link, visible keyboard-focus rings, semantic landmarks, responsive down to ~360px (verified: no horizontal scroll), and a subtle scroll reveal that switches off under `prefers-reduced-motion`.
- Added Open Graph / Twitter link-preview meta tags and an inline SVG favicon.
- Content is placeholder for now — 15 spots marked `<!-- CHANGE THIS -->`.

### Repository & hosting (GitHub Pages)
- Repo `stevenliterature/EarthSweetEarth` set to **public** (required for free GitHub Pages).
- GitHub Pages: **Deploy from a branch**, `main` / root.
- Custom domain `earthsweetearth.org` set; GitHub committed the `CNAME` file (kept — deleting it breaks the domain).
- Added `.gitignore` (ignores `.DS_Store` and similar clutter).

### Domain & DNS (Namecheap)
- Nameservers left on **Namecheap BasicDNS**.
- Deleted the default parking records (the `@` parking A record, the `www → parkingpage.namecheap.com` CNAME, and the URL-forward redirect).
- Added four `A` records on `@` → GitHub Pages IPs `185.199.108–111.153`, plus a `www` CNAME → `stevenliterature.github.io`.

### HTTPS
- GitHub issued the SSL certificate; **Enforce HTTPS** is on. `http://` and `www` both redirect to `https://earthsweetearth.org`.

### Email
- Namecheap free email forwarding set up for `hello@earthsweetearth.org` and `info@earthsweetearth.org`. The site's "Say hello" link uses `hello@`.

### Verified
- `dig` returns the four GitHub IPs across multiple resolvers; `www` resolves through to GitHub.
- `https://earthsweetearth.org` returns `200` from GitHub with a valid certificate, serving the current `index.html`.

---

## Next up (nothing here is blocking)

- [ ] Founder reviews the visuals and fills in the `CHANGE THIS` content (name, mission, three focus areas, contact email).
- [ ] Add real photos to the "From the ground" strip (optimize as WebP first).
- [ ] Confirm the domain is set to **auto-renew** (letting it lapse is costly to recover).
- [ ] When there's real activity: decide fiscal sponsorship vs. own 501(c)(3) with the adult partner (background in `README.md`).

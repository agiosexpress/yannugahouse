# Casa Yannuga

Booking app for the beach house in Rye (VIC), shared between friends.
One HTML file, no build step. Portuguese and English, switchable from the top bar.
Database on Supabase, hosting on GitHub Pages.

## What's in here

| File | What it is |
|---|---|
| `index.html` | The whole app — screens, calendar, credits, scoreboard, history |
| `config.js` | The two Supabase keys. **The only file you edit.** |
| `supabase/schema.sql` | Tables, realtime and policies. Run it once. |
| `photos/` | The 7 photos of the house |
| `manifest.webmanifest` | Lets it install as an app on a phone's home screen |

## Step 1 — Supabase

1. supabase.com → **New project**. Pick the **Sydney** region.
2. **SQL Editor** → **New query** → paste all of `supabase/schema.sql` → **Run**.
   Safe to re-run: it only adds what's missing, and it upgrades a database built
   on the old room model without dropping the bookings already in it.
3. **Project Settings → API**. Copy the **Project URL** and the **anon public** key.
4. Edit `config.js` and paste both values in.

## Step 1b — the accounts

1. **Authentication → Users → Add user**, once per member. One email each, a password you
   choose, and tick **Auto Confirm User** — otherwise Supabase tries to send an email and stalls.
2. Copy each user's **UUID** (it shows in the list).
3. **SQL Editor** → run this, swapping in the UUIDs:

```sql
insert into profiles (user_id, hh, admin) values
  ('pedro-uuid',   'pj', true),
  ('niklas-uuid',  'nc', true),
  ('du-uuid',      'dj', false),
  ('bruna-uuid',   'bc', false),
  ('couple5-uuid', 'n5', false),
  ('victor-uuid',  'vt', false)
on conflict (user_id) do update set hh = excluded.hh, admin = excluded.admin;
```

The member codes are `pj`, `nc`, `dj`, `bc`, `n5`, `vt` — same order they appear in the app.
Anyone with `admin = true` can book in anyone's name; the others only in their own.

Send each member their password by WhatsApp. They sign in once and the browser remembers.

## Step 2 — GitHub Pages

1. Create a new repository (it can be private; Pages works on private repos on a paid plan, on a free account use public).
2. Upload every file in this project.
3. **Settings → Pages → Source: Deploy from a branch → main / (root)** → Save.
4. In a minute or two the address appears: `https://YOUR-USERNAME.github.io/casa-yannuga/`

Send that link to everyone. On a phone, **Share → Add to Home Screen** installs it as an app.

## The model, as the code implements it

**One cota = $190/month = 100 credits/year** (`COTA`, `PER`). Same price for everyone.
A couple is two cotas: $380 and 200 credits. Eleven cotas bring in $2,090/month.

**The aporte** is the gap between the cotas and the $2,800 the house costs: **$760/month**,
paid by Pedro & Júlia and Niklas & Carol, $380 each. It lives in the `ap` field of each
household in `DEF`, has its own row in the payments grid, and every dollar the house earns
goes back to the payers before anything reaches the house fund.

**You book a bed, not a room.** The six beds are in `BEDS`, each with a weight:

| Bed | `id` | Sleeps | Low | Mid | Peak |
|---|---|---|---|---|---|
| Bedroom 1 (double) | `q1` | 2 | 2 | 4 | 8 |
| Bedroom 2 (double) | `q2` | 2 | 2 | 4 | 8 |
| Bunk, bottom | `bl` | 2 | 1 | 2 | 4 |
| Bunk, top | `bu` | 2 | 1 | 2 | 4 |
| Sofa bed | `sf` | 2 | 1 | 2 | 4 |
| Folding single | `fd` | 1 | 1 | 2 | 4 |

A night costs `bed weight × season weight`, with season weights in `W`
(peak 4, mid 2, low 1). Peak is 18 Dec – 26 Jan (`AI`/`AO`), mid is Fridays, Saturdays
and the long weekends, low is everything else.

**The whole house is never paid in credits** — it is a daily rate, in `DAYR`:
$200 Monday–Thursday, $350 weekends, $400 in summer. Same for a member and an outsider.
That money goes to the aporte.

**Extra credits** are $25 each (`EXTRA`), no limit, any time. Also to the aporte.

## Rules baked into the code

- **21-day booking window** (`AHEAD`). Major holidays are exempt — those are agreed as a group.
- **Two consecutive weekends in the same double room, maximum** (`MAXWK`, `DOUBLES`).
- One bed, one booking, one night: `taken()` and `clash()` enforce it.
- Cancelling refunds the credits immediately and writes the cancellation to the open history.
- Everything is logged to `log` and shown to everyone: who booked, which bed, which nights,
  when the booking was made, what it cost, plus cancellations, credit purchases and
  whole-house nights.
- Lease 2 Oct 2026 – 1 Oct 2027 (`IN`/`OUT`), in Pedro & Júlia's and Niklas & Carol's names.

To change any number, edit the constants at the start of the `<script>` in `index.html`.
Names and cota counts live in the `DEF` array just below them.

## First access: the cotas, then the terms, then the login

The first time the app opens on a device it shows the full **cotas page** — prices per bed,
the calculator, what a cota buys, the rules, the monthly sums — and only lets the person
through after they tick the declaration and tap **I agree and want to join**. The acceptance
is saved on the device with the date, and once they sign in it is written to
`profiles.terms_at` so it is on record for everyone.

The login screen has a link, **Reread the cotas and the rules**, that reopens the page
before signing in, as many times as they like. After login the **Cotas** button in the
top bar does the same.

The page is one block of bilingual HTML inside `index.html` (`<div class="terms tpage">`);
the standalone copy published as an artifact is the same block with its own frame. When a
number changes, change it in both. `TERMS_V` at the top of the terms code is the version —
bump it and everyone is asked to agree again.

## Language

The app picks Portuguese or English from the browser and remembers the choice per device.
The **PT / EN** button in the top bar switches it. Static text lives in paired
`data-l="pt"` / `data-l="en"` elements; everything the script writes comes from the `TX`
dictionary at the top of the `<script>`.

## Security

Every table requires a login: without an account, anyone who finds the address can neither
read nor write. The history table is append-only — anyone signed in can add to it and read
it, nobody can edit or delete what is already there. Each person only sees themselves when
booking; anyone with `admin` can book for everyone. To remove someone from the group, delete
their user under **Authentication → Users**.

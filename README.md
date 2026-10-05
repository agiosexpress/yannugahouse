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
| `manifest.webmanifest`, `sw.js`, `icons/` | Let it install as an app on a phone's home screen |

## Step 1 — Supabase

1. supabase.com → **New project**. Pick the **Sydney** region.
2. **SQL Editor** → **New query** → paste all of `supabase/schema.sql` → **Run**.
   Safe to re-run: it only adds what's missing, and it upgrades a database built
   on the old room model without dropping the bookings already in it.
3. **Project Settings → API**. Copy the **Project URL** and the **anon public** key.
4. Edit `config.js` and paste both values in.

## Step 1b — the accounts

1. **Authentication → Users → Add user**, once per person — every cota holder has their own
   account. One email each, a password you choose, and tick **Auto Confirm User** — otherwise
   Supabase tries to send an email and stalls.
2. Copy each user's **UUID** (it shows in the list).
3. **SQL Editor** → run this, swapping in the UUIDs:

```sql
insert into profiles (user_id, hh, admin) values
  ('pedro-uuid',  'pe', true),
  ('julia-uuid',  'ju', false),
  ('niklas-uuid', 'ni', true),
  ('carol-uuid',  'ca', false),
  ('du-uuid',     'du', false),
  ('john-uuid',   'jo', false),
  ('bruna-uuid',  'br', false),
  ('caio-uuid',   'cc', false)
on conflict (user_id) do update set hh = excluded.hh, admin = excluded.admin;
```

The codes come from `DEF` in `index.html`. Cotas 9–12 are `c9`, `c10`, `c11`, `c12`: when
someone takes one, change its `name` (and `ab`, the initials) in `DEF`, delete `vaga:true`,
create their account and add their profile row. The aporte and the sums on the cotas page
recalculate on their own.
Anyone with `admin = true` can book in anyone's name; the others only in their own.

Send each member their password by WhatsApp. They sign in once and the browser remembers.

## Step 2 — GitHub Pages

1. Create a new repository (it can be private; Pages works on private repos on a paid plan, on a free account use public).
2. Upload every file in this project.
3. **Settings → Pages → Source: Deploy from a branch → main / (root)** → Save.
4. In a minute or two the address appears: `https://YOUR-USERNAME.github.io/casa-yannuga/`

Send that link to everyone. On a phone, **Share → Add to Home Screen** installs it as an app.

## The model, as the code implements it

**One person, one cota: $190/month = 100 credits/year** (`COTA`, `PER`). Same for everyone,
couple or single — credits, payments, the ficha and expenses are all individual. Up to 12
cotas (`DEF`); the ones still open carry `vaga:true` and stay out of every sum.

**The aporte** is the gap between the filled cotas and the $2,500 the house costs (rent and
bills, flat — `RENT`), split between the people marked `apo:true` (Pedro, Júlia, Niklas,
Carol): `APO_TOTAL = RENT − COTA × filled cotas`. With 8 cotas that is $980/month, $245 each;
every cota filled lowers it by $47.50 each. It has its own row in the payments grid, and every
dollar the house earns goes back to the payers. There is no house fund: expenses are split
between everyone by cota as they happen.

**Credits are per person, per night:** low 1, mid 2, peak 4 (`W`), in any bed, alone or not —
nobody pays double for coming alone. Peak is 18 Dec – 26 Jan (`AI`/`AO`), mid is Fridays,
Saturdays and the long weekends, low is everything else.

**You book a bed and mark who sleeps in it.** Each person on the booking (`ppl`) pays their
share from their own credits; a bed takes as many people as it sleeps (`BEDS[].sl`):
Bedrooms 1 and 2 and the bunks and sofa sleep 2, the folding single 1.

**The ficha** (`FREE_N`, `FREE_MAX`, `FREE_AHEAD`): once a year each person can seal the whole
house for free, up to 5 nights, booked up to 60 days ahead, with at least one free night
between two fichas (no back-to-back). Dates touching peak or a major holiday (`CRIT`) need
everyone else's approval: the request holds the dates, shows on the home screen with
Approve / Decline, and approvals live in `app_state.consent` under `fr_<booking id>`.
Cancelling a ficha under 24h uses it up.

**The whole house is never paid in credits** — it is a daily rate, in `DAYR`:
$200 Monday–Thursday, $350 weekends, $400 in summer. Same for a member and an outsider.
That money goes to the aporte.

**Extra credits** are $20 each (`EXTRA`), no limit, any time. Also to the aporte.

## Rules baked into the code

- **21-day booking window** (`AHEAD`). Major holidays are exempt — those are agreed as a group.
- **Two consecutive weekends in the same double room, maximum** (`MAXWK`, `DOUBLES`).
- One bed, one booking, one night: `taken()` and `clash()` enforce it.
- Cancelling refunds the credits immediately and writes the cancellation to the open history —
  unless it is less than 24 hours before arrival (2pm on the first day, `CI_HOUR`, Melbourne time).
  Then the bed is freed but the credits are lost: the log entry is marked `late` and `used()`
  keeps counting it for each person on the booking (`ppl`, `pc`). Daily-rate nights and guests are not affected.
- Extra house costs (gardener, repairs, damage) go in **House expenses** and are split equally
  by cota; the app shows each person's share. They no longer come out of the fund or the aporte.
- Everything is logged to `log` and shown to everyone: who booked, which bed, which nights,
  when the booking was made, what it cost, plus cancellations, credit purchases and
  whole-house nights.
- Lease 2 Oct 2026 – 1 Oct 2027 (`IN`/`OUT`), in Pedro & Júlia's and Niklas & Carol's names.
  Joining is a 12-month commitment to the end of the lease; the group reviews the terms at
  6 months, in April 2027.

To change any number, edit the constants at the start of the `<script>` in `index.html`.
Names, initials, colours and who pays the aporte live in the `DEF` array just below them.

## First access: the cotas, then the terms, then the login

The first time the app opens on a device it shows the full **cotas page** — prices per bed,
the calculator, what a cota buys, the rules, the monthly sums — and only lets the person
through after they tick the declaration and tap **I agree and want to join**. The acceptance
is saved on the device with the date, and once they sign in it is written to
`profiles.terms_at` so it is on record for everyone.

A member who already agreed on another device taps **I am already a member and agreed
before — sign in** under the button. After login the app checks `profiles.terms_at`: if it is
on record (and not older than `TERMS_V`) the page is skipped, otherwise it is shown again
and has to be accepted.

A device that is still signed in skips all of this and opens straight into the app; the
session is kept by Supabase in the browser, so people only type the password again after
signing out or clearing the browser.

The login screen has a link, **Reread the cotas and the rules**, that reopens the page
before signing in, as many times as they like. After login the **Cotas** button in the
top bar does the same.

The page is one block of bilingual HTML inside `index.html` (`<div class="terms tpage">`);
the standalone copy published as an artifact is the same block with its own frame. When a
number changes, change it in both. `TERMS_V` at the top of the terms code is the version (a date, `YYYY-MM-DD`) —
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

## Installing on the phone

The first time someone gets into the app (after the cotas page and the login), a banner
offers to install it. On Android/Chrome the **Install** button opens the system prompt; on
iPhone it explains **Share → Add to Home Screen**, since Safari has no install button.
It shows once per device (`yannuga.inst` in the browser) and never inside the installed app.
When a file changes, bump `CACHE` in `sw.js` only if offline copies look stale; the app
always loads from the network first.

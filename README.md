# Pussore Playstation booking page

A mobile-friendly public booking page with live slot availability and a Supabase-powered admin panel.

## Connect Supabase

1. Create a Supabase project and open its SQL Editor.
2. Run [`supabase-setup.sql`](./supabase-setup.sql).
3. In Supabase **Authentication → Users**, create the admin account `dg3667610@gmail.com` and set its password. Do not enable public sign-ups.
4. Copy the project URL and the public anon/publishable key from **Project Settings → API** into `SUPABASE_URL` and `SUPABASE_ANON_KEY` near the top of the script in [`index.html`](./index.html). The anon key is intended for browser use; never put a service-role key in the page.
5. Serve `index.html` from any static web host and share that URL. For local testing, use a local static web server rather than opening the file directly.

## Using the page

- Anyone can see live session availability, open an available session, enter a name and party size, and confirm the displayed total.
- The administrator signs in with the account above to add, edit, or delete sessions, see booking details, or cancel a booking.
- A confirmed booking changes the session to red/booked for everyone. Cancelling it makes the session green/available again.
- Session time is stored as an absolute timestamp; the browser displays it in each visitor's local time zone.

The database uses row-level security so the public can read session status but cannot read customer details or directly change sessions. Booking is performed by a database function that locks the session while it is being booked, preventing two visitors from claiming the same session simultaneously.

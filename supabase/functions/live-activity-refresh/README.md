# Live Activity refresh worker

The function accepts authenticated device registrations and sends one-minute
ActivityKit updates. Before enabling its cron request, set these server-only
Edge Function secrets:

- `APNS_PRIVATE_KEY`: contents of an Apple `.p8` APNs key
- `APNS_KEY_ID`: the key ID shown by Apple
- `APNS_TEAM_ID`: `56N7X7AGCM`
- `LTA_ACCOUNT_KEY`: the LTA DataMall key
- `LIVE_ACTIVITY_CRON_SECRET`: a random secret shared only with Supabase Vault

Deploy with Supabase gateway JWT verification enabled. Registration requests
use the anonymous user's access token and the scheduled request uses the
project service-role token in addition to the cron secret:

`supabase functions deploy live-activity-refresh`

Then insert the same cron secret into Vault and schedule an HTTP POST every
minute with body `{"action":"refresh"}` and header
`x-catch-cron-secret: <secret>`.

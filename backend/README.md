# Catch feedback backend

The app contains a real Supabase REST client and a feedback board. It does not pretend that local drafts were submitted. Deployment remains required: no Supabase account or endpoint was available in the workspace.

## Connect
1. Create or select a Supabase project. Run `feedback.sql` once in its SQL editor.
2. Enable anonymous sign-ins under Authentication. This lets users submit without typing an email. Configure signup/IP rate limits appropriate for the launch. The SQL additionally limits each authenticated author to five submissions/hour; it does not prevent attackers from making multiple anonymous accounts. For a public launch, add CAPTCHA or app attestation and test its client flow.
3. Fill in `Catch/FeedbackConfig.plist` with string keys `URL` (the HTTPS project URL) and `PublishableKey` (the client publishable/anon key). It is already included in the app’s Copy Bundle Resources phase. Never place a service-role key in the app.
4. Build and test with two separate installs: submit from A, see it in the dashboard and A's board; ensure B cannot read it until `published` is true. Confirm that clients cannot update status/replies, publish posts, or read author IDs. Test duplicate retry, offline retry, and the five/hour limit.
5. Update the privacy policy to disclose user-submitted feedback, anonymous account IDs, hosting, retention, and how to request removal before release.

## Review and reply
Use Supabase Table Editor → feedback. Set `published` to true for reviewed messages to appear on everyone's board. Use `status` values `received`, `accepted`, `in progress`, or `completed`, and write `developer_response`. Keep sensitive/abusive reports unpublished. The app exposes no administrative credentials or update endpoints to users.

Submission IDs make retries idempotent. Authentication refresh tokens are stored in iOS Keychain. Only a successful server response produces the thank-you confirmation. Failed submissions stay in the editor. The board shows at most the latest 100 visible posts, with date sorting. Voting is not implemented; this first version supports feedback and developer responses.

Sources: https://supabase.com/docs/guides/auth/auth-anonymous and https://supabase.com/docs/guides/database/postgres/row-level-security

## Live Activity background updates (separate from feedback)
The app's native timer progress and countdown advance from the last arrival estimate without opening Catch. Fetching revised predictions while suspended additionally needs an authenticated server registration endpoint, APNs Live Activity push tokens, and a scheduled worker. Required resources are an Apple APNs signing key (.p8 stored only in server secrets), its Key ID, Apple Team ID, and the LTA API key in server secrets. Do not paste the .p8 key or service-role key into chat or bundle them into the iOS app. Feedback setup alone does not enable this service. It is not implemented/deployed yet.

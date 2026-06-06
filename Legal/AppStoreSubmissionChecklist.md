# Catch App Store Legal And Privacy Checklist

Last reviewed: June 6, 2026

This checklist is based on Apple developer documentation and Catch's current local-first implementation. It is not legal advice. Review with counsel before submission.

## Required Before App Review

- Publish a public Privacy Policy URL. Apple requires a Privacy Policy URL for iOS apps in App Store Connect.
- For GitHub Pages, use `https://adiarya05.github.io/Catch/privacy.html` after Pages is enabled.
- For GitHub Pages Terms, use `https://adiarya05.github.io/Catch/terms.html` after Pages is enabled.
- Keep Privacy Policy accessible inside the app. Catch currently links Terms and Privacy from Settings.
- Add Terms of Service or EULA access inside the app, especially because Catch has subscriptions.
- If using Apple's standard EULA, include Apple's EULA link in App Store metadata where appropriate.
- If using a custom EULA, provide it in App Store Connect and keep it accessible.
- Make sure subscription paywall clearly shows product name, price, period, renewal/cancellation terms, trial terms, and what Pro unlocks.
- Make sure in-app purchase products are functional and visible to App Review.
- Make sure App Store privacy nutrition labels match the actual app behavior.
- Confirm the support/privacy contact email in Terms and Privacy is correct before publishing.
- Mirror the exact subscription products, prices, and trial duration in App Store Connect.
- Include `Catch/PrivacyInfo.xcprivacy` in the shipped app target.

## Catch Privacy Label Draft

Current app behavior appears local-first, with no backend account database, no ads, and no tracking. Final labels must be checked against the final binary and every SDK before submission.

Likely disclosures:

- Location: used on device for nearby stops and catchability. If not transmitted off device or retained by a third party beyond real-time request servicing, Apple says on-device data is not "collected" for privacy label purposes. Confirm final implementation before answering.
- Purchases: Apple handles payment; Catch receives entitlement status. If Catch does not collect purchase history on a developer server, payment information is not collected by Catch.
- User Content / Other Data: saved places, display name, and pinned buses are currently local. If never transmitted off device, they may not be "collected" for the privacy label, but they must still be explained in the Privacy Policy because the app handles them.
- Diagnostics / Analytics: do not disclose unless an analytics or crash SDK is added.
- Tracking: No, unless an advertising/analytics SDK or data broker sharing is added.

## Security Review

- Verify there are no analytics, advertising, tracking, or crash SDKs added unexpectedly.
- Verify OpenAIService is unused unless intentionally enabled and disclosed.
- Verify LTA API key exposure is acceptable for the app's current architecture. A mobile app cannot fully hide this key; the production-grade fix is a backend/proxy with abuse controls.
- Verify no precise location history is stored unnecessarily.
- Verify saved places and pinned stops are only used for app functionality.
- Verify notification toggle cannot schedule alerts when disabled.
- Verify deleting the app removes local app data from the device, subject to iOS backups.
- Verify App Group data only contains widget/Live Activity data needed for display.

## Official Apple Sources To Review

- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- Manage App Privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- App Information Reference: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- Auto-renewable subscriptions: https://developer.apple.com/app-store/subscriptions/
- Standard Apple EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

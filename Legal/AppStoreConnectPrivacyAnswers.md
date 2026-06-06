# Catch App Store Connect Privacy Answers

Last reviewed: June 6, 2026

Use this as the App Store Connect privacy-label draft for the current local-first Catch build. Re-check it whenever the app adds accounts, cloud sync, analytics, crash reporting, ads, a backend, or any new SDK.

## Privacy Policy URL

Required before submission. Publish `Legal/PrivacyPolicy.md` as a public webpage and paste that URL into App Store Connect.

GitHub Pages path once enabled for this repo:

```text
https://adiarya05.github.io/Catch/privacy.html
```

## User Privacy Choices URL

Optional, but recommended. You can use the same Privacy Policy page if it includes the deletion and permission controls section, or publish a shorter privacy choices page.

Recommended value:

```text
https://adiarya05.github.io/Catch/privacy.html
```

## Tracking

Answer: No.

Reason: Catch does not track users across apps or websites for advertising or advertising measurement and does not use App Tracking Transparency in the current build.

## Data Collection

Recommended answer for the current build: Data Not Collected by the developer.

Reason: Catch is local-first. Location, saved places, pinned buses, settings, notification preferences, and widget/live activity state are processed or stored on device and are not transmitted to a Catch-controlled backend. Apple says data processed only on device is not considered collected for App Store privacy answers.

Important nuance:

- LTA DataMall receives bus stop codes in arrival requests and standard network metadata such as IP address as part of servicing the request.
- Apple handles purchases, StoreKit entitlements, App Store analytics, notifications, widgets, and Live Activities through Apple platform services.
- If Catch later stores user data on a server, adds analytics/crash SDKs, adds ads, or sends precise/coarse location to a backend, these answers must change.

## Data Types To Avoid Selecting For Current Build

Do not select these unless the code changes:

- Contact Info
- Health and Fitness
- Financial Info
- Contacts
- User Content
- Browsing History
- Search History
- Identifiers
- Usage Data
- Diagnostics
- Other Data

## Location

Do not mark location as collected for the current build if precise location remains on device only.

The Privacy Policy still explains location handling because the app uses location permission, but App Store privacy labels are about data collected by the developer or third-party partners beyond transient request servicing.

## Required Reason API Privacy Manifest

The app includes `Catch/PrivacyInfo.xcprivacy` for UserDefaults:

```text
NSPrivacyAccessedAPICategoryUserDefaults
Reason: CA92.1
```

This covers app preferences, onboarding state, Pro state, widget sharing flags, and local feature toggles.

## Subscription Review Notes

Products to create in App Store Connect:

```text
com.adityaarya.catch.pro.monthly
S$3.99/month
3-day free trial

com.adityaarya.catch.pro.annual
S$29.99/year
3-day free trial
```

Subscription group:

```text
Catch Pro
```

Review note:

```text
Catch Pro unlocks widgets, Live Board/Dynamic Island/Live Activities, smart leave-now alerts, unlimited saved stops, all app icons, and Can I Catch It decision tools. The app is local-first and does not require an account.
```

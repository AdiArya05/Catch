# Local LTA configuration and credential safety

The app and widget no longer contain a checked-in DataMall AccountKey.

## Local development

Create a file named `Secrets.xcconfig` outside the repository, or in the repository root (it is ignored), containing your own authorised value:

```xcconfig
LTA_API_KEY = YOUR_OWN_KEY
```

Do not commit the file or place the real value in project.pbxproj, Info.plist, a shared scheme, screenshots, logs, or documentation.

Build with Xcode's additional configuration override, for example:

```sh
xcodebuild -project Catch.xcodeproj -scheme Catch -xcconfig /absolute/path/to/Secrets.xcconfig
```

Both the main app and widget Info.plists expand `$(LTA_API_KEY)`. A scheme environment variable named `LTA_API_KEY` is also supported for development, but it does not automatically configure a separately launched widget. Without configuration, requests fail before sending an AccountKey.

## Important limits

This change removes the literals from current source only. It does not revoke a previously exposed key or erase Git history, forks, clones, caches, or previously built apps. Treat a key that was committed publicly as compromised and revoke or rotate it with LTA.

A credential injected into an iOS application bundle is still extractable. This configuration is for development and source hygiene, not production secret storage. A production replacement should remain on a server behind a constrained, rate-limited transit proxy; neither the app nor widget should receive that replacement credential.

Coordinate revocation with migration of installed versions and any backend using the old key. Revoking a key still used by a released app can stop its live data until an update is installed. No key rotation, history rewrite, backend deployment, or App Store release is performed by this source change.

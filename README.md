# IPTV Player

A native iOS IPTV player for Xtream Codes panels and M3U playlists, built with SwiftUI and Liquid Glass.

## Features

- Sign in with an Xtream Codes account (server, username, password) or a single M3U playlist URL
- Logins are checked against the service and stored in the Keychain
- Live channels grouped by category, with logos and search
- Category chips for quick filtering, favourite categories and a favourites-only view
- Settings with the service details, category favourites and the app version
- Full screen playback with the system player controls

Both HTTP and HTTPS services work; when the address has no scheme, both are tried.

## Requirements

- iOS 26 or newer
- Xcode 26

## Beta builds

Every push to `main` runs the `Beta IPA` workflow. It archives the app for a real device, packages the `.ipa` and publishes it as a **pre-release** tagged `beta-<run number>`, with the IPA attached. Each build number is the workflow run number, so a new beta replaces the previous one on the device.

Download `IPTV-Player-<version>-beta.<build>.ipa` from the [releases page](../../releases).

### Always unsigned

Every IPA is built unsigned on purpose: the workflow never touches a certificate, and it fails if the archive ever comes out signed. Sign the IPA yourself before installing, for example with [Feather](https://github.com/khcrysalis/Feather) and a certificate from arcticsign.

- A distribution certificate is enough for normal installs
- A developer certificate is needed for JIT: switch JIT on in Feather's signing options and keep the device paired while Feather attaches the debugger

An unsigned IPA cannot be installed on a device on its own; the signing tool adds the signature, the entitlements and, for JIT, the debug entitlement.

## Building locally

Open `IPTV-Player.xcodeproj`, pick a simulator and run. To build the IPA yourself:

```sh
xcodebuild -project IPTV-Player.xcodeproj -scheme IPTV-Player \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/IPTV-Player.xcarchive \
  CODE_SIGNING_ALLOWED=NO clean archive
```

## Stream support

Playback uses `AVPlayer`, so HLS (`.m3u8`) plays natively. Panels and playlists that only offer raw MPEG-TS streams cannot be played and show an error instead.

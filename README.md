# IPTV Player

A native iOS IPTV player for Xtream Codes panels and M3U playlists, built with SwiftUI and Liquid Glass.

## Features

- Sign in with an Xtream Codes account (server, username, password) or a single M3U playlist URL
- Logins are checked against the service and stored in the Keychain
- Live channels grouped by category, with logos and search
- Full screen playback with the system player controls

Both HTTP and HTTPS services work; when the address has no scheme, both are tried.

## Requirements

- iOS 26 or newer
- Xcode 26

## Beta builds

Every push to `main` runs the `Beta IPA` workflow. It archives the app for a real device, packages the `.ipa` and publishes it as a **pre-release** tagged `beta-<run number>`, with the IPA attached. Each build number is the workflow run number, so a new beta replaces the previous one on the device.

Download a build from the [releases page](../../releases) and install it with AltStore, Sideloadly or Xcode.

### Signed or unsigned

Without secrets the workflow produces an **unsigned** IPA: the sideloading tool signs it with your own Apple ID before installing it.

To get a directly signed IPA, add these repository secrets under *Settings → Secrets and variables → Actions*:

| Secret | Content |
| --- | --- |
| `SIGNING_CERTIFICATE_BASE64` | Your `.p12` distribution certificate, base64 encoded |
| `SIGNING_CERTIFICATE_PASSWORD` | The password of that `.p12` |
| `SIGNING_PROFILE_BASE64` | Your `.mobileprovision`, base64 encoded |
| `APPLE_TEAM_ID` | Your Apple Developer team identifier |

The provisioning profile has to match the bundle identifier of the app (`com.organizationName.IPTV-Player` in the Xcode project).

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

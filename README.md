# IPTV Player

A native iOS IPTV player for Xtream Codes panels and M3U playlists, built with SwiftUI and Liquid Glass.

## Features

- Sign in with an Xtream Codes account (server, username, password) or a single M3U playlist URL
- Logins are checked against the service and stored in the Keychain
- Live channels grouped by category, with wide logo tiles, initials as a placeholder while a logo loads, and search
- A toolbar switch between the channel rows and a two column grid of tiles; a long press offers Play, Copy name and the favourite toggle
- Category chips for quick filtering, favourite categories and a favourites-only view
- Favourite channels, added by long press or swipe, in their own section above the categories, plus a Recently Watched row of the last channels played; both are stored per account
- Settings with the service details, category favourites and the app version
- Movies and Series tabs for Xtream accounts: category rows, See All grids, Recent and Favourites, search, and a detail page with plot, year, rating, cast and (for series) seasons and episodes
- Movies and episodes resume where they stopped
- A custom full screen player on AVPlayer: glass bars with close, channel name and category, play and pause, skip, volume, AirPlay and picture in picture, a buffering spinner and a retry on errors
- Swipe up or down in the player to move to the next or previous channel of the same category, with a short banner naming it; a tap hides or shows the controls
- Landscape fills the screen; in portrait the video sits on top with the channels of the category underneath

Both HTTP and HTTPS services work; when the address has no scheme, both are tried.

## Requirements

- iOS 26 or newer
- Xcode 26

## Beta builds

Every push to `main` runs the `Beta IPA` workflow. It archives the app for a real device, packages the `.ipa` and publishes it as a **pre-release** tagged `beta-<run number>`, with the IPA attached.

Download `IPTV-Player-<version>-beta.<build>.ipa` from the [releases page](../../releases).

### Versions

Every commit raises the version by itself, so iOS and Feather always see a new build as an update. The version is `<major>.<minor>.<build>`: the first two parts come from the Xcode project, the last one is the workflow run number, which is also the build number. Commit 15 becomes `1.0.15`, build `15`. To start a new line such as `1.1`, raise the app's version in the Xcode project; the numbering then continues as `1.1.<build>`.

### Updates with Feather

Add the source once in Feather under Sources, then every new build shows up as an update:

```
https://crzx.space/repo/repo.json
```

The source lists IPTV Player (`com.crzx.player`) next to the other apps of the repo and takes its IPAs from the GitHub releases of this repository. For that to keep working, the IPA keeps its name `IPTV-Player-<version>-beta.<build>.ipa`, so do not rename it in the workflow. A new build can take a moment to appear in the source.

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

Playback uses `AVPlayer`, so HLS (`.m3u8`) plays natively. Panels and playlists that only offer raw MPEG-TS streams cannot be played and show an error instead. Movies and episodes play in the container the panel delivers; MP4 and M4V work, `.mkv` and `.avi` files are not supported by the native player and show an error.

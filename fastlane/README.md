fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Push a new beta build to TestFlight

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload metadata (text only) to App Store Connect - NO screenshots

### ios screenshots_generate

```sh
[bundle exec] fastlane ios screenshots_generate
```

Generate screenshots for App Store. Usage: screenshots_generate [iphone|ipad] (no arg = both)

### ios generate_device_screenshots

```sh
[bundle exec] fastlane ios generate_device_screenshots
```

Generate screenshots for a specific device type (:iphone or :ipad)

### ios screenshots_download

```sh
[bundle exec] fastlane ios screenshots_download
```

Download current screenshots from App Store Connect (creates correct folder structure)

### ios screenshots_upload

```sh
[bundle exec] fastlane ios screenshots_upload
```

Upload screenshots to App Store Connect

### ios screenshots_full

```sh
[bundle exec] fastlane ios screenshots_full
```

Generate AND upload all screenshots to App Store Connect

### ios release

```sh
[bundle exec] fastlane ios release
```

Deploy a new version to the App Store (builds and submits)

### ios submit_for_review

```sh
[bundle exec] fastlane ios submit_for_review
```

Submit existing TestFlight build to App Store for review (no rebuild)

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests

### ios bump_build

```sh
[bundle exec] fastlane ios bump_build
```

Increment build number

### ios transfer_prepare

```sh
[bundle exec] fastlane ios transfer_prepare
```

Clear all TestFlight data (testers, test info, beta groups) for app transfer

### ios transfer_check

```sh
[bundle exec] fastlane ios transfer_check
```

Diagnose what's blocking an app transfer on App Store Connect

### ios expire_builds

```sh
[bundle exec] fastlane ios expire_builds
```

Expire all TestFlight builds (iOS + macOS) to prepare for app transfer

----


## Mac

### mac beta

```sh
[bundle exec] fastlane mac beta
```

Push a new beta build to TestFlight for macOS

### mac metadata

```sh
[bundle exec] fastlane mac metadata
```

Upload metadata (text only) to App Store Connect for macOS - NO screenshots

### mac screenshots_generate

```sh
[bundle exec] fastlane mac screenshots_generate
```

Instructions for macOS App Store screenshots (manual capture required)

### mac screenshots_upload

```sh
[bundle exec] fastlane mac screenshots_upload
```

Upload macOS screenshots to App Store Connect

### mac screenshots_full

```sh
[bundle exec] fastlane mac screenshots_full
```

Generate AND upload macOS screenshots to App Store Connect

### mac submit_for_review

```sh
[bundle exec] fastlane mac submit_for_review
```

Submit existing TestFlight build to Mac App Store for review (no rebuild)

----


## Android

### android beta

```sh
[bundle exec] fastlane android beta
```

Push a new beta build to Google Play internal testing

### android metadata

```sh
[bundle exec] fastlane android metadata
```

Upload metadata (text only) to Google Play - NO images or screenshots

### android screenshots_download

```sh
[bundle exec] fastlane android screenshots_download
```

Download metadata and screenshots from Google Play

### android screenshots_generate

```sh
[bundle exec] fastlane android screenshots_generate
```

Generate screenshots for Google Play. Usage: screenshots_generate [phone|sevenInch|tenInch] (no arg = all)

### android generate_device_screenshots

```sh
[bundle exec] fastlane android generate_device_screenshots
```

Internal: Generate screenshots for a specific device type. Use screenshots_generate instead.

### android screenshots_upload

```sh
[bundle exec] fastlane android screenshots_upload
```

Upload screenshots, icon, and feature graphic to Google Play

### android screenshots_full

```sh
[bundle exec] fastlane android screenshots_full
```

Generate AND upload screenshots to Google Play

### android release

```sh
[bundle exec] fastlane android release
```

Deploy a new version to the Google Play Store (builds and uploads binary + changelog only)

### android release_full

```sh
[bundle exec] fastlane android release_full
```

Deploy with ALL metadata (use sparingly - triggers longer content review)

### android promote

```sh
[bundle exec] fastlane android promote
```

Promote existing internal/beta build to production (no rebuild)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

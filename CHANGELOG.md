# Changelog

# 3.1.0
- Google Drive support.
- Use "Montserrat" font everywhere.
- Fixed some colors for better readability.
- Better download progress display with percentage.
- Updated translations.
- Lots of minor UI fixes.

# 3.0.0
- UI redesign.

## 2.9.0
- Show app version at bottom of settings.
- Added preliminary proofmode support for WebDAV and Dropbox spaces.
- Fixed SHA256 digest generation.
- Fixed minor issues when trying to log into a WebDAV account.

## 2.8.2
- Fixed minor bugs.
- Fixed minor potential security issues.
- Added security features:
  - Option to disallow third-party keyboards.
  - Option to hide app content in app slider.
  - Option to use biometrics or passphrase to unlock app.
- Updated translations.

## 2.8.1
- Improved "Orbot not running" warnings.
- Fixed unresponsiveness/crash on first run.
- Added disclose button to password field.

## 2.8.0
- Improved support for bigger fonts for accessibility.
- Fixed problem, where main scene showed the wrong state.
- Dropbox support now allows files bigger than 150 MByte.
- Reworked upload management scene: 
  - Current upload will now continue while reordering others.
  - Finished uploads will be displayed until user leaves.
- Added support for Orbot iOS.
- Updated translations.

## 2.7.1
- Improved stability of uploads.
- Fixed issues with Dropbox.
- Improved handling of large videos.
- Keep the screen on in the upload scene, so users can finish their huge uploads without attending to the app all the time.
- Fixed UI issues.
- Updated translations.

## 2.7.0
- Added translations: Italian.  
- Updated translations.
- Support iOS 15.
- Added CleanInsights for upload health check.
- Fixed various bugs and crashes. 

## 2.6.0
- Added Dropbox support.
- Updated dependencies.
- Fixed layouting issues.

## 2.5.0
- Updated dependencies: CocoaPods, Alamofire, CrossroadRegex, TLPhotoPicker, YapDatabase, FavIcon, FontBlaster, Fastlane
- Fixed dark mode issue with launch screen.
- Made text "Tap buttons below to add media to your project." tappable itself.
- Encode asset digest as hexadecimal number instead of BASE64 to be in line with tools like sha256sum.
- Fixed issues with soft keyboard on forms on iPad.
- Rephrased claim.

## 2.4.0
- Fixed iOS 13 dark mode bugs.
- Added Arabic and Farsi localization.

## 2.3.0
- Uses Xcode 11 (iOS 13)
- Improved thumbnail quality.
- Indicate audio/video content.
- Added Transifex support.
- Fixed "Screenshot" target, improved screenshots.
- Replaced hovering "+" button with a "+" button in an always visible toolbar.
- Replaced Google tab bar with self-made one. New project button now always visible and a big plus sign instead of word "New".
- Fixed bugs when returning from a share extension.
- Added French, Spanish (partial) and Russian (partial) localization. 

## 2.2.0

- Added Nextcloud upload chunking support.
- Improved wording regarding private servers. Make clear, it's about WebDAV.
- Fixed issue where toolbar wasn't hidden, when project was switched.
- Reduced app size.

## 2.1.0

- Added infobox to explain Internet Archive.
- Added compression option to reduce (esp.) video size.

## 2.0.0

- Initial version, called 2.0.0 to be in line with the Android version

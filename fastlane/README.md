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

### ios test

```sh
[bundle exec] fastlane ios test
```

Run unit tests

### ios local

```sh
[bundle exec] fastlane ios local
```

Build for local testing

### ios prepare

```sh
[bundle exec] fastlane ios prepare
```

Prepare the app for dev or build

### ios tf

```sh
[bundle exec] fastlane ios tf
```

Build and upload to TestFlight for internal testing

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight for internal and external testing

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload to the App Store

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

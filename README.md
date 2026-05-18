# KONSTRUX iOS App

This repository contains the Capacitor iOS project for the KONSTRUX app — the ultimate platform for Australian tradies.

## Overview

The KONSTRUX iOS app is a native iOS wrapper built with [Capacitor](https://capacitorjs.com/) that loads the KONSTRUX web app from `https://konstrux.com.au`. This approach gives users a native iOS app experience while the web app handles all the business logic.

## App Details

| Property | Value |
|----------|-------|
| Bundle ID | `com.konstrux.app` |
| App Name | KONSTRUX |
| Minimum iOS | 13.0 |
| Web URL | https://konstrux.com.au |

## Building with Codemagic

This project is configured to build automatically via [Codemagic CI/CD](https://codemagic.io). The `codemagic.yaml` file defines the build workflow.

### Prerequisites

Before triggering a build, you need:

1. **Apple Developer Account** — Enroll at [developer.apple.com/enroll](https://developer.apple.com/enroll) ($149 AUD/year)
2. **App Store Connect App** — Create the app at [appstoreconnect.apple.com](https://appstoreconnect.apple.com) with bundle ID `com.konstrux.app`
3. **Codemagic Code Signing** — Set up iOS distribution certificate and provisioning profile in Codemagic settings

### Build Steps

1. Connect this repo to Codemagic
2. Configure iOS code signing (see Codemagic docs)
3. Set `APP_STORE_APP_ID` in `codemagic.yaml` to your App Store Connect app ID
4. Trigger a build

## Local Development

```bash
# Install dependencies
npm install

# Sync web assets to iOS project
npx cap sync ios

# Open in Xcode (requires macOS)
npx cap open ios
```

## Project Structure

```
konstrux-ios/
├── capacitor.config.ts     # Capacitor configuration
├── codemagic.yaml          # CI/CD build workflow
├── package.json            # Node dependencies
├── www/                    # Web assets placeholder
│   └── index.html
└── ios/
    └── App/
        ├── App/
        │   ├── AppDelegate.swift
        │   ├── Info.plist
        │   ├── capacitor.config.json
        │   └── Assets.xcassets/
        ├── App.xcodeproj/
        ├── App.xcworkspace/
        └── Podfile
```

## Support

Email: support@konstrux.com.au

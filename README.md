<p align="center">
  <img src="docs/brand/spendly-logo-motion.gif" width="600" alt="Spendly logo animation">
</p>

# Spendly

A minimal expense tracker for iPhone. Type the amount, tap a category, and it is saved.

![Swift](https://img.shields.io/badge/Swift_6-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0D96F6?logo=swift&logoColor=white)
![SwiftData](https://img.shields.io/badge/SwiftData-1C1C1E?logo=apple&logoColor=white)
![iOS 18+](https://img.shields.io/badge/iOS-18%2B-000000?logo=apple&logoColor=white)

<p align="center">
  <img src="docs/screenshots/01-quick-add.png" width="200" alt="Quick add">
  <img src="docs/screenshots/03-just-saved.png" width="200" alt="Saved with undo">
  <img src="docs/screenshots/06-overview.png" width="200" alt="Monthly overview">
  <img src="docs/screenshots/10-widget.jpg" width="200" alt="Home screen widget">
</p>

## About

Most budgeting apps try to do everything. Spendly focuses on one thing: logging an expense in a few seconds. The app opens on the keypad, works offline and needs no account. Expenses can also be logged from a home screen widget or with Siri, without opening the app.

## Features

- Two-tap logging with undo
- Suggestion to repeat your usual expense
- Income entries and past days
- Monthly overview by category
- Your own categories with a name, emoji and color
- Monthly budget per category, with a notification at 80% and 100%
- Daily and weekly reminders
- Home screen and lock screen widgets, Control Center button
- Siri and Shortcuts support
- English and Turkish

**Spendly Pro** (monthly or one-time purchase) removes the free limits of 3 custom categories and 1 budget, and adds CSV export.

## Screenshots

| Quick add | Amount typed | Saved | Income |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/01-quick-add.png" width="180"> | <img src="docs/screenshots/02-amount-typed.png" width="180"> | <img src="docs/screenshots/03-just-saved.png" width="180"> | <img src="docs/screenshots/04-income.png" width="180"> |

| Past day | Overview | Budget | Edit |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/05-day-picker.png" width="180"> | <img src="docs/screenshots/06-overview.png" width="180"> | <img src="docs/screenshots/07-budget.png" width="180"> | <img src="docs/screenshots/08-edit.png" width="180"> |

| Settings | Widget |
|:---:|:---:|
| <img src="docs/screenshots/09-settings.png" width="180"> | <img src="docs/screenshots/10-widget.jpg" width="180"> |

## Tech Stack

| Area | Technology |
|------|------------|
| Language | Swift 6 |
| UI | SwiftUI |
| Storage | SwiftData, shared through an App Group |
| Sync | CloudKit (ready, turned on with the iCloud capability) |
| Widgets | WidgetKit (home screen, lock screen, Control Center) |
| Siri and Shortcuts | App Intents |
| Notifications | UserNotifications (local reminders and budget alerts) |
| Purchases | StoreKit 2 |
| Localization | String Catalogs (English, Turkish) |
| Modules | Swift Package Manager |
| Tests | Swift Testing |

## Architecture

Spendly has no backend. The app, the widgets and Siri all read and write the same local store, and the shared logic lives in a Swift package.

```mermaid
flowchart TB
    accTitle: Spendly Architecture Overview
    accDescr: The app, widget extension and App Intents all use the SpendlyKit package, which stores data in a SwiftData store shared through an App Group and can sync to iCloud.

    subgraph device["iPhone"]
        app["Spendly app<br/>Quick add, Overview, Settings"]
        widgets["Widget extension<br/>Home screen, lock screen, Control Center"]
        intents["App Intents<br/>Siri, Shortcuts, widget buttons"]
        kit["SpendlyKit package<br/>Core, Data, UI"]
        store[("SwiftData store<br/>App Group container")]
        reminders["Local notifications"]
    end
    icloud[("iCloud<br/>CloudKit")]
    appstore[("App Store<br/>StoreKit 2")]

    app --> kit
    widgets --> intents
    intents --> kit
    widgets --> kit
    kit --> store
    app --> reminders
    store -.->|"optional sync"| icloud
    app -.->|"Spendly Pro"| appstore

    classDef surface fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#1e3a5f
    classDef shared fill:#ede9fe,stroke:#7c3aed,stroke-width:2px,color:#3b0764
    classDef data fill:#dcfce7,stroke:#16a34a,stroke-width:2px,color:#14532d
    classDef external fill:#f3f4f6,stroke:#6b7280,stroke-width:2px,color:#1f2937

    class app,widgets,intents surface
    class kit,reminders shared
    class store data
    class icloud,appstore external
```

```
Spendly/              App: screens and reminders
SpendlyWidgets/       Widget extension
Shared/               App Intents and the shared store, used by the app and the widgets
Packages/SpendlyKit/  SpendlyCore (money, keypad), SpendlyData (storage), SpendlyUI (design system)
```

## Getting Started

Requires an iOS 18+ simulator or device. Built with Xcode 27.

```bash
open Spendly.xcodeproj
```

Run the `Spendly` scheme. To load sample data in a debug build, launch with the `-demo` argument:

```bash
xcrun simctl launch booted com.kaancankurt.spendly -demo
```

In-app purchases can be tried locally with the `Spendly.storekit` configuration, which the `Spendly` scheme uses when the app is run from Xcode.

Run the tests:

```bash
cd Packages/SpendlyKit && swift test
```

The earlier Flutter and Node.js version is on the [`archive/flutter`](https://github.com/KaanCan1/Spendly/tree/archive/flutter) branch.

## Author

**Kaan Can Kurt**, Flutter and Full Stack Developer

[Portfolio](https://kaancankurt.vercel.app) · [LinkedIn](https://linkedin.com/in/kaan-can-kurt-805990299) · [GitHub](https://github.com/KaanCan1)

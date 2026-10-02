# 💸 Spendly

> Log an expense in two taps: type the amount, tap a category. That's it.

![Swift](https://img.shields.io/badge/Swift_6-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0D96F6?logo=swift&logoColor=white)
![SwiftData](https://img.shields.io/badge/SwiftData-1C1C1E?logo=apple&logoColor=white)
![iOS 18+](https://img.shields.io/badge/iOS-18%2B-000000?logo=apple&logoColor=white)

Spendly is a minimal, native iPhone expense tracker. Most budgeting apps try to do everything and feel heavy; Spendly does one thing — capture spending in about three seconds — and stays out of the way. It opens straight onto the keypad, works offline, needs no account, and logs from the home screen, Siri, or Control Center without even opening the app.

<p align="center">
  <img src="docs/screenshots/01-quick-add.png" width="200" alt="Quick add">
  <img src="docs/screenshots/03-just-saved.png" width="200" alt="Just saved, with undo">
  <img src="docs/screenshots/06-overview.png" width="200" alt="Monthly overview">
  <img src="docs/screenshots/10-widget.jpg" width="200" alt="Home screen widget">
</p>

## ✨ Features

- ⌨️ **Two-tap logging** — the app opens on the keypad; tapping a category *is* the save. No save button, no confirmation dialog.
- ↩️ **Undo instead of "are you sure?"** — every save shows a 4-second undo.
- 🔁 **Habit suggestion** — "☕ coffee ₺85 again?" logs your usual in one tap.
- ➕ **Income too** — tap the `−` sign to flip to `+`.
- 📅 **Past days** — "today ⌄" picks any of the last 7 days.
- 📊 **Monthly overview** — one stacked bar by category, entries grouped by day, swipe to delete, tap to edit.
- 🎯 **Budgets** — a monthly limit per category; the line turns red at 80%.
- 🔔 **Reminders** — an optional daily recap ("today you spent ₺420 — mostly food") and a Sunday summary, all local notifications.
- 🧩 **Home screen widget** — today's total plus your usual expenses as buttons that log **without opening the app**.
- 🗣️ **Siri, Shortcuts and the Action Button** — "Log an expense in Spendly".
- 🎛️ **Control Center and lock screen** — jump straight to the keypad.
- 💱 **Currency** — detected from the device region; ₺, $, € and £ one tap away.
- 📤 **CSV export** — all your data, any time.
- 🔒 **Private by design** — no account, no server, nothing collected; data lives on the device (and in your own iCloud once sync is turned on).

## 📱 Screenshots

| Quick add | Amount typed | Just saved | Income |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/01-quick-add.png" width="190"> | <img src="docs/screenshots/02-amount-typed.png" width="190"> | <img src="docs/screenshots/03-just-saved.png" width="190"> | <img src="docs/screenshots/04-income.png" width="190"> |

| Past day | Overview | Budget | Edit |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/05-day-picker.png" width="190"> | <img src="docs/screenshots/06-overview.png" width="190"> | <img src="docs/screenshots/07-budget.png" width="190"> | <img src="docs/screenshots/08-edit.png" width="190"> |

| Settings | Widget |
|:---:|:---:|
| <img src="docs/screenshots/09-settings.png" width="190"> | <img src="docs/screenshots/10-widget.jpg" width="190"> |

## 🏗️ Architecture

Spendly is **local-first with no backend**. Everything the MVP needs — storage, sync, reminders, purchases — is handled on the device by Apple frameworks.

```
┌───────────────────────── iPhone ──────────────────────────┐
│  Spendly app (SwiftUI)          SpendlyWidgets extension   │
│  quick add · overview ·         home / lock screen widgets │
│  budgets · settings             Control Center control     │
│        │                                 │                 │
│        └──────────── App Intents ────────┘  ← Siri,        │
│              (log · quick log · open keypad)  Shortcuts,   │
│                          │                    Action Button│
│                 ┌────────▼────────┐                        │
│                 │  ExpenseStore   │  protocol              │
│                 │ SwiftData impl  │                        │
│                 └────────┬────────┘                        │
│            App Group container (app + widgets)             │
└──────────────────────────┼─────────────────────────────────┘
                           ▼
            iCloud (CloudKit private database) — optional
```

- **One store, three processes.** The app, the widget extension and the App Intents all open the same SwiftData store in a shared App Group container, so a coffee logged from the widget shows up in the app instantly.
- **Storage behind a protocol.** Screens only talk to `ExpenseStore` and plain value types (`ExpenseRecord`, `CategoryRecord`), never to SwiftData models. A server backend later (Vapor or Supabase) means writing another `ExpenseStore`, not touching the UI.
- **CloudKit-ready.** Models follow CloudKit's rules (optional or defaulted properties, no unique constraints, inverse relationships), so iCloud sync is a capability toggle, not a migration.
- **Money is never a `Double`.** Amounts are stored as `Int64` minor units (kuruş, cents) plus a currency code.

### Project structure

```
Spendly/                 App target: screens, reminders, Siri phrases
  Features/QuickAdd/     The two-tap keypad screen
  Features/Overview/     Month view, budgets, entry editor
  Features/Settings/     Currency, reminders, limits, CSV export
  Services/              Local notification scheduling
SpendlyWidgets/          Widget extension: home + lock screen widgets, Control Center
Shared/                  Compiled into both targets: App Intents, shared store
Packages/SpendlyKit/     Swift package
  SpendlyCore/           Money, keypad input, currency rules (pure Swift)
  SpendlyData/           SwiftData models, ExpenseStore and its implementation
  SpendlyUI/             Design system: colors, type, keypad, chips, toast
```

### Design

Dark by design — graphite surfaces with a single lime signature color for "today", selection and focus, and red reserved for over-budget and delete. Numbers are SF Pro, light weight with tight tracking; each category has its own identity hue used consistently in chips, the overview bar and rows.

## 🚀 Getting started

Requirements: an iOS 18+ simulator or device. Built and tested with Xcode 27.

```bash
open Spendly.xcodeproj
```

Pick the **Spendly** scheme and run. To fill the app with realistic sample data (debug builds only), launch with the `-demo` argument on an empty install:

```bash
xcrun simctl launch booted com.kaancankurt.spendly -demo
```

Run the unit tests (money, keypad input, persistence) from the package:

```bash
cd Packages/SpendlyKit && swift test
```

### Turning on iCloud sync

1. In Xcode, select the **Spendly** target → *Signing & Capabilities* and choose your team.
2. Add **iCloud** → check **CloudKit** → add a container (e.g. `iCloud.com.kaancankurt.spendly`).
3. Add **Background Modes** → **Remote notifications**.
4. Make sure the **App Groups** capability on both targets lists `group.com.kaancankurt.spendly`.

No code change is needed: the store already syncs whenever the capability is present.

## 🗺️ Roadmap

- [x] Two-tap logging, undo, habit suggestion, income, past days
- [x] Monthly overview, budgets with 80% warning, edit and delete
- [x] Daily and weekly reminders, CSV export
- [x] Home screen, lock screen and Control Center widgets; Siri and Shortcuts
- [ ] App icon
- [ ] iCloud sync switched on (needs a developer team)
- [ ] Freemium with StoreKit 2
- [ ] Custom categories and colors

The earlier Flutter + Node.js version lives on the [`archive/flutter`](https://github.com/KaanCan1/Spendly/tree/archive/flutter) branch.

## 👤 Author

**Kaan Can Kurt** — Flutter & Full Stack Developer
🌐 [Portfolio](https://kaancankurt.vercel.app) · 💼 [LinkedIn](https://linkedin.com/in/kaan-can-kurt-805990299) · 🐙 [GitHub](https://github.com/KaanCan1)

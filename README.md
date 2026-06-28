# 💸 Spendly

> A clean, minimal expense tracker that helps you stay on top of your spending.

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?logo=node.js&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)

Spendly is a full-stack expense tracking app: a Flutter client backed by a custom Node.js REST API and containerized with Docker for a reproducible setup.

## ✨ Features

- 👋 **Onboarding** — a guided first-run flow
- ➕ **Add expenses** — log and categorize spending quickly
- 📊 **Weekly summary** — see your spending at a glance with a chart
- 🧾 **Transactions** — full history of your activity
- ⚙️ **Settings** — manage your preferences
- 🔌 **REST backend** — Node.js API, reproducible via Docker

## 🛠️ Tech Stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter · Dart |
| Backend | Node.js (REST API) |
| Infra | Docker / Docker Compose |

## 🚀 Getting Started

**Mobile app**

```bash
flutter pub get
flutter run
```

**Backend**

```bash
cd backend
cp .env.example .env    # configure your environment variables
docker compose up       # or: npm install && npm start
```

## 👤 Author

**Kaan Can Kurt** — Flutter & Full Stack Developer
🌐 [Portfolio](https://kaancankurt.vercel.app) · 💼 [LinkedIn](https://linkedin.com/in/kaan-can-kurt-805990299) · 🐙 [GitHub](https://github.com/KaanCan1)

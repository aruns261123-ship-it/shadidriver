# shadidriver
ShadiDriver - Premium Indian Wedding & Event Chauffeur Marketplace

## Repository Layout

```
shadidriver/
├── frontend/          # Flutter app (all product code lives here)
│   ├── lib/           # Application source (features/, core/, app/, services/)
│   ├── test/          # Unit, widget, and flow tests
│   ├── android/ ios/ web/ windows/ linux/ macos/
│   └── pubspec.yaml
├── docs/              # Architecture notes, reviews, and roadmaps
└── infra/             # Deployment / environment tooling
```

This is a **frontend-only** project: all data is served by in-app mock repositories,
so `frontend/` is the whole product. A `backend/` folder can be added alongside later
without touching the app.

## Getting Started

```bash
cd frontend
flutter pub get
flutter run
```

Run checks:

```bash
cd frontend
flutter analyze   # static analysis (flutter_lints)
flutter test      # full test suite
```

See [docs/](docs/) for the frontend review and improvement roadmap.

# INDEX

A beautiful, minimal SQL client for iOS and iPadOS.

## Features

### Multiple Database Support
- PostgreSQL
- MySQL
- SQLite

### Beautiful UI
- Minimal, clean design
- Smooth animations
- Dark theme optimized
- Optimized for both iPad and iPhone

### Powerful SQL Editor
- Multi-line query support
- Real-time query execution
- Clean results visualization
- Query history tracking

### Connection Management
- Save multiple database connections
- Test connections before saving
- Easy connection switching
- Secure credential storage

### Onboarding Experience
- Interactive tutorial
- Beautiful animations
- Easy to understand

## Technical Details

- Built with SwiftUI
- iOS 17.0+
- Universal app (iPhone & iPad)
- No external dependencies
- Pure Swift implementation

## Project Structure

```
SQLClient/
├── SQLClientApp.swift          # App entry point
├── ContentView.swift            # Root view
├── Models/
│   ├── DatabaseConnection.swift # Connection model
│   └── QueryResult.swift        # Query result model
├── Services/
│   └── DatabaseService.swift    # Database operations
├── Views/
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   ├── Connections/
│   │   ├── ConnectionsView.swift
│   │   └── AddConnectionView.swift
│   ├── Editor/
│   │   ├── SQLEditorView.swift
│   │   └── QueryResultView.swift
│   ├── History/
│   │   └── HistoryView.swift
│   └── Settings/
│       └── SettingsView.swift
└── Assets.xcassets/
```

## Design Principles

1. **Minimal** - Clean, uncluttered interface
2. **Fast** - Optimized performance
3. **Beautiful** - Smooth animations and transitions
4. **Functional** - All essential features included

## Getting Started

1. Open `SQLClient.xcodeproj` in Xcode
2. Select your target device (iPhone or iPad)
3. Build and run (⌘R)

## Usage

1. Complete the onboarding tutorial
2. Add a database connection
3. Connect to your database
4. Write and execute SQL queries
5. View results in a beautiful table format

## Future Enhancements

- SQL syntax highlighting
- Query autocompletion
- Export results to CSV/JSON
- Database schema browser
- Saved queries/snippets
- iCloud sync for connections

## Requirements

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

## License

Copyright © 2024 INDEX. All rights reserved.

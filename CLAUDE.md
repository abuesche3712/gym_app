# Gym App

iOS workout tracking app built with SwiftUI. Offline-first with CoreData, Firebase for cloud sync.

## Quick Reference

**Build:** `xcodebuild -scheme "gym app" -destination "generic/platform=iOS Simulator" build`

**Detailed docs:** See `CLAUDE_CONTEXT.md` for comprehensive architecture, bug history, and implementation details.

## Tech Stack

- **UI:** SwiftUI (iOS 17+)
- **Local Storage:** CoreData
- **Cloud:** Firebase (Auth, Firestore, Storage, Crashlytics)
- **Architecture:** MVVM with repository pattern

## Project Structure

```
gym app/
├── Models/           # Data models (Session, Module, Workout, etc.)
├── ViewModels/       # Observable view models
├── Views/            # SwiftUI views organized by feature
│   ├── Session/      # Active workout UI
│   ├── Social/       # Friends, messaging, feed
│   ├── Home/         # Dashboard, calendar
│   └── Components/   # Reusable UI components
├── Repositories/     # CoreData access layer
├── Services/         # Business logic (Sync, Sharing, etc.)
├── Theme/            # Design system (colors, spacing, typography)
└── CoreData/         # Entity definitions
```

## Design System

**Always use theme constants, never hardcode values:**

```swift
// Colors
AppColors.dominant          // Primary purple
AppColors.background        // Dark background
AppColors.textPrimary       // Main text
AppColors.surfaceSecondary  // Card/input backgrounds

// Spacing
AppSpacing.xs / .sm / .md / .lg / .xl

// Typography (as View modifiers)
.headline()    .body()    .caption()
.monoMedium()  // For timers/numbers

// Corners
AppCorners.small / .medium / .large
```

## Key Patterns

### Navigation
- Custom tab bar in `MainTabView.swift` using `safeAreaInset`
- Hide tab bar in detail views via `@Environment(\.hideTabBar)`
- Each tab has its own NavigationStack

### Data Flow
- `DataRepository.shared` → entity-specific repositories
- ViewModels observe repositories via `@Published`
- Cloud sync via `FirestoreService` + `SyncManager`

### Logging
```swift
Logger.debug("message")           // DEBUG builds only
Logger.error(error, context: "")  // Always logs + Crashlytics
```

## Common Tasks

### Adding a new MessageContent type
1. Add case to `MessageContent` enum in `Message.swift`
2. Update `ContentType` enum, `init(from:)`, `encode(to:)`, `previewText`
3. Update `isImportable`/`isSharedContent` in `SharingService.swift`
4. Update `SharedContentCard.swift` switch statements
5. Update `ChatView.swift` MessageBubble `contentView`
6. Update `Post.swift` if applicable

### Adding a new ShareBundle type
1. Add struct to `ShareBundles.swift`
2. Add version constant to `SchemaVersions.swift`
3. Add creation method to `SharingService.swift`

## Build Issues

- **PIF errors:** `rm -rf ~/Library/Developer/Xcode/DerivedData/gym_app-*`
- **Firebase slow:** Package resolution can take time on first build
- **Compiler timeout:** Use enum-based sheet routing instead of multiple `.sheet()` modifiers

## Testing

Run the app and check Xcode console for debug logs. Key log prefixes:
- `[ERROR]` - Always logged, sent to Crashlytics
- `[INFO]` / `[WARN]` - DEBUG builds only
- `ChatView.onAppear:` - Chat debug info
- `ChatViewModel.isBlocked:` - Block status checks

## Implementation Guidelines

### Feature Implementation Checklist

Before marking any user-facing feature as complete:

1. **Verify UI Entry Points** - Ensure users can actually access the new functionality
   - Where will users navigate to use this feature?
   - Is there a button/link/menu item that leads to it?
   - Check that the entry point exists and is wired up correctly

2. **Complete User Journey** - Test the full flow, not just the new code
   - Start from the main screen and navigate to the feature
   - Verify all intermediate screens work
   - Check that back navigation works properly

3. **Environment Considerations**
   - Does the feature work with the custom tab bar? (use `@Environment(\.hideTabBar)` if needed)
   - Are keyboard/input areas unobstructed?
   - Does it work in both light/dark mode?

### Definition of Done

A feature is complete when:
- [ ] Code compiles without warnings
- [ ] UI entry point exists and is accessible
- [ ] Full user journey verified manually
- [ ] Error states handled gracefully
- [ ] Logging added for debugging (Logger.debug/error)

### Project Path Verification

Before starting work, confirm the project structure. If file reads fail:
```bash
# Verify project root
ls /Users/andrewsmacmini/Desktop/sw_projects/gym_app

# Find specific files if needed
find . -name "*.swift" -path "*/Views/*" | head -20
```

## Claude Code Tips

**Hooks** - Auto-run builds after edits:
```json
// ~/.claude/settings.json
{
  "hooks": {
    "afterEdit": "xcodebuild -scheme 'gym app' -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5"
  }
}
```

**Parallel Exploration** - Use Task agents to explore multiple areas simultaneously when investigating complex issues.

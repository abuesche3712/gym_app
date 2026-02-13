# AGENTS.md

## Purpose
This file defines how coding agents should work in this repository.

Primary goal: ship safe, working changes to the iOS app with minimal regressions.

## Project Facts
- App: `gym app` (SwiftUI, iOS 17+)
- Data: CoreData (offline-first) + Firebase sync
- Architecture: MVVM + repository + services
- Extra target: `TodayWorkoutWidget`

## Where To Work
- App source: `gym app/`
- Unit tests: `gym appTests/`
- UI tests: `gym appUITests/`
- Widget: `TodayWorkoutWidget/`
- Design docs: `design docs/`
- Architecture history/reference: `CLAUDE_CONTEXT.md`

## Build And Test Commands
Run from repo root: `/Users/andrewsmacmini/Desktop/sw_projects/gym_app`

- Build:
  - `xcodebuild -project "gym app.xcodeproj" -scheme "gym app" -destination "generic/platform=iOS Simulator" build`
- Test (default: unit tests only):
  - `xcodebuild -project "gym app.xcodeproj" -scheme "gym app" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:"gym appTests" test`
- UI tests (only when UI behavior is directly changed or requested):
  - `xcodebuild -project "gym app.xcodeproj" -scheme "gym app" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:"gym appUITests" test`
- CI-safe build (no signing):
  - `xcodebuild -project "gym app.xcodeproj" -scheme "gym app" -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`

If simulator name fails locally, list devices first:
- `xcrun simctl list devices available`

## Formatting And Linting
Use lightweight formatting/linting when tools are installed locally.

- Config files live at repo root:
  - `.swiftformat`
  - `.swiftlint.yml`
- Non-blocking policy:
  - Run these checks when available, but do not block small feature work on style-only warnings.
- Preferred usage:
  - Format changed Swift files: `swiftformat <file1> <file2> ...`
  - Lint project: `swiftlint lint`
- If a lint/format tool is not installed, continue work and note it in validation output.

## Non-Negotiable Engineering Rules
- Do not hardcode design values in UI code.
  - Use `AppColors`, `AppSpacing`, `AppCorners`, and typography modifiers from `Theme/`.
- Keep business logic out of views.
  - Put logic in `ViewModels/`, `Services/`, or `Repositories/`.
- Keep persistence and sync behavior consistent.
  - If changing models, verify CoreData mapping and Firebase encode/decode paths.
- Prefer incremental changes over broad refactors unless explicitly requested.
- Add or update tests for behavior changes in repositories/services/view models.

## Feature Work Checklist
Before marking work complete:
1. Build succeeds.
2. Relevant unit tests pass for logic/behavior changes.
3. Build-only validation is acceptable for small copy/layout tweaks.
4. If tests are skipped, document why.
5. User can reach the feature in UI (entry point exists).
6. Happy path and at least one failure/empty state are checked.
7. Logging is meaningful for new failure points (`Logger.error(...)`).

## Protected Areas (Approval Required)
- Do not edit `gym app.xcodeproj/project.pbxproj` without explicit user approval.
- Ask before any Firebase behavior/config/schema change in:
  - `gym app/Services/Firebase/`
- Ask before any migration/schema-impacting change (CoreData model/persistence/mapping), including:
  - `gym app/CoreData/`
  - model encode/decode or persistence mapping changes in `gym app/Models/` and repositories/services.

## Git Workflow
- Work directly on `main` (no feature branch required unless user asks).
- Keep commit messages short and descriptive (single line preferred).
- Do not make commits unless the user asks for a commit.

## High-Risk Areas (Be Extra Careful)
- Sync pipeline and conflict handling:
  - `gym app/Services/Firebase/`
  - `gym app/Services/SyncManager.swift`
- CoreData schema/model conversions:
  - `gym app/CoreData/`
  - `gym app/Models/`
- Social/messaging consistency:
  - `gym app/ViewModels/ChatViewModel.swift`
  - `gym app/ViewModels/ConversationsViewModel.swift`
  - `gym app/Services/Firebase/FirestoreMessagingService.swift`

## PR / Change Notes Expectations
For every substantial change, include:
- What changed
- Why it changed
- How it was validated (build/tests/manual)
- Known risks and follow-up tasks

## When Unsure
- Prefer reading `CLAUDE.md` for quick patterns.
- Use `CLAUDE_CONTEXT.md` for deeper architecture and prior decisions.
- Choose the smallest safe change that solves the current task.

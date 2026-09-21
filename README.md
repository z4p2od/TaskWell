# TaskWell

iPhone MVP for a personal task **pool**: quick capture, then one-card suggestions when you have time.

Local-only SwiftUI + SwiftData. Designed so CloudKit sync, Apple Watch, App Intents/voice, and AI ranking can land without a rewrite.

## Open in Xcode

1. Open `TaskWell.xcodeproj` (double-click, or `open ~/Projects/TaskWell/TaskWell.xcodeproj`).
2. Select an **iPhone** simulator (iOS 17+; project targets iPhone only).
3. Press **Run** (⌘R).

If Xcode asks for a Team under Signing & Capabilities, pick your personal team (or leave empty for Simulator-only runs). Bundle ID is `com.taskwell.app`.

### Command line

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd ~/Projects/TaskWell
xcodebuild -scheme TaskWell -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

## What’s in the MVP

- **Quick add** — free-text first (on-device parse + local/optional BYOK enrichment chips); structured fields under More options / Edit
- **Pool** — open tasks with effort / enjoyment / due filters; tap to edit; swipe Done (confirm actuals) or Delete
- **Suggest** — presets or **Custom** (time + appetite dials) → one card with Accept / Skip / Snooze. **Accept** starts the task (in progress); **Done** completes it with feedback. Edit from the active card.
- **Done** — completed history with reopen/delete; stores actual minutes/effort/enjoyment for learning
- **Settings** (Suggest gear) — optional OpenAI/Anthropic keys in Keychain; toggle AI enrichment

## Project layout

| Folder | Role |
|--------|------|
| `Models/` | SwiftData `PoolTask` + enums (stable UUIDs, sync-friendly) |
| `Capture/` | Quick-add sheet + App Intent stub |
| `Pool/` | List, filters, rows |
| `Suggest/` | `TaskSuggesting` protocol, `LocalTaskScorer`, card UI |
| `History/` | Completed log |
| `Shared/` | Theme + empty/loading/error chrome |

## Future hooks

- **CloudKit** — models already use stable `id: UUID` and scalar optionals. Turn on `cloudKitDatabase` in `TaskWellApp` once a Developer Team is set. Do not enable yet.
- **Apple Watch** — Phase 2 companion can reuse `Models/` + `LocalTaskScorer` / `TaskSuggesting`; sync via WatchConnectivity first or CloudKit later.
- **App Intents / voice** — `AddPoolTaskIntent` is stubbed in `Capture/`. Share a ModelContainer (app group) before shipping Shortcuts.
- **AI ranking** — implement `TaskSuggesting` with an LLM-backed type and inject it where `SuggestView` currently uses `LocalTaskScorer`.
- **Calendar / location** — extend `SuggestScoreContext` with EventKit free gaps or geofence signals; keep the protocol boundary.

## Design notes

Light mode, teal “well” palette (not generic purple). Brand **TaskWell** is the hero on the Suggest tab. SF Symbols + system rounded type.

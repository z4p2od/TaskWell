# TaskWell

iPhone MVP for a personal task **pool**: structured capture, then one-card suggestions when you have time.

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

- **Quick add** — structured form (title autofocus + optional due / effort / enjoyment / duration chips: 10m · 30m · 1h · 2h+ · Custom…). Unset duration = unknown. **2h+** stores 120 minutes.
- **Pool** — available + in-progress first; **Snoozed** section when snoozed tasks exist; Status filter includes Snoozed; unsnooze via swipe / inline / edit.
- **Suggest** — presets or **Custom** (time + appetite) → one card. **Skip** is session-only; **Snooze** opens a picker (1h / 4h / Tonight / Tomorrow morning / custom) → `snoozedUntil`. **Accept** starts the task; **Done** completes with feedback.
- **Done** — completed history; stores actual minutes/effort/enjoyment for learning.
- **Settings** (Suggest gear) — optional OpenAI/Anthropic keys in Keychain for future voice enrichment.

## Project layout

| Folder | Role |
|--------|------|
| `Models/` | SwiftData `PoolTask` + enums (stable UUIDs, sync-friendly) |
| `Capture/` | Structured add/edit, Done confirm, parser/enrichment (voice-ready), App Intent |
| `Pool/` | List, filters (incl. Snoozed), rows |
| `Suggest/` | Scorer, card UI, snooze picker, custom mood |
| `History/` | Completed log |
| `Shared/` | Theme + duration chips + empty/loading/error chrome |

## Future hooks

- **CloudKit** — models already use stable `id: UUID` and scalar optionals. Turn on `cloudKitDatabase` in `TaskWellApp` once a Developer Team is set. Do not enable yet.
- **Apple Watch** — Phase 2 companion can reuse `Models/` + `LocalTaskScorer` / `TaskSuggesting`.
- **App Intents / voice** — `AddPoolTaskIntent` parses a phrase into a pool task. Share a ModelContainer (app group) before shipping Shortcuts; present pre-filled `TaskEditorSheet` for confirm.
- **AI ranking** — implement `TaskSuggesting` with an LLM-backed type where `SuggestView` uses `LocalTaskScorer`.
- **Calendar / location** — extend `SuggestScoreContext` with EventKit or geofence signals.

## Design notes

Light mode, teal “well” palette (not generic purple). Brand **TaskWell** is the hero on the Suggest tab. SF Symbols + system rounded type.

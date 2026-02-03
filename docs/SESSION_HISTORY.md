# Session History

Chronological log of development sessions for IntegrityStudio.ai.

---

## 2026-02-02: Marionette MCP Integration for AI Agent Testing

### Summary
Researched and integrated Flutter testing tooling compatible with Claude Code. Installed Marionette MCP for runtime widget inspection and AI agent interaction.

### Research Findings
Evaluated Flutter testing tools with Claude Code integration:

| Tool | Purpose | Notes |
|------|---------|-------|
| **Dart/Flutter MCP Server** | Official, dev-time tasks | Requires Dart 3.9+, analysis/testing/hot reload |
| **Maestro MCP** | iOS/Android E2E | YAML scenarios, ~2,100 tokens |
| **Mobile MCP** | Generic mobile | Device control, ~2,900 tokens |
| **Marionette MCP** | Flutter-specific, all platforms | Lightweight (~1,300 tokens), by Patrol author |

Selected **Marionette MCP** for:
- Flutter-specific (not generic mobile)
- All platforms including web/desktop
- Minimal token overhead
- Made by LeanCode (Patrol creators)

### Changes Made

**Files Modified:**
- `lib/main.dart` - Added MarionetteBinding initialization in debug mode
- `pubspec.yaml` - Added `marionette_flutter: ^0.3.0` dependency
- `.mcp.json` - Created project-level MCP config for Marionette

**Packages Installed:**
- `marionette_mcp` (global CLI tool via `dart pub global activate`)
- `marionette_flutter` (Flutter package)

### Key Technical Decisions
1. **Project-level MCP config** - Used `--scope project` to add `.mcp.json` rather than global config
2. **Debug-only initialization** - MarionetteBinding only in `kDebugMode`, standard WidgetsFlutterBinding in release
3. **No main.dart restructuring** - Minimal changes, preserved existing Sentry/GTM initialization flow

### Commits
- `2dbe3d0` - feat(testing): add Marionette MCP for AI agent UI testing

### Usage
1. Run app in debug mode: `flutter run -d chrome`
2. Copy VM service URI from console (e.g., `ws://127.0.0.1:12345/ws`)
3. Ask Claude to connect via Marionette and interact with app

### Status
✅ Complete

---

## Previous Sessions
See `docs/CHANGELOG.md` for historical session details merged from previous SESSION_HISTORY.md files.

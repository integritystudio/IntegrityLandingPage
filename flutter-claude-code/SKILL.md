---
name: flutter-claude-code
description: Dart/Flutter web development for IntegrityLandingPage — widget authoring, unit+widget tests, content.yaml patterns, Cloudflare deployment.
allowed-tools: [Read, Write, Edit, Grep, Bash]
tags: [flutter, dart, frontend, testing, cloudflare]
argument-hint: "[widget-name or task-description]"
model: claude-sonnet-4-6
---

# Flutter + Claude Code Development

You are a Flutter web engineer for IntegrityLandingPage. Follow these conventions for widget creation, testing, and deployment.

## When to Use

- Building or modifying Flutter widgets, pages, or sections
- Writing or updating Flutter tests
- Working with content.yaml or the content loading system
- Cloudflare Pages deployment or Workers changes
- Do NOT use for non-Flutter tasks, pure documentation, or backend-only work

## Workflow

1. Read existing widget/file before modifying
2. Check theme tokens — never hardcode colors, spacing, or font sizes
3. Check `content.yaml` — never hardcode user-facing strings
4. Write or edit using conventions below
5. Run `flutter analyze` (must pass with zero warnings)
6. Write tests for every new widget (desktop + mobile viewports)
7. Run `flutter test` before declaring done

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `lib/pages/` | Full page widgets (GoRouter) |
| `lib/widgets/{common,sections,modals,navigation}/` | UI components |
| `lib/services/` | External integrations (content_loader, analytics) |
| `lib/theme/` | Design system (AppColors, AppTypography, AppSpacing) |
| `lib/config/content/` | Content models |
| `test/` | Pages, widgets, services, controllers, integration tests |
| `workers/` | Cloudflare Workers (contact form) |

## Code Conventions

- **StatelessWidget** by default; StatefulWidget only for local state (scroll, hover, animation)
- Props via constructor with `required` named params; `const` constructors
- Relative imports with `..`; triple-slash doc comments for public widgets
- Provider for app-wide state; ValueNotifier for simple reactive state

### Theme System

Always use tokens from `lib/theme/`: `AppColors.blue500`, `AppTypography.headingMD`, `AppSpacing.md`, `AppDecorations.gradientBackground`. Never hardcode values.

### Content Pattern

All user-facing text in `content.yaml`, loaded via `ContentLoader`:
```dart
final hero = AppContent.hero;
Text(hero.headline);
```
New content: add to YAML, create typed model in `lib/config/content/`, wire through ContentLoader.

## Testing

- Two `pump()` calls after `pumpWidget` for stabilization
- Mock via `IntegrationMocks`; find by type/text/Semantics (not key)
- Test both viewports: `setDesktopSize(tester)` and `setMobileSize(tester)`
- Helpers in `test/helpers/`: `test_helpers.dart`, `test_content.dart`

## Commands

| Command | Purpose |
|---------|---------|
| `flutter analyze` | Lint (zero warnings required) |
| `flutter test` | All tests (~1978 passing) |
| `flutter build web --release` | Production build |

## Output

Report files created/modified, test file location and count, any `flutter analyze` warnings resolved.

## Telemetry

Completion signal (always emit as final output line):
```
[SKILL_COMPLETE] skill=flutter-claude-code outcome=success|failure files_changed=N tests_passing=N
```

| Span | Attributes | Source |
|------|-----------|--------|
| `skill-activation-prompt` | `skill_activation.matches` | user-prompt.ts |
| `plugin-post-tool` | `plugin.name=flutter-claude-code`, `plugin.output_size` | post-tool.ts |
| `builtin-post-tool` | `builtin.tool=Bash` (flutter analyze/test), `builtin.tool=Write\|Edit` (widget code) | post-tool.ts |

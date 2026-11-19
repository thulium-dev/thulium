---
name: thulium-ui
description: Implement or review Thulium Flutter screens, UI copy, lists, interaction states, loading, and navigation using the project's restrained Forui design language. Use for Thulium UI changes, not generic website design or backend-only work.
---

# Thulium interface

Thulium is a campus tool for students checking courses, deadlines, files, and
calendar plans. Prioritize finding real information quickly. The established
identity is a quiet neutral surface, readable text, compact rows, fine dividers,
and color reserved for urgency, categories, selection, and errors.

## Start from the implementation

Read repository `AGENTS.md` and the affected screen. Check the Forui version in
`pubspec.yaml`: online docs may describe APIs newer than the pinned dependency.
Use the installed package source to confirm a style or variant API. Reuse:

- `lib/widgets/flat_tile_style.dart` for list groups and rows
- `lib/widgets/app_page_scaffold.dart` for nested page chrome and reading width
- `lib/navigation/app_page_route.dart` for pushed routes
- `lib/widgets/course_content_loading.dart` for course loading surfaces

## Calendar boundary

The user has approved the central calendar panel. Preserve its grid, layout,
colors, and interactions during general UI work. Shared navigation outside the
panel may be updated; changing the panel itself needs an explicit user request.

## Surfaces and hierarchy

- Use `context.theme` colors, typography, spacing, and border tokens. Keep light
  and dark themes coherent. The neutral dark reference is background `#09090B`,
  foreground `#FAFAFA`, muted foreground `#A1A1AA`, border `#27272A`; these are
  design references, not permission to hard-code runtime colors.
- Use the existing system type family. Titles are semibold; metadata is smaller
  and muted. Keep the same left edge and page padding through a navigation flow.
- Courses, assignments, and file lists use a single page surface and thin lines
  between adjacent rows. Do not add per-row boxes, outer list borders, stacked
  cards, shadows, or gradients. Preserve meaningful badges and deadline colors.
- Navigation rows keep the page background on press and hover. Retain a visible
  keyboard focus outline, semantic labels, and practical touch targets. Selected
  controls and destructive buttons still need their semantic interaction states.
- Use Forui controls and Lucide icons for product surfaces. Flutter layout and
  platform integration are fine; avoid Material-styled product controls.

## Copy

- Short titles, labels, notices, empty states, and slogans normally have no final
  period in English or Chinese. Preserve questions, necessary punctuation within
  multi-sentence explanations, decimal numbers, and file extensions.
- A title plus an icon should usually explain a navigation action. Do not add
  subtitles that restate them or explain the categories on the following screen.
- Keep actual content metadata: instructor, schedule, file size/type, deadline,
  and assignment state. These are not slogans.
- Loading, errors, and empty states should explain the current state concisely.
  Provide an action when it helps. Keep safety-critical explanations intact.
- Put interface copy in `lib/l10n/app_en.arb`, translate the other ARBs, and run
  `flutter gen-l10n`. Update affected copy assertions. Do not trim translations
  at render time or silently rewrite user-provided course/document content.

## Navigation and asynchronous content

- Keep back/title/action placement and background stable from course detail to
  files or assignments to document preview. Forms and settings use the same
  nested-page shell. Calendar grids can retain their dense, full-width layout.
- Use the shared route: a short fade with a small directional horizontal offset
  on navigation. Honor reduced motion with zero duration. Avoid unanimated
  `PageRouteBuilder`, inconsistent platform transitions, decorative page-load
  entrances, or staggered list-item animation.
- Keep existing content visible during refresh. Show progress in an existing
  action slot; don't replace the whole page with an empty spinner.
- Match loading placeholders to the eventual layout. Use the same document
  loading surface while fetching bytes and opening the native PDF renderer.
  Loading-to-content transitions should be brief and honor reduced motion.
- Do not invert document pages to simulate dark mode. Theme the viewer chrome
  and surrounding surface; keep the document's actual colors.
- Preserve cached campus information if background reauthentication needs user
  verification. Offer an explicit sign-in action rather than an abrupt redirect.

## Review and finish

Check the affected flow in both themes and on a narrow screen. Check pressed
rows, keyboard focus, long titles, loading, empty/error states, refresh, back
navigation, and reduced motion where relevant. Prefer screenshots for visual
review when the environment supports them; describe device-only gaps honestly.
Run relevant analysis and behavioral tests. Include a Git commit description
that matches the actual diff and any new untracked files.

## Reference documentation

Use these for interaction and composition principles, not as pixel templates or
permission to replace Flutter with React:

- [Forui themes](https://forui.dev/docs/concepts/themes)
- [Forui tile groups](https://forui.dev/docs/widgets/tile/tile-group)
- [Forui widget styles](https://forui.dev/docs/guides/customizing-widget-styles)
- [shadcn/ui items](https://ui.shadcn.com/docs/components/item)
- [shadcn/ui separators](https://ui.shadcn.com/docs/components/separator)
- [shadcn/ui semantic themes](https://ui.shadcn.com/docs/theming)

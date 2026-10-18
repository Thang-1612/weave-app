# Weave responsive UI starter

This is a UI foundation/demo intended to be copied into the Weave Flutter project.
It does not replace Firebase services or existing screens and is not wired into
`main.dart` by default.

## Included
- `lib/theme/app_theme.dart`: proposed warm-minimal theme and design tokens.
- `lib/widgets/weave_responsive_shell.dart`: mobile / tablet / desktop responsive shell.
- `lib/demo/responsive_home_demo.dart`: static demo screen showing the shell.

## How to try it
1. Copy the `lib/` files into your project, backing up existing files first.
2. Because `lib/theme/app_theme.dart` replaces the existing theme file, check any
   project code that imports `AppColors` or `GradientAppBarBackground`. The existing
   names are retained for compatibility.
3. Temporarily show the demo from a route or replace the home body in a development
   branch with `const ResponsiveHomeDemo()`. Do not replace `AuthGate` in production.
4. Run `flutter pub get`, `flutter analyze`, and test with window widths below 600,
   600–999, and 1000+ logical pixels.
5. Once the shell is approved, integrate the navigation callbacks with existing
   `HomeScreen` routes; the demo's navigation items are placeholders.

## Design tokens
- Brand indigo: `#4F46E5`
- Background: `#F7F7FB`
- Surface: `#FFFFFF`
- Text: `#202235`
- Secondary text: `#6B7280`
- Border: `#E6E7EF`
- Accent teal: `#0F766E`
- Soft indigo: `#EEF2FF`
- Radius: 12–18 px
- Content max width: 1440 px
- Breakpoints: <600 mobile; 600–999 tablet/narrow window; >=1000 desktop

This is a starter/demo, not a claim that the full application has been integrated
or tested. Review project-specific navigation and run Flutter analysis before release.

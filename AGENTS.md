# Interface Style

Use a restrained, dark, minimalist visual language for Thulium, consistent with
the existing calendar and Forui components.

- Prefer Forui components and their theme tokens. Keep surfaces simple, with
  clear hierarchy, fine borders, compact spacing, and consistent interaction
  states.
- Use near-black backgrounds, subtle grid lines, and low-contrast cards for
  dense calendar views. Reserve saturated colors for meaningful categories,
  urgency, selection, or other necessary emphasis.
- Favor legible typography, concise labels, and predictable alignment. Let
  spacing, weight, and a small number of semantic colors establish hierarchy
  instead of decoration.
- Keep shadows, gradients, rounded containers, and ornamental effects subtle.
  Avoid visual clutter and unnecessary card-on-card layouts.
- Maintain sufficient contrast and readable text in both light and dark themes;
  use the shared theme rather than hard-coding colors when practical.
- Keep interactions visually quiet and consistent: use unobtrusive controls,
  clear selected and focus states, and touch targets appropriate to each
  platform.
- Do not introduce Material-styled widgets into Forui product surfaces. Use the
  existing project patterns for platform integration where needed.

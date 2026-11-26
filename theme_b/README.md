# Theme B — 深夜森林

Version: `1.2.0-theme-b.1`, based on shared shell `v1.2.0`.
Branch: `theme-b`. Entry: `res://theme_b/level_select.tscn`.

| Source level | Theme B scene | Display name |
| --- | --- | --- |
| level0 | tutorial/main.tscn | 教学关 |
| level1_new | level1/main.tscn | 第一关 |
| level2 | level2/main.tscn | 第二关 |
| level2_new | level3/main.tscn | 第三关 |

Open the repository's project.godot, then run theme_b/level_select.tscn with F6.
The shared theme hub is unchanged; its maintainer can link the entry above when merging.

All theme-specific scene/script/material changes live in this directory. Identical binary assets use the shared assets directory. `runtime/` contains the required theme-specific dependencies, not a second Godot project. `migration_map.json` records their source paths.

The scene-local runtime replaces the old BlockArchitecture autoload without editing project.godot. Progress uses a separate theme_b_progress.cfg. The tutorial has no block timer and requires MovableBox_C to enter G_Tool before the final button works; the other levels retain the 30-second block timer.

No exports, .godot cache, executable files or source-project settings are included. The original working project is unchanged.

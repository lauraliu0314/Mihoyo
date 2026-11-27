# Theme C — Any Side Up

此目录包含教学关、关卡01～03、选关页及这些场景专用的资源和脚本。
共用工程根目录的 `project.godot`、`assets/`、`player/` 均未修改。

## 在 Godot 中检查

1. 打开仓库根目录的 `project.godot`。
2. 在文件系统面板打开 `res://theme_c/level_select.tscn`，按 **F6** 运行当前场景。
3. 可从选关页直接进入教学关及三个正式关卡。进入关卡后可用 **R** 重开。

## 接入共用主题菜单

合并时将主题 C 的入口指向 `res://theme_c/level_select.tscn`。
此分支没有改动共用 `theme_select.tscn`，以免与其他主题产生冲突。

`local_assets/` 和 `local_player/` 只包含与共用版本不同、且本关卡实际依赖的文件；
其余未修改的资源仍引用仓库原有路径。

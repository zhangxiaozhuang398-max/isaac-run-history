# Run History / 对局记录

《以撒的结合：忏悔》的 mod：自动记录最近 20 局对局，并用游戏自己的纸张菜单风格显示出来。

A mod for *The Binding of Isaac: Repentance* that records your last 20 runs and shows them in a page styled like the game's own paper menus. (English summary at the bottom.)

## 功能

**每局记录**

- 角色、种子、难度、结果（胜利 / 死亡 / 放弃）、用时
- 最终道具
- 最后拿着的主动道具（包括学生书包副槽、口袋主动）和饰品（金饰品显示为金色，吞下的饰品显示为半透明）
- 最终属性：移速、射速、伤害、射程、弹速、运气
- 最后击败的 Boss
- 死因（死亡的对局）：被哪个敌人 / Boss 杀死，或尖刺、诅咒房门、自伤等，带游戏死亡画面里的头像

**每层记录**

- 本层获得的道具（开局自带的道具单独列为"初始道具"）
- 击败的关底 Boss（带小图标）
- 本层用时
- 离开本层时的金币、炸弹、钥匙数量
- 恶魔房 / 天使房是否出现、是否进入

记录按存档槽分开保存，每个存档最多保留 20 局。

## 必须安装：REPENTOGON 1.0.12e

| 项目 | 是否需要 | 说明 |
| --- | --- | --- |
| 忏悔 DLC，游戏版本 v1.7.9b | **必需** | mod 就是为这个版本做的 |
| [REPENTOGON 1.0.12e](https://github.com/TeamREPENTOGON/REPENTOGON/releases/tag/1.0.12e)（必须是这个版本） | **必需** | 更新的 REPENTOGON 只支持忏悔+，在这里用不了 |
| 忏悔+ | 不支持 | 没有测试过 |
| 胎衣+ 及更早版本 | 不支持 | 需要忏悔 |
| EID（External Item Descriptions） | 可选 | 只用于显示其他 mod 加入的敌人和 Boss 的名字 |

**不要用创意工坊里的 REPENTOGON。** 那是最新版，只支持忏悔+，而且订阅并不会安装它。1.0.12e 只能在 GitHub 下载。

### REPENTOGON 1.0.12e 安装步骤

1. 打开 [REPENTOGON 1.0.12e 发布页](https://github.com/TeamREPENTOGON/REPENTOGON/releases/tag/1.0.12e)，在"Assets"下面下载 `REPENTOGON.zip`。
2. 打开游戏目录：在 Steam 库里右键《以撒的结合：重生》→ 管理 → 浏览本地文件，也就是有 `isaac-ng.exe` 的那个文件夹。
3. 把 `REPENTOGON.zip` 里的**全部文件**解压到这个文件夹；Windows 问是否替换时选替换。
4. 从 Steam 启动游戏。第一次启动时可能会弹出 REPENTOGON 的更新程序，或者游戏自己关掉。**不要安装更新程序提供的任何东西**（它装的是忏悔+ 用的版本）。
5. 用记事本打开游戏目录里的 `dsound.ini`，确认写的是 `CheckForUpdates = 0`，保存。
6. 再启动游戏。装好后游戏窗口标题会显示 `The Binding of Isaac: Repentance (+ REPENTOGON 1.0.12e)`。

没装好时，记录页面标题旁边会显示红字"需要 REPENTOGON 1.0.12e"。以后想卸载 REPENTOGON，删掉游戏目录里的 `dsound.dll` 即可。

## 安装本 mod

先装好 REPENTOGON 1.0.12e，然后在 Steam 创意工坊订阅：<https://steamcommunity.com/sharedfiles/filedetails/?id=3838982654>

或者手动安装：把整个文件夹放进游戏目录的 `mods` 文件夹，文件夹名保持为 `run history`：

```
The Binding of Isaac Rebirth/mods/run history/
```

## 怎么打开

| 位置 | 操作 |
| --- | --- |
| 主菜单 | 任意界面按 `F2`；或进入"统计数据"，选中右上角的"对局记录"便签按确认 |
| 对局中 | 按 `F2` |

页面内的操作：

- `↑` `↓` 选择对局 / 滚动楼层
- `空格` 查看详情；在详情页再按 `空格` 进入道具选择，用方向键逐个查看道具的官方名称和拾取说明
- `←` `→` 在详情页切换对局
- 主菜单里 `ESC` 返回、`F2` 关闭；对局内用 `退格键` 返回、`F2` 关闭（对局内按 ESC 会暂停游戏）

对局内打开页面时角色不会移动或射击，但敌人不会暂停，建议在清完的房间里看。

## 设置

编辑 `rh_config.lua`：

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `ToggleKey` | `Keyboard.KEY_F2` | 打开 / 关闭页面的按键（主菜单和对局内都用它） |
| `MaxRuns` | `20` | 最多保留多少局 |
| `Language` | `"auto"` | `"auto"` 跟随游戏语言，或 `"zh"` / `"en"` |
| `SkipQuickRestarts` | `true` | 没打完第一层就重开的对局不记录 |
| `MenuOffsetX` / `MenuOffsetY` | `0` | 主菜单里页面位置的微调（像素） |

控制台命令：`runhistory` 开关页面，`runhistory clear` 清空当前存档的记录。

## 已知限制

- 道具数量超过一屏能放下的格数时，多出来的道具显示为 "+N"，无法选中查看名字。
- 贪婪模式不记录每层的波次 Boss，只记录最后的究极贪婪。
- 用手柄时，按键提示仍然显示键盘按键。
- 旧版本 mod 记录的对局缺少后来才加入的数据（属性、每层用时、金币、死因、主动和饰品等），对应位置显示为空。
- 属性、主动道具和饰品只记录 1 号角色（雅各和以扫只记录雅各）。
- 死因按角色最后一次受到的伤害判断；其他 mod 添加的敌人没有头像，名字需要装有 EID 才能显示。
- 界面有中文和英文；其他语言的游戏会显示英文。

## 数据存在哪

```
The Binding of Isaac Rebirth/data/run history/save1.dat
```

`save1` / `save2` / `save3` 对应三个存档槽。文件内容是 JSON 文本。mod 数据不走 Steam 云同步，删除 mod 也不会删除记录。

## 文件说明

| 文件 | 内容 |
| --- | --- |
| `main.lua` | 记录逻辑 |
| `rh_ui.lua` | 页面绘制和对局内的按键处理 |
| `rh_menu.lua` | 主菜单里的入口：F2 和"统计数据"里的便签（REPENTOGON） |
| `rh_names.lua` | 楼层名和界面文字 |
| `rh_names_data.lua` | 道具 / 角色 / Boss 的官方中英文名（由游戏本地化文件生成） |
| `rh_boss_icons.lua` | Boss 小图标对照表（自动生成） |
| `rh_config.lua` | 设置 |
| `resources/gfx/` | 动画定义，以及便签、键帽贴图 |

纸张、字体、属性图标、Boss 小图等都是直接引用游戏自带的资源，本仓库不包含游戏文件。

## English summary

Records the last 20 runs per save slot: character, seed, result, time, final items and stats, the active items and trinkets you ended with, what killed you, and for every floor the items picked up, bosses defeated, time spent, coins / bombs / keys when leaving, and whether a devil or angel room appeared and was entered.

**Requirements**

- The Repentance DLC, game **v1.7.9b**. Repentance+ and Afterbirth+ or older are not supported.
- **[REPENTOGON 1.0.12e](https://github.com/TeamREPENTOGON/REPENTOGON/releases/tag/1.0.12e) (required, exactly this version).** Newer REPENTOGON versions, including the one on the Steam Workshop, are for Repentance+ only.
- Optional: EID, for names of enemies from other mods.

**Installing REPENTOGON 1.0.12e**

1. Download `REPENTOGON.zip` from the [1.0.12e release page](https://github.com/TeamREPENTOGON/REPENTOGON/releases/tag/1.0.12e) (under "Assets").
2. Open the game folder (Steam Library → right-click the game → Manage → Browse local files; it contains `isaac-ng.exe`) and extract everything from the zip into it, replacing files.
3. Start the game. If a REPENTOGON updater appears or the game closes, don't install anything it offers. Open `dsound.ini` in the game folder, make sure it says `CheckForUpdates = 0`, and start the game again.
4. When it works, the window title reads `The Binding of Isaac: Repentance (+ REPENTOGON 1.0.12e)`. To remove REPENTOGON, delete `dsound.dll`.

**Using the mod**

- Subscribe on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3838982654), or copy this folder to `mods/run history/` in the game directory.
- Press `F2` in the main menu or during a run, or pick the "Run History" note in the Stats screen. In the floor view, press `Space` to browse items and see their names.
- If REPENTOGON is missing, the page shows a red "Needs REPENTOGON 1.0.12e" next to its title.
- Settings are in `rh_config.lua`.

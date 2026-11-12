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

## 怎么打开

| 位置 | 操作 | 需要 |
| --- | --- | --- |
| 对局中 | 按 `F2` | 无 |
| 主菜单 → 统计数据 | 选中右上角的"对局记录"便签，按确认 | [REPENTOGON](https://github.com/TeamREPENTOGON/REPENTOGON) |

原版游戏的 mod 接口在主菜单里不运行，所以菜单入口只有装了 REPENTOGON 才会出现；没装时 mod 的其余功能不受影响。

页面内的操作：

- `↑` `↓` 选择对局 / 滚动楼层
- `空格` 查看详情；在详情页再按 `空格` 进入道具选择，用方向键逐个查看道具的官方名称和拾取说明
- `←` `→` 在详情页切换对局
- 主菜单里 `ESC` 返回；对局内用 `退格键` 返回、`F2` 关闭（对局内按 ESC 会暂停游戏）

对局内打开页面时角色不会移动或射击，但敌人不会暂停，建议在清完的房间里看。

## 安装

把整个文件夹放进游戏目录的 `mods` 文件夹，文件夹名保持为 `run history`：

```
The Binding of Isaac Rebirth/mods/run history/
```

## 适用版本

- 在 **Repentance v1.7.9b**（不含 Repentance+）上开发和测试。
- 菜单入口在 **REPENTOGON 1.0.12e** 上测试，这是最后一个支持 v1.7.9b 的版本。
- 没有在 Repentance+ 或更新版本的 REPENTOGON 上测试过。

## 设置

编辑 `rh_config.lua`：

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `ToggleKey` | `Keyboard.KEY_F2` | 对局内打开 / 关闭页面的按键 |
| `MaxRuns` | `20` | 最多保留多少局 |
| `Language` | `"auto"` | `"auto"` 跟随游戏语言，或 `"zh"` / `"en"` |
| `SkipQuickRestarts` | `true` | 没打完第一层就重开的对局不记录 |
| `MenuOffsetX` / `MenuOffsetY` | `0` | 主菜单里页面位置的微调（像素） |

控制台命令：`runhistory` 开关页面，`runhistory clear` 清空当前存档的记录。

## 已知限制

- 道具数量超过一屏能放下的格数时，多出来的道具显示为 "+N"，无法选中查看名字。
- 没装 REPENTOGON 时，游戏不向 mod 提供系统时间，对局日期为空。
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
| `rh_menu.lua` | 主菜单"统计数据"里的入口（REPENTOGON） |
| `rh_names.lua` | 楼层名和界面文字 |
| `rh_names_data.lua` | 道具 / 角色 / Boss 的官方中英文名（由游戏本地化文件生成） |
| `rh_boss_icons.lua` | Boss 小图标对照表（自动生成） |
| `rh_config.lua` | 设置 |
| `resources/gfx/` | 动画定义，以及便签、键帽贴图 |

纸张、字体、属性图标、Boss 小图等都是直接引用游戏自带的资源，本仓库不包含游戏文件。

## English summary

Records the last 20 runs per save slot: character, seed, result, time, final items and stats, the active items and trinkets you ended with, what killed you, and for every floor the items picked up, bosses defeated, time spent, coins / bombs / keys when leaving, and whether a devil or angel room appeared and was entered.

- Press `F2` during a run to open the history. In the floor view, press `Space` to browse items and see their names.
- With [REPENTOGON](https://github.com/TeamREPENTOGON/REPENTOGON) installed, a "Run History" note also appears in the main menu's Stats screen.
- Developed and tested on Repentance v1.7.9b with REPENTOGON 1.0.12e; not tested on Repentance+.
- Install by copying this folder to `mods/run history/` in the game directory. Settings are in `rh_config.lua`.

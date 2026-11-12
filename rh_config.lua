-- Run History 设置 / settings
-- 修改后重启游戏（或在控制台输入 luamod run history）生效。

return {
	-- 打开/关闭对局记录界面的按键。常用值：Keyboard.KEY_F2、Keyboard.KEY_H、Keyboard.KEY_F3 ...
	ToggleKey = Keyboard.KEY_F2,

	-- 最多保留多少局记录
	MaxRuns = 20,

	-- 界面语言："auto"（跟随游戏语言）、"zh"（中文）、"en"（English）
	Language = "auto",

	-- 没打过第一层就重开（长按 R）的对局不计入记录
	SkipQuickRestarts = true,

	-- 主菜单"统计数据"里的页面位置微调（像素）。只有装了 REPENTOGON 才用得到；
	-- 如果便签和纸张整体偏了，改这两个数把它挪回去。
	MenuOffsetX = 0,
	MenuOffsetY = 0,
}

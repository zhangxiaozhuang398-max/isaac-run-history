-- Run History: 对局记录页面（以撒菜单风格：纸张 + 手写体 + 菜单箭头）
--
-- 页面画在一张 480x270 的"虚拟画布"上，和游戏主菜单的画布一致：
--   * 对局内：画布居中显示在屏幕上（按 F2 打开）
--   * 主菜单：由 rh_menu.lua 把画布对齐到"统计数据"菜单（需要 REPENTOGON）
--
-- 列表页：左边是对局列表，右边是选中对局的概要和最终道具
-- 详情页：逐层显示获得的道具和击败的 Boss

local mod = RunHistory
local game = Game()
local Names = mod.Names

local UI = {
	open = false, -- 页面是否可见（包含收起动画）
	closing = false,
	anim = 0, -- 0 = 完全收起，1 = 完全展开
	mode = "run", -- "run" | "menu"
	view = "list", -- "list" | "detail"
	sel = 1, -- 选中的对局
	listTop = 1, -- 列表第一行显示的对局
	detailTop = 1, -- 详情页第一行显示的楼层块
}

----------------------------------------------------------------------
-- 语言与字体
----------------------------------------------------------------------

local lang = "en"
local initialized = false

-- top = 字形顶端相对绘制坐标的偏移，h = 字形高度，step = 行距
local Small = { font = Font(), top = 4, h = 10, step = 13 }
local Big = { font = Font(), top = 6, h = 16, step = 25 }

local function tryLoad(font, path)
	local ok = pcall(function() font:Load(path) end)
	return ok and font:IsLoaded()
end

local function init()
	if initialized then return end
	initialized = true

	local want = mod.Config.Language
	if want ~= "zh" and want ~= "en" then
		want = (Options ~= nil and Options.Language == "zh") and "zh" or "en"
	end

	if want == "zh" then
		-- 游戏中文版自带的手写体；加载不到时退回像素中文字体
		if tryLoad(Small.font, "font/teammeatfontextended10.fnt") then
			if not tryLoad(Big.font, "font/teammeatfontextended16bold.fnt") then Big = Small end
		elseif tryLoad(Small.font, "font/cjk/lanapixel.fnt") then
			Small.top, Small.h, Small.step = 1, 10, 12
			Big = Small
		else
			want = "en"
		end
	end
	if want == "en" then
		tryLoad(Small.font, "font/teammeatfont10.fnt")
		if not tryLoad(Big.font, "font/teammeatfont16bold.fnt") then Big = Small end
	end
	lang = want
end

local function T(key)
	local tbl = Names.Text[lang] or Names.Text.en
	return tbl[key] or Names.Text.en[key] or key
end
UI.Text = function(key)
	init()
	return T(key)
end
UI.Fonts = function()
	init()
	return Small, Big
end

----------------------------------------------------------------------
-- 绘制工具（坐标都是虚拟画布坐标，OX/OY 是画布左上角在屏幕上的位置）
----------------------------------------------------------------------

local OX, OY = 0, 0

local function loadSprite(path)
	local sprite = Sprite()
	sprite:Load(path, true)
	sprite:Play("Idle", true)
	return sprite
end

local pixel = loadSprite("gfx/runhistory_pixel.anm2")
local paper = loadSprite("gfx/runhistory_paper.anm2")
local cursor = loadSprite("gfx/runhistory_cursor.anm2")
UI.CursorSprite = cursor
local keys = loadSprite("gfx/runhistory_keys.anm2")
-- 游戏自带的属性栏图标和小地图房间图标
local statIcon = loadSprite("gfx/ui/hudstats2.anm2")
local pickupIcon = loadSprite("gfx/ui/hudpickups.anm2")
local bossIcon = loadSprite("gfx/runhistory_boss.anm2")
bossIcon.Scale = Vector(0.5, 0.5)
-- 游戏死亡画面里"致死者"用的敌人头像
local enemyIcon = loadSprite("gfx/runhistory_enemy.anm2")
enemyIcon.Scale = Vector(0.5, 0.5)
local BOSS_PORTRAITS, ENEMY_PORTRAITS = 147, 417
local devilIcon = Sprite()
devilIcon:Load("gfx/ui/minimap_icons.anm2", true)
devilIcon:Play("IconDevilRoom", true)
local angelIcon = Sprite()
angelIcon:Load("gfx/ui/minimap_icons.anm2", true)
angelIcon:Play("IconAngelRoom", true)

-- 墨水颜色（取自游戏菜单贴图）
local INK = KColor(0.21, 0.17, 0.17, 1)
local FADED = KColor(0.21, 0.17, 0.17, 0.5)
local RED = KColor(0.58, 0.10, 0.10, 1)
local GREEN = KColor(0.13, 0.40, 0.16, 1)
local BLUE = KColor(0.16, 0.27, 0.52, 1)
UI.Ink = INK

local function rect(x, y, w, h, r, g, b, a)
	if w <= 0 or h <= 0 then return end
	pixel.Scale = Vector(w / 16, h / 16)
	pixel.Color = Color(r, g, b, a, 0, 0, 0)
	pixel:Render(Vector(OX + x, OY + y), Vector.Zero, Vector.Zero)
end

-- 纸上的墨线
local function rule(x, y, w, alpha)
	rect(x, y, w, 1, 0.21, 0.17, 0.17, alpha or 0.35)
end

local function vrule(x, y, h, alpha)
	rect(x, y, 1, h, 0.21, 0.17, 0.17, alpha or 0.35)
end

local function textWidth(F, str)
	return F.font:GetStringWidthUTF8(str)
end

-- y 是字形顶端的位置
local function text(F, str, x, y, color)
	F.font:DrawStringScaledUTF8(str, OX + x, OY + y - F.top, 1, 1, color or INK, 0, false)
end

local function textRight(F, str, x, y, color)
	text(F, str, x - textWidth(F, str), y, color)
end

-- 文字超出宽度时截断（按 UTF-8 字符截断，避免把汉字切成两半）
local function fit(F, str, maxWidth)
	if textWidth(F, str) <= maxWidth then return str end
	local chars = {}
	for ch in string.gmatch(str, "[\1-\127\194-\244][\128-\191]*") do
		chars[#chars + 1] = ch
	end
	while #chars > 1 do
		chars[#chars] = nil
		local candidate = table.concat(chars) .. ".."
		if textWidth(F, candidate) <= maxWidth then return candidate end
	end
	return str
end

-- 道具图标（每个道具一个 Sprite，用到时才创建）
local ICON = 16
local iconCache = {}

local function getIcon(id)
	local sprite = iconCache[id]
	if sprite == nil then
		sprite = Sprite()
		sprite:Load("gfx/runhistory_icon.anm2", false)
		local ok, item = pcall(function() return Isaac.GetItemConfig():GetCollectible(id) end)
		if ok and item ~= nil and item.GfxFileName ~= nil and item.GfxFileName ~= "" then
			sprite:ReplaceSpritesheet(0, item.GfxFileName)
		end
		sprite:LoadGraphics()
		sprite:Play("Idle", true)
		sprite.Scale = Vector(0.5, 0.5)
		iconCache[id] = sprite
	end
	return sprite
end

-- 饰品图标（和道具图标同样大小；金饰品染成金色）
local trinketCache = {}
local TRINKET_GOLDEN = 32768

local function getTrinketIcon(id)
	local base = id % TRINKET_GOLDEN
	local sprite = trinketCache[base]
	if sprite == nil then
		sprite = Sprite()
		sprite:Load("gfx/runhistory_icon.anm2", false)
		local ok, trinket = pcall(function() return Isaac.GetItemConfig():GetTrinket(base) end)
		if ok and trinket ~= nil and trinket.GfxFileName ~= nil and trinket.GfxFileName ~= "" then
			sprite:ReplaceSpritesheet(0, trinket.GfxFileName)
		end
		sprite:LoadGraphics()
		sprite:Play("Idle", true)
		sprite.Scale = Vector(0.5, 0.5)
		trinketCache[base] = sprite
	end
	return sprite
end

local function iconRows(count, width)
	local cols = math.max(1, math.floor(width / ICON))
	return math.max(1, math.ceil(count / cols))
end

-- 在 (x, y) 开始、宽 width 的区域里画一排排道具图标，最多 maxRows 行，放不下的显示 "+N"
local function drawIcons(items, x, y, width, maxRows)
	local count = #items
	if count == 0 then
		text(Small, T("noItems"), x + 2, y + (ICON - Small.h) / 2, FADED)
		return
	end
	local cols = math.max(1, math.floor(width / ICON))
	local capacity = cols * math.max(1, maxRows)
	local shown = count
	if count > capacity then
		shown = math.max(0, capacity - 2) -- 留两格位置显示 "+N"
	end
	for i = 1, shown do
		local col = (i - 1) % cols
		local row = (i - 1) // cols
		getIcon(items[i]):Render(Vector(OX + x + col * ICON + 8, OY + y + row * ICON + 8), Vector.Zero, Vector.Zero)
	end
	if shown < count then
		local col = shown % cols
		local row = shown // cols
		text(Small, string.format(T("more"), count - shown), x + col * ICON + 2, y + row * ICON + (ICON - Small.h) / 2, FADED)
	end
end

-- 菜单箭头：箭头本体在贴图里偏移 (4,4)，大小约 12x15。(x, cy) = 箭头左边缘 / 垂直中心
local function drawCursor(x, cy)
	cursor:Render(Vector(OX + x - 4, OY + cy - 11), Vector.Zero, Vector.Zero)
end

----------------------------------------------------------------------
-- 对局信息 -> 文字
----------------------------------------------------------------------

local function getEntries()
	local list = {}
	if mod.Data.current ~= nil then
		list[#list + 1] = { run = mod.Data.current, running = true }
	end
	for _, run in ipairs(mod.Data.runs) do
		list[#list + 1] = { run = run, running = false }
	end
	return list
end

local function playerName(run)
	local tbl = Names.Players[lang] or Names.Players.en
	return tbl[run.player] or run.playerName or "?"
end

local function resultInfo(entry)
	if entry.running then return T("running"), BLUE end
	local result = entry.run.result
	if result == "win" then return T("win"), GREEN end
	if result == "death" then return T("death"), RED end
	return T("quit"), FADED
end

local function modeText(run)
	if (run.challenge or 0) > 0 then
		return T("challenge") .. tostring(run.challenge)
	end
	local difficulty = run.difficulty or 0
	if difficulty == 1 then return T("hard") end
	if difficulty == 2 then return T("greed") end
	if difficulty == 3 then return T("greedier") end
	return T("normal")
end

local function timeText(run)
	local seconds = (run.time or 0) // 30
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

local function floorName(run, floor)
	return Names.Stage(floor, run.greed, lang)
end

local function lastFloorName(run)
	local floor = run.floors[#run.floors]
	if floor == nil then return "?" end
	return floorName(run, floor)
end

local function bossName(boss)
	if type(boss) == "number" then
		local tbl = Names.Bosses[lang] or Names.Bosses.en
		return tbl[boss] or Names.Bosses.en[boss] or (T("unknownBoss") .. " #" .. tostring(boss))
	end
	-- 模组 Boss：存的是 "类型.变种"，有 EID 的话借用它的实体名称表
	if EID ~= nil and type(EID.XMLEntityNames) == "table" and EID.XMLEntityNames[boss] ~= nil then
		return EID.XMLEntityNames[boss]
	end
	return T("unknownBoss")
end

local function lastBossName(run)
	for i = #run.floors, 1, -1 do
		local bosses = run.floors[i].bosses
		if bosses ~= nil and #bosses > 0 then
			return bossName(bosses[#bosses])
		end
	end
	return T("noBoss")
end

local function finalItems(entry)
	if entry.running then
		return mod.BuildFinalItems(entry.run)
	end
	return entry.run.finalItems or {}
end

local function keyName()
	local key = mod.Config.ToggleKey
	for name, value in pairs(Keyboard) do
		if value == key then
			return (string.gsub(name, "^KEY_", ""))
		end
	end
	return "?"
end

----------------------------------------------------------------------
-- 操作提示：键帽贴图 + 说明文字
----------------------------------------------------------------------

local KEY_H = 13
local ARROW_FRAMES = { up = 3, down = 4, left = 5, right = 6 }

local function keyWidth(key)
	if ARROW_FRAMES[key] ~= nil then return 13 end
	return math.max(13, textWidth(Small, key) + 7)
end

-- 画一个键帽，(x, y) 是左上角。key 是 "up"/"down"/"left"/"right" 或键名文字（如 "ESC"）
local function drawKey(key, x, y)
	local width = keyWidth(key)
	keys:SetFrame("Idle", 0)
	keys.Scale = Vector(1, 1)
	keys:Render(Vector(OX + x, OY + y), Vector.Zero, Vector.Zero)
	keys:SetFrame("Idle", 1)
	keys.Scale = Vector((width - 6) / 4, 1)
	keys:Render(Vector(OX + x + 3, OY + y), Vector.Zero, Vector.Zero)
	keys:SetFrame("Idle", 2)
	keys.Scale = Vector(1, 1)
	keys:Render(Vector(OX + x + width - 3, OY + y), Vector.Zero, Vector.Zero)
	local arrow = ARROW_FRAMES[key]
	if arrow ~= nil then
		keys:SetFrame("Idle", arrow)
		keys:Render(Vector(OX + x + 3, OY + y + 2), Vector.Zero, Vector.Zero)
	else
		text(Small, key, x + (width - textWidth(Small, key)) / 2, y + 2, INK)
	end
end

-- 提示内容：{ { keys = {...}, label = "..." }, ... }，整体右对齐到 (right, y)，y 是文字顶端。返回最左边的 x
local function drawHints(hints, right, y)
	local total = 0
	for i, hint in ipairs(hints) do
		for _, key in ipairs(hint.keys) do total = total + keyWidth(key) + 1 end
		total = total + 3 + textWidth(Small, hint.label)
		if i < #hints then total = total + 10 end
	end
	local x = right - total
	local left = x
	for _, hint in ipairs(hints) do
		for _, key in ipairs(hint.keys) do
			drawKey(key, x, y - 2)
			x = x + keyWidth(key) + 1
		end
		x = x + 3
		text(Small, hint.label, x, y, FADED)
		x = x + textWidth(Small, hint.label) + 10
	end
	return left
end

local function hintsFor(view)
	local menu = UI.mode == "menu"
	-- 主菜单里用游戏自己的菜单键（方向键 / 空格 / ESC）；对局内 ESC 会暂停游戏，所以用退格键和开关键
	local confirmKey = "SPACE"
	local backKey = menu and "ESC" or "BKSP"
	if view == "list" then
		return {
			{ keys = { "up", "down" }, label = T("hSelect") },
			{ keys = { confirmKey }, label = T("hDetails") },
			{ keys = { menu and "ESC" or keyName() }, label = T("hClose") },
		}
	end
	if view == "items" then
		return {
			{ keys = { "up", "down", "left", "right" }, label = T("hSelect") },
			{ keys = { backKey }, label = T("hBack") },
		}
	end
	return {
		{ keys = { "up", "down" }, label = T("hScroll") },
		{ keys = { "left", "right" }, label = T("hSwitch") },
		{ keys = { confirmKey }, label = T("hItems") },
		{ keys = { backKey }, label = T("hBack") },
	}
end

-- 属性图标（游戏自带的属性栏图标）：帧序号 = 移速、射速、伤害、射程、弹速、运气
local STAT_ORDER = { "speed", "tears", "damage", "range", "shotSpeed", "luck" }

-- 金币 / 炸弹 / 钥匙（游戏自带的拾取物图标，帧序号 0 = 金币，1 = 钥匙，2 = 炸弹）
local PICKUP_ORDER = { { "coins", 0 }, { "bombs", 2 }, { "keys", 1 } }

-- 六项属性，两行、每行三个
local function drawStats(stats, x, y, width)
	local cellW = width // 3
	for i, key in ipairs(STAT_ORDER) do
		local col = (i - 1) % 3
		local row = (i - 1) // 3
		local cx, cy = x + col * cellW, y + row * 15
		statIcon:SetFrame("Idle", i - 1)
		statIcon:Render(Vector(OX + cx, OY + cy), Vector.Zero, Vector.Zero)
		text(Small, string.format("%.2f", tonumber(stats[key]) or 0), cx + 18, cy + 3, INK)
	end
end

-- 楼层用时：帧 -> "分:秒"
local function shortTime(frames)
	local seconds = (tonumber(frames) or 0) // 30
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Boss 小图标（游戏死亡画面用的那张图，每格 64x48，缩小一半显示）
local BOSS_ICON_W, BOSS_ICON_H = 32, 24

local function drawBossIcon(boss, x, y)
	local frame = type(boss) == "number" and mod.BossIcons and mod.BossIcons[boss]
	if frame == nil or frame == false then return false end
	bossIcon:SetFrame("Idle", frame)
	bossIcon:Render(Vector(OX + x, OY + y), Vector.Zero, Vector.Zero)
	return true
end

-- 死因：返回 显示名, 头像（{ sprite, 帧 } 或 nil）
local function killerInfo(killer)
	if type(killer) ~= "string" or killer == "" then return nil end
	if killer:sub(1, 1) == "@" then
		return T("k_" .. killer:sub(2)), nil
	end
	local entities = mod.NamesData and mod.NamesData.entities or {}
	local data = entities[killer] or entities[(killer:match("^(%d+)%.") or "") .. ".0"]
	if data ~= nil then
		local name = (lang == "zh") and data[2] or data[1]
		local portrait = tonumber(data[3]) or -1
		local icon
		if portrait >= 0 then
			-- 和死亡画面一样：Boss 用 Boss 头像表，其余（包括 Boss 发射出来的东西）用敌人头像表
			if data[4] == 1 and portrait < BOSS_PORTRAITS then
				icon = { bossIcon, portrait }
			elseif portrait < ENEMY_PORTRAITS then
				icon = { enemyIcon, portrait }
			end
		end
		return name, icon
	end
	-- 其他 mod 的敌人：有 EID 的话借用它的实体名称表
	if EID ~= nil and type(EID.XMLEntityNames) == "table" and EID.XMLEntityNames[killer] ~= nil then
		return EID.XMLEntityNames[killer], nil
	end
	return T("unknownEnemy"), nil
end

-- 道具名称和拾取说明（官方中英文；其他 mod 的道具用道具配置里的名字）
local function itemText(id)
	local pair = Names.Items and Names.Items[id]
	if pair ~= nil then
		if lang == "zh" then return pair[2], pair[4] or "" end
		return pair[1], pair[3] or ""
	end
	local ok, config = pcall(function() return Isaac.GetItemConfig():GetCollectible(id) end)
	if ok and config ~= nil and type(config.Name) == "string" and config.Name ~= "" and config.Name:sub(1, 1) ~= "#" then
		local desc = type(config.Description) == "string" and config.Description or ""
		if desc:sub(1, 1) == "#" then desc = "" end
		return config.Name, desc
	end
	return "#" .. tostring(id), ""
end

-- 最终主动道具和饰品：右对齐画在 (right, y) 开始的一行（高 16），最多占 maxW 宽。
-- 吞下的饰品画成半透明。宽度不够时先去掉文字标签，再去掉多出来的图标。返回是否画了东西
local LOADOUT_GAP = 8

local function loadoutGroups(run)
	local groups = {}
	if type(run.actives) == "table" and #run.actives > 0 then
		local icons = {}
		for _, id in ipairs(run.actives) do icons[#icons + 1] = { id = id } end
		groups[#groups + 1] = { label = T("actives"), icons = icons }
	end
	local trinketIcons = {}
	for _, id in ipairs(type(run.trinkets) == "table" and run.trinkets or {}) do
		trinketIcons[#trinketIcons + 1] = { id = id, trinket = true }
	end
	for _, id in ipairs(type(run.smelted) == "table" and run.smelted or {}) do
		trinketIcons[#trinketIcons + 1] = { id = id, trinket = true, smelted = true }
	end
	if #trinketIcons > 0 then
		groups[#groups + 1] = { label = T("trinkets"), icons = trinketIcons }
	end
	return groups
end

local function groupsWidth(groups, withLabels)
	if #groups == 0 then return 0 end
	local total = (#groups - 1) * LOADOUT_GAP
	for _, group in ipairs(groups) do
		total = total + #group.icons * ICON
		if withLabels then total = total + textWidth(Small, group.label) + 2 end
	end
	return total
end

local function loadoutWidth(run, withLabels)
	return groupsWidth(loadoutGroups(run), withLabels)
end

local function drawLoadout(run, right, y, maxW)
	local groups = loadoutGroups(run)
	if #groups == 0 then return false end
	local GAP = LOADOUT_GAP
	local function width(withLabels) return groupsWidth(groups, withLabels) end
	local withLabels = width(true) <= maxW
	-- 实在放不下：从后往前去掉图标
	local budget = math.max(0, maxW - (#groups - 1) * GAP)
	if not withLabels and width(false) > maxW then
		local keep = budget // ICON
		for _, group in ipairs(groups) do
			while #group.icons > math.max(0, keep) do table.remove(group.icons) end
			keep = keep - #group.icons
		end
	end

	local x = right - width(withLabels)
	for _, group in ipairs(groups) do
		if withLabels then
			text(Small, group.label, x, y + (ICON - Small.h) / 2, FADED)
			x = x + textWidth(Small, group.label) + 2
		end
		for _, icon in ipairs(group.icons) do
			local sprite
			if icon.trinket then
				sprite = getTrinketIcon(icon.id)
				local alpha = icon.smelted and 0.5 or 1
				if icon.id >= TRINKET_GOLDEN then
					sprite.Color = Color(1, 0.9, 0.45, alpha, 0.25, 0.18, 0)
				else
					sprite.Color = Color(1, 1, 1, alpha, 0, 0, 0)
				end
			else
				sprite = getIcon(icon.id)
			end
			sprite:Render(Vector(OX + x + 8, OY + y + 8), Vector.Zero, Vector.Zero)
			x = x + ICON
		end
		x = x + GAP
	end
	return true
end

-- 恶魔房 / 天使房在本层的状态：返回 { { sprite, text, color }, ... }
local function dealLines(floor)
	local lines = {}
	local deal = floor.deal
	if type(deal) ~= "table" then return lines end
	for _, kind in ipairs({ "devil", "angel" }) do
		local level = tonumber(deal[kind]) or 0
		if level > 0 then
			lines[#lines + 1] = {
				sprite = (kind == "devil") and devilIcon or angelIcon,
				text = T(level >= 2 and "dealEntered" or "dealSkipped"),
				color = (level < 2) and FADED or ((kind == "devil") and RED or BLUE),
			}
		end
	end
	return lines
end

local function playSound(id)
	if id ~= nil and SFXManager ~= nil then
		SFXManager():Play(id, 1, 0, false, 1)
	end
end

----------------------------------------------------------------------
-- 页面布局（纸张贴图画在 (40,12)，可写区域大约是 x 60..432，y 28..234）
----------------------------------------------------------------------

local X0, X1 = 60, 432
local Y0 = 30
local CONTENT_BOTTOM = 217
local HINT_Y = 222

local function drawPaper()
	paper:Render(Vector(OX + 40, OY + 12), Vector.Zero, Vector.Zero)
end

local function drawList(entries)
	local maxRuns = tonumber(mod.Config.MaxRuns) or 20

	text(Big, T("title"), X0, Y0, INK)
	textRight(Small, string.format("%d / %d", #mod.Data.runs, maxRuns), X1, Y0 + 5, FADED)
	rule(X0, Y0 + 21, X1 - X0)
	drawHints(hintsFor("list"), X1, HINT_Y)

	local top = Y0 + 26
	if #entries == 0 then
		text(Small, T("empty"), X0 + 4, top + 8, INK)
		return
	end

	-- 左侧：对局列表（选中的一行前面画菜单箭头）
	local lx, lw = X0 + 14, 140
	local rowH = Small.step * 2 + 2
	local visible = math.max(1, (CONTENT_BOTTOM - top) // rowH)
	if UI.sel < UI.listTop then UI.listTop = UI.sel end
	if UI.sel > UI.listTop + visible - 1 then UI.listTop = UI.sel - visible + 1 end
	if UI.listTop > math.max(1, #entries - visible + 1) then UI.listTop = math.max(1, #entries - visible + 1) end

	for i = UI.listTop, math.min(#entries, UI.listTop + visible - 1) do
		local entry = entries[i]
		local run = entry.run
		local y = top + (i - UI.listTop) * rowH
		if i == UI.sel then
			drawCursor(X0 - 1, y + rowH / 2 - 1)
		end
		local resultStr, resultColor = resultInfo(entry)
		local resultW = textWidth(Small, resultStr)
		text(Small, fit(Small, playerName(run), lw - resultW - 8), lx, y + 1, INK)
		textRight(Small, resultStr, lx + lw, y + 1, resultColor)
		local seedStr = run.seed or ""
		text(Small, seedStr, lx, y + 1 + Small.step, FADED)
		textRight(Small, fit(Small, lastFloorName(run), lw - textWidth(Small, seedStr) - 8), lx + lw, y + 1 + Small.step, FADED)
		if i < math.min(#entries, UI.listTop + visible - 1) then
			rule(lx, y + rowH - 1, lw, 0.12)
		end
	end

	-- 滚动条
	if #entries > visible then
		local trackH = visible * rowH - 2
		local barH = math.max(8, trackH * visible / #entries)
		local barY = top + (trackH - barH) * (UI.listTop - 1) / (#entries - visible)
		rect(lx + lw + 4, top, 1, trackH, 0.21, 0.17, 0.17, 0.15)
		rect(lx + lw + 3, barY, 3, barH, 0.21, 0.17, 0.17, 0.6)
	end

	-- 右侧：选中对局的概要
	local entry = entries[UI.sel]
	local run = entry.run
	local rx = lx + lw + 14
	local rw = X1 - rx
	local y = top + 1
	local resultStr, resultColor = resultInfo(entry)
	vrule(rx - 6, top, CONTENT_BOTTOM - top, 0.2)

	local function line(label, value, color)
		local labelStr = label .. ": "
		local labelW = textWidth(Small, labelStr)
		text(Small, labelStr, rx, y, FADED)
		text(Small, fit(Small, value, rw - labelW), rx + labelW, y, color or INK)
		y = y + Small.step
	end

	line(T("character"), playerName(run) .. " (" .. modeText(run) .. ")")
	line(T("seed"), run.seed or "?")
	textRight(Small, T("time") .. " " .. timeText(run), X1, y - Small.step, FADED)
	-- 结果和到达的楼层写在同一行
	local resultLabel = T("result") .. ": "
	local labelW = textWidth(Small, resultLabel)
	text(Small, resultLabel, rx, y, FADED)
	text(Small, resultStr, rx + labelW, y, resultColor)
	local floorX = rx + labelW + textWidth(Small, resultStr) + 6
	text(Small, fit(Small, lastFloorName(run) .. (run.partial and T("partial") or ""), X1 - floorX), floorX, y, INK)
	y = y + Small.step
	line(T("finalBoss"), lastBossName(run), RED)
	if run.date ~= nil and run.date ~= "" then
		textRight(Small, run.date, X1, y - Small.step, FADED)
	end

	-- 死因（只有死亡的对局才有；旧版本记录的对局没有这项数据）
	if run.result == "death" and run.killer ~= nil then
		local killerName, icon = killerInfo(run.killer)
		if killerName ~= nil then
			local labelStr = T("killedBy") .. ": "
			local kx = rx + textWidth(Small, labelStr)
			if icon ~= nil then y = y + 3 end
			text(Small, labelStr, rx, y, FADED)
			if icon ~= nil then
				icon[1]:SetFrame("Idle", icon[2])
				icon[1]:Render(Vector(OX + kx - 2, OY + y - 7), Vector.Zero, Vector.Zero)
				kx = kx + BOSS_ICON_W
			end
			text(Small, fit(Small, killerName, X1 - kx), kx, y, RED)
			y = y + Small.step + (icon ~= nil and 4 or 0)
		end
	end

	-- 最终属性（旧版本记录的对局没有这项数据）
	if type(run.stats) == "table" then
		y = y + 2
		drawStats(run.stats, rx, y, rw)
		y = y + 30
	end

	y = y + 2
	rule(rx, y, rw, 0.25)
	y = y + 4
	local items = finalItems(entry)
	local headerLabel = entry.running and T("currentItems") or T("finalItems")
	local header = headerLabel .. " (" .. tostring(#items) .. ")"
	-- 标题同一行的右边：最终的主动道具和饰品（旧版本记录的对局没有这项数据）。
	-- 放不下"主动 / 饰品"文字时，标题先省掉道具数量
	local needW = loadoutWidth(run, true)
	if needW > rw - textWidth(Small, header) - 8 then header = headerLabel end
	if needW > rw - textWidth(Small, header) - 8 then
		-- 还是放不下（英文标签更宽、饰品很多）：主动和饰品单独占一行，标题照常写在下面
		drawLoadout(run, rx + math.min(needW, rw), y, rw)
		y = y + ICON + 2
		header = headerLabel .. " (" .. tostring(#items) .. ")"
		text(Small, header, rx, y, FADED)
		y = y + Small.step
	elseif drawLoadout(run, X1, y, rw - textWidth(Small, header) - 8) then
		text(Small, header, rx, y + (ICON - Small.h) / 2, FADED)
		y = y + ICON
	else
		text(Small, header, rx, y, FADED)
		y = y + Small.step
	end
	drawIcons(items, rx, y, rw, math.max(1, (CONTENT_BOTTOM - y) // ICON))
end

local function drawDetail(entries)
	local entry = entries[UI.sel]
	local run = entry.run
	local resultStr, resultColor = resultInfo(entry)

	-- 标题两行：角色/结果，种子/最终 Boss/用时
	local name = playerName(run)
	text(Big, name, X0, Y0, INK)
	local x = X0 + textWidth(Big, name) + 6
	local modeStr = "(" .. modeText(run) .. ")  "
	text(Small, modeStr, x, Y0 + 5, FADED)
	text(Small, resultStr, x + textWidth(Small, modeStr), Y0 + 5, resultColor)
	textRight(Small, string.format("%d / %d", UI.sel, #entries), X1, Y0 + 5, FADED)

	local y = Y0 + 21
	local seedLabel = T("seed") .. ": "
	text(Small, seedLabel, X0, y, FADED)
	text(Small, run.seed or "?", X0 + textWidth(Small, seedLabel), y, INK)
	local timeStr = T("time") .. " " .. timeText(run)
	textRight(Small, timeStr, X1, y, FADED)
	local bossLabel = T("finalBoss") .. ": "
	local bossStr = lastBossName(run)
	local bx = X1 - textWidth(Small, timeStr) - 12 - textWidth(Small, bossStr)
	text(Small, bossStr, bx, y, RED)
	textRight(Small, bossLabel, bx, y, FADED)
	local hintLeft = drawHints(hintsFor(UI.itemMode and "items" or "detail"), X1, HINT_Y)

	-- 三列：楼层 | 获得道具 | 击败 Boss
	local floorX, floorW = X0, 88
	local bossW = 98
	local bossX = X1 - bossW
	-- 道具右边三列：本层结束时的金币 / 炸弹 / 钥匙
	local PICKUP_W = 20
	local pickupX = bossX - 6 - PICKUP_W * 3
	local itemX = floorX + floorW + 4
	local itemW = pickupX - itemX - 4

	y = y + Small.step + 2
	rule(X0, y, X1 - X0)
	y = y + 3
	text(Small, T("floorHeader"), floorX, y, FADED)
	text(Small, T("itemHeader"), itemX, y, FADED)
	text(Small, T("bossHeader"), bossX, y, FADED)
	for i, entry in ipairs(PICKUP_ORDER) do
		pickupIcon:SetFrame("Idle", entry[2])
		pickupIcon:Render(Vector(OX + pickupX + (i - 1) * PICKUP_W + (PICKUP_W - 16) / 2, OY + y - 4), Vector.Zero, Vector.Zero)
	end
	local top = y + Small.step

	-- 组装所有要显示的块：初始道具、每一层、最终道具
	local blocks = {}
	if run.startItems ~= nil and #run.startItems > 0 then
		blocks[#blocks + 1] = { label = T("startItems"), items = run.startItems, color = BLUE }
	end
	for _, floor in ipairs(run.floors) do
		blocks[#blocks + 1] = {
			label = floorName(run, floor),
			items = floor.items or {},
			bosses = floor.bosses or {},
			deals = dealLines(floor),
			time = (floor.time ~= nil) and shortTime(floor.time) or nil,
			floor = floor,
			color = INK,
		}
	end
	local final = finalItems(entry)
	blocks[#blocks + 1] = {
		label = entry.running and T("currentItems") or T("finalItems"),
		note = "x " .. tostring(#final),
		items = final,
		color = GREEN,
	}

	local maxRows = math.max(1, (CONTENT_BOTTOM - top - 3) // ICON)
	for _, block in ipairs(blocks) do
		local rows = math.min(maxRows, iconRows(#block.items, itemW))
		local bossLines = block.bosses and #block.bosses or 0
		-- 楼层名下面的附加行：本层用时和恶魔房 / 天使房排在同一行，放不下再换行
		local lines = {}
		local lineW = 0
		local function add(item, width)
			if #lines == 0 or lineW + width > floorW then
				lines[#lines + 1] = {}
				lineW = 0
			end
			item.x = lineW
			table.insert(lines[#lines], item)
			lineW = lineW + width
		end
		if block.time ~= nil then
			add({ text = block.time, color = FADED }, textWidth(Small, block.time) + 8)
		end
		for _, deal in ipairs(block.deals or {}) do
			add(deal, 11 + textWidth(Small, deal.text) + 6)
		end
		block.lines = lines
		block.rows = rows
		block.height = math.max(rows * ICON, bossLines * BOSS_ICON_H, 13 + #lines * 11, ICON) + 3
	end

	-- 限制滚动范围：最后一块必须能完整显示
	local maxTop = #blocks
	local used = blocks[#blocks].height
	while maxTop > 1 and used + blocks[maxTop - 1].height <= CONTENT_BOTTOM - top do
		maxTop = maxTop - 1
		used = used + blocks[maxTop].height
	end
	-- 每块里能选中的道具数（和 drawIcons 一样：放不下时最后两格显示 "+N"）
	local cols = math.max(1, math.floor(itemW / ICON))
	local shown = {}
	for b, block in ipairs(blocks) do
		local capacity = cols * math.max(1, block.rows)
		local count = #block.items
		shown[b] = (count > capacity) and math.max(0, capacity - 2) or count
	end
	UI.layout = { cols = cols, shown = shown }

	-- 道具选择模式：保证选中的道具所在的块在屏幕内
	local sel = UI.itemMode and UI.itemSel or nil
	if sel ~= nil then
		if sel.b > #blocks or (shown[sel.b] or 0) == 0 then
			UI.itemMode, sel = false, nil
		else
			sel.k = math.max(1, math.min(sel.k, shown[sel.b]))
			if sel.b < UI.detailTop then UI.detailTop = sel.b end
			local function spanHeight()
				local h = 0
				for i = UI.detailTop, sel.b do h = h + blocks[i].height end
				return h
			end
			while UI.detailTop < sel.b and spanHeight() > CONTENT_BOTTOM - top + 1 do
				UI.detailTop = UI.detailTop + 1
			end
		end
	end
	if UI.detailTop > maxTop and sel == nil then UI.detailTop = maxTop end
	if UI.detailTop < 1 then UI.detailTop = 1 end

	-- 道具选择模式：底部左边显示选中道具的名字和拾取说明
	if sel ~= nil then
		local name, desc = itemText(blocks[sel.b].items[sel.k])
		local width = hintLeft - X0 - 10
		text(Small, fit(Small, name, width), X0, HINT_Y, INK)
		local nameW = textWidth(Small, name)
		if desc ~= "" and nameW + 20 < width then
			text(Small, fit(Small, desc, width - nameW - 8), X0 + nameW + 8, HINT_Y, FADED)
		end
	end

	y = top
	for i = UI.detailTop, #blocks do
		local block = blocks[i]
		if y + block.height > CONTENT_BOTTOM + 1 then break end
		local textY = y + (ICON - Small.h) / 2
		text(Small, fit(Small, block.label, floorW), floorX, textY, block.color)
		if block.note ~= nil and block.rows > 1 then
			text(Small, block.note, floorX, textY + Small.step, FADED)
		end
		-- 楼层名下面：本层用时，以及恶魔房 / 天使房的状态（小地图图标 + 是否进入）
		for j, line in ipairs(block.lines or {}) do
			local lineY = textY + j * 11
			for _, item in ipairs(line) do
				local ix = floorX + item.x
				if item.sprite ~= nil then
					item.sprite:Render(Vector(OX + ix - 3, OY + lineY - 3), Vector.Zero, Vector.Zero)
					ix = ix + 11
				end
				text(Small, item.text, ix, lineY, item.color)
			end
		end
		drawIcons(block.items, itemX, y, itemW, block.rows)
		-- 选中的道具：画一个墨水方框
		if sel ~= nil and sel.b == i then
			local bx0 = itemX + ((sel.k - 1) % cols) * ICON - 1
			local by0 = y + ((sel.k - 1) // cols) * ICON - 1
			rect(bx0, by0, ICON + 2, 1, 0.21, 0.17, 0.17, 0.9)
			rect(bx0, by0 + ICON + 1, ICON + 2, 1, 0.21, 0.17, 0.17, 0.9)
			rect(bx0, by0, 1, ICON + 2, 0.21, 0.17, 0.17, 0.9)
			rect(bx0 + ICON + 1, by0, 1, ICON + 2, 0.21, 0.17, 0.17, 0.9)
		end
		-- 本层结束时的金币 / 炸弹 / 钥匙（旧记录没有这项数据）
		if block.floor ~= nil and block.floor.coins ~= nil then
			for j, entry in ipairs(PICKUP_ORDER) do
				local value = tostring(math.floor(tonumber(block.floor[entry[1]]) or 0))
				text(Small, value, pickupX + (j - 1) * PICKUP_W + (PICKUP_W - textWidth(Small, value)) / 2, textY, INK)
			end
		end
		if block.bosses ~= nil then
			if #block.bosses == 0 then
				text(Small, T("noItems"), bossX, textY, FADED)
			else
				-- 每个 Boss 一行：小图标 + 名字
				for j, boss in ipairs(block.bosses) do
					local by = y + (j - 1) * BOSS_ICON_H
					local nameX = bossX
					if drawBossIcon(boss, bossX - 2, by - 3) then nameX = bossX + BOSS_ICON_W end
					text(Small, fit(Small, bossName(boss), bossX + bossW - nameX), nameX, by + (BOSS_ICON_H - 6 - Small.h) / 2, RED)
				end
			end
		end
		y = y + block.height
		rule(X0, y - 2, X1 - X0, 0.12)
	end

	-- 滚动条
	if maxTop > 1 then
		local trackH = CONTENT_BOTTOM - top
		local barH = math.max(8, trackH / maxTop)
		local barY = top + (trackH - barH) * (UI.detailTop - 1) / (maxTop - 1)
		rect(X1 + 4, top, 1, trackH, 0.21, 0.17, 0.17, 0.15)
		rect(X1 + 3, barY, 3, barH, 0.21, 0.17, 0.17, 0.6)
	end
end

----------------------------------------------------------------------
-- 打开 / 关闭 / 每帧更新
----------------------------------------------------------------------

-- 道具选择模式：在详情页里用方向键逐个选道具，底部显示名字
UI.itemMode = false
UI.itemSel = nil
UI.layout = nil

local function enterItemMode()
	local layout = UI.layout
	if layout == nil then return end
	-- 从当前屏幕上第一个有道具的块开始
	local first
	for b = UI.detailTop, #layout.shown do
		if layout.shown[b] > 0 then first = b break end
	end
	if first == nil then
		for b = 1, #layout.shown do
			if layout.shown[b] > 0 then first = b break end
		end
	end
	if first == nil then return end
	UI.itemMode = true
	UI.itemSel = { b = first, k = 1 }
	playSound(SoundEffect.SOUND_MENU_SCROLL)
end

local function itemModeInput(input)
	local layout, sel = UI.layout, UI.itemSel
	if layout == nil or sel == nil then
		UI.itemMode = false
		return
	end
	if input("back", false) or input("confirm", false) then
		UI.itemMode = false
		playSound(SoundEffect.SOUND_MENU_SCROLL)
		return
	end
	local cols, shown = layout.cols, layout.shown
	local function count(b) return shown[b] or 0 end
	local function prevBlock(b)
		for i = b - 1, 1, -1 do if count(i) > 0 then return i end end
	end
	local function nextBlock(b)
		for i = b + 1, #shown do if count(i) > 0 then return i end end
	end
	local oldB, oldK = sel.b, sel.k
	local col = (sel.k - 1) % cols
	if input("left", true) then
		if sel.k > 1 then
			sel.k = sel.k - 1
		else
			local p = prevBlock(sel.b)
			if p then sel.b, sel.k = p, count(p) end
		end
	elseif input("right", true) then
		if sel.k < count(sel.b) then
			sel.k = sel.k + 1
		else
			local n = nextBlock(sel.b)
			if n then sel.b, sel.k = n, 1 end
		end
	elseif input("up", true) then
		if sel.k - cols >= 1 then
			sel.k = sel.k - cols
		else
			local p = prevBlock(sel.b)
			if p then
				local lastRowStart = ((count(p) - 1) // cols) * cols
				sel.b, sel.k = p, math.min(count(p), lastRowStart + col + 1)
			end
		end
	elseif input("down", true) then
		if (sel.k - 1) // cols < (count(sel.b) - 1) // cols then
			sel.k = math.min(count(sel.b), sel.k + cols)
		else
			local n = nextBlock(sel.b)
			if n then sel.b, sel.k = n, math.min(count(n), col + 1) end
		end
	end
	if sel.b ~= oldB or sel.k ~= oldK then
		playSound(SoundEffect.SOUND_MENU_SCROLL)
	end
end

function UI.Open(mode)
	init()
	UI.mode = mode or "run"
	UI.open = true
	UI.closing = false
	UI.anim = 0
	UI.view = "list"
	UI.itemMode = false
	UI.sel = 1
	UI.listTop = 1
	UI.detailTop = 1
	playSound(SoundEffect.SOUND_PAPER_IN)
end

-- 播放收起动画后关闭
function UI.Close()
	if UI.open and not UI.closing then
		UI.closing = true
		playSound(SoundEffect.SOUND_PAPER_OUT)
	end
end

-- 立即关闭（切换场景时用）
function UI.ForceClose()
	UI.open = false
	UI.itemMode = false
	UI.closing = false
	UI.anim = 0
end

function UI.Toggle()
	if UI.open and not UI.closing then UI.Close() else UI.Open("run") end
end

-- 处理输入并绘制一帧。
--   ox, oy：虚拟画布左上角的屏幕坐标
--   input(name, allowRepeat)：name 为 "up" / "down" / "left" / "right" / "confirm" / "back"
-- 返回页面是否仍然可见。
function UI.Frame(ox, oy, input)
	if not UI.open then return false end
	init()

	-- 展开 / 收起动画
	if UI.closing then
		UI.anim = UI.anim - 0.125
		if UI.anim <= 0 then
			UI.ForceClose()
			return false
		end
	elseif UI.anim < 1 then
		UI.anim = math.min(1, UI.anim + 0.125)
	end

	local entries = getEntries()
	if UI.sel > #entries then UI.sel = math.max(1, #entries) end
	if UI.sel < 1 then UI.sel = 1 end

	if UI.anim >= 1 and not UI.closing then
		if #entries == 0 then
			UI.view = "list"
			if input("back", false) or input("confirm", false) then UI.Close() end
		elseif UI.view == "list" then
			if input("up", true) and UI.sel > 1 then
				UI.sel = UI.sel - 1
				playSound(SoundEffect.SOUND_MENU_SCROLL)
			end
			if input("down", true) and UI.sel < #entries then
				UI.sel = UI.sel + 1
				playSound(SoundEffect.SOUND_MENU_SCROLL)
			end
			if input("confirm", false) or input("right", false) then
				UI.view = "detail"
				UI.detailTop = 1
				playSound(SoundEffect.SOUND_PAPER_IN)
			elseif input("back", false) then
				UI.Close()
			end
		elseif UI.itemMode then
			itemModeInput(input)
		else
			if input("up", true) then UI.detailTop = UI.detailTop - 1 end
			if input("down", true) then UI.detailTop = UI.detailTop + 1 end
			if input("left", false) and UI.sel > 1 then
				UI.sel = UI.sel - 1
				UI.detailTop = 1
				playSound(SoundEffect.SOUND_MENU_SCROLL)
			end
			if input("right", false) and UI.sel < #entries then
				UI.sel = UI.sel + 1
				UI.detailTop = 1
				playSound(SoundEffect.SOUND_MENU_SCROLL)
			end
			if input("confirm", false) then
				enterItemMode()
			elseif input("back", false) then
				UI.view = "list"
				playSound(SoundEffect.SOUND_PAPER_OUT)
			end
		end
	end

	-- 纸张从屏幕下方滑入
	local t = 1 - UI.anim
	OX, OY = ox, oy + t * t * 290

	drawPaper()
	if UI.view == "detail" and #entries > 0 then
		drawDetail(entries)
	else
		drawList(entries)
	end
	return true
end

----------------------------------------------------------------------
-- 对局内：按键打开，画布居中
----------------------------------------------------------------------

local NAV = {
	up = { keys = { Keyboard.KEY_UP, Keyboard.KEY_W }, action = ButtonAction.ACTION_MENUUP },
	down = { keys = { Keyboard.KEY_DOWN, Keyboard.KEY_S }, action = ButtonAction.ACTION_MENUDOWN },
	left = { keys = { Keyboard.KEY_LEFT, Keyboard.KEY_A }, action = ButtonAction.ACTION_MENULEFT },
	right = { keys = { Keyboard.KEY_RIGHT, Keyboard.KEY_D }, action = ButtonAction.ACTION_MENURIGHT },
	confirm = { keys = { Keyboard.KEY_SPACE, Keyboard.KEY_E }, action = ButtonAction.ACTION_MENUCONFIRM },
	back = { keys = { Keyboard.KEY_BACKSPACE }, action = ButtonAction.ACTION_MENUBACK },
}
local holdFrames = {}

-- 按住不放时过一会儿开始连续触发（方便滚动）
function UI.Repeat(name, triggered, held, allowRepeat)
	if triggered then
		holdFrames[name] = 0
		return true
	end
	if held and allowRepeat then
		local frames = (holdFrames[name] or 0) + 1
		holdFrames[name] = frames
		return frames > 24 and frames % 4 == 0
	end
	holdFrames[name] = nil
	return false
end

local function runInput(name, allowRepeat)
	local nav = NAV[name]
	local triggered, held = false, false
	for _, key in ipairs(nav.keys) do
		if Input.IsButtonTriggered(key, 0) then triggered = true end
		if Input.IsButtonPressed(key, 0) then held = true end
	end
	-- 手柄
	local player = Isaac.GetPlayer(0)
	local controller = player ~= nil and player.ControllerIndex or 0
	if controller > 0 then
		if Input.IsActionTriggered(nav.action, controller) then triggered = true end
		if Input.IsActionPressed(nav.action, controller) then held = true end
	end
	return UI.Repeat(name, triggered, held, allowRepeat)
end

function UI.OnRender()
	local toggleKey = mod.Config.ToggleKey
	if toggleKey ~= nil and Input.IsButtonTriggered(toggleKey, 0) then
		UI.Toggle()
	end
	if not UI.open then return end
	if UI.mode ~= "run" then
		UI.ForceClose()
		return
	end

	local W, H = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
	-- 压暗游戏画面
	OX, OY = 0, 0
	rect(0, 0, W, H, 0, 0, 0, 0.5 * UI.anim)
	UI.Frame((W - 480) / 2, (H - 270) / 2, runInput)
end
mod:AddCallback(ModCallbacks.MC_POST_RENDER, UI.OnRender)

-- 页面打开时，方向键/空格等只用来操作页面，不让角色移动、射击、用道具
function UI.OnInputAction(_, entity, hook, action)
	if not UI.open or entity == nil then return end
	if entity.Type ~= EntityType.ENTITY_PLAYER then return end
	if action > ButtonAction.ACTION_DROP then return end
	if hook == InputHook.GET_ACTION_VALUE then
		return 0.0
	end
	return false
end
mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, UI.OnInputAction)

return UI

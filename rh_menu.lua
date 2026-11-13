-- Run History: 主菜单"统计数据"里的入口（需要 REPENTOGON）
--
-- 原版忏悔的 mod 接口在主菜单里不运行，所以这部分只有装了 REPENTOGON 才会生效；
-- 没装的时候本文件直接返回，mod 的其余功能（记录 + 对局内 F2 查看）不受影响。
--
-- 做法：
--   * 在"统计数据"菜单右上角钉一张"对局记录"便签，作为第 5 个可选项：
--     在第一项上按"上"或在最后一项上按"下"就会选中它，按"确认"打开页面。
--   * 页面是一张从下方滑入的纸，盖在统计菜单上；打开期间屏蔽原菜单的输入。

local mod = RunHistory
local UI = mod.UI

local Menu = { Available = false }

if not (REPENTOGON and MenuManager and StatsMenu and MainMenuType
		and ModCallbacks.MC_MAIN_MENU_RENDER and Isaac.WorldToMenuPosition) then
	return Menu
end
Menu.Available = true

local STATS = MainMenuType.STATS

-- 统计菜单自带的可选项：道具 / 结局 / 成就 / 怪物图鉴（序号从 0 开始）
local FIRST_ELEMENT, LAST_ELEMENT = 0, 3

-- 菜单贴图（statsmenu.anm2）原点对应的菜单坐标，和 REPENTOGON 自带的统计页扩展一致
local CANVAS_ORIGIN = Vector(-39, -15)

-- 便签在菜单画布上的位置（左上角）和大小
local NOTE_X, NOTE_Y = 343, 6
local NOTE_W, NOTE_H = 108, 44

-- 输入屏蔽：只在本回调之外生效（回调内部读到的是未屏蔽的输入）
local ALL_INPUTS = 0xFFFFFFFF
local function bits(...)
	local mask = 0
	for _, action in ipairs({ ... }) do
		mask = mask | (1 << action)
	end
	return mask
end
-- 选中便签时：不让原菜单响应上/下/确认
local MASK_NOTE = ALL_INPUTS & ~bits(
	ButtonAction.ACTION_UP, ButtonAction.ACTION_DOWN,
	ButtonAction.ACTION_SHOOTUP, ButtonAction.ACTION_SHOOTDOWN,
	ButtonAction.ACTION_MENUUP, ButtonAction.ACTION_MENUDOWN,
	ButtonAction.ACTION_MENUCONFIRM, ButtonAction.ACTION_ITEM)
-- 页面打开时：只保留全屏和静音
local MASK_PAGE = bits(ButtonAction.ACTION_FULLSCREEN, ButtonAction.ACTION_MUTE)

-- 不响应 F2 的菜单：标题画面、选存档（还没读入存档槽），以及改键界面（F2 可能正被绑定成按键）
local NO_HOTKEY = {}
for _, name in ipairs({ "TITLE", "SAVES", "KEYCONFIG" }) do
	if MainMenuType[name] ~= nil then NO_HOTKEY[MainMenuType[name]] = true end
end

local state = {
	free = false, -- 页面是在统计菜单以外用 F2 打开的（画在屏幕中央）
	selected = false, -- 便签是否被选中
	prevElement = nil, -- 上一帧统计菜单选中的项
	cooldown = 0, -- 打开/关闭页面后的几帧里继续屏蔽输入，防止同一次按键被原菜单再处理一遍
	hold = 0, -- 离开便签后的几帧里继续屏蔽上/下/确认，原因同上
	mask = ALL_INPUTS,
	cursorHidden = false,
	loadedSlot = false,
}

local note = Sprite()
note:Load("gfx/runhistory_note.anm2", true)
note:Play("Idle", true)

----------------------------------------------------------------------
-- 输入（所有手柄/键盘）
----------------------------------------------------------------------

local function deviceCount()
	local count = 1
	if Input.GetDeviceNameByIdx ~= nil then
		while count < 8 and Input.GetDeviceNameByIdx(count) ~= nil do
			count = count + 1
		end
	end
	return count
end

local devices = 1

local function triggered(action)
	for i = 0, devices do
		if Input.IsActionTriggered(action, i) then return true end
	end
	return false
end

local function pressed(action)
	for i = 0, devices do
		if Input.IsActionPressed(action, i) then return true end
	end
	return false
end

local ACTIONS = {
	up = ButtonAction.ACTION_MENUUP,
	down = ButtonAction.ACTION_MENUDOWN,
	left = ButtonAction.ACTION_MENULEFT,
	right = ButtonAction.ACTION_MENURIGHT,
	confirm = ButtonAction.ACTION_MENUCONFIRM,
	back = ButtonAction.ACTION_MENUBACK,
}

local function menuInput(name, allowRepeat)
	local action = ACTIONS[name]
	return UI.Repeat("menu_" .. name, triggered(action), pressed(action), allowRepeat)
end

----------------------------------------------------------------------
-- 与原菜单的配合
----------------------------------------------------------------------

local function setMask(mask)
	if state.mask ~= mask then
		state.mask = mask
		MenuManager.SetInputMask(mask)
	end
end

-- 便签被选中时，把原菜单自己的箭头藏起来
local function setVanillaCursorHidden(hidden)
	if state.cursorHidden == hidden then return end
	state.cursorHidden = hidden
	pcall(function()
		StatsMenu.GetStatsMenuSprite():GetLayer("Cursor"):SetVisible(not hidden)
	end)
end

local function playSound(id)
	if id ~= nil then SFXManager():Play(id, 1, 0, false, 1) end
end

local function reset()
	state.selected = false
	state.prevElement = nil
	state.cooldown = 0
	state.hold = 0
	setMask(ALL_INPUTS)
	setVanillaCursorHidden(false)
	if UI.open and UI.mode == "menu" then UI.ForceClose() end
end

local function canvasOrigin()
	local offset = Vector(CANVAS_ORIGIN.X + (mod.Config.MenuOffsetX or 0), CANVAS_ORIGIN.Y + (mod.Config.MenuOffsetY or 0))
	return Isaac.WorldToMenuPosition(STATS, offset)
end

local function drawNote(origin)
	local Small, Big = UI.Fonts()
	note:Render(Vector(origin.X + NOTE_X, origin.Y + NOTE_Y), Vector.Zero, Vector.Zero)
	local label = UI.Text("menuEntry")
	local F = Big
	if F.font:GetStringWidthUTF8(label) > NOTE_W - 16 then F = Small end
	local width = F.font:GetStringWidthUTF8(label)
	local x = origin.X + NOTE_X + (NOTE_W - 4 - width) / 2
	local y = origin.Y + NOTE_Y + (NOTE_H - 6 - F.h) / 2
	F.font:DrawStringScaledUTF8(label, x, y - F.top, 1, 1, UI.Ink, 0, false)
	if state.selected then
		-- 箭头贴图里箭头本体偏移 (4,4)，大小约 12x15
		UI.CursorSprite:Render(Vector(origin.X + NOTE_X - 18, origin.Y + NOTE_Y + (NOTE_H - 6) / 2 - 11), Vector.Zero, Vector.Zero)
	end
end

----------------------------------------------------------------------
-- 回调
----------------------------------------------------------------------

local function hotkeyTriggered()
	local key = mod.Config.ToggleKey
	return key ~= nil and Input.IsButtonTriggered(key, 0)
end

function Menu.OnRender()
	local active = MenuManager.GetActiveMenu()
	local secrets = StatsMenu.IsSecretsMenuVisible()

	devices = deviceCount()
	if state.cooldown > 0 then state.cooldown = state.cooldown - 1 end

	-- F2：在主菜单的任意界面直接打开 / 关闭页面
	local pageOpen = UI.open and UI.mode == "menu"
	if state.cooldown == 0 and hotkeyTriggered() then
		if pageOpen then
			UI.Close()
			state.cooldown = 12
		elseif not NO_HOTKEY[active] then
			mod:LoadHistory()
			UI.Open("menu")
			state.free = (active ~= STATS) or secrets
			state.cooldown = 10
			pageOpen = true
		end
	end
	if not pageOpen then state.free = false end

	-- 统计菜单以外打开的页面：压暗屏幕，画在屏幕中央
	if pageOpen and state.free then
		local W, H = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
		UI.Dim(W, H)
		local wasClosing = UI.closing
		UI.Frame((W - 480) / 2, (H - 270) / 2, menuInput)
		if (UI.closing and not wasClosing) or not UI.open then
			state.cooldown = 12
		end
		setMask(MASK_PAGE)
		return
	end

	if active ~= STATS or secrets then
		if state.cooldown > 0 then
			-- 刚关掉页面：再屏蔽几帧，免得关页面的那次按键被原菜单当成"返回"
			setMask(MASK_PAGE)
		elseif state.selected or state.mask ~= ALL_INPUTS or state.cursorHidden or (UI.open and UI.mode == "menu") then
			reset()
		end
		state.prevElement = nil
		-- 便签钉在统计菜单上，镜头移开时会跟着菜单一起移出屏幕
		if not secrets then drawNote(canvasOrigin()) end
		return
	end

	-- 进入统计菜单时读取当前存档槽的记录
	if not state.loadedSlot then
		state.loadedSlot = true
		mod:LoadHistory()
	end

	if state.hold > 0 then state.hold = state.hold - 1 end

	local element = StatsMenu.GetSelectedElement()

	if not pageOpen then
		local up, down = triggered(ACTIONS.up), triggered(ACTIONS.down)
		if state.selected then
			if up then
				state.selected = false
				state.hold = 3
				StatsMenu.SetSelectedElement(LAST_ELEMENT)
				playSound(SoundEffect.SOUND_MENU_SCROLL)
			elseif down then
				state.selected = false
				state.hold = 3
				StatsMenu.SetSelectedElement(FIRST_ELEMENT)
				playSound(SoundEffect.SOUND_MENU_SCROLL)
			elseif state.cooldown == 0 and triggered(ACTIONS.confirm) then
				mod:LoadHistory()
				UI.Open("menu")
				state.cooldown = 10
				pageOpen = true
			end
			element = StatsMenu.GetSelectedElement()
		elseif state.prevElement ~= nil and state.hold == 0 then
			-- 在第一项上按"上"，或在最后一项上按"下"：选中便签
			if (up and state.prevElement == FIRST_ELEMENT) or (down and state.prevElement == LAST_ELEMENT) then
				state.selected = true
				playSound(SoundEffect.SOUND_MENU_SCROLL)
			end
		end
	end
	state.prevElement = element

	local origin = canvasOrigin()
	-- 页面完全展开后会盖住便签的位置，这时不画便签
	if not (pageOpen and UI.anim >= 1 and not UI.closing) then
		drawNote(origin)
	end

	if pageOpen then
		local wasClosing = UI.closing
		UI.Frame(origin.X, origin.Y, menuInput)
		if (UI.closing and not wasClosing) or not UI.open then
			state.cooldown = 12
		end
	end

	-- 设置下一帧原菜单能收到的输入
	if (UI.open and UI.mode == "menu") or state.cooldown > 0 then
		setMask(MASK_PAGE)
	elseif state.selected or state.hold > 0 then
		setMask(MASK_NOTE)
	else
		setMask(ALL_INPUTS)
	end
	setVanillaCursorHidden(state.selected)
end
mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, Menu.OnRender)

-- 切换存档槽后重新读取记录
if ModCallbacks.MC_POST_SAVESLOT_LOAD ~= nil then
	mod:AddCallback(ModCallbacks.MC_POST_SAVESLOT_LOAD, function()
		state.loadedSlot = false
	end)
end

-- 进入对局时恢复原菜单的状态
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
	state.free = false
	state.selected = false
	state.prevElement = nil
	state.cooldown = 0
	state.hold = 0
	state.mask = ALL_INPUTS
	state.cursorHidden = false
	state.loadedSlot = false
end)

Menu.State = state
return Menu

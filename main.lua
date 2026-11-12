-- Run History / 对局记录
-- 记录最近若干局对局：种子、角色、最终道具、击败的 Boss，以及逐层的道具与关底 Boss。
-- 适用于 Repentance v1.7.9b（不需要 REPENTOGON）。

local mod = RegisterMod("Run History", 1)
RunHistory = mod

local json = require("json")
local game = Game()

mod.Config = include("rh_config")
-- 官方名称表和 Boss 图标表在这里直接加载，rh_names.lua 再从 mod 上取用
mod.NamesData = include("rh_names_data")
mod.BossIcons = include("rh_boss_icons")
mod.Names = include("rh_names")

local MAX_ITEMS_PER_FLOOR = 120 -- 防止不停重随道具的角色（如堕化伊甸）把存档撑爆

-- 存档内容：runs = 已结束的对局（新的在前），current = 正在进行的对局
mod.Data = { version = 1, runs = {} }
-- 当前房间在进入时是否已经清理过（用于判断"刚刚打完 Boss"）
mod.RoomWasClear = true
-- 没有 BossID 的 Boss 房（模组 Boss）里血量最高的 Boss 实体，作为名称兜底
mod.FallbackBoss = nil
-- 是否已经进入对局（POST_GAME_STARTED 之后为 true，退出对局后为 false）
mod.InRun = false

----------------------------------------------------------------------
-- 存档读写
----------------------------------------------------------------------

-- 旧版本记录里可能混有"路过"的空楼层：没有道具、没有 Boss，而且下一层的层数反而更小
local function removePhantomFloors(run)
	if type(run) ~= "table" or type(run.floors) ~= "table" then return end
	for i = #run.floors - 1, 1, -1 do
		local floor, nextFloor = run.floors[i], run.floors[i + 1]
		if #(floor.items or {}) == 0 and #(floor.bosses or {}) == 0
			and (nextFloor.stage or 0) < (floor.stage or 0) and (nextFloor.stage or 0) > 1
			and not nextFloor.ascent and not floor.ascent then
			table.remove(run.floors, i)
		end
	end
end

function mod:LoadHistory()
	local data
	if mod:HasData() then
		local ok, decoded = pcall(json.decode, mod:LoadData())
		if ok and type(decoded) == "table" then
			data = decoded
		end
	end
	data = data or {}
	if type(data.runs) ~= "table" then data.runs = {} end
	if type(data.current) ~= "table" then data.current = nil end
	for _, run in ipairs(data.runs) do removePhantomFloors(run) end
	data.version = 1
	mod.Data = data
end

function mod:SaveHistory()
	local ok, encoded = pcall(json.encode, mod.Data)
	if ok then
		mod:SaveData(encoded)
	else
		Isaac.DebugString("[Run History] failed to encode save data: " .. tostring(encoded))
	end
end

----------------------------------------------------------------------
-- 道具栏扫描
----------------------------------------------------------------------

local validItemIds = nil

-- 所有有效的道具 ID（包含其他 mod 添加的道具）
local function getValidItemIds()
	if validItemIds == nil then
		validItemIds = {}
		local config = Isaac.GetItemConfig()
		local maxId = config:GetCollectibles().Size - 1
		for id = 1, maxId do
			if config:GetCollectible(id) ~= nil then
				validItemIds[#validItemIds + 1] = id
			end
		end
	end
	return validItemIds
end

-- 形态切换时共用同一份道具栏的角色，归并到同一个类型
local function normalizePlayerType(playerType)
	if playerType == PlayerType.PLAYER_THESOUL then return PlayerType.PLAYER_THEFORGOTTEN end
	if playerType == PlayerType.PLAYER_JACOB2_B then return PlayerType.PLAYER_JACOB_B end
	return playerType
end

-- 返回 { {key = "序号:角色类型", player = EntityPlayer}, ... }
local function getTrackedPlayers()
	local list = {}
	for i = 0, game:GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		if player ~= nil
			and player.Variant == 0 -- 排除联机宝宝
			and player.Parent == nil -- 排除稻草人等附属角色
			and player:GetPlayerType() ~= PlayerType.PLAYER_THESOUL_B -- 道具都在堕化遗骸本体身上
		then
			list[#list + 1] = {
				key = tostring(i) .. ":" .. tostring(normalizePlayerType(player:GetPlayerType())),
				player = player,
			}
		end
	end
	return list
end

-- 返回 { ["道具ID"] = 数量 }
local function scanPlayer(player)
	local snapshot = {}
	for _, id in ipairs(getValidItemIds()) do
		local count = player:GetCollectibleNum(id, true)
		if count > 0 then
			snapshot[tostring(id)] = count
		end
	end
	return snapshot
end

local function sortedIds(snapshot)
	local ids = {}
	for idStr in pairs(snapshot) do
		ids[#ids + 1] = tonumber(idStr)
	end
	table.sort(ids)
	return ids
end

----------------------------------------------------------------------
-- 对局记录
----------------------------------------------------------------------

local function currentFloor(run)
	return run.floors[#run.floors]
end

local function newFloorRecord()
	local level = game:GetLevel()
	return {
		stage = level:GetStage(),
		stageType = level:GetStageType(),
		xl = (level:GetCurses() & LevelCurse.CURSE_OF_LABYRINTH) ~= 0,
		ascent = level:IsAscent(),
		enter = game:GetFrameCount(), -- 进入本层的时间（用于识别"路过"的空楼层）
		t0 = game.TimeCounter, -- 进入本层时的对局计时
		time = 0, -- 在本层花费的时间（帧，30 帧 = 1 秒）
		items = {}, -- 本层获得的道具 ID（按获得顺序）
		bosses = {}, -- 本层击败的 Boss：数字 = BossID，字符串 = "类型.变种"（模组 Boss）
		lost = {}, -- 本层失去的道具（用于忽略"放下又捡回来"）
	}
end

local function round2(value)
	return math.floor((tonumber(value) or 0) * 100 + 0.5) / 100
end

-- 记录角色当前的六项属性（和游戏内属性栏显示的数值一致）
local function captureStats(run)
	local player = Isaac.GetPlayer(0)
	if run == nil or player == nil then return end
	local ok, stats = pcall(function()
		return {
			speed = round2(player.MoveSpeed),
			tears = round2(30 / (player.MaxFireDelay + 1)),
			damage = round2(player.Damage),
			range = round2(player.TearRange / 40),
			shotSpeed = round2(player.ShotSpeed),
			luck = round2(player.Luck),
		}
	end)
	if ok then run.stats = stats end
end

-- 记录本层的恶魔房 / 天使房：1 = 出现了（门开了），2 = 进去过
local function recordDeal(kind, level)
	local run = mod.Data.current
	if run == nil then return end
	local floor = run.floors[#run.floors]
	if floor == nil then return end
	floor.deal = floor.deal or {}
	if (floor.deal[kind] or 0) < level then
		floor.deal[kind] = level
	end
end

-- 当前房间里有没有通往恶魔房 / 天使房的门
local function checkDealDoors()
	local room = game:GetRoom()
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		local door = room:GetDoor(slot)
		if door ~= nil then
			local target = door.TargetRoomType
			if target == RoomType.ROOM_DEVIL then
				recordDeal("devil", 1)
			elseif target == RoomType.ROOM_ANGEL then
				recordDeal("angel", 1)
			end
		end
	end
end

-- 更新当前楼层已经花费的时间，以及此刻的金币 / 炸弹 / 钥匙数量。
-- 离开楼层（或对局结束）时最后更新一次，留下的就是"这一层结束时"的数值。
local function updateFloorTime(run)
	local floor = run and run.floors[#run.floors]
	if floor == nil then return end
	if floor.t0 ~= nil then
		floor.time = math.max(0, game.TimeCounter - floor.t0)
	end
	local player = Isaac.GetPlayer(0)
	if player ~= nil then
		floor.coins = player:GetNumCoins()
		floor.bombs = player:GetNumBombs()
		floor.keys = player:GetNumKeys()
	end
end

local function getDateString()
	local ok, result = pcall(function()
		return os.date("%Y-%m-%d %H:%M")
	end)
	if ok and type(result) == "string" then return result end
	return ""
end

-- 对比道具栏快照，把新增的道具记到当前楼层
function mod:UpdateInventory()
	local run = mod.Data.current
	if run == nil then return end
	local floor = currentFloor(run)
	if floor == nil then return end
	floor.lost = floor.lost or {}

	local active = {}
	for _, entry in ipairs(getTrackedPlayers()) do
		local key = entry.key
		active[#active + 1] = key
		local now = scanPlayer(entry.player)
		local old = run.snap[key]
		if old ~= nil then
			for _, id in ipairs(sortedIds(now)) do
				local idStr = tostring(id)
				local gained = now[idStr] - (old[idStr] or 0)
				for _ = 1, gained do
					if (floor.lost[idStr] or 0) > 0 then
						-- 本层放下过又捡回来的道具，不重复记录
						floor.lost[idStr] = floor.lost[idStr] - 1
					elseif #floor.items < MAX_ITEMS_PER_FLOOR then
						floor.items[#floor.items + 1] = id
					end
				end
			end
			for idStr, count in pairs(old) do
				local lostCount = count - (now[idStr] or 0)
				if lostCount > 0 then
					floor.lost[idStr] = (floor.lost[idStr] or 0) + lostCount
				end
			end
		end
		-- old == nil：第一次见到这个角色形态（变身/复活/切换形态），只建立基线，不算作获得
		run.snap[key] = now
	end
	run.active = active
end

-- 根据快照生成"最终道具"列表：先按获得顺序排，剩下的按 ID 排
local function buildFinalItems(run)
	local counts = {}
	for _, key in ipairs(run.active or {}) do
		for idStr, count in pairs(run.snap[key] or {}) do
			counts[idStr] = (counts[idStr] or 0) + count
		end
	end

	local final = {}
	local function take(id)
		local idStr = tostring(id)
		if (counts[idStr] or 0) > 0 then
			counts[idStr] = counts[idStr] - 1
			final[#final + 1] = id
		end
	end
	for _, id in ipairs(run.startItems or {}) do take(id) end
	for _, floor in ipairs(run.floors) do
		for _, id in ipairs(floor.items) do take(id) end
	end
	for _, id in ipairs(sortedIds(counts)) do
		for _ = 1, counts[tostring(id)] do
			final[#final + 1] = id
		end
	end
	return final
end
mod.BuildFinalItems = buildFinalItems

-- 开始记录一局新对局
local function startRun(partial)
	local player = Isaac.GetPlayer(0)
	local run = {
		seed = game:GetSeeds():GetStartSeedString(),
		player = player:GetPlayerType(),
		playerName = player:GetName(),
		difficulty = game.Difficulty,
		greed = game:IsGreedMode(),
		challenge = Isaac.GetChallenge(),
		date = getDateString(),
		time = game.TimeCounter,
		partial = partial or nil,
		startItems = {},
		floors = { newFloorRecord() },
		snap = {},
		active = {},
	}

	-- 开局自带的道具作为基线，不算作第一层获得的道具
	for _, entry in ipairs(getTrackedPlayers()) do
		local snapshot = scanPlayer(entry.player)
		run.snap[entry.key] = snapshot
		run.active[#run.active + 1] = entry.key
		for _, id in ipairs(sortedIds(snapshot)) do
			for _ = 1, snapshot[tostring(id)] do
				run.startItems[#run.startItems + 1] = id
			end
		end
	end

	captureStats(run)
	mod.Data.current = run
	return run
end

-- 结束当前对局并写入历史。result: "win" | "death" | "quit"
-- stale = true 表示这是上次没正常结束的对局（此时场上的角色已经不是那一局的了）
local function finalizeRun(result, stale)
	local run = mod.Data.current
	if run == nil then return end

	if not stale then
		mod:UpdateInventory()
		run.time = game.TimeCounter
		updateFloorTime(run)
		captureStats(run)
	end

	run.result = result
	run.finalItems = buildFinalItems(run)
	run.snap = nil
	run.active = nil
	for _, floor in ipairs(run.floors) do
		floor.lost = nil
		floor.enter = nil
		floor.t0 = nil
	end

	local skip = false
	if result == "quit" and mod.Config.SkipQuickRestarts then
		-- 第一层都没打完就重开的对局不记录
		skip = #run.floors <= 1 and #run.floors[1].bosses == 0
	end

	if not skip then
		table.insert(mod.Data.runs, 1, run)
		local maxRuns = math.max(1, tonumber(mod.Config.MaxRuns) or 20)
		while #mod.Data.runs > maxRuns do
			table.remove(mod.Data.runs)
		end
	end

	mod.Data.current = nil
	mod:SaveHistory()
end

-- 记录本层击败的一个 Boss
local function recordBoss(boss)
	local run = mod.Data.current
	if run == nil or boss == nil then return end
	local floor = currentFloor(run)
	for _, existing in ipairs(floor.bosses) do
		if existing == boss then return end
	end
	floor.bosses[#floor.bosses + 1] = boss
	run.lastBoss = boss
end

-- 在 Boss 房里：房间从"未清理"变成"已清理"时记录 Boss
local function checkBossRoom(force)
	local run = mod.Data.current
	if run == nil then return end
	local room = game:GetRoom()
	if room:GetType() ~= RoomType.ROOM_BOSS then return end
	if mod.RoomWasClear then return end

	local bossId = room:GetBossID()
	if not room:IsClear() and not force then
		-- 模组 Boss 没有 BossID：记下血量最高的 Boss 实体作为兜底
		if bossId == 0 and game:GetFrameCount() % 15 == 0 then
			local best = mod.FallbackBoss
			for _, entity in ipairs(Isaac.GetRoomEntities()) do
				if entity:IsBoss() and (best == nil or entity.MaxHitPoints > best.hp) then
					best = {
						hp = entity.MaxHitPoints,
						key = tostring(entity.Type) .. "." .. tostring(entity.Variant),
					}
				end
			end
			mod.FallbackBoss = best
		end
		return
	end

	mod.RoomWasClear = true
	if bossId > 0 then
		recordBoss(bossId)
	elseif mod.FallbackBoss ~= nil then
		recordBoss(mod.FallbackBoss.key)
	end
	mod.FallbackBoss = nil
end

----------------------------------------------------------------------
-- 回调
----------------------------------------------------------------------

function mod:OnGameStarted(isContinued)
	mod.InRun = true
	validItemIds = nil
	mod:LoadHistory()

	local seed = game:GetSeeds():GetStartSeedString()
	local run = mod.Data.current

	if isContinued then
		if run ~= nil and run.seed == seed and type(run.floors) == "table" and #run.floors > 0 then
			-- 继续上次的对局
			run.snap = run.snap or {}
			run.active = run.active or {}
		else
			-- 存档里没有这局的记录（比如中途才装上 mod）
			if run ~= nil then finalizeRun("quit", true) end
			startRun(true)
		end
	else
		-- 新开一局；如果上一局没正常结束，按"放弃"归档
		if run ~= nil then finalizeRun("quit", true) end
		startRun(false)
	end

	local room = game:GetRoom()
	mod.RoomWasClear = room:IsClear()
	mod.FallbackBoss = nil
	mod:SaveHistory()
end
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnGameStarted)

function mod:OnNewLevel()
	-- 开局/继续时 POST_NEW_LEVEL 比 POST_GAME_STARTED 先触发，这时交给 OnGameStarted 处理
	if not mod.InRun or game:GetFrameCount() == 0 then return end

	local run = mod.Data.current
	if run == nil then
		-- 例如胜利后进入胜利之旅：作为一局新的记录继续
		startRun(true)
	else
		mod:UpdateInventory() -- 下楼前刚拿到的道具仍然算在上一层
		updateFloorTime(run)
		-- 走隐藏出口进入支线楼层时，游戏会先瞬间"路过"另一层再到达真正的楼层：丢掉这种空楼层
		local last = run.floors[#run.floors]
		if #run.floors > 1 and last.enter ~= nil and game:GetFrameCount() - last.enter < 30
			and #last.items == 0 and #last.bosses == 0 and last.deal == nil then
			table.remove(run.floors)
		end
		run.floors[#run.floors + 1] = newFloorRecord()
		run.time = game.TimeCounter
		captureStats(run)
	end
	mod.FallbackBoss = nil
	mod:SaveHistory()
end
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.OnNewLevel)

function mod:OnNewRoom()
	local room = game:GetRoom()
	mod.RoomWasClear = room:IsClear()
	mod.FallbackBoss = nil
	-- 开局时这个回调比 POST_GAME_STARTED 先触发，那时还没有对局记录
	if mod.InRun and mod.Data.current ~= nil and game:GetFrameCount() > 0 then
		local roomType = room:GetType()
		if roomType == RoomType.ROOM_DEVIL then
			recordDeal("devil", 2)
		elseif roomType == RoomType.ROOM_ANGEL then
			recordDeal("angel", 2)
		end
	end
end
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoom)

function mod:OnUpdate()
	if not mod.InRun or mod.Data.current == nil then return end
	local frame = game:GetFrameCount()
	if frame % 8 == 0 then
		mod:UpdateInventory()
	end
	if frame % 15 == 0 then
		checkDealDoors()
	end
	if frame % 30 == 0 then
		captureStats(mod.Data.current)
		updateFloorTime(mod.Data.current)
	end
	checkBossRoom(false)
end
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdate)

-- 不在普通 Boss 房里、或者一死就直接进结局的 Boss，靠击杀事件记录
function mod:OnEntityKill(entity)
	if not mod.InRun or mod.Data.current == nil then return end
	local entityType, variant = entity.Type, entity.Variant
	local bossId
	if entityType == 951 and variant == 0 then bossId = 100 -- 祸兽
	elseif entityType == 950 and variant == 2 then bossId = 99 -- 教条（最终形态）
	elseif entityType == 275 and variant == 0 then bossId = 55 -- 超级撒但（第二阶段）
	elseif entityType == 406 then bossId = (variant == 1) and 71 or 62 -- 究极贪婪 / 究极更贪婪
	elseif entityType == 412 and variant == 0 then bossId = 70 -- 精神错乱
	elseif entityType == 407 and variant == 0 then bossId = 63 -- 死寂
	end
	if bossId ~= nil then
		recordBoss(bossId)
	end
end
mod:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, mod.OnEntityKill)

function mod:OnGameEnd(isGameOver)
	if not mod.InRun or mod.Data.current == nil then return end
	if not isGameOver then
		checkBossRoom(true) -- 通关时还在 Boss 房里：确保最后的 Boss 被记录
	end
	finalizeRun(isGameOver and "death" or "win", false)
end
mod:AddCallback(ModCallbacks.MC_POST_GAME_END, mod.OnGameEnd)

function mod:OnGameExit(shouldSave)
	if mod.UI then mod.UI.ForceClose() end
	local wasInRun = mod.InRun
	mod.InRun = false
	if not wasInRun then return end
	local run = mod.Data.current
	if run == nil then return end
	if shouldSave then
		-- 保存并退出：对局还会继续
		mod:UpdateInventory()
		run.time = game.TimeCounter
		updateFloorTime(run)
		captureStats(run)
		mod:SaveHistory()
	else
		-- 长按 R 重开等：按"放弃"归档
		finalizeRun("quit", false)
	end
end
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.OnGameExit)

----------------------------------------------------------------------
-- 界面
----------------------------------------------------------------------

mod.UI = include("rh_ui")
-- 主菜单"统计数据"里的入口（需要 REPENTOGON；没装时这个模块什么都不做）
mod.Menu = include("rh_menu")

-- 控制台命令：runhistory（开关界面）/ runhistory clear（清空记录）
function mod:OnCommand(command, args)
	if string.lower(command) ~= "runhistory" then return end
	if string.lower(args or "") == "clear" then
		mod.Data.runs = {}
		mod:SaveHistory()
		print("[Run History] " .. mod.UI.Text("cleared"))
	else
		mod.UI.Toggle()
	end
end
mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, mod.OnCommand)

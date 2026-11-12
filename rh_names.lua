-- Run History: 名称表（角色 / Boss / 楼层 / 界面文字）
-- 适用于 Repentance v1.7.9b

local Names = {}

----------------------------------------------------------------------
-- 角色  PlayerType -> 名称
----------------------------------------------------------------------
Names.Players = {
	en = {
		[0] = "Isaac", [1] = "Magdalene", [2] = "Cain", [3] = "Judas", [4] = "???",
		[5] = "Eve", [6] = "Samson", [7] = "Azazel", [8] = "Lazarus", [9] = "Eden",
		[10] = "The Lost", [11] = "Lazarus", [12] = "Dark Judas", [13] = "Lilith",
		[14] = "Keeper", [15] = "Apollyon", [16] = "The Forgotten", [17] = "The Forgotten",
		[18] = "Bethany", [19] = "Jacob & Esau", [20] = "Esau",
		[21] = "T. Isaac", [22] = "T. Magdalene", [23] = "T. Cain", [24] = "T. Judas",
		[25] = "T. ???", [26] = "T. Eve", [27] = "T. Samson", [28] = "T. Azazel",
		[29] = "T. Lazarus", [30] = "T. Eden", [31] = "T. Lost", [32] = "T. Lilith",
		[33] = "T. Keeper", [34] = "T. Apollyon", [35] = "T. Forgotten", [36] = "T. Bethany",
		[37] = "T. Jacob", [38] = "T. Lazarus", [39] = "T. Jacob", [40] = "T. Forgotten",
	},
	zh = {
		[0] = "以撒", [1] = "抹大拉", [2] = "该隐", [3] = "犹大", [4] = "???",
		[5] = "夏娃", [6] = "参孙", [7] = "阿撒泻勒", [8] = "拉撒路", [9] = "伊甸",
		[10] = "游魂", [11] = "拉撒路", [12] = "黑犹大", [13] = "莉莉丝",
		[14] = "店主", [15] = "亚玻伦", [16] = "遗骸", [17] = "遗骸",
		[18] = "伯大尼", [19] = "雅各和以扫", [20] = "以扫",
		[21] = "堕化以撒", [22] = "堕化抹大拉", [23] = "堕化该隐", [24] = "堕化犹大",
		[25] = "堕化???", [26] = "堕化夏娃", [27] = "堕化参孙", [28] = "堕化阿撒泻勒",
		[29] = "堕化拉撒路", [30] = "堕化伊甸", [31] = "堕化游魂", [32] = "堕化莉莉丝",
		[33] = "堕化店主", [34] = "堕化亚玻伦", [35] = "堕化遗骸", [36] = "堕化伯大尼",
		[37] = "堕化雅各", [38] = "堕化拉撒路", [39] = "堕化雅各", [40] = "堕化遗骸",
	},
}

----------------------------------------------------------------------
-- Boss  Room:GetBossID() -> 名称   （ID 来自 bossportraits.xml）
----------------------------------------------------------------------
Names.Bosses = {
	en = {
		[1] = "Monstro", [2] = "Larry Jr.", [3] = "Chub", [4] = "Gurdy", [5] = "Monstro II",
		[6] = "Mom", [7] = "Scolex", [8] = "Mom's Heart", [9] = "Famine", [10] = "Pestilence",
		[11] = "War", [12] = "Death", [13] = "Duke of Flies", [14] = "Peep", [15] = "Loki",
		[16] = "Blastocyst", [17] = "Gemini", [18] = "Fistula", [19] = "Gish", [20] = "Steven",
		[21] = "C.H.A.D.", [22] = "Headless Horseman", [23] = "The Fallen", [24] = "Satan",
		[25] = "It Lives", [26] = "The Hollow", [27] = "The Carrion Queen", [28] = "Gurdy Jr.",
		[29] = "The Husk", [30] = "The Bloat", [31] = "Lokii", [32] = "The Blighted Ovum",
		[33] = "Teratoma", [34] = "The Widow", [35] = "Mask of Infamy", [36] = "The Wretched",
		[37] = "Pin", [38] = "Conquest", [39] = "Isaac", [40] = "???", [41] = "Daddy Long Legs",
		[42] = "Triachnid", [43] = "The Haunt", [44] = "Dingle", [45] = "Mega Maw",
		[46] = "The Gate", [47] = "Mega Fatty", [48] = "The Cage", [49] = "Mama Gurdy",
		[50] = "Dark One", [51] = "The Adversary", [52] = "Polycephalus", [53] = "Mr. Fred",
		[54] = "The Lamb", [55] = "Mega Satan", [56] = "Gurglings", [57] = "The Stain",
		[58] = "Brownie", [59] = "The Forsaken", [60] = "Little Horn", [61] = "Rag Man",
		[62] = "Ultra Greed", [63] = "Hush", [64] = "Dangle", [65] = "Turdling",
		[66] = "The Frail", [67] = "Rag Mega", [68] = "Sisters Vis", [69] = "Big Horn",
		[70] = "Delirium", [71] = "Ultra Greedier", [72] = "The Matriarch", [73] = "The Pile",
		[74] = "Reap Creep", [75] = "Lil Blub", [76] = "Wormwood", [77] = "Rainmaker",
		[78] = "The Visage", [79] = "The Siren", [80] = "Tuff Twins", [81] = "The Heretic",
		[82] = "Hornfel", [83] = "Great Gideon", [84] = "Baby Plum", [85] = "The Scourge",
		[86] = "Chimera", [87] = "Rotgut", [88] = "Mother", [89] = "Mom",
		[90] = "Mom's Heart", [91] = "Min-Min", [92] = "Clog", [93] = "Singe",
		[94] = "Bumbino", [95] = "Colostomia", [96] = "The Shell", [97] = "Turdlet",
		[98] = "Raglich", [99] = "Dogma", [100] = "The Beast", [101] = "Horny Boys",
		[102] = "Clutch",
	},
	zh = {
		[1] = "萌死戳", [2] = "小拉里", [3] = "查布", [4] = "古蒂", [5] = "萌死戳二世",
		[6] = "妈妈", [7] = "斯科莱克斯", [8] = "妈妈的心脏", [9] = "饥荒", [10] = "瘟疫",
		[11] = "战争", [12] = "死亡", [13] = "苍蝇公爵", [14] = "窥眼", [15] = "洛基",
		[16] = "胚囊", [17] = "双子", [18] = "瘘管", [19] = "吉什", [20] = "史蒂文",
		[21] = "查德", [22] = "无头骑士", [23] = "堕落者", [24] = "撒但",
		[25] = "它还活着", [26] = "空心虫", [27] = "腐尸女王", [28] = "小古蒂",
		[29] = "蝇壳", [30] = "浮肿", [31] = "洛基二世", [32] = "枯萎卵",
		[33] = "畸胎瘤", [34] = "寡妇", [35] = "恶名面具", [36] = "悲惨者",
		[37] = "大头针", [38] = "征服", [39] = "以撒", [40] = "???", [41] = "长腿爸爸",
		[42] = "三腿蛛", [43] = "闹鬼", [44] = "丁格", [45] = "巨口",
		[46] = "大门", [47] = "超级胖子", [48] = "牢笼", [49] = "古蒂妈妈",
		[50] = "黑暗者", [51] = "敌对者", [52] = "多头怪", [53] = "弗雷德先生",
		[54] = "羔羊", [55] = "超级撒但", [56] = "咕噜", [57] = "污点",
		[58] = "布朗尼", [59] = "遗弃者", [60] = "小号角", [61] = "破布人",
		[62] = "究极贪婪", [63] = "死寂", [64] = "当格", [65] = "小屎怪",
		[66] = "虚弱者", [67] = "超级破布", [68] = "维斯姐妹", [69] = "大号角",
		[70] = "精神错乱", [71] = "究极更贪婪", [72] = "女族长", [73] = "骨堆",
		[74] = "收割爬行者", [75] = "小别西卜", [76] = "苦艾", [77] = "唤雨者",
		[78] = "面甲", [79] = "塞壬", [80] = "硬汉双子", [81] = "异教徒",
		[82] = "角页岩", [83] = "伟大的基甸", [84] = "小梅子", [85] = "天灾",
		[86] = "奇美拉", [87] = "腐肠", [88] = "母亲", [89] = "妈妈",
		[90] = "妈妈的心脏", [91] = "敏敏", [92] = "堵塞", [93] = "烧焦",
		[94] = "小班比诺", [95] = "结肠造口", [96] = "贝壳", [97] = "小粪团",
		[98] = "破布巫妖", [99] = "教条", [100] = "祸兽", [101] = "好色男孩",
		[102] = "离合",
	},
}

----------------------------------------------------------------------
-- 楼层
----------------------------------------------------------------------
-- 章节名：[章节][StageType]
local Chapters = {
	en = {
		{ [0] = "Basement", [1] = "Cellar", [2] = "Burning Basement", [4] = "Downpour", [5] = "Dross" },
		{ [0] = "Caves", [1] = "Catacombs", [2] = "Flooded Caves", [4] = "Mines", [5] = "Ashpit" },
		{ [0] = "Depths", [1] = "Necropolis", [2] = "Dank Depths", [4] = "Mausoleum", [5] = "Gehenna" },
		{ [0] = "Womb", [1] = "Utero", [2] = "Scarred Womb", [4] = "Corpse", [5] = "Mortis" },
	},
	zh = {
		{ [0] = "地下室", [1] = "地窖", [2] = "燃烧地下室", [4] = "下水道", [5] = "污水井" },
		{ [0] = "洞穴", [1] = "墓穴", [2] = "淹水洞穴", [4] = "矿洞", [5] = "灰坑" },
		{ [0] = "深牢", [1] = "坟场", [2] = "阴湿深牢", [4] = "陵墓", [5] = "炼狱" },
		{ [0] = "子宫", [1] = "血宫", [2] = "结痂子宫", [4] = "尸宫", [5] = "尸宫" },
	},
}

local Special = {
	en = {
		blueWomb = "???", sheol = "Sheol", cathedral = "Cathedral", darkRoom = "Dark Room",
		chest = "Chest", void = "The Void", home = "Home", shop = "The Shop",
		ultraGreed = "Ultra Greed", unknown = "Stage ", ascent = " (Ascent)",
	},
	zh = {
		blueWomb = "???", sheol = "阴间", cathedral = "教堂", darkRoom = "暗室",
		chest = "玩具箱", void = "虚空", home = "家", shop = "商店",
		ultraGreed = "究极贪婪", unknown = "楼层 ", ascent = "（回溯）",
	},
}

--- 根据楼层记录生成楼层名
---@param floor table {stage, stageType, xl, ascent}
---@param greed boolean 是否为贪婪模式
---@param lang string "zh" | "en"
function Names.Stage(floor, greed, lang)
	local chapters = Chapters[lang] or Chapters.en
	local sp = Special[lang] or Special.en
	local stage = floor.stage or 0
	local stageType = floor.stageType or 0
	local name

	if greed then
		if stage >= 1 and stage <= 4 then
			name = chapters[stage][stageType] or chapters[stage][0]
		elseif stage == 5 then name = sp.sheol
		elseif stage == 6 then name = sp.shop
		elseif stage == 7 then name = sp.ultraGreed
		end
	else
		if stage >= 1 and stage <= 8 then
			local chapter = (stage + 1) // 2
			name = chapters[chapter][stageType] or chapters[chapter][0]
			if floor.xl then
				name = name .. " XL"
			else
				name = name .. ((stage % 2 == 1) and " I" or " II")
			end
		elseif stage == 9 then name = sp.blueWomb
		elseif stage == 10 then name = (stageType == 1) and sp.cathedral or sp.sheol
		elseif stage == 11 then name = (stageType == 1) and sp.chest or sp.darkRoom
		elseif stage == 12 then name = sp.void
		elseif stage == 13 then name = sp.home
		end
	end

	name = name or (sp.unknown .. tostring(stage))
	if floor.ascent then name = name .. sp.ascent end
	return name
end

----------------------------------------------------------------------
-- 界面文字
----------------------------------------------------------------------
Names.Text = {
	zh = {
		title = "对局记录",
		empty = "还没有对局记录，打完一局后再来看看吧！",
		win = "胜利", death = "死亡", quit = "放弃", running = "进行中",
		character = "角色", seed = "种子", result = "结果", mode = "模式",
		time = "用时", date = "日期",
		finalBoss = "最终击败", noBoss = "无",
		diedAt = "止步于", reached = "到达",
		finalItems = "最终道具", currentItems = "当前道具",
		startItems = "初始道具",
		floorHeader = "楼层 / 用时", itemHeader = "获得道具", bossHeader = "击败 Boss",
		noItems = "-",
		normal = "普通", hard = "困难", greed = "贪婪", greedier = "更贪婪",
		challenge = "挑战 #",
		partial = "（中途记录）",
		more = "+%d",
		hSelect = "选择", hDetails = "查看详情", hClose = "关闭",
		hScroll = "滚动", hSwitch = "切换对局", hBack = "返回",
		devil = "恶魔房", angel = "天使房", dealEntered = "已进入", dealSkipped = "未进入", floorTime = "用时",
		hItems = "道具名称",
		killedBy = "死因", unknownEnemy = "未知敌人",
		k_curseDoor = "诅咒房门", k_spikes = "尖刺", k_spikedChest = "尖刺箱子", k_pit = "坑",
		k_self = "自伤", k_ownBomb = "自己的炸弹", k_explosion = "爆炸", k_fire = "火焰",
		k_poop = "大便", k_crush = "碾压", k_timer = "时间耗尽",
		menuEntry = "对局记录",
		unknownBoss = "未知 Boss",
		cleared = "已清空对局记录",
	},
	en = {
		title = "Run History",
		empty = "No runs recorded yet. Finish a run and check back!",
		win = "Victory", death = "Death", quit = "Abandoned", running = "In progress",
		character = "Character", seed = "Seed", result = "Result", mode = "Mode",
		time = "Time", date = "Date",
		finalBoss = "Last boss", noBoss = "None",
		diedAt = "Died in", reached = "Reached",
		finalItems = "Final items", currentItems = "Current items",
		startItems = "Starting items",
		floorHeader = "Floor / time", itemHeader = "Items obtained", bossHeader = "Boss defeated",
		noItems = "-",
		normal = "Normal", hard = "Hard", greed = "Greed", greedier = "Greedier",
		challenge = "Challenge #",
		partial = " (partial)",
		more = "+%d",
		hSelect = "Select", hDetails = "Details", hClose = "Close",
		hScroll = "Scroll", hSwitch = "Switch run", hBack = "Back",
		devil = "Devil", angel = "Angel", dealEntered = "entered", dealSkipped = "skipped", floorTime = "Time",
		hItems = "Item names",
		killedBy = "Killed by", unknownEnemy = "Unknown enemy",
		k_curseDoor = "Curse room door", k_spikes = "Spikes", k_spikedChest = "Spiked chest", k_pit = "Pit",
		k_self = "Self-damage", k_ownBomb = "Own bomb", k_explosion = "Explosion", k_fire = "Fire",
		k_poop = "Poop", k_crush = "Crushed", k_timer = "Out of time",
		menuEntry = "Run History",
		unknownBoss = "Unknown boss",
		cleared = "Run history cleared",
	},
}

----------------------------------------------------------------------
-- 用游戏官方名称覆盖上面的手写名称（rh_names_data.lua 由游戏自带的本地化表生成）
----------------------------------------------------------------------
local data = RunHistory and RunHistory.NamesData
if type(data) == "table" then
	for id, pair in pairs(data.players or {}) do
		Names.Players.en[id] = pair[1]
		Names.Players.zh[id] = pair[2]
	end
	for id, pair in pairs(data.bosses or {}) do
		Names.Bosses.en[id] = pair[1]
		Names.Bosses.zh[id] = pair[2]
	end
	Names.Items = data.items -- [道具ID] = { 英文名, 中文名 }
end

return Names

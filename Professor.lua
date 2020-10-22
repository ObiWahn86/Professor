local _VERSION = GetAddOnMetadata('Professor', 'version')

local addon	= LibStub("AceAddon-3.0"):NewAddon("Professor", "AceConsole-3.0", "AceEvent-3.0")
_G.Professor = addon

-- Returns true if the player has the archaeology secondary skill
local function HasArchaeology()
	local _, _, arch = _G.GetProfessions()
	return arch
end

function addon:OnInitialize() -- ADDON_LOADED
	addon:RegisterChatCommand("prof", "SlashProcessorFunction")
	addon:LoadOptions()
end

function addon:OnEnable() -- PLAYER_LOGIN
	if HasArchaeology() then
		local loaded, reason = _G.LoadAddOn("Blizzard_ArchaeologyUI")
		if loaded then
			addon:RegisterEvent("RESEARCH_ARTIFACT_HISTORY_READY", "OnArtifactHistoryReady")
			addon:RegisterEvent("RESEARCH_ARTIFACT_UPDATE", "OnArtifactUpdate")
			addon:RegisterEvent("PLAYER_LOGOUT", "SaveOptions")
			addon:BuildFrame()
			addon:CreateOptionsFrame()
			self:SetHide(Professor.options.hide)
		else
			self:SetHide(true)
		end
	end
end

Professor.races = nil
Professor.UIFrame = nil
Professor.detailedframe = {}

Professor.COLOURS = {
	text     = '|cffaaaaaa',
	common   = '|cffffffff',
	rare     = '|cff66ccff',
	pristine = '|cff33ff99',
	total    = '|cffffffff',
}

Professor.Race = {}
Professor.Artifact = {}

function Professor.Race:new(id, name, icon, raceItemID)
	local o = {
		id = id,
		name = name,
		icon = icon,
		raceItemID = raceItemID,

		totalCommon = 0,
		totalRare = 0,
		totalPristine = 0,

		completedCommon = 0,
		completedRare = 0,
		completedPristine = 0,
		totalSolves = 0,

		artifacts = {},

		GetString = function(self)
			return string.format("|T%s:0:0:0:0:64:64:0:38:0:38|t %s%s|r", self.icon, _G['ORANGE_FONT_COLOR_CODE'], self.name)
		end,

		AddArtifact = function(self, name, icon, spellId, itemId, rare, fragments, questId)
			local anArtifact = Professor.Artifact:new(name, icon, spellId, itemId, rare, fragments, questId)

			if anArtifact.rare then
				self.totalRare = self.totalRare + 1
			else
				self.totalCommon = self.totalCommon + 1
			end

			if anArtifact.pristineId then
				self.totalPristine = self.totalPristine + 1
			end

			-- We can't identify artifacts by name, because in some locales the spell and artifact names are slightly different, and we can't use GetItemInfo because it's unreliable
			self.artifacts[icon] = anArtifact
		end,

		UpdateHistory = function(self)
			local artifactIndex = 1
			local done = false

			self.completedCommon = 0
			self.completedRare = 0
			self.completedPristine = 0
			self.totalSolves = 0

			repeat
				local name, description, rarity, icon, spellDescription,  _, _, firstCompletionTime, completionCount = GetArtifactInfoByRace(self.id, artifactIndex)

				artifactIndex = artifactIndex + 1
				if name then
--					icon = string.upper(icon)
					if completionCount > 0 then
						if self.artifacts[icon] then
							self.artifacts[icon].firstCompletionTime = firstCompletionTime
							self.artifacts[icon].solves = completionCount
						--[===[@alpha@
						else
							addon:Print("Artifact missing from database: "..icon)
						--@end-alpha@]===]
						end

						if rarity == 0 then
							self.completedCommon = self.completedCommon + 1
						else
							self.completedRare = self.completedRare + 1
						end

						self.totalSolves = self.totalSolves + completionCount
					end
					if self.artifacts[icon] and self.artifacts[icon].pristineId then
						self.artifacts[icon].pristineSolved = IsQuestFlaggedCompleted(self.artifacts[icon].pristineId);
						if self.artifacts[icon].pristineSolved then
							self.completedPristine = self.completedPristine + 1
						end
					end
				else
					done = true
				end
			until done
		end,
	}

	setmetatable(o, self)
	self.__index = self
	return o
end

function Professor.Artifact:new(name, icon, spellId, itemId, rare, fragments, questId)
	local o = {
		name = name,
		icon = icon,
		spellId = spellId,
		itemId = itemId,
		rare = rare,
		fragments = fragments,

		firstCompletionTime = nil,
		solves = 0,

		pristineId = questId,
		pristineSolved = false,

		getLink = function(self)
			local name, link = GetItemInfo(self.itemId)
			if (link == nil) then
				link = GetSpellLink(self.spellId)
			end

			return "|T"..self.icon..":0|t "..link
		end
	}

	setmetatable(o, self)
	self.__index = self
	return o
end

function addon:LoadRaces()
	local raceCount = GetNumArchaeologyRaces()
	self.races = {}

	for raceIndex = 1, raceCount do
		local raceName, raceTexture, raceItemID = GetArchaeologyRaceInfo(raceIndex)

		local aRace = Professor.Race:new(raceIndex, raceName, raceTexture, raceItemID)

		if (Professor.artifactDB[aRace.raceItemID]) then
			for i, artifact in ipairs( Professor.artifactDB[aRace.raceItemID] ) do
				local itemId, spellId, rarity, fragments, questId, icon = unpack(artifact)
				local name = GetSpellInfo(spellId)

				-- icon = string.gsub(string.upper(GetFileName(GetSpellTexture(spellId))), ".BLP", "")
				icon = GetFileIDFromPath(icon)
				aRace:AddArtifact(name, icon, spellId, itemId, (rarity == 1), fragments, questId)
			end
		end

		self.races[raceIndex] = aRace
	end
end

function addon:UpdateHistory()
	for raceIndex, race in pairs(self.races) do
		race:UpdateHistory()
	end
end

local function PrintDetailed(raceId)
	if not raceId then
		addon:Print("Please specify a Race ID to print a detailed summary of.")
		return
	end
	local race = addon.races[raceId]

	print()
	print(race:GetString())

	local incomplete, rare, therest = {}, {}, {}

	for icon, artifact in pairs(race.artifacts) do
		local link = GetSpellLink(artifact.spellId)

		if artifact.solves == 0 then
			table.insert(incomplete, "  |cffaa3333×|r  " .. link )
		elseif artifact.rare then
			table.insert(rare, "  |cff3333aa+|r  " .. link )
		else
			table.insert(therest, "  |cff33aa33+|r  " .. link .. addon.COLOURS.text .. "×" .. artifact.solves .. "|r" )
		end
	end

	for _, artifactString in ipairs(incomplete) do print(artifactString) end
	for _, artifactString in ipairs(rare) do print(artifactString) end
	for _, artifactString in ipairs(therest) do print(artifactString) end
end

local function PrintSummary()
	totalSolves = 0

	for id, race in pairs(addon.races) do
		if race.totalCommon > 0 or race.totalRare > 0 then
			totalSolves = race.totalSolves + totalSolves

			print( string.format("%s|r%s: %s%d%s/%s%d|r%s, %s%d%s/%s%d|r%s, %s%d%s/%s%d|r%s — %s%d|r%s total",
				race:GetString(),
				addon.COLOURS.text,
				addon.COLOURS.common, race.completedCommon,
				addon.COLOURS.text,
				addon.COLOURS.common, race.totalCommon,
				addon.COLOURS.text,
				addon.COLOURS.rare, race.completedRare,
				addon.COLOURS.text,
				addon.COLOURS.rare, race.totalRare,
				addon.COLOURS.text,
				addon.COLOURS.pristine, race.completedPristine,
				addon.COLOURS.text,
				addon.COLOURS.pristine, race.totalPristine,
				addon.COLOURS.text,
				addon.COLOURS.total, race.totalSolves, addon.COLOURS.text
		) )
		end
	end

	print("Total Solves: " .. totalSolves)
end

-- Code snippet stolen from GearGuage by Torhal and butchered by Ackis
local function StrSplit(input)
	if not input then
		return nil, nil
	end
	local arg1, arg2, var1

	arg1, var1 = input:match("^([^%s]+)%s*(.*)$")
	arg1 = (arg1 and arg1:lower() or input:lower())

	if var1 then
		local var2
		arg2, var2 = var1:match("^([^%s]+)%s*(.*)$")
		arg2 = (arg2 and arg2:lower() or var1:lower())
	end
	return arg1, arg2
end

function addon:SlashProcessorFunction(input)
	local _, _, hasArchaeology = GetProfessions()
	if not hasArchaeology then
		addon:Print("You do not have Archaeology learned as a secondary profession.")
		return
	end

	local arg1, arg2 = StrSplit(input)

	-- No arguments, print off summary
	if not arg1 or (arg1 and arg1:trim() == "") then
		addon:Print("Acceptable commands are: detailed, show, hide, toggle, help")
		self.action = PrintSummary
		RequestArtifactCompletionHistory()
	-- First arg is detailed, second is the race number, print off detailed summary for that
	elseif arg1 == "detailed" or arg1 == "Detailed" then
		local raceId = tonumber(arg2)
		self.action = function () PrintDetailed(raceId) end
		RequestArtifactCompletionHistory()
	elseif arg1 == "show" or arg1 == "Show" then
		addon:SetHide(false)
	elseif arg1 == "hide" or arg1 == "Hide" then
		addon:SetHide(true)
	elseif arg1 == "toggle" or arg1 == "Toggle" then
		addon:ToggleHide()
	elseif arg1 == "help" or arg1 == "Help" then
		addon:Print("Professor will display detailed information about what archaeology solves you have completed and are missing.")
		addon:Print("Acceptable slash commands are: ")
		addon:Print("None - Prints out a summary by type of the total number of solves you have completed.")
		addon:Print("Detailed X - Where X is from 1 to 15, it will print out detailed information about that specific race.  E.G. /prof detailed 2 will print out detailed information about Draenei solves.")
		addon:Print("Show - Shows the GUI.")
		addon:Print("Hide - Hides the GUI.")
		addon:Print("Toggle - Toggles the display of the GUI.")
		addon:Print("Help - This help screen.")
	end
end

-- { [raceKeystoneItemID] = { { itemId, spellId, rarity, fragments, questId, icon }, ... }, ... }
Professor.artifactDB = {
	-- Dwarf
	[52843] = {
		{  64373,  90553, 1, 100,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_CHALICE OF MOUNTAINKINGS' },  -- Chalice of the Mountain Kings
		{  64372,  90521, 1, 100,   nil, 'INTERFACE\\ICONS\\INV_MISC_HEAD_CLOCKWORKGNOME_01' },  -- Clockwork Gnome
		{  64489,  91227, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_STAFFOFSORCERER_THAN THAURISSAN' },  -- Staff of Sorcerer-Thane Thaurissan
		{  64488,  91226, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_THEINNKEEPERSDAUGHTER' },  -- The Innkeeper's Daughter

		{  63113,  88910, 0,  34,   nil, 'INTERFACE\\ICONS\\INV_BELT_40A' },  -- Belt Buckle with Anvilmar Crest
		{  64339,  90411, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SILVERDOORKNOCKER OF FEMALE DWARF' },  -- Bodacious Door Knocker
		{  63112,  86866, 0,  32,   nil, 'INTERFACE\\ICONS\\INV_MISC_DICE_02' },  -- Bone Gaming Dice
		{  64340,  90412, 0,  34,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_DECORATED LEATHER BOOT HEEL' },  -- Boot Heel with Scrollwork
		{  63409,  86864, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_MISC_URN_01' },  -- Ceramic Funeral Urn
		{  64362,  90504, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_DENTEDSHIELD' },  -- Dented Shield of Horuz Killcrow
		{  66054,  93440, 0,  30,   nil, 'INTERFACE\\ICONS\\INV_BOOTS_CLOTH_14' },  -- Dwarven Baby Socks
		{  64342,  90413, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_GOLDCHAMBERPOT' },  -- Golden Chamber Pot
		{  64344,  90419, 0,  36,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_STONESHIELD' },  -- Ironstar's Petrified Shield
		{  64368,  90518, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_MITHRILNECKLACE' },  -- Mithril Chain of Angerforge
		{  63414,  89717, 0,  34,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_GEMMEDDRINKINGCUP' },  -- Moltenfist's Jeweled Goblet
		{  64337,  90410, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_NOTCHEDSWORD' },  -- Notched Sword of Tunadil the Redeemer
		{  63408,  86857, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_MISC_BEER_01' },  -- Pewter Drinking Cup
		{  64659,  91793, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MISC_PIPE_01' },  -- Pipe of Franclorn Forgewright
		{  64487,  91225, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_JEWELEDDWARFSCEPTER' },  -- Scepter of Bronzebeard
		{  64367,  90509, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SPINEDQUILLBOARSCEPTER' },  -- Scepter of Charlga Razorflank
		{  64366,  90506, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_BLACKENEDSTAFF' },  -- Scorched Staff of Shadow Priest Anund
		{  64483,  91219, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SILVERDAGGER' },  -- Silver Kris of Korl
		{  63411,  88181, 0,  34,   nil, 'INTERFACE\\ICONS\\INV_JEWELRY_NECKLACE_07' },  -- Silver Neck Torc
		{  64371,  90519, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SKULLSTAFF' },  -- Skull Staff of Shadowforge
		{  64485,  91223, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_QIRAJ_HILTSPIKED' },  -- Spiked Gauntlets of Anvilrage
		{  63410,  88180, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_CARVED WILDHAMMER GRYPHON FIGURINE' },  -- Stone Gryphon
		{  64484,  91221, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MACE_81' },  -- Warmaul of Burningeye
		{  64343,  90415, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_WINGEDHELM' },  -- Winged Helm of Corehammer
		{  63111,  88909, 0,  28,   nil, 'INTERFACE\\ICONS\\ABILITY_HUNTER_BEASTCALL' },  -- Wooden Whistle
		{  64486,  91224, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MISC_PEARLRING2' },  -- Word of Empress Zoe
		{  63110,  86865, 0,  30,   nil, 'INTERFACE\\ICONS\\INV_SWORD_110' },  -- Worn Hunting Knife
	},
	-- Troll
	[63128] = {
		{  64377,  90608, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_ZINROKH SWORD' },  -- Zin'rokh, Destroyer of Worlds
		{  69824,  98588, 1, 100,   nil, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_TROLLGOLEM' },  -- Voodoo Figurine
		{  69777,  98556, 1, 100,   nil, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_TROLLDRUM' },  -- Haunted War Drum

		{  64348,  90429, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_TROLLBATSCEPTER' },  -- Atal'ai Scepter
		{  64346,  90421, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_MISC_SILVERJADENECKLACE' },  -- Bracelet of Jade and Coins
		{  63524,  89891, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_BIJOU_RED' },  -- Cinnabar Bijou
		{  64375,  90581, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_SWORD_95' },  -- Drakkari Sacrificial Knife
		{  63523,  89890, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_ZULGURUBTRINKET' },  -- Eerie Smolderthorn Idol
		{  63413,  89711, 0,  34,   nil, 'INTERFACE\\ICONS\\INV_JEWELRY_NECKLACE_AHNQIRAJ_02' },  -- Feathered Gold Earring
		{  63120,  88907, 0,  30,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_TROLLBATIDOL' },  -- Fetish of Hir'eek
		{  66058,  93444, 0,  32,   nil, 'INTERFACE\\ICONS\\INV_SWORD_36' },  -- Fine Bloodscalp Dinnerware
		{  64347,  90423, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_WHITEHYDRAFIGURINE' },  -- Gahz'rilla Figurine
		{  63412,  89701, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_JEWELCRAFTING_JADESERPENT' },  -- Jade Asp with Ruby Eyes
		{  63118,  88908, 0,  32,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_TROLLLIZARDFOOTCHARM' },  -- Lizard Foot Charm
		{  64345,  90420, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_OFFHAND_ZULAMAN_D_01' },  -- Skull-Shaped Planter
		{  64374,  90558, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_TROLLTOOTH W GOLDFILLING' },  -- Tooth with Gold Filling
		{  63115,  88262, 0,  27,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_TROLL_VOODOODOLL' },  -- Zandalari Voodoo Doll
	},
	-- Fossil
	[0] = {
		{  69764,  98533, 1, 150,   nil, 'INTERFACE\\ICONS\\INV_SHIELD_18' },  -- Extinct Turtle Shell
		{  60955,  89693, 1,  85,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_TINYDINOSAURSKELETON' },  -- Fossilized Hatchling
		{  60954,  90619, 1, 100,   nil, 'INTERFACE\\ICONS\\ABILITY_MOUNT_FOSSILIZEDRAPTOR' },  -- Fossilized Raptor
		{  69821,  98582, 1, 120,   nil, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_BABYPTERRODAX' },  -- Pterrodax Hatchling
		{  69776,  98560, 1, 100,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_INSECT IN AMBER' },  -- Ancient Amber

		{  64355,  90452, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SHARK JAWS' },  -- Ancient Shark Jaws
		{  63121,  88930, 0,  25,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_FOSSIL_FERN' },  -- Beautiful Preserved Fern
		{  63109,  88929, 0,  31,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_BLACKTRILOBITE' },  -- Black Trilobite
		{  64349,  90432, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_MISC_MONSTERHORN_08' },  -- Devilsaur Tooth
		{  64385,  90617, 0,  33,   nil, 'INTERFACE\\ICONS\\INV_FEATHER_15' },  -- Feathered Raptor Arm
		{  64473,  91132, 0,  45,   nil, 'INTERFACE\\ICONS\\ACHIEVEMENT_BOSS_YOGGSARON_01' },  -- Imprint of a Kraken Tentacle
		{  64350,  90433, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_INSECT IN AMBER' },  -- Insect in Amber
		{  64468,  91089, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_FOSSIL_DINOSAURBONE' },  -- Proto-Drake Skeleton
		{  66056,  93442, 0,  30,   nil, 'INTERFACE\\ICONS\\INV_MISC_FOOD_155_FISH_78' },  -- Shard of Petrified Wood
		{  66057,  93443, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_INSCRIPTION_PIGMENT_BUG07' },  -- Strange Velvet Worm
		{  63527,  89895, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_FOSSIL_SNAILSHELL' },  -- Twisted Ammonite Shell
		{  64387,  90618, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_MISC_FISH_83' },  -- Vicious Ancient Fish
	},
	-- Night Elf
	[63127] = {
		{  64646,  91761, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_BONES OF TRANSFORMATION' },  -- Bones of Transformation
		{  64361,  90493, 1, 100,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_DRUIDPRIESTSTATUESET' },  -- Druid and Priest Statue Set
		{  64358,  90464, 1, 100,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_HIGHBORNESOULMIRROR' },  -- Highborne Soul Mirror
		{  64383,  90614, 1,  98,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_KALDOREIWINDCHIMES' },  -- Kaldorei Wind Chimes
		{  64643,  90616, 1, 100,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_QUEENAZSHARA DRESSINGGOWN' },  -- Queen Azshara's Dressing Gown
		{  64645,  91757, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_TYRANDESFAVORITEDOLL' },  -- Tyrande's Favorite Doll
		{  64651,  91773, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_WISPAMULET' },  -- Wisp Amulet

		{  64647,  91762, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MISC_FORESTNECKLACE' },  -- Carcanet of the Hundred Magi
		{  64379,  90610, 0,  34,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_CHESTOFTINYGLASSANIMALS' },  -- Chest of Tiny Glass Animals
		{  63407,  89696, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_ANTLEREDCLOAKCLASP' },  -- Cloak Clasp with Antlers
		{  63525,  89893, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_MISC_ELVENCOINS' },  -- Coin from Eldre'Thalas
		{  64381,  90611, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_CRACKEDCRYSTALVIAL' },  -- Cracked Crystal Vial
		{  64357,  90458, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_DELICATEMUSICBOX' },  -- Delicate Music Box
		{  63528,  89896, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_JEWELRY_RING_41' },  -- Green Dragon Ring
		{  64356,  90453, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_HAIRPINSILVERMALACHITE' },  -- Hairpin of Silver and Malachite
		{  63129,  89009, 0,  30,   nil, 'INTERFACE\\ICONS\\INV_INSCRIPTION_INKPURPLE02' },  -- Highborne Pyxis
		{  63130,  89012, 0,  30,   nil, 'INTERFACE\\ICONS\\INV_MISC_COMB_01' },  -- Inlaid Ivory Comb
		{  64354,  90451, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_ALCHEMY_IMBUEDVIAL' },  -- Kaldorei Amphora
		{  66055,  93441, 0,  30,   nil, 'INTERFACE\\ICONS\\INV_JEWELRY_NECKLACE_11' },  -- Necklace with Elune Pendant
		{  63131,  89014, 0,  30,   nil, 'INTERFACE\\ICONS\\INV_FABRIC_MAGEWEAVE_01' },  -- Scandalous Silk Nightgown
		{  64382,  90612, 0,  35,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_BLOODYSATYRSCEPTER' },  -- Scepter of Xavius
		{  63526,  89894, 0,  35,   nil, 'INTERFACE\\ICONS\\ABILITY_UPGRADEMOONGLAIVE' },  -- Shattered Glaive
		{  64648,  91766, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SILVERSCROLLCASE' },  -- Silver Scroll Case
		{  64378,  90609, 0,  35,   nil, 'INTERFACE\\ICONS\\INV_JEWELRY_NECKLACE_10' },  -- String of Small Pink Pearls
		{  64650,  91769, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_THROWINGCHAKRUM_01' },  -- Umbra Crescent
	},
	-- Orc
	[64392] = {
		{  64644,  90843, 1, 130,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_ANCIENTORCSHAMANHEADDRESS' },  -- Headdress of the First Shaman

		{  64436,  90831, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MISC_CROP_01' },  -- Fiendish Whip
		{  64421,  90734, 0,  45,   nil, 'INTERFACE\\ICONS\\ABILITY_MOUNT_WHITEDIREWOLF' },  -- Fierce Wolf Figurine
		{  64418,  90728, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_CANDLESTUB' },  -- Gray Candle Stub
		{  64417,  90720, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_OGRE2HANDEDHAMMER' },  -- Maul of Stone Guard Mur'og
		{  64419,  90730, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_RUSTEDSTEAKKNIFE' },  -- Rusted Steak Knife
		{  64420,  90732, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_BLADEDORCSCEPTER' },  -- Scepter of Nekros Skullcrusher
		{  64438,  90833, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SKULLMUG' },  -- Skull Drinking Cup
		{  64437,  90832, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MISC_STONETABLET_03' },  -- Tile of Glazed Clay
		{  64389,  90622, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_TINYBRONZESCORPION' },  -- Tiny Bronze Scorpion
	},
	-- Draenei
	[64394] = {
		{  64456,  90983, 1, 124,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_NAARUCRYSTAL' },  -- Arrival of the Naaru
		{  64457,  90984, 1, 130,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_DRAENEIRELIC' },  -- The Last Relic of Argus

		{  64440,  90853, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MISC_VINERING' },  -- Anklet with Golden Bells
		{  64453,  90968, 0,  46,   nil, 'INTERFACE\\ICONS\\INV_MISC_QUIVER_05' },  -- Baroque Sword Scabbard
		{  64442,  90860, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_CARVED HARP OF EXOTIC WOOD' },  -- Carved Harp of Exotic Wood
		{  64455,  90975, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_DIGNIFIED DRAENEI PORTRAIT' },  -- Dignified Portrait
		{  64454,  90974, 0,  44,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_DRAENEI CANDELABRA' },  -- Fine Crystal Candelabra
		{  64458,  90987, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_SPEAR_01' },  -- Plated Elekk Goad
		{  64444,  90864, 0,  46,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_BURNINGDEMONSCEPTER' },  -- Scepter of the Nathrezim
		{  64443,  90861, 0,  46,   nil, 'INTERFACE\\ICONS\\INV_STONE_16' },  -- Strange Silver Paperweight
	},
	-- Vrykul
	[64395] = {
		{  64460,  90997, 1, 130,   nil, 'INTERFACE\\ICONS\\INV_AXE_97' },  -- Nifflevar Bearded Axe
		{  69775,  98569, 1, 100,   nil, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_VRYKULDRINKINGHORN' },  -- Vrykul Drinking Horn

		{  64464,  91014, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_JEWELRY_TRINKET_01' },  -- Fanged Cloak Pin
		{  64462,  91012, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_STONE_GRINDINGSTONE_02' },  -- Flint Striker
		{  64459,  90988, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MISC_KEY_07' },  -- Intricate Treasure Chest Key
		{  64461,  91008, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_SWORD_118' },  -- Scramseax
		{  64467,  91084, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MISC_THORNNECKLACE' },  -- Thorned Necklace
	},
	-- Nerubian
	[64396] = {
		{  64481,  91214, 1, 140,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_OLDGODTRINKET' },  -- Blessing of the Old God
		{  64482,  91215, 1, 140,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_CTHUNSPUZZLEBOX' },  -- Puzzle Box of Yogg-Saron

		{  64479,  91209, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_POTION_100' },  -- Ewer of Jormungar Blood
		{  64477,  91191, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MISC_ORNATEBOX' },  -- Gruesome Heart Box
		{  64476,  91188, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MISC_RUBYSTAR' },  -- Infested Ruby Ring
		{  64475,  91170, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_NERUBIANSPIDERSCEPTER' },  -- Scepter of Nezar'Azret
		{  64478,  91197, 0,  45,   nil, 'INTERFACE\\ICONS\\ACHIEVEMENT_DUNGEON_AZJOLLOWERCITY_25MAN' },  -- Six-Clawed Cornice
		{  64474,  91133, 0,  45,   nil, 'INTERFACE\\ICONS\\INV_MISC_POCKETWATCH_03' },  -- Spidery Sundial
		{  64480,  91211, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_AQIR_HIEROGLYPHIC' },  -- Vizier's Scrawled Streamer
	},
	-- Tol'vir
	[64397] = {
		{  60847,  92137, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SHRIVELEDMONKEYPAW' },  -- Crawling Claw
		{  64881,  92145, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_PENDANT OF THE AQIR' },  -- Pendant of the Scarab Storm
		{  64904,  92168, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_RING OF THE BOYEMPEROR' },  -- Ring of the Boy Emperor
		{  64883,  92148, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SCEPTOR OF AZAQIR' },  -- Scepter of Azj'Aqir
		{  64885,  92163, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SCIMITAR OF THE SIROCCO' },  -- Scimitar of the Sirocco
		{  64880,  92139, 1, 150,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_STAFF OF AMMUNRAE' },  -- Staff of Ammunae

		{  64657,  91790, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_ULDUMCANOPICJAR' },  -- Canopic Jar
		{  64652,  91775, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SAND CASTLE' },  -- Castle of Sand
		{  64653,  91779, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_CATSTATUEEMERALDEYES' },  -- Cat Statue with Emerald Eyes
		{  64656,  91785, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_ENGRAVEDSCIMITARPOMMEL' },  -- Engraved Scimitar Hilt
		{  64658,  91792, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SKETCHDESERTPALACE' },  -- Sketch of a Desert Palace
		{  64654,  91780, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_SOAPSTONESCARABNECKLACE' },  -- Soapstone Scarab Necklace
		{  64655,  91782, 0,  45,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_TINYOASISMOSAIC' },  -- Tiny Oasis Mosaic
	},
	-- Pandaren
	[79868] = {
		{  89685, 113981, 1, 180,   nil, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_SPEAROFXUEN' },  -- Spear of Xuen
		{  89684, 113980, 1, 180,   nil, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_UMBRELLAOFCHIJI' },  -- Umbrella of Chi-Ji

		{  79903, 113977, 0,  50, 31802, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_APOTHECARYTINS' },  -- Apothecary Tins
		{  79901, 113975, 0,  50, 31800, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_CARVEDBRONZEMIRROR' },  -- Carved Bronze Mirror
		{  79897, 113971, 0,  50, 31796, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_CHANGKIBOARD' },  -- Panderan Game Board
		{  79900, 113974, 0,  50, 31799, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_EMPTYKEGOFBREWFATHERXINWOYIN' },  -- Empty Keg of Brewfather Xin Wo Yin
		{  79902, 113976, 0,  50, 31801, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_GOLDINLAIDPORCELAINFUNERARYFIGURINE' },  -- Gold-Inlaid Porecelain Funerary Figurine
		{  79904, 113978, 0,  50, 31803, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_PEARLOFYULON' },  -- Pearl of Yu'lon
		{  79905, 113979, 0,  50, 31804, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_STANDARDOFNUZAO' },  -- Standard  of Niuzao
		{  79898, 113972, 0,  50, 31797, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_TWINSTEINSETOFBREWFATHERQUANTOUKUO' },  -- Twin Stein Set of Brewfather Quan Tou Kuo
		{  79899, 113973, 0,  50, 31798, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_WALKINGCANEOFBREWFATHERRENYUN' },  -- Walking Cane of Brewfather Ren Yun
		{  79896, 113968, 0,  50, 31795, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_PANDARENTEASET' },  -- Pandaren Tea Set
	},
	-- Mogu
	[79869] = {
		{  89614, 113993, 1, 180,   nil, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_ANATOMICALDUMMY' },  -- Anatomical Dummy
		{  89611, 113992, 1, 180,   nil, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_QUILENSTATUETTE' },  -- Quilen Statuette

		{  79909, 113983, 0,  50, 31787, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_CRACKEDMOGURUNESTONE' },  -- Cracked Mogu Runestone
		{  79913, 113987, 0,  50, 31791, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_EDICTSOFTHETHUNDERKING' },  -- Edicts of the Thunder King
		{  79914, 113988, 0,  50, 31792, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_IRONAMULET' },  -- Iron Amulet
		{  79908, 113982, 0,  50, 31786, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_MANACLESOFREBELLION' },  -- Manacles of Rebellion
		{  79916, 113990, 0,  50, 31794, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_MOGUCOIN' },  -- Mogu Coin
		{  79911, 113985, 0,  50, 31789, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_PETRIFIEDBONEWHIP' },  -- Petrified Bone Whip
		{  79910, 113984, 0,  50, 31788, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_TERRACOTTAARM' },  -- Terracotta Arm
		{  79912, 113986, 0,  50, 31790, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_THUNDERKINGINSIGNIA' },  -- Thunder King Insignia
		{  79915, 113989, 0,  50, 31793, 'INTERFACE\\ICONS\\ARCHAEOLOGY_5_0_WARLORDSBRANDINGIRON' },  -- Warlord's Branding Iron
		{  79917, 113991, 0,  50, 31805, 'INTERFACE\\ICONS\\ABILITY_WARLOCK_ANCIENTGRIMOIRE' },  -- Worn Monument Ledger
	},
	-- Mantid
	[95373] = {
		{  95391, 139786, 1, 180,   nil, 'INTERFACE\\ICONS\\INV_SWORD_1H_MANTIDARCH_C_01' },  -- Mantid Sky Reaver
		{  95392, 139787, 1, 180,   nil, 'INTERFACE\\ICONS\\INV_FIREARM_2H_RIFLE_ARCHAEOLOGY_D_01' },  -- Sonic Pulse Generator

		{  95375, 139776, 0,  50, 32686, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_MANTIDBANNER_01' },  -- Banner of the Mantid Empire
		{  95376, 139779, 0,  50, 32687, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_MANTIDFEEDINGDEVICE_01' },  -- Ancient Sap Feeder
		{  95377, 139780, 0,  50, 32688, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_MANTIDSTATUE_01' },  -- The Praying Mantid
		{  95378, 139781, 0,  50, 32689, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_MANTIDCELLTOWERUNGEMMED_01' },  -- Inert Sound Beacon
		{  95379, 139782, 0,  50, 32690, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_MANTIDHEAD_01' },  -- Remains of a Paragon
		{  95380, 139783, 0,  50, 32691, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_MANTIDLAMPPOST_01' },  -- Mantid Lamp
		{  95381, 139784, 0,  50, 32692, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_MANTIDPOLLENCOLLECTOR_01' },  -- Pollen Collector
		{  95382, 139785, 0,  50, 32693, 'INTERFACE\\ICONS\\INV_MISC_ARCHAEOLOGY_MANTIDBASKET_01' },  -- Kypari Sap Container
	},
	-- Ogre
	[109584] = {
		{ 117385, 168319, 1, 150,   nil, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_SORCERER_KING_TOE_RING' },  -- Sorcerer-King Toe Ring
		{ 117384, 168320, 1, 200,   nil, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_WARMAUL_CHIEFTAIN' },  -- Warmaul of the Warmaul Chieftain

		{ 114191, 168315, 0,  70, 36767, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_HARGUNN_EYE' },  -- Eye of Har'gunn the Blind
		{ 114189, 168313, 0,  50, 36765, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_GLADIATOR_SHIELD' },  -- Gladiator's Shield
		{ 114190, 168314, 0,  55, 36766, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_MORTARPESTLE' },  -- Mortar and Pestle
		{ 114185, 168311, 0,  45, 36763, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_FIGURINE' },  -- Ogre Figurine
		{ 114187, 168312, 0,  55, 36764, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_PICTOGRAM_TABLET' },  -- Pictogram Carving
		{ 114194, 168318, 0,  45, 36770, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_IMPERIAL_DECREE_STELE' },  -- Imperial Decree Stele
		{ 114193, 168317, 0,  55, 36769, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_CHIMERA_RIDING_HARNESS' },  -- Rylak Riding Harness
		{ 114192, 168316, 0,  50, 36768, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_IRONGOB' },  -- Stone Dentures
		{ 114183, 168310, 0,  55, 36762, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_STONE_MANACLES' },  -- Stone Manacles
		{ 114181, 168309, 0,  40, 36761, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_OGRES_STONEMAUL_SUCCESSION_STONE' },  -- Stonemaul Succession Stone
	},
	-- Draenor Clans
	[108439] = {
		{ 117380, 172466, 1, 175,   nil, 'INTERFACE\\ICONS\\INV_JEWELRY_FROSTWOLFTRINKET_02' },  -- Ancient Frostwolf Fang
		{ 116985, 172459, 1, 180,   nil, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_ANCIENTORCSHAMANHEADDRESS' },  -- Headdress of the First Shaman

		{ 114171, 168305, 0,  55, 36756, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_TALISMAN' },  -- Ancestral Talisman
		{ 114163, 168301, 0,  45, 36753, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_BARBEDHOOK' },  -- Barbed Fishing Hook
		{ 114157, 168298, 0,  50, 36750, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_BLACKROCKRAZOR' },  -- Blackrock Razor
		{ 114165, 168302, 0,  45, 36754, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_JAREYE' },  -- Calcified Eye In a Jar
		{ 114167, 168303, 0,  40, 36755, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_TATTOOKNIFE' },  -- Ceremonial Tattoo Needles
		{ 114169, 168304, 0,  45, 36757, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_CRACKEDIDOL' },  -- Cracked Ivory Idol
		{ 114177, 168308, 0,  40, 36760, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_DOOMSDAYTABLET' },  -- Doomsday Prophecy
		{ 114155, 168297, 0,  65, 36749, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_BELLOW' },  -- Elemental Bellows
		{ 114141, 168290, 0,  50, 36725, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_FROSTWOLFAXE' },  -- Fang-Scarred Frostwolf Axe
		{ 114173, 168306, 0,  50, 36758, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_BLAZEGREASE' },  -- Flask of Blazegrease
		{ 114143, 168291, 0,  60, 36743, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_SCRIMSHAW' },  -- Frostwolf Ancestry Scrimshaw
		{ 114161, 168300, 0,  60, 36752, 'INTERFACE\\ICONS\\INV_MISC_SKINNINGKNIFE' },  -- Hooked Dagger
		{ 114153, 168296, 0,  50, 36748, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_METALWORKERSHAMMER' },  -- Metalworker's Hammer
		{ 114175, 168307, 0,  55, 36759, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_GRONTOOTHNECKLACE' },  -- Gronn-Tooth Necklace
		{ 114147, 168293, 0,  45, 36745, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_WARSINGERSDRUMS' },  -- Warsinger's Drums
		{ 114151, 168295, 0,  60, 36747, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_WARSONGPIKE' },  -- Warsong Ceremonial Pike
		{ 114159, 168299, 0,  45, 36751, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_HOOKEDDAGGER' },  -- Weighted Chopping Axe
		{ 114145, 168292, 0,  45, 36744, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_ORCCLANS_SNOWSHOE' },  -- Wolfskin Snowshoes
		{ 114149, 168294, 0,  55, 36746, 'INTERFACE\\ICONS\\INV_BULLROARER' },  -- Screaming Bullroarer
	},
	-- Arakkoa
	[109585] = {
		{ 117354, 172460, 1, 250,   nil, 'INTERFACE\\ICONS\\ABILITY_SKYREACH_EMPOWERED' },  -- Ancient Nest Guardian
		{ 117382, 168331, 1, 190,   nil, 'INTERFACE\\ICONS\\INV_MACE_1H_ARAKKOA_C_01' },  -- Beakbreaker of Terokk

		{ 114204, 168328, 0,  70, 36778, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_APEXISCRYSTAL' },  -- Apexis Crystal
		{ 114205, 168329, 0,  65, 36779, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_APEXISHIEROGLYPH' },  -- Apexis Hieroglyph
		{ 114206, 168330, 0,  50, 36780, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_APEXISSCROLL' },  -- Apexis Scroll
		{ 114198, 168322, 0,  55, 36772, 'INTERFACE\\ICONS\\INV__WOD_ARAKOA6' },  -- Burial Urn
		{ 114199, 168323, 0,  50, 36773, 'INTERFACE\\ICONS\\INV__WOD_ARAKOA5' },  -- Decree Scrolls
		{ 114197, 168321, 0,  45, 36771, 'INTERFACE\\ICONS\\INV__WOD_ARAKOA1' },  -- Dreamcatcher
		{ 114203, 168327, 0,  45, 36777, 'INTERFACE\\ICONS\\TRADE_ARCHAEOLOGY_OUTCASTDREAMCATCHER' },  -- Outcast Dreamcatcher
		{ 114200, 168324, 0,  45, 36774, 'INTERFACE\\ICONS\\INV__WOD_ARAKOA4' },  -- Solar Orb
		{ 114201, 168325, 0,  60, 36775, 'INTERFACE\\ICONS\\INV__WOD_ARAKOA3' },  -- Sundial
		{ 114202, 168326, 0,  50, 36776, 'INTERFACE\\ICONS\\INV__WOD_ARAKOA2' },  -- Talonpriest Mask
	},
	-- Highborne
	[130903] = {
		{ 130907, 196471, 0,  45, 40350, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_HIGHBORNE_INERTLEYSTONECHARM' },  -- Inert Leystone Charm
		{ 130910, 196474, 0, 100, 40353, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_HIGHBORNE_NOBLEMANSLETTEROPENER' },  -- Nobleman's Letter Opener
		{ 130909, 196473, 0, 120, 40352, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_HIGHBORNE_PREWARTAPESTRY' },  -- Pre-War Highborne Tapestry
		{ 130908, 196472, 0,  50, 40351, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_HIGHBORNE_VIALOFPOISON' },  -- Quietwine Vial
		{ 130906, 196470, 0,  35, 40349, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_HIGHBORNE_VIOLETGLASSVESSEL' },  -- Violetglass Vessel
	},
	-- Highmountain tauren
	[130904] = {
		{ 130914, 196478, 0, 115, 40357, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_TAUREN_DROGBARGEMROLLER' },  -- Drogbar Gem-Roller
		{ 130913, 196477, 0,  50, 40356, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_TAUREN_HANDSMOOTHEDPYRESTONE' },  -- Hand-Smoothed Pyrestone
		{ 130912, 196476, 0,  30, 40355, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_TAUREN_MOOSEBONEFISHHOOK' },  -- Moosebone Fish-Hook
		{ 130915, 196479, 0, 105, 40358, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_TAUREN_STONEWOODBOW' },  -- Stonewood Bow
		{ 130911, 196475, 0,  65, 40354, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_TAUREN_DRUM' },  -- Trailhead Drum
	},
	-- Demonic
	[130905] = {
		{ 130917, 196481, 0,  85, 40360, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_DEMON_FLAYEDSKINCHRONICLE' },  -- Flayed-Skin Chronicle
		{ 130920, 196484, 0, 170, 40363, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_DEMON_HOUNDSTOOTHHAUBERK' },  -- Houndstooth Hauberk
		{ 130916, 196480, 0,  60, 40359, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_DEMON_IMPSCUP' },  -- Imp's Cup
		{ 130918, 196482, 0,  95, 40361, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_DEMON_MALFORMEDABYSSAL' },  -- Malformed Abyssal
		{ 130919, 196483, 0, 140, 40362, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_70_DEMON_ORBOFINNERCHAOS' },  -- Orb of Inner Chaos
	},
	-- Drust
	[154990] = { 
		{ 160751, 273852, 1, 150, nil, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_WITCH_DANCEOFTHEDEAD' },  -- Dance of the Dead
		{ 161089, 273854, 1, 185, nil, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_WITCH_RESTOREDREVENANT' },  -- Pile of Bones
		{ 160833, 273855, 1, 200, nil, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_WITCH_FETISHOFTHEQUESTIONINGMIND' },  -- Fetish of the Tormented Mind

		{ 154926, 257715, 0, 40, 51950, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_WITCH_GUILLOTINEAXE' },  -- Ceremonial Bonesaw
		{ 154927, 257716, 0, 50, 51951, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_WITCH_BOOK' },  -- Ancient Runebound Tome
		{ 154928, 257717, 0, 45, 51952, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_WITCH_BONESCYTHE' },  -- Disembowling Sickle
		{ 154929, 257718, 0, 35, 51953, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_WITCH_DAGGER' },  -- Jagged Blade of the Drust
		{ 154930, 257719, 0, 35, 51954, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_WITCH_SKULL' },  -- Ritual Fetish
		{ 160742, 257851, 0, 70, 51955, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_WITCH_CHEST' },  -- Soul Coffer
	},
	-- Zandalari
	[154989] = {
		{ 160740, 273815, 1, 150, nil, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_ZANDALARI_CROAKCROCK' },  -- Croak Crock
		{ 161080, 273817, 1, 185, nil, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_ZANDALARI_DIREHORNHATCHLING' },  -- Intact Direhorn Hatchling
		{ 160753, 273819, 1, 200, nil, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_ZANDALARI_SANGUINETOTEM' },  -- Sanguinating Totem

		{ 154931, 257720, 0, 35, 51926, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_ZANDALARI_BOTTLE' },  -- Akun'Jar Vase
		{ 154932, 257721, 0, 45, 51929, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_ZANDALARI_URN' },  -- Urn of Passage
		{ 154933, 257722, 0, 50, 51932, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_ZANDALARI_IDOL' },  -- Rezan Idol
		{ 154934, 257723, 0, 50, 51934, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_ZANDALARI_LEATHERHELM' },  -- High Apothecary's Hood
		{ 154935, 257724, 0, 65, 51936, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_ZANDALARI_MASK' },  -- Bwonsamdi Voodoo Mask
		{ 160744, 273812, 0, 35, 51937, 'INTERFACE\\ICONS\\INV_ARCHAEOLOGY_80_ZANDALARI_BLOWDARTGUN' },  -- Blowgun of the Sethra
	},
}

Professor.defaults = {
	hide = false,
	lock = false,
	frameRef = "CENTER",
	frameX = 0,
	frameY = 0,

	framePadding = 3,
	frameIconSize = 30,
	frameMeterSize = 40,
}

Professor.options = {}

function addon:LoadOptions()
	_G.ProfessorDB = _G.ProfessorDB or {}

	local db = _G.ProfessorDB
	local p = Professor

	Professor.options = {}
	for k,v in pairs(p.defaults) do
		if (db[k]) then
			Professor.options[k] = db[k]
		else
			Professor.options[k] = v
		end
	end
end

function addon:SaveOptions()
	local p = Professor
	local cfg = Professor.options

	local point, relativeTo, relativePoint, xOfs, yOfs = p.UIFrame:GetPoint()
	cfg.frameRef = relativePoint
	cfg.frameX = xOfs
	cfg.frameY = yOfs

	_G.ProfessorDB = cfg
end

function addon:BuildFrame()
	-- need races before we create icons
	addon:LoadRaces()
	RequestArtifactCompletionHistory()

	local cfg = Professor.options
	local p = Professor

	p.FrameWidth = (cfg.framePadding * 5) + (cfg.frameIconSize) + (cfg.frameMeterSize * 3)

	p.UIFrame = CreateFrame("Frame", nil, UIParent)
	p.UIFrame:SetFrameStrata("BACKGROUND")
	p.UIFrame:SetWidth(p.FrameWidth)
	p.UIFrame:SetHeight(100)
	p.UIFrame:SetPoint(cfg.frameRef, cfg.frameX, cfg.frameY)
	p.UIFrame:SetMovable(true)

	p.UIFrame.texture = p.UIFrame:CreateTexture()
	p.UIFrame.texture:SetAllPoints(p.UIFrame)
	p.UIFrame.texture:SetTexture(0, 0, 0, 0.5)

	p.Cover = CreateFrame("Button", nil, p.UIFrame)
	p.Cover:SetFrameLevel(100)
	p.Cover:SetAllPoints()
	addon:Mouseify(p.Cover)

	local y = cfg.framePadding

	for raceIndex, race in pairs(self.races) do
		race.iconBtn = p:CreateButton(cfg.framePadding, y, cfg.frameIconSize, cfg.frameIconSize, race.icon, raceIndex, 0)
		race.iconBtn:SetFrameLevel(101)
		race.bar1bg = p:CreateBar(cfg.framePadding + cfg.framePadding + cfg.frameIconSize, y, cfg.frameMeterSize, cfg.frameIconSize, 0.5, 0.5, 0.5, raceIndex, 1)
		race.bar1bg:SetFrameLevel(101)
		race.bar1fg = p:CreateBar(cfg.framePadding + cfg.framePadding + cfg.frameIconSize, y, cfg.frameMeterSize / 2, cfg.frameIconSize, 1, 1, 1, raceIndex, 1)
		race.bar1fg:SetFrameLevel(102)
		race.bar2bg = p:CreateBar(cfg.framePadding + cfg.framePadding + cfg.frameIconSize + cfg.framePadding + cfg.frameMeterSize, y, cfg.frameMeterSize, cfg.frameIconSize, 0.5, 0.5, 0.8, raceIndex, 2)
		race.bar2bg:SetFrameLevel(101)
		race.bar2fg = p:CreateBar(cfg.framePadding + cfg.framePadding + cfg.frameIconSize + cfg.framePadding + cfg.frameMeterSize, y, cfg.frameMeterSize / 2, cfg.frameIconSize, 0, 0, 0.8, raceIndex, 2)
		race.bar2fg:SetFrameLevel(102)
		race.bar3bg = p:CreateBar(cfg.framePadding + cfg.framePadding + cfg.frameIconSize + (cfg.framePadding + cfg.frameMeterSize)*2, y, cfg.frameMeterSize, cfg.frameIconSize, 0.2, 0.6, 0.6, raceIndex, 3)
		race.bar3bg:SetFrameLevel(101)
		race.bar3fg = p:CreateBar(cfg.framePadding + cfg.framePadding + cfg.frameIconSize + (cfg.framePadding + cfg.frameMeterSize)*2, y, cfg.frameMeterSize / 2, cfg.frameIconSize, 0, 1, 0, raceIndex, 3)
		race.bar3fg:SetFrameLevel(102)

		y = y + cfg.framePadding + cfg.frameIconSize
	end

	p.UIFrame:SetHeight(y)
	p.UIFrame:Hide()
end

function addon:CreateButton(x, y, w, h, texture, race, mode)
	local p = Professor

	local b = CreateFrame("Button", nil, p.UIFrame)
	b:SetPoint("TOPLEFT", x, 0-y)
	b:SetWidth(w)
	b:SetHeight(h)
	b.tt_race = race
	b.tt_mode = mode

	b.texture = b:CreateTexture(nil, "ARTWORK")
	b.texture:SetAllPoints(b)
	b.texture:SetTexture(texture)
	b.texture:SetTexCoord(0.0, 0.5703, 0.0, 0.6484)

	addon:Mouseify(b, true)

	b:SetHitRectInsets(0, 0, 0, 0)
	b:SetScript("OnEnter", function(bself)
		addon:ShowTooltip(bself.tt_race, bself.tt_mode)
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return b
end

local BARTEXTURE = [[Interface\TargetingFrame\UI-StatusBar]]
local FONTNAME = [[Fonts\FRIZQT__.TTF]]

function addon:CreateBar(x, y, w, h, red, green, blue, race, mode)
	local p = Professor

	local b = CreateFrame("StatusBar", nil, p.UIFrame)
	b:SetPoint("TOPLEFT", x, 0-y)
	b:SetWidth(w)
	b:SetHeight(h)
	b:SetMinMaxValues(0, 100)
	b:SetValue(100)
	b:SetOrientation("HORIZONTAL")
	b:SetStatusBarTexture(BARTEXTURE, "ARTWORK")
	b:SetStatusBarColor(red, green, blue)
	b.tt_race = race
	b.tt_mode = mode

	b.label = b:CreateFontString(nil, "OVERLAY")
	b.label:SetTextColor(1, 1, 1, 1)
	b.label:SetFont(FONTNAME, 12, "OUTLINE")
	b.label:SetPoint("LEFT", b, "LEFT", 0, 0)
	b.label:SetText(" ")
	b.label:Show()

	addon:Mouseify(b)

	b:SetHitRectInsets(0, 0, 0, 0)
	b:SetScript("OnEnter", function(bself)
		addon:ShowTooltip(bself.tt_race, bself.tt_mode)
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return b
end

function addon:Mouseify(f, is_button)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", self.OnDragStart)
	f:SetScript("OnDragStop", self.OnDragStop)

	if (is_button) then
		f:RegisterForClicks("AnyUp")
		f:SetScript("OnClick", self.OnClick)
	else
		f:SetScript("OnMouseUp", self.OnClick)
	end
end

function addon:OnDragStart(frame)
	local p = Professor
	local cfg = Professor.options

	if (cfg.lock == false) then

		p.UIFrame:StartMoving()
		p.UIFrame.isMoving = true
		GameTooltip:Hide()
	end
end

function addon:OnDragStop(frame)
	local p = Professor
	p.UIFrame:StopMovingOrSizing()
	p.UIFrame.isMoving = false
end

function addon:OnClick(aButton)
	if (aButton == "RightButton") then
		GameTooltip:Hide()
		addon:ShowMenu()
	end
end

function addon:ShowTooltip(raceId, mode)
	local race = self.races[raceId]

	if (mode == 0) then
		GameTooltip:SetOwner(race.iconBtn, "ANCHOR_BOTTOM", 0, 10)

		GameTooltip:AddLine(race.id .. ". " .. race.name, 1, 1, 0) -- yellow
		GameTooltip:AddLine(race.completedCommon.."/"..race.totalCommon.." Commons", 1, 1, 1)
		GameTooltip:AddLine(race.completedRare.."/"..race.totalRare.." Rares", 0.375, 0.75, 1)
		GameTooltip:AddLine(race.completedPristine.."/"..race.totalPristine.." Pristine", 0.2, 1, 0.2)
	end

	if (mode == 1) then
		GameTooltip:SetOwner(race.bar1bg, "ANCHOR_BOTTOM", 0, 10)

		GameTooltip:AddLine("Common "..race.name.." Artifacts", 1, 1, 0) -- yellow
		if (race.completedCommon == race.totalCommon) then
			GameTooltip:AddLine("Complete! "..race.completedCommon.."/"..race.totalCommon, 0, 1, 0)
		else
			GameTooltip:AddLine("Found "..race.completedCommon.."/"..race.totalCommon.." ("..(race.totalCommon-race.completedCommon).." Missing)", 1, 0, 0)
			GameTooltip:AddLine(" ")

			for icon, artifact in pairs(race.artifacts) do
				if ((artifact.solves == 0) and (artifact.rare == false)) then
					GameTooltip:AddLine(artifact:getLink())
				end
			end
		end
	end

	if (mode == 2) then
		GameTooltip:SetOwner(race.bar2bg, "ANCHOR_BOTTOM", 0, 10)

		GameTooltip:AddLine("Rare "..race.name.." Artifacts", 1, 1, 0) -- yellow
		if (race.completedRare == race.totalRare) then
			GameTooltip:AddLine("Complete! "..race.completedRare.."/"..race.totalRare, 0, 1, 0)
		else
			GameTooltip:AddLine("Found "..race.completedRare.."/"..race.totalRare.." ("..(race.totalRare-race.completedRare).." Missing)", 1, 0, 0)
			GameTooltip:AddLine(" ")

			for icon, artifact in pairs(race.artifacts) do
				if ((artifact.solves == 0) and (artifact.rare == true)) then
					GameTooltip:AddLine(artifact:getLink())
				end
			end
		end
	end

	if (mode == 3) then
		GameTooltip:SetOwner(race.bar3bg, "ANCHOR_BOTTOM", 0, 10)

		GameTooltip:AddLine("Pristine "..race.name.." Artifacts", 1, 1, 0) -- yellow
		if (race.completedPristine == race.totalPristine) then
			GameTooltip:AddLine("Complete! "..race.completedPristine.."/"..race.totalPristine, 0, 1, 0)
		else
			GameTooltip:AddLine("Found "..race.completedPristine.."/"..race.totalPristine.." ("..(race.totalPristine-race.completedPristine).." Missing)", 1, 0, 0)
			GameTooltip:AddLine(" ")

			for icon, artifact in pairs(race.artifacts) do
				if (artifact.pristineId and artifact.pristineSolved == false) then
					GameTooltip:AddLine(artifact:getLink())
				end
			end
		end
	end

	GameTooltip:ClearAllPoints()
	GameTooltip:Show()
end

function addon:ShowMenu()
	local menu_frame = CreateFrame("Frame", "menuFrame", UIParent, "UIDropDownMenuTemplate")

	local menuList = {}
	local first = true

	table.insert(menuList, {
		text = "Options",
		func = function()
			InterfaceOptionsFrame_OpenToCategory(addon.OptionsFrame.About)
			InterfaceOptionsFrame_OpenToCategory(addon.OptionsFrame.About)
			InterfaceOptionsFrame_OpenToCategory(addon.OptionsFrame.name)
		end,
		isTitle = false,
		checked = false,
		disabled = false,
	})

	table.insert(menuList, {
		text = "About",
		func = function()
			InterfaceOptionsFrame_OpenToCategory(addon.OptionsFrame.name)
			InterfaceOptionsFrame_OpenToCategory(addon.OptionsFrame.About)
		end,
		isTitle = false,
		checked = false,
		disabled = false,
	})

	local locked = false
	if (Professor.options.lock) then locked = true end

	table.insert(menuList, {
		text = "Lock Frame",
		func = function() addon:ToggleLock() end,
		isTitle = false,
		checked = locked,
		disabled = false,
	})

	table.insert(menuList, {
		text = "Hide Window",
		func = function() addon:SetHide(true) end,
		isTitle = false,
		checked = false,
		disabled = false,
	})

	EasyMenu(menuList, menu_frame, "cursor", 0 , 0, "MENU")
end

function addon:SetHide(a)
	Professor.options.hide = a
	if (a) then
		Professor.UIFrame:Hide()
	else
		Professor.UIFrame:Show()
	end
end

function addon:ToggleHide()
	if (Professor.options.hide) then
		self:SetHide(false)
	else
		self:SetHide(true)
	end
end

function addon:SetLocked(a)
	Professor.options.lock = a
end

function addon:ToggleLock()
	if (Professor.options.lock) then
		self:SetLocked(false)
	else
		self:SetLocked(true)
	end
end

function addon:OnArtifactHistoryReady(event, ...)
	if IsArtifactCompletionHistoryAvailable() then
		if not self.races then
			self:LoadRaces()
		end

		self:UpdateHistory()

		if self.action then
			self:action()
			self.action = nil
		end

		local cfg = Professor.options

		for raceIndex, race in pairs(self.races) do
			if (race.completedCommon  == 0 or race.totalCommon == 0) then
				race.bar1fg:Hide()
			else
				race.bar1fg:Show()
				race.bar1fg:SetWidth(cfg.frameMeterSize * race.completedCommon / race.totalCommon)
				if (race.completedCommon == race.totalCommon) then
					race.bar1fg:SetStatusBarColor(0, 1, 0)
				else
					race.bar1fg:SetStatusBarColor(1, 1, 1)
				end
			end

			local frameWidth
			if race.totalRare > 0 then
				frameWidth = cfg.frameMeterSize * race.completedRare / race.totalRare
			else
				frameWidth = cfg.frameMeterSize
			end
			if frameWidth == 0 then
				race.bar2fg:Hide()
			else
				race.bar2fg:Show()
				race.bar2fg:SetWidth(frameWidth)

				if (race.completedRare == race.totalRare) then
					race.bar2fg:SetStatusBarColor(0, 1, 0)
				else
					race.bar2fg:SetStatusBarColor(0, 0, 0.8)
				end
			end

			local frameWidth
			if race.totalPristine > 0 then
				frameWidth = cfg.frameMeterSize * race.completedPristine / race.totalPristine
			else
				frameWidth = cfg.frameMeterSize
			end
			if frameWidth == 0 then
				race.bar3fg:Hide()
			else
				race.bar3fg:Show()
				race.bar3fg:SetWidth(frameWidth)

				if (race.completedPristine == race.totalPristine) then
					race.bar3fg:SetStatusBarColor(0, 1, 0)
				else
					race.bar3fg:SetStatusBarColor(0, 0, 0.8)
				end
			end
		end
	end
end

function addon:OnArtifactUpdate(event, ...)
	RequestArtifactCompletionHistory()
end

function addon:CreateOptionsFrame()
	self.OptionsFrame = CreateFrame("Frame", "ProfessorOptionsFrame", UIParent)
	self.OptionsFrame:SetFrameStrata("DIALOG")
	self.OptionsFrame:Hide()
	self.OptionsFrame.name = 'Professor'

	self:CreateOptionButton(self.OptionsFrame, 'prof_opt_show', 10, 10, 150, "Show window", function() addon:SetHide(false) end)
	self:CreateOptionButton(self.OptionsFrame, 'prof_opt_hide', 10, 34, 150, "Hide window", function() addon:SetHide(true) end)

	InterfaceOptions_AddCategory(self.OptionsFrame)

	if LibStub:GetLibrary("LibAboutPanel", true) then
		self.OptionsFrame["About"] = LibStub:GetLibrary("LibAboutPanel").new(addon.OptionsFrame.name, addon.OptionsFrame.name)
	end
end

function addon:CreateOptionButton(parent, id, x, y, w, value, onClick)
	local b = CreateFrame("Button", id, parent, "UIPanelButtonTemplate")
	b:SetPoint("TOPLEFT", x, 0-y)
	b:SetWidth(w)
	b:SetHeight(24)

	b.text = b:GetFontString()
	b.text:SetPoint("LEFT", b, "LEFT", 7, 0)
	b.text:SetPoint("RIGHT", b, "RIGHT", -7, 0)

	b:SetScript("OnClick", onClick)
	b:RegisterForClicks("AnyDown")

	b:SetText(value)
	b:EnableMouse(true)
end

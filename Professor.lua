local _VERSION = GetAddOnMetadata('Professor', 'version')


local Professor = LibStub("AceAddon-3.0"):NewAddon("Professor", "AceConsole-3.0", "AceEvent-3.0")

Professor:RegisterChatCommand("prof", "SlashProcessorFunction")

function Professor:OnInitialize()
  -- Code that you want to run when the addon is first loaded goes here.
	
end


function Professor:OnEnable()
    -- Called when the addon is enabled
end

function Professor:OnDisable()
    -- Called when the addon is disabled
end


Professor.races = {}
Professor.artifacts = {
	{27; 4};
	{8; 2};
	{12; 2};
	{18; 7};
	{7; 2};
	{9; 1};
	{7; 6};
	{14; 1};
	{5; 1};
	{0; 0};
}

Professor.COLORS = {
	text   = '|cffaaaaaa';
	race   = _G['ORANGE_FONT_COLOR_CODE'];
	common = '|cffffffff';
	rare   = '|cff66ccff';
	total  = '|cffffffff';
}

function Professor:LoadRaces()
	local raceCount = GetNumArchaeologyRaces()
	if raceCount ~= #self.artifacts then
		print("Error: unknown races detected")
		return
	end
	self.races = {}
	
	for raceIndex=1, raceCount do
		local raceName, raceCurrency, raceTexture, raceItemID = GetArchaeologyRaceInfo(raceIndex)
		local artifactCount = GetNumArtifactsByRace(raceIndex)
		
		local artifactIndex = 1
		local done = false
		local common = 0
		local rare = 0
		local total = 0
		
		repeat
			local name, description, rarity, icon, spellDescription,  _, _, firstComletionTime, completionCount = GetArtifactInfoByRace(raceIndex, artifactIndex)
			artifactIndex = artifactIndex + 1
			if name then
				-- print ('   ' .. name .. completionCount)
				
				if completionCount > 0 then
					
					if rarity == 0 then
						common = common + 1
					else
						rare = rare + 1
					end
					
					total = total + completionCount
				end
				
			else				
				done = true
			end				
		until done
		
		self.races[raceIndex] = {
			name = raceName;
			texture = raceTexture;
			completedCommon = common;
			completedRare = rare;
			totalSolves = total;	
		}
	end
end

function Professor:Print()
	if not self.races then
		return
	end
	for id, race in ipairs(self.races) do
		print( string.format("|T%s:0:0:0:0:64:64:0:38:0:38|t %s%s|r%s: %s%d%s/%s%d|r%s, %s%d%s/%s%d|r%s — %s%d|r%s total",
			race.texture,
			
			self.COLORS.race,
			race.name,
			self.COLORS.text,
			
			self.COLORS.common,
			race.completedCommon,
			self.COLORS.text,
			self.COLORS.common,
			self.artifacts[id][1],
			self.COLORS.text,
			
			self.COLORS.rare,
			race.completedRare,
			self.COLORS.text,
			self.COLORS.rare,
			self.artifacts[id][2],
			self.COLORS.text,
			
			self.COLORS.total,
			race.totalSolves,
			self.COLORS.text
		) )
	end
end

function Professor:OnHistoryReady(event, ...)
	if IsArtifactCompletionHistoryAvailable() then
		self:LoadRaces()
		self:Print()
	self:UnregisterEvent("ARTIFACT_HISTORY_READY");
	end
end


function Professor:SlashProcessorFunction(input)
  -- Process the slash command ('input' contains whatever follows the slash command)
  -- prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions();
  -- print (GetProfessionInfo(archaeology))  
  
  
  self:RegisterEvent("ARTIFACT_HISTORY_READY", "OnHistoryReady");
  
  RequestArtifactCompletionHistory()
  

end


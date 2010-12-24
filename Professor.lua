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

Professor.ARTIFACT_COUNTS = {
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

function Professor:OnHistoryReady(event, ...)
	if IsArtifactCompletionHistoryAvailable() then
		
		raceCount = GetNumArchaeologyRaces()
		
		for raceIndex=1, raceCount do
			raceName, raceCurrency, raceTexture, raceItemID = GetArchaeologyRaceInfo(raceIndex)
			artifactCount = GetNumArtifactsByRace(raceIndex)
			
			artifactIndex = 1
			local done = false
			local common = 0
			local rare = 0
			local total = 0
			
			repeat
				name, description, rarity, icon, spellDescription,  _, _, firstComletionTime, completionCount = GetArtifactInfoByRace(raceIndex, artifactIndex)
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
			
			
			
			print( "|cff666666" .. raceName .. "|r: "
				.. common .. "/" .. Professor.ARTIFACT_COUNTS[raceIndex][1] .. ", "
				.. "|cff9999ff" .. rare .. "/" .. Professor.ARTIFACT_COUNTS[raceIndex][2] .. "|r -- "
				.. total .. " total")
			
		end
		
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


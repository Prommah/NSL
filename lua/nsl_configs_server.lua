// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_configs_server.lua
// - Dragon

//NSL Configs

local configFileName = "NSLConfig.json"
local configUpdateURL = "https://raw.githubusercontent.com/xToken/NSL/master/configs/nsl_leagueconfig.json"
local configlocalFile = "configs/nsl_leagueconfig.json"
local configUpdateRequestSent = false
local configUpdateRetries = 0
local NSL_Mode = "PCW"
local NSL_League = "NSL"
local NSL_PerfLevel = "DEFAULT"
local NSL_CachedScores = { }
local NSL_Scores = { }
local NSL_LeagueAdminsAccess = false
local cachedScoresValidFor = 10 * 60
local expectedNSLConfigVersion = 1.5

function GetNSLMode()
	return NSL_Mode
end

function GetNSLModEnabled()
	return NSL_Mode ~= "DISABLED"
end

function GetActiveLeague()
	return NSL_League
end

function GetRecentScores()
	return NSL_CachedScores
end

function GetNSLPerfLevel()
	return NSL_PerfLevel
end

function GetNSLLeagueAdminsAccess()
	return NSL_LeagueAdminsAccess
end

local function LoadConfig()
	local defaultConfig = { mode = "PCW", league = "NSL", perf = "DEFAULT", recentgames = { }, adminaccess = false }
	WriteDefaultConfigFile(configFileName, defaultConfig)
	local config = LoadConfigFile(configFileName) or defaultConfig
	NSL_Mode = config.mode or "PCW"
	NSL_League = config.league or "NSL"
	NSL_PerfLevel = config.perf or "DEFAULT"
	NSL_LeagueAdminsAccess = config.adminaccess or false
	local loadedScores = config.recentgames or { }
	local updated = false
	for t, s in pairs(loadedScores) do
		if type(s) == "table" and (Shared.GetSystemTime() - (s.scoretime or 0) < cachedScoresValidFor) and (s.score or 0) > 0 then
			NSL_CachedScores[t] = s.score or 0
		end
	end
end

LoadConfig()

local function SetSeasonOnLoad()
	if GetNSLModEnabled() then
		Server.SetServerProperty(Seasons.kPropertyKey, Seasons.kNone)
	end
end

SetSeasonOnLoad()

local function SavePluginConfig()
	SaveConfigFile(configFileName, { mode = NSL_Mode, league = NSL_League, perf = NSL_PerfLevel, recentgames = NSL_Scores, adminaccess = NSL_LeagueAdminsAccess })
end

function SetNSLMode(state)
	if NSL_Mode ~= state then
		NSL_Mode = state
		SavePluginConfig()
		if NSL_Mode == "DISABLED" then
			GetGamerules():OnTournamentModeDisabled()
		else
			GetGamerules():OnTournamentModeEnabled()
		end
		for i = 1, #gPluginStateChange do
			gPluginStateChange[i](NSL_Mode)
		end
	end
end

function SetActiveLeague(state)
	if NSL_League ~= state then
		NSL_League = state
		SavePluginConfig()
		if GetNSLModEnabled() then
			EstablishConfigDependantSettings()
		end
	end
end

function SetPerfLevel(state)
	if NSL_PerfLevel ~= state then
		NSL_PerfLevel = state
		SavePluginConfig()
		if GetNSLModEnabled() then
			EstablishConfigDependantSettings()
		end
	end
end

function SetNSLAdminAccess(state)
	if NSL_LeagueAdminsAccess ~= state then
		NSL_LeagueAdminsAccess = state
		SavePluginConfig()
	end
end

function UpdateNSLScores(team1name, team1score, team2name, team2score)
	NSL_Scores[team1name] = { score = team1score, scoretime = Shared.GetSystemTime() }
	NSL_Scores[team2name] = { score = team2score, scoretime = Shared.GetSystemTime() }
	SavePluginConfig()
end

local DefaultConfig = {
AutomaticMapCycleDelay				= 180 * 60,
PauseEndDelay 						= 5,
PauseStartDelay 					= 1,
PauseMaxPauses 						= 3,
PausedReadyNotificationDelay 		= 30,
PauseEnabled 						= true,
FriendlyFireDamagePercentage 		= 0.33,
FriendlyFireEnabled			 		= false,
TournamentModeAlertDelay 			= 30,
TournamentModeGameStartDelay 		= 15,
PausedMaxDuration 					= 120,
TournamentModeForfeitClock			= 0,
TournamentModeRestartDuration 		= 90,
Limit6PlayerPerTeam 				= false,
MercsRequireApproval 				= false,
FirstPersonSpectate					= false,
UseCustomSpawnConfigs				= false,
UseFixedSpawnsPerMap				= false,
UseDefaultSkins						= false,
PauseOnDisconnect					= false
}

local DefaultPerfConfig = {
Interp 								= 100,
MoveRate 							= 30,
ClientRate 							= 20,
TickRate 							= 30,
MaxDataRate 						= 50,
}

local Configs = { }
local PerfConfigs = { }

local function OnConfigResponse(response)
	if response then
		local responsetable = json.decode(response)
		if responsetable == nil or responsetable.Version == nil then
			//RIP
			//Retry?
			if configUpdateRetries < 3 then
				configUpdateRequestSent = false
				configUpdateRetries = configUpdateRetries + 1
			else
				Shared.Message("Failed getting latest config from GitHub.")
				local file = io.open(configlocalFile, "r")
				if file then
					responsetable = json.decode(file:read("*all"))
					file:close()
				end
			end
		end
		if responsetable and responsetable.Version and responsetable.EndOfTable then
			if responsetable.Version < expectedNSLConfigVersion then
				//Old version still on github, use local cache
				local file = io.open(configlocalFile, "r")
				if file then
					responsetable = json.decode(file:read("*all"))
					file:close()
				end
			end
			for i, config in ipairs(responsetable.Configs) do
				if config.LeagueName then
					//assume valid, update Configs table, always uppercase
					//Shared.Message("Loading config " .. config.LeagueName .. ".")
					Configs[string.upper(config.LeagueName)] = config
				elseif config.PerfLevel then
					//Performance configs
					//Shared.Message("Loading perf config " .. config.PerfLevel .. ".")
					PerfConfigs[string.upper(config.PerfLevel)] = config
				end
			end
			if GetNSLModEnabled() then
				EstablishConfigDependantSettings()
			end
		end
	end
end

local function OnServerUpdated()
	if not configUpdateRequestSent then
		Shared.SendHTTPRequest(configUpdateURL, "GET", OnConfigResponse)
		configUpdateRequestSent = true
	end
end

Event.Hook("UpdateServer", OnServerUpdated)

function GetNSLConfigValue(value)
	//Check base config
	if Configs[NSL_League] and Configs[NSL_League][value] then
		return Configs[NSL_League][value]
	end
	//Check Mode Specific config
	if Configs[NSL_League] and Configs[NSL_League][NSL_Mode] and Configs[NSL_League][NSL_Mode][value] then
		return Configs[NSL_League][NSL_Mode][value]
	end
	if DefaultConfig[value] then
		return DefaultConfig[value]
	end
	return nil
end

function GetNSLPerfValue(value)
	//Check base config
	if PerfConfigs[NSL_PerfLevel] and PerfConfigs[NSL_PerfLevel][value] then
		return PerfConfigs[NSL_PerfLevel][value]
	end
	if DefaultPerfConfig[value] then
		return DefaultPerfConfig[value]
	end
	return nil
end

function GetNSLLeagueValid(league)
	if Configs[league] and Configs[league].LeagueName then
		return true
	end
	return false
end

function GetPerfLevelValid(level)
	if PerfConfigs[level] and PerfConfigs[level].PerfLevel then
		return true
	end
	return false
end

function GetIsNSLRef(ns2id)
	if ns2id then
		local pData = GetNSLUserData(ns2id)
		if pData and pData.NSL_Level then
			return pData.NSL_Level >= GetNSLConfigValue("PlayerRefLevel")
		end
	end
	return false
end

local function GetGroupCanRunCommand(groupData, commandName)
    
	local existsInList = false
	local commands = groupData.commands
	
	if commands then
		for c = 1, #groupData.commands do
			if groupData.commands[c] == commandName then
				existsInList = true
				break
			end
		end
	end
	
	if groupData.type == "allowed" then
		return existsInList
	elseif groupData.type == "disallowed" then
		return not existsInList
	else
		//Invalid structure
		return false
	end
	
end

function GetCanRunCommandviaNSL(ns2id, commandName)
	if NSL_LeagueAdminsAccess and GetIsNSLRef(ns2id) then
		local pData = GetNSLUserData(ns2id)
		if pData and pData.NSL_Level then
			local level = tostring(pData.NSL_Level)
			local groupData = GetNSLConfigValue("AdminGroups")
			if groupData and groupData[level] then
				return GetGroupCanRunCommand(groupData[level], commandName)
			end
		end		
	end
	return false
end

local Messages = {
PauseResumeMessage 					= "Game Resumed.  %s have %s pauses remaining",
PausePausedMessage					= "Game Paused.",
PauseWarningMessage					= "Game will %s in %d seconds.",
PauseResumeWarningMessage 			= "Game will automatically resume in %d seconds.",
PausePlayerMessage					= "%s has paused the game.",
PauseTeamReadiedMessage				= "%s readied for %s, resuming game.",
PauseTeamReadyMessage				= "%s readied for %s, waiting for the %s.",
PauseTeamReadyPeriodicMessage		= "%s are ready, waiting for the %s.",
PauseNoTeamReadyMessage				= "No team is ready to resume, type unpause in console to ready for your team.",
PauseCancelledMessage				= "Game Pause Cancelled.",
PauseDisconnectedMessage			= "%s disconnected, pausing game.",
PauseTooManyPausesMessage			= "Your team is out of pauses.",
TournamentModeTeamReadyAlert 		= "%s are ready, waiting on %s to start game.",
TournamentModeCountdown 			= "Game will start in %s seconds!",
TournamentModeReadyAlert 			= "Both teams need to ready for the game to start.",
TournamentModeTeamReady				= "%s has %s for %s.",
TournamentModeGameCancelled			= "Game start cancelled.",
TournamentModeForfeitWarning		= "%s have %d %s left to ready before forfeiting.",
TournamentModeGameForfeited			= "%s have forfeit the round due to not reading within %s seconds.",
TournamentModeReadyNoComm			= "Your team needs a commander to ready.",
TournamentModeStartedGameCancelled  = "%s un-readied for the %s, resetting game.",
UnstuckCancelled					= "You moved or were unable to be unstuck currently.",
Unstuck								= "Unstuck!",
UnstuckIn							= "You will be unstuck in %s seconds.",
UnstuckRecently						= "You have unstucked too recently, please wait %d seconds.",
UnstuckFailed						= "Unstuck Failed after %s attempts.",
MercApprovalNeeded					= "The opposite team will need to approve you as a merc.",
MercApproved 						= "%s has been approved as a merc for %s.",
MercsReset 							= "Merc approvals have been reset."
}

function GetNSLMessage(message)
	return Messages[message] or ""
end
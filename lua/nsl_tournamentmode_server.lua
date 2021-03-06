// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_tournamentmode_server.lua
// - Dragon

//NS2 Tournament Mod Server side script

Script.Load("lua/nsl_class.lua")

local TournamentModeSettings = { 
countdownstarted = false, 
countdownstarttime = 0, 
countdownstartcount = 0, 
lastmessage = 0,  
roundstarted = 0
}

function TournamentModeOnGameEnd()
	GetGamerules():SetTeamsReady(false)
end

local originalNS2GROnCreate
originalNS2GROnCreate = Class_ReplaceMethod("NS2Gamerules", "OnCreate", 
	function(self)
		originalNS2GROnCreate(self)
		if GetNSLModEnabled() then
			GetGamerules():OnTournamentModeEnabled()
		end
	end
)

local originalNS2GRSetGameState
originalNS2GRSetGameState = Class_ReplaceMethod("NS2Gamerules", "SetGameState", 
	function(self, state)
		if self.gameState ~= kGameState.Started and state == kGameState.Started then
			GetGamerules():SetTeamsReady(false)
		end
		originalNS2GRSetGameState(self, state)
	end
)

//Derrrrrrrp
//Seems wierd, but makes game start the same frame as final counter expires.
local originalNS2GRGetPregameLength
originalNS2GRGetPregameLength = Class_ReplaceMethod("NS2Gamerules", "GetPregameLength", 
	function(self)
		if GetNSLModEnabled() then
			return -1
		end
		return originalNS2GRGetPregameLength(self)
	end
)

//Allow imbalanced teams, but also dont allow more than 6 players per team in an in-progress game.
local originalNS2GameRulesGetCanJoinTeamNumber
originalNS2GameRulesGetCanJoinTeamNumber = Class_ReplaceMethod("NS2Gamerules", "GetCanJoinTeamNumber", 
	function(self, teamNumber)
		if (teamNumber == 1 or teamNumber == 2) and GetNSLModEnabled() and GetNSLConfigValue("Limit6PlayerPerTeam") then
			if self:GetGameState() == kGameState.Started then
				local team1Players = self.team1:GetNumPlayers()
				local team2Players = self.team2:GetNumPlayers()
				if (teamNumber == 1 and team1Players >= 6) or (teamNumber == 2 and team2Players >= 6) then
					return false
				end
			end
		end
		return originalNS2GameRulesGetCanJoinTeamNumber(self, teamNumber)
	end
)

local function ClearTournamentModeState()
	TournamentModeSettings[1] = {ready = false, lastready = 0}
	TournamentModeSettings[2] = {ready = false, lastready = 0}
	TournamentModeSettings.countdownstarted = false
	TournamentModeSettings.countdownstarttime = 0
	TournamentModeSettings.countdownstartcount = 0
	TournamentModeSettings.lastmessage = 0
end

ClearTournamentModeState()

local function CheckCancelGameStart()
	if TournamentModeSettings.countdownstarttime ~= 0 then
		SendAllClientsMessage(GetNSLMessage("TournamentModeGameCancelled"))
		ClearTournamentModeState()
	end
end

local originalNS2OnCommanderLogOut = OnCommanderLogOut
function OnCommanderLogOut(commander)
	originalNS2OnCommanderLogOut(commander)
	if commander and GetNSLModEnabled() then
		local teamnum = commander:GetTeamNumber()
		if TournamentModeSettings[teamnum].ready and (GetGamerules():GetGameState() == kGameState.NotStarted or GetGamerules():GetGameState() == kGameState.PreGame) then
			TournamentModeSettings[teamnum].ready = false
			CheckCancelGameStart()
			SendTeamMessage(teamnum, GetNSLMessage("TournamentModeReadyNoComm"))
		end
	end
end

local function CheckGameStart()
	if TournamentModeSettings.countdownstarttime < Shared.GetTime() then
		GetGamerules():SetTeamsReady(true)
		ClearTournamentModeState()
		TournamentModeSettings.roundstarted = Shared.GetTime()
	end
end

local function AnnounceTournamentModeCountDown()

	if TournamentModeSettings.countdownstarted and TournamentModeSettings.countdownstarttime - TournamentModeSettings.countdownstartcount < Shared.GetTime() and TournamentModeSettings.countdownstartcount ~= 0 then
		if (math.fmod(TournamentModeSettings.countdownstartcount, 5) == 0 or TournamentModeSettings.countdownstartcount <= 5) then
			SendAllClientsMessage(string.format(GetNSLMessage("TournamentModeCountdown"), TournamentModeSettings.countdownstartcount))
		end
		TournamentModeSettings.countdownstartcount = TournamentModeSettings.countdownstartcount - 1
	end
	
end

local function DisplayReadiedTeamAlertMessages(ReadiedTeamNum)
	local notreadyteamname = GetActualTeamName((ReadiedTeamNum == 2 and 1) or 2)
	local readyteamname = GetActualTeamName(ReadiedTeamNum)
	SendAllClientsMessage(string.format(GetNSLMessage("TournamentModeTeamReadyAlert"), readyteamname, notreadyteamname))
	if GetNSLConfigValue("TournamentModeForfeitClock") > 0 then
		if Shared.GetTime() - (TournamentModeSettings[ReadiedTeamNum].lastready + GetNSLConfigValue("TournamentModeForfeitClock")) > 0 then
			SendAllClientsMessage(string.format(GetNSLMessage("TournamentModeGameForfeited"), notreadyteamname, GetNSLConfigValue("TournamentModeForfeitClock")))
			TournamentModeSettings[ReadiedTeamNum].ready = false
			TournamentModeSettings[ReadiedTeamNum].lastready = Shared.GetTime()
		else
			local timeremaining = (TournamentModeSettings[ReadiedTeamNum].lastready + GetNSLConfigValue("TournamentModeForfeitClock")) - Shared.GetTime()
			local unit = "seconds"
			if (timeremaining / 60) > 1 then
				timeremaining = (timeremaining / 60)
				unit = "minutes"
			end
			SendAllClientsMessage(string.format(GetNSLMessage("TournamentModeForfeitWarning"), notreadyteamname, timeremaining, unit))
		end
	end
end

local function MonitorCountDown()

	if not TournamentModeSettings.countdownstarted then
		if TournamentModeSettings.lastmessage + GetNSLConfigValue("TournamentModeAlertDelay") < Shared.GetTime() then
			if TournamentModeSettings[1].ready or TournamentModeSettings[2].ready then
				if TournamentModeSettings[1].ready then
					DisplayReadiedTeamAlertMessages(1)
				else
					DisplayReadiedTeamAlertMessages(2)
				end
			else
				SendAllClientsMessage(GetNSLMessage("TournamentModeReadyAlert"))
			end
			TournamentModeSettings.lastmessage = Shared.GetTime()
		end
	else
		AnnounceTournamentModeCountDown()
		CheckGameStart()
	end
	
end

local originalNS2GamerulesUpdatePregame
originalNS2GamerulesUpdatePregame = Class_ReplaceMethod("NS2Gamerules", "UpdatePregame", 
	function(self, timePassed)
		if (self:GetGameState() == kGameState.PreGame or self:GetGameState() == kGameState.NotStarted) and not self.teamsReady and GetNSLModEnabled() then
			MonitorCountDown()
		else
			originalNS2GamerulesUpdatePregame(self, timePassed)
		end
	end
)

local function TournamentModeOnDisconnect(client)
	if TournamentModeSettings.countdownstarted then
		CheckCancelGameStart()
	end
end

Event.Hook("ClientDisconnect", TournamentModeOnDisconnect)

local function CheckGameCountdownStart()
	if TournamentModeSettings[1].ready and TournamentModeSettings[2].ready then
		TournamentModeSettings.countdownstarted = true
		TournamentModeSettings.countdownstarttime = Shared.GetTime() + GetNSLConfigValue("TournamentModeGameStartDelay")
		TournamentModeSettings.countdownstartcount = GetNSLConfigValue("TournamentModeGameStartDelay")
	end
end

local function OnCommandForceStartRound(client, duration)
	if not client then return end
	local NS2ID = client:GetUserId()
	local duration = tonumber(duration) or 15
	if GetIsNSLRef(NS2ID) then
		ClearTournamentModeState()
		TournamentModeSettings[1].ready = true
		TournamentModeSettings[2].ready = true
		CheckGameCountdownStart()
		TournamentModeSettings.countdownstarttime = Shared.GetTime() + duration
		SendAllClientsMessage(string.format(GetNSLMessage("TournamentModeCountdown"), duration))
		ServerAdminPrint(client, "Forcing game start.")
	end
end

Event.Hook("Console_sv_nslforcestart",               OnCommandForceStartRound)

local function OnCommandCancelRoundStart(client)
	if not client then return end
	local NS2ID = client:GetUserId()
	if GetIsNSLRef(NS2ID) then
		CheckCancelGameStart()
		ClearTournamentModeState()
		ServerAdminPrint(client, "Cancelling countdown in progress.")
	end
end

Event.Hook("Console_sv_nslcancelstart",               OnCommandCancelRoundStart)

local function ClientReady(client)

	local player = client:GetControllingPlayer()
	local playername = player:GetName()
	local teamnum = player:GetTeamNumber()
	if teamnum == 1 or teamnum == 2 then
		local gamerules = GetGamerules()
		local team1Commander = gamerules.team1:GetCommander()
        local team2Commander = gamerules.team2:GetCommander()
		if (not team1Commander and teamnum == 1) or (not team2Commander and teamnum == 2) then
			SendTeamMessage(teamnum, GetNSLMessage("TournamentModeReadyNoComm"))
		elseif TournamentModeSettings[teamnum].lastready + 2 < Shared.GetTime() then
			TournamentModeSettings[teamnum].ready = not TournamentModeSettings[teamnum].ready
			TournamentModeSettings[teamnum].lastready = Shared.GetTime()
			SendAllClientsMessage(string.format(GetNSLMessage("TournamentModeTeamReady"), playername, ConditionalValue(TournamentModeSettings[teamnum].ready, "readied", "unreadied"), GetActualTeamName(teamnum)))
			CheckGameCountdownStart()
		end	
	end
	if TournamentModeSettings[1].ready == false or TournamentModeSettings[2].ready == false then
		CheckCancelGameStart()
	end
	
end

local function CheckforInProgressGameToCancel(client, gamerules)
	if gamerules:GetGameState() == kGameState.Started and (TournamentModeSettings.roundstarted or 0) + GetNSLConfigValue("TournamentModeRestartDuration") > Shared.GetTime() then
		local player = client:GetControllingPlayer()
		local playername = player:GetName()
		local teamnum = player:GetTeamNumber()
		if (teamnum == 1 or teamnum == 2) then
			gamerules:SetTeamsReady(false)
			SendAllClientsMessage(string.format(GetNSLMessage("TournamentModeStartedGameCancelled"), playername, GetActualTeamName(teamnum)))
		end
	end
end

local function OnCommandReady(client)
	local gamerules = GetGamerules()
	if gamerules and client and GetNSLModEnabled() then
		if gamerules:GetGameState() == kGameState.NotStarted or gamerules:GetGameState() == kGameState.PreGame then
			ClientReady(client)
		else
			CheckforInProgressGameToCancel(client, gamerules)
		end
	end
end

Event.Hook("Console_ready",                 OnCommandReady)
gChatCommands["ready"] = OnCommandReady
gChatCommands["!ready"] = OnCommandReady
gChatCommands["rdy"] = OnCommandReady

local function ClientNotReady(client)

	local player = client:GetControllingPlayer()
	local playername = player:GetName()
	local teamnum = player:GetTeamNumber()
	if (teamnum == 1 or teamnum == 2) and TournamentModeSettings[teamnum].ready then
		TournamentModeSettings[teamnum].ready = false
		TournamentModeSettings[teamnum].lastready = Shared.GetTime()
		SendAllClientsMessage(string.format(GetNSLMessage("TournamentModeTeamReady"), playername, "unreadied", GetActualTeamName(teamnum)))
	end
	if TournamentModeSettings[1].ready == false or TournamentModeSettings[2].ready == false then
		CheckCancelGameStart()
	end
	
end

local function OnCommandNotReady(client)
	local gamerules = GetGamerules()
	if gamerules and client and GetNSLModEnabled() then
		if gamerules:GetGameState() == kGameState.NotStarted or gamerules:GetGameState() == kGameState.PreGame then
			ClientNotReady(client)
		else
			CheckforInProgressGameToCancel(client, gamerules)
		end
	end
end

Event.Hook("Console_notready",                 OnCommandNotReady)
gChatCommands["notready"] = OnCommandNotReady
gChatCommands["!notready"] = OnCommandNotReady
gChatCommands["notrdy"] = OnCommandNotReady
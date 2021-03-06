// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_consistencyenforcer_server.lua
// - Dragon

//Hmm lets see what kind of craziness THIS can cause...

local ConsistencyApplied = false
local consistencyLocalFile = "configs/nsl_leagueconfig.json"

local function ApplyNSLConsistencyConfig()

	local consistencyConfig = GetNSLConfigValue("ConsistencyConfig")
	
	if not consistencyConfig then
		local file = io.open(consistencyLocalFile, "r")
		if file then
			consistencyConfig = json.decode(file:read("*all"))
			file:close()
		end
	end
		
	if consistencyConfig and not ConsistencyApplied then

		local startTime = Shared.GetSystemTime()
		//First, remove ANY established config
		Server.RemoveFileHashes("*.*")
		
		if type(consistencyConfig.check) == "table" then
			local check = consistencyConfig.check
			for c = 1, #check do
				local numHashed = Server.AddFileHashes(check[c])
				Shared.Message("Hashed " .. numHashed .. " " .. check[c] .. " files for consistency")
			end
		end

		if type(consistencyConfig.ignore) == "table" then
			local ignore = consistencyConfig.ignore
			for c = 1, #ignore do
				local numHashed = Server.RemoveFileHashes(ignore[c])
				Shared.Message("Skipped " .. numHashed .. " " .. ignore[c] .. " files for consistency")
			end
		end
		
		if type(consistencyConfig.restrict) == "table" then
			local check = consistencyConfig.restrict
			for c = 1, #check do
				local numHashed = Server.AddRestrictedFileHashes(check[c])
				Shared.Message("Hashed " .. numHashed .. " " .. check[c] .. " files for consistency")
			end
		end
		
		local endTime = Shared.GetSystemTime()
		Print("NSL Enhanced Consistency checking took " .. ToString(endTime - startTime) .. " seconds.")
		ConsistencyApplied = true
		
	end
	
end

table.insert(gConfigLoadedFunctions, ApplyNSLConsistencyConfig)
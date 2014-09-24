Script.Load("lua/nsl_class.lua")
Script.Load("lua/nsl_pause_shared.lua")

local kMaxTeamNameLength = 50
local kMaxAdminChatLength = 250

local kTeamNameUpdateMessage =
{
    team1name = string.format("string (%d)", kMaxTeamNameLength + 1),
	team2name = string.format("string (%d)", kMaxTeamNameLength + 1),
	team1score = "integer (0 to 10)",
	team2score = "integer (0 to 10)"
}

Shared.RegisterNetworkMessage("TeamNames", kTeamNameUpdateMessage)

local kAdminChatMessage =
{
    message = string.format("string (%d)", kMaxAdminChatLength + 1)
}

Shared.RegisterNetworkMessage("AdminMessage", kAdminChatMessage)

gRefBadges = 
{
	{
		name = "ensl_staff",
		unitStatusTexture = "ui/badges/ensl_staff.dds",
        scoreboardTexture = "ui/badges/ensl_staff.dds"
	},
	{
		name = "ensl_admin",
		unitStatusTexture = "ui/badges/ensl_admin.dds",
        scoreboardTexture = "ui/badges/ensl_admin.dds"
	}
}

local kRefBadgesMessage = 
{
    clientId = "integer",
}

for _, badge in ipairs(gRefBadges) do
    kRefBadgesMessage[ "has_" .. badge.name .. "_badge" ] = "boolean"
end

Shared.RegisterNetworkMessage("RefBadges", kRefBadgesMessage)

local kTechTreeRequest = 
{
	teamNumber =  string.format("integer (-1 to %d)", kSpectatorIndex)
}

Shared.RegisterNetworkMessage("RequestTeamTechTree", kTechTreeRequest)

local originalNS2SpectatorOnCreate
originalNS2SpectatorOnCreate = Class_ReplaceMethod("Spectator", "OnCreate", 
	function(self)
		originalNS2SpectatorOnCreate(self)
		self.hookedTechTree = 0
	end
)

Class_Reload( "Spectator", {hookedTechTree = string.format("integer (-1 to %d)", kSpectatorIndex)} )
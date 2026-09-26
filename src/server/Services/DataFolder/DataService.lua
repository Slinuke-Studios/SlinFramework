local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataService = require(ServerScriptService.Server.Services.PlayerDataService)

local DataService = {}
DataService.__index = DataService

local KEY_ALIAS = {
	dailyReward = "DailyReward",
	stats = "Stats",
	cooldowns = "Cooldowns",
}

local function alias(key)
	return KEY_ALIAS[key] or key
end

DataService.ProfileLoaded = Instance.new("BindableEvent")
DataService.StatChanged = Instance.new("BindableEvent")
DataService.LeveledUp = Instance.new("BindableEvent")
DataService.DailyReward = Instance.new("BindableEvent")
DataService.Banned = Instance.new("BindableEvent")

PlayerDataService.ProfileLoaded:Connect(function(player)
	DataService.ProfileLoaded:Fire(player)
end)

PlayerDataService.Changed:Connect(function(player, path, newValue, oldValue)
	DataService.StatChanged:Fire(player, path, newValue, oldValue)
end)

PlayerDataService.LeveledUp:Connect(function(player, level)
	DataService.LeveledUp:Fire(player, level)
end)

PlayerDataService.DailyRewardClaimed:Connect(function(player, reward, streak)
	DataService.DailyReward:Fire(player, reward, streak)
end)

PlayerDataService.Banned:Connect(function(player, reason, expiresAt)
	DataService.Banned:Fire(player, reason, expiresAt)
end)

function DataService:Init(network)
	if self._initialized then
		warn("DataService already initialized")
		return
	end
	self._initialized = true

	if not network then return end

	network.OnRequest("ClaimDaily", function(player)
		self:ClaimDaily(player)
	end)

	network.OnRequest("SpinWheel", function(player)
		local result = self:SpinWheel(player)
		network.SendSpinResult(player, result)
	end)

	network.OnRequest("GetSpinStatus", function(player)
		local status = self:GetSpinStatus(player)
		network.SendSpinStatus(player, status)
	end)
end

function DataService:Get(player, key)
	return PlayerDataService:Get(player, alias(key))
end

function DataService:Set(player, key, value)
	return PlayerDataService:Set(player, alias(key), value)
end

function DataService:Add(player, key, amount)
	return PlayerDataService:Add(player, alias(key), amount)
end

function DataService:AddXP(player, amount)
	return PlayerDataService:AddXP(player, amount)
end

function DataService:ClaimDaily(player)
	return PlayerDataService:ClaimDaily(player)
end

function DataService:SetCooldown(player, name, duration)
	return PlayerDataService:SetCooldown(player, name, duration)
end

function DataService:IsCooldown(player, name)
	return PlayerDataService:IsCooldown(player, name)
end

function DataService:Ban(player, reason)
	return PlayerDataService:BanPlayer(player, reason)
end

function DataService:SpinWheel(player)
	return PlayerDataService:SpinWheel(player)
end

function DataService:GetSpinStatus(player)
	return PlayerDataService:GetSpinStatus(player)
end

return DataService
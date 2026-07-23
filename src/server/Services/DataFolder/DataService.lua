local Signals = require(game.ReplicatedStorage.Shared.Signals)

local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")

local ProfileStore = require(script.Parent.ProfileStore)

local DataService = {}
DataService.__index = DataService

local NetworkService = nil

local DEFAULT_PROFILE = {
	Cash = 0,
	Gems = 0,
	XP = 0,
	Level = 1,

	stats = {
		playtime = 0,
	},

	dailyReward = {
		lastClaim = 0,
		streak = 0,
	},

	cooldowns = {},
	transactionLog = {},

	banned = {
		isBanned = false,
		reason = "",
		expiresAt = 0,
	},

	_metadata = {
		version = 1,
	},
}

local LEVEL_CONFIG = {
	BaseXP = 100,
	Scale = 1.5,
	Max = 1000,
}

local DAILY = {
	[1] = {Cash = 100},
	[2] = {Cash = 150},
	[3] = {Cash = 200, Gems = 5},
	[4] = {Cash = 250},
	[5] = {Cash = 300, Gems = 10},
	[6] = {Cash = 400},
	[7] = {Cash = 500, Gems = 25},
}

local function copy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k,v in pairs(t) do c[k]=copy(v) end
	return c
end

local function xpRequired(level)
	return math.floor(LEVEL_CONFIG.BaseXP * (LEVEL_CONFIG.Scale ^ (level - 1)))
end

local Store = ProfileStore.New("SlinWork_V1", DEFAULT_PROFILE)

local function getProfile(player)
	return Store:GetActiveProfile(player)
end

DataService.ProfileLoaded = Instance.new("BindableEvent")
DataService.StatChanged = Instance.new("BindableEvent")
DataService.LeveledUp = Instance.new("BindableEvent")
DataService.DailyReward = Instance.new("BindableEvent")
DataService.Banned = Instance.new("BindableEvent")

local function push(player, path, value)
	if NetworkService then
		NetworkService.SendDelta(player, {
			path = path,
			value = value
		})
	end
end

function DataService:Init(network)
	NetworkService = network

	local function load(player)
		Store:LoadProfile(player, function(profile)
			if not profile then return end

			self.ProfileLoaded:Fire(player)

			print("Loaded profile for", player.Name)

			NetworkService.SendFullData(player, profile:GetData())
		end)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(load, p)
	end

	Players.PlayerAdded:Connect(load)
	
	Signals.OnPlayerAdded:Connect(function(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = getProfile(player)
		if profile then profile:Release() end
	end)

	MessagingService:SubscribeAsync("DataStoreProTrusted", function(msg) -- name it well master
		local data = msg.Data
		local player = Players:GetPlayerByUserId(data.userId)
		if not player then return end

		local profile = getProfile(player)
		if not profile then return end

		for k,v in pairs(data.data) do
			profile:Set(k, v)
		end
	end)
end

function DataService:Set(player, key, value)
	local p = getProfile(player)
	if not p then return end

	local old = p:Get(key)
	p:Set(key, value)

	self.StatChanged:Fire(player, key, value, old)
	push(player, key, value)
end

function DataService:Add(player, key, amount)
	local p = getProfile(player)
	if not p then return end

	local old = p:Get(key) or 0
	local new = old + amount

	p:Set(key, new)

	self.StatChanged:Fire(player, key, new, old)
	push(player, key, new)
end

function DataService:AddXP(player, amount)
	local p = getProfile(player)
	if not p then return end

	local level = p:Get("Level")
	local xp = p:Get("XP")

	xp += amount

	while xp >= xpRequired(level) do
		xp -= xpRequired(level)
		level += 1

		self.LeveledUp:Fire(player, level)
	end

	p:Set("XP", xp)
	p:Set("Level", level)

	push(player, "XP", xp)
	push(player, "Level", level)
end

function DataService:ClaimDaily(player)
	local p = getProfile(player)
	if not p then return end

	local d = p:Get("dailyReward")
	local now = os.time()

	if now - d.lastClaim < 86400 then return end

	d.streak = math.min(d.streak + 1, 7)
	d.lastClaim = now

	local reward = DAILY[d.streak]

	p:Set("dailyReward", d)

	if reward.Cash then self:Add(player, "Cash", reward.Cash) end
	if reward.Gems then self:Add(player, "Gems", reward.Gems) end

	self.DailyReward:Fire(player, reward, d.streak)
end

function DataService:SetCooldown(player, name, duration)
	local p = getProfile(player)
	if not p then return end

	local c = p:Get("cooldowns")
	c[name] = os.time() + duration

	p:Set("cooldowns", c)
end

function DataService:IsCooldown(player, name)
	local p = getProfile(player)
	if not p then return false end

	local c = p:Get("cooldowns")
	return c[name] and os.time() < c[name]
end

function DataService:Ban(player, reason)
	local p = getProfile(player)
	if not p then return end

	p:Set("banned", {
		isBanned = true,
		reason = reason,
		expiresAt = 0
	})

	player:Kick("Banned: " .. reason)
end

return DataService
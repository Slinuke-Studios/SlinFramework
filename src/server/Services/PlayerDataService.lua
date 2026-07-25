local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SlinServer = require(ServerScriptService.Slin.SlinServer)
local SlinProfileStore = require(ServerScriptService.Slin.SlinProfileStore)
local SlinReplicaService = require(ServerScriptService.Slin.SlinReplicaService)
local Signal = require(ReplicatedStorage.Slin.Signal)

local DEFAULT_DATA = {
	Cash = 0,
	Gems = 0,
	XP = 0,
	Level = 1,
	Stats = {
		Playtime = 0,
	},
	DailyReward = {
		LastClaim = 0,
		Streak = 0,
	},
	Cooldowns = {},
}

local DAILY_REWARDS = {
	[1] = { Cash = 100 },
	[2] = { Cash = 150 },
	[3] = { Cash = 200, Gems = 5 },
	[4] = { Cash = 250 },
	[5] = { Cash = 300, Gems = 10 },
	[6] = { Cash = 400 },
	[7] = { Cash = 500, Gems = 25 },
}

local Store = SlinProfileStore.New("SlinFramework_V3_v1_3", DEFAULT_DATA, {
	Debug = true,
})

local PlayerDataService = SlinServer.CreateService({
	Name = "PlayerDataService",
	Priority = 10,
	Client = {},
	ProfileLoaded = Signal.New(),
	Changed = Signal.New(),
})

local function getProfile(player)
	return Store:Get(player)
end

local function getReplica(player)
	return SlinReplicaService.GetReplica(player, "PlayerData")
end

function PlayerDataService:SlinStart()
	Store:StartAutosave(60)

	local function loadPlayer(player)
		local profile = Store:LoadAsync(player)

		SlinReplicaService.NewReplica({
			Token = "PlayerData",
			Player = player,
			Data = profile.Data,
		})

		self.ProfileLoaded:Fire(player, profile.Data)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(loadPlayer, player)
	end

	Players.PlayerAdded:Connect(loadPlayer)

	Players.PlayerRemoving:Connect(function(player)
		Store:Release(player)
	end)

	game:BindToClose(function()
		Store:SaveAll()
	end)
end

function PlayerDataService:Get(player, path)
	local profile = getProfile(player)

	if not profile then
		return nil
	end

	return profile:Get(path)
end

function PlayerDataService:Set(player, path, value)
	local profile = getProfile(player)
	local replica = getReplica(player)

	if not profile or not replica then
		return
	end

	local oldValue = profile:Set(path, value)
	replica:Set(path, value)

	self.Changed:Fire(player, path, value, oldValue)
end

function PlayerDataService:Add(player, path, amount)
	local current = self:Get(player, path) or 0
	local nextValue = current + amount

	self:Set(player, path, nextValue)

	return nextValue, current
end

function PlayerDataService:Save(player)
	local profile = getProfile(player)

	if not profile then
		return false, "ProfileNotLoaded"
	end

	return profile:Save()
end

function PlayerDataService.Client:DebugAddCash(player, amount)
	amount = tonumber(amount) or 100

	local newCash = PlayerDataService:Add(player, "Cash", amount)
	local saved = PlayerDataService:Save(player)

	return saved, newCash
end

function PlayerDataService:ClaimDaily(player)
	local profile = getProfile(player)

	if not profile then
		return false, "ProfileNotLoaded"
	end

	local daily = profile:Get("DailyReward")
	local now = os.time()

	if now - daily.LastClaim < 86400 then
		return false, "AlreadyClaimed"
	end

	local nextStreak = math.clamp((daily.Streak or 0) + 1, 1, 7)
	local reward = DAILY_REWARDS[nextStreak]

	self:Set(player, "DailyReward", {
		LastClaim = now,
		Streak = nextStreak,
	})

	if reward.Cash then
		self:Add(player, "Cash", reward.Cash)
	end

	if reward.Gems then
		self:Add(player, "Gems", reward.Gems)
	end

	return true, reward
end

function PlayerDataService.Client:GetData(player)
	local profile = getProfile(player)

	return profile and profile.Data or nil
end

function PlayerDataService.Client:ClaimDaily(player)
	return PlayerDataService:ClaimDaily(player)
end

return PlayerDataService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")

local GAMEPASS_IDS = {
	DOP = 1941739887,
	IOP = 1951604637,
}

local SlinServer = require(ServerScriptService.Server.Slin.SlinServer)
local SlinProfileStore = require(ServerScriptService.Server.Slin.SlinProfileStore)
local SlinReplicaService = require(ServerScriptService.Server.Slin.SlinReplicaService)
local Signal = require(ReplicatedStorage.Shared.Slin.Signal)

local DEFAULT_DATA = {
	Cash = 0,
	Gems = 0,
	duck_damage = 1,
	duck_multiplier = 1,
	Rebirths = 0,

	oxySeconds = 25,
	swimSpeed = 16,

	banned = {
		isBanned = false,
		reason = "",
		expiresAt = 0,
	},

	DailyReward = {
		LastClaim = 0,
		Streak = 0,
	},

	redeemedCodes = {},

	spinData = {
		lastSpin = 0,
		streak = 0,
	},

	gamepasses = {
		DOP = false,
		IOP = false,
	},
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

local LEVEL_CONFIG = {
	BaseXP = 100,
	Scale = 1.5,
	Max = 1000,
}

local function xpRequired(level)
	return math.floor(LEVEL_CONFIG.BaseXP * (LEVEL_CONFIG.Scale ^ (level - 1)))
end

local SPIN_COOLDOWN = 86400
local SPIN_STREAK_WINDOW = 172800
local MAX_STREAK = 7

local SPIN_STREAK_MULTIPLIER = {
	[1] = 1,
	[2] = 1.1,
	[3] = 1.2,
	[4] = 1.3,
	[5] = 1.5,
	[6] = 1.75,
	[7] = 2,
}

local PRIZES = {
	{ name = "RedPrize",    prize = "Cash", amount = 1000, min = 1,   max = 90  },
	{ name = "BluePrize",   prize = "Gems", amount = 100,  min = 91,  max = 180 },
	{ name = "GreenPrize",  prize = "Cash", amount = 500,  min = 181, max = 270 },
	{ name = "YellowPrize", prize = "Gems", amount = 50,   min = 271, max = 360 },
}

local Store = SlinProfileStore.New("SlinFramework_V3", DEFAULT_DATA, {
	Debug = true,
})

local PlayerDataService = SlinServer.CreateService({
	Name = "PlayerDataService",
	Priority = 10,
	Client = {},
	ProfileLoaded = Signal.New(),
	Changed = Signal.New(),
	LeveledUp = Signal.New(),
	DailyRewardClaimed = Signal.New(),
	Banned = Signal.New(),
})

local function deepCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function getProfile(player)
	return Store:Get(player)
end

local function getReplica(player)
	return SlinReplicaService.GetReplica(player, "PlayerData")
end

function PlayerDataService:IsBanned(player)
	local profile = getProfile(player)
	if not profile then return false end

	local banned = profile:Get("banned")
	if not banned or not banned.isBanned then
		return false
	end

	if banned.expiresAt ~= 0 and os.time() >= banned.expiresAt then
		self:Set(player, "banned", { isBanned = false, reason = "", expiresAt = 0 })
		return false
	end

	return true, banned.reason, banned.expiresAt
end

function PlayerDataService:BanPlayer(player, reason, duration)
	local expiresAt = (duration and duration > 0) and (os.time() + duration) or 0

	self:Set(player, "banned", {
		isBanned = true,
		reason = reason or "No reason provided",
		expiresAt = expiresAt,
	})
	self:Save(player)

	self.Banned:Fire(player, reason or "No reason provided", expiresAt)

	player:Kick("You have been banned. Reason: " .. (reason or "No reason provided"))
end

function PlayerDataService:UnbanPlayer(player)
	self:Set(player, "banned", { isBanned = false, reason = "", expiresAt = 0 })
	self:Save(player)
end

function PlayerDataService:SlinStart()
	Store:StartAutosave(60)

	local function loadPlayer(player)
		local profile = Store:LoadAsync(player)
		if not profile then
			player:Kick("Failed to load your data. Please rejoin.")
			return
		end

		local banned = profile.Data.banned
		if banned and banned.isBanned then
			if banned.expiresAt ~= 0 and os.time() >= banned.expiresAt then
				profile:Set("banned", { isBanned = false, reason = "", expiresAt = 0 })
			else
				local msg = "You have been banned."
				if banned.reason and banned.reason ~= "" then
					msg ..= " Reason: " .. banned.reason
				end
				msg ..= (banned.expiresAt ~= 0)
					and (" Expires: " .. os.date("%c", banned.expiresAt))
					or " This ban is permanent."

				player:Kick(msg)
				Store:Release(player)
				return
			end
		end

		SlinReplicaService.NewReplica({
			Token = "PlayerData",
			Player = player,
			Data = profile.Data,
		})

		self.ProfileLoaded:Fire(player, profile.Data)

		for gamepassKey in pairs(GAMEPASS_IDS) do
			task.spawn(function()
				self:CheckGamepass(player, gamepassKey)
			end)
		end
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

	local subscribed, err = pcall(function()
		MessagingService:SubscribeAsync("DataStoreProTrusted", function(msg)
			local data = msg.Data
			if type(data) ~= "table" then return end

			local player = Players:GetPlayerByUserId(data.userId)
			if not player then return end

			local profile = getProfile(player)
			if not profile then return end

			if type(data.data) ~= "table" then return end

			for k, v in pairs(data.data) do
				self:Set(player, k, v)
			end
		end)
	end)

	if not subscribed then
		warn("[PlayerDataService] MessagingService subscription failed:", err)
	end
end

function PlayerDataService:CheckGamepass(player, gamepassKey)
	local profile = getProfile(player)
	if not profile then
		return false, "ProfileNotLoaded"
	end

	local gamepassId = GAMEPASS_IDS[gamepassKey]
	if not gamepassId then
		return false, "UnknownGamepass"
	end

	local cached = profile:Get("gamepasses")
	if cached and cached[gamepassKey] then
		return true
	end

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)

	if not success then
		warn("[PlayerDataService] Gamepass check failed for", player.Name, owns)
		return false, "CheckFailed"
	end

	if owns then
		local gamepasses = deepCopy(profile:Get("gamepasses") or {})
		gamepasses[gamepassKey] = true
		self:Set(player, "gamepasses", gamepasses)
	end

	return owns
end

function PlayerDataService.Client.CheckGamepass(player, gamepassKey)
	return PlayerDataService:CheckGamepass(player, gamepassKey)
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

	self.DailyRewardClaimed:Fire(player, reward, nextStreak)

	return true, reward
end

function PlayerDataService.Client:GetData(player)
	local profile = getProfile(player)

	return profile and profile.Data or nil
end

function PlayerDataService.Client:ClaimDaily(player)
	return PlayerDataService:ClaimDaily(player)
end

function PlayerDataService:AddXP(player, amount)
	local level = self:Get(player, "Level") or 1
	local xp = self:Get(player, "XP") or 0

	xp += amount

	while xp >= xpRequired(level) do
		xp -= xpRequired(level)
		level += 1

		self.LeveledUp:Fire(player, level)
	end

	self:Set(player, "XP", xp)
	self:Set(player, "Level", level)
end

function PlayerDataService:SetCooldown(player, name, duration)
	local profile = getProfile(player)
	if not profile then return end

	local c = deepCopy(profile:Get("Cooldowns") or {})
	c[name] = os.time() + duration

	self:Set(player, "Cooldowns", c)
end

function PlayerDataService:IsCooldown(player, name)
	local profile = getProfile(player)
	if not profile then return false end

	local c = profile:Get("Cooldowns") or {}
	return c[name] ~= nil and os.time() < c[name]
end

function PlayerDataService:GetSpinStatus(player)
	local profile = getProfile(player)
	if not profile then
		return { ready = false, remaining = SPIN_COOLDOWN, streak = 0, multiplier = 1 }
	end

	local spinData = profile:Get("spinData")
	local now = os.time()
	local elapsed = now - spinData.lastSpin
	local remaining = math.max(0, SPIN_COOLDOWN - elapsed)

	local nextStreak = elapsed > SPIN_STREAK_WINDOW and 1 or math.min(spinData.streak + 1, MAX_STREAK)

	return {
		ready = remaining <= 0,
		remaining = remaining,
		streak = spinData.streak,
		multiplier = SPIN_STREAK_MULTIPLIER[nextStreak] or 1,
	}
end

function PlayerDataService:SpinWheel(player)
	local profile = getProfile(player)
	if not profile then return { success = false, reason = "NoProfile" } end

	local spinData = deepCopy(profile:Get("spinData"))
	local now = os.time()
	local elapsed = now - spinData.lastSpin

	if elapsed < SPIN_COOLDOWN then
		return {
			success = false,
			reason = "Cooldown",
			remaining = SPIN_COOLDOWN - elapsed,
		}
	end

	if elapsed > SPIN_STREAK_WINDOW then
		spinData.streak = 1
	else
		spinData.streak = math.min(spinData.streak + 1, MAX_STREAK)
	end
	spinData.lastSpin = now

	self:Set(player, "spinData", spinData)

	local angle = math.random(1, 360)
	local won
	for _, entry in ipairs(PRIZES) do
		if angle >= entry.min and angle <= entry.max then
			won = entry
			break
		end
	end

	if not won then
		return { success = false, reason = "NoPrizeMatched" }
	end

	local multiplier = SPIN_STREAK_MULTIPLIER[spinData.streak] or 1
	local amount = math.floor(won.amount * multiplier)

	self:Add(player, won.prize, amount)

	return {
		success = true,
		angle = angle,
		prizeName = won.name,
		prize = won.prize,
		amount = amount,
		streak = spinData.streak,
		multiplier = multiplier,
	}
end

function PlayerDataService.Client:SpinWheel(player)
	return PlayerDataService:SpinWheel(player)
end

function PlayerDataService.Client:GetSpinStatus(player)
	return PlayerDataService:GetSpinStatus(player)
end

function PlayerDataService:Rebirth(player)
	local profile = getProfile(player)
	if not profile then
		return false, "ProfileNotLoaded"
	end

	local canRebirth, reason = self:CanRebirth(player)
	if not canRebirth then
		return false, reason
	end

	local currentRebirths = profile:Get("Rebirths") or 0
	local newRebirths = currentRebirths + 1

	for key, defaultValue in pairs(DEFAULT_DATA) do
		if key ~= "Rebirths" then
			local valueToSet = defaultValue
			if type(defaultValue) == "table" then
				valueToSet = deepCopy(defaultValue)
			end
			self:Set(player, key, valueToSet)
		end
	end

	self:Set(player, "Rebirths", newRebirths)
	self:Set(player, "duck_multiplier", 1 + (newRebirths * 0.5))

	return true, newRebirths
end

local rebirth_money = 10000000
local rebirth_gems = 5000

function PlayerDataService:CanRebirth(player)
	local profile = getProfile(player)
	if not profile then
		return false, "ProfileNotLoaded"
	end

	local playerCash = profile:Get("Cash")
	local playerGems = profile:Get("Gems")

	if playerCash >= rebirth_money and playerGems >= rebirth_gems then
		return true
	end

	return false, "NotEligible"
end

function PlayerDataService.Client:CheckIfRebirth(player)
	return PlayerDataService:CanRebirth(player)
end

local lastRebirthAttempt = {}

function PlayerDataService.Client:Rebirth(player)
	local now = os.clock()
	if lastRebirthAttempt[player] and now - lastRebirthAttempt[player] < 1 then
		return false, "TooFast"
	end
	lastRebirthAttempt[player] = now

	return PlayerDataService:Rebirth(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastRebirthAttempt[player] = nil
end)

return PlayerDataService
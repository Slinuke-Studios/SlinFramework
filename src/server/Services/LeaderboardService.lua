local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local SlinServer = require(ServerScriptService.Slin.SlinServer)

local DEFAULT_BOARD = "Cash"
local DEFAULT_LIMIT = 10
local MAX_LIMIT = 100
local CROWN = utf8.char(0x1F451)

local LeaderboardService = SlinServer.CreateService({
	Name = "LeaderboardService",
	Priority = 20,
	Client = {},
	Boards = {
		Cash = {
			DataPath = "Cash",
			StoreName = "SlinLeaderboard_Cash",
			DisplayName = "Cash",
		},
		Gems = {
			DataPath = "Gems",
			StoreName = "SlinLeaderboard_Gems",
			DisplayName = "Gems",
		},
		Level = {
			DataPath = "Level",
			StoreName = "SlinLeaderboard_Level",
			DisplayName = "Level",
		},
	},
	_nameCache = {},
})

local BOARD_ALIASES = {
	cash = "Cash",
	most_cash = "Cash",
	gems = "Gems",
	gem = "Gems",
	most_gems = "Gems",
	level = "Level",
}

local function clampLimit(limit)
	limit = tonumber(limit) or DEFAULT_LIMIT
	return math.clamp(math.floor(limit), 1, MAX_LIMIT)
end

local function normalizeBoardName(boardName)
	boardName = boardName or DEFAULT_BOARD

	if LeaderboardService.Boards[boardName] then
		return boardName
	end

	local normalized = string.lower(tostring(boardName))
	normalized = string.gsub(normalized, "%s+", "_")

	return BOARD_ALIASES[normalized] or boardName
end

local function getBoardConfig(boardName)
	boardName = normalizeBoardName(boardName)
	return boardName, LeaderboardService.Boards[boardName]
end

local function normalizeClientArgs(first, second, third)
	if typeof(first) == "Instance" and first:IsA("Player") then
		return second, third
	end

	return first, second
end

function LeaderboardService:_getStore(boardName)
	local _, config = getBoardConfig(boardName)

	if not config then
		return nil
	end

	if not config.Store then
		config.Store = DataStoreService:GetOrderedDataStore(config.StoreName)
	end

	return config.Store
end

function LeaderboardService:_getPlayerName(userId)
	local cached = self._nameCache[userId]

	if cached then
		return cached
	end

	local player = Players:GetPlayerByUserId(userId)
	if player then
		self._nameCache[userId] = player.Name
		return player.Name
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if ok then
		self._nameCache[userId] = name
		return name
	end

	return "User_" .. tostring(userId)
end

function LeaderboardService:SlinStart()
	local PlayerDataService = SlinServer.GetService("PlayerDataService")

	if not PlayerDataService then
		warn("[LeaderboardService] PlayerDataService was not found")
		return
	end

	PlayerDataService.ProfileLoaded:Connect(function(player)
		for boardName, config in pairs(self.Boards) do
			local value = PlayerDataService:Get(player, config.DataPath)
			self:UpdateScore(player, boardName, value or 0)
		end
	end)

	PlayerDataService.Changed:Connect(function(player, path, value)
		for boardName, config in pairs(self.Boards) do
			if config.DataPath == path then
				self:UpdateScore(player, boardName, value)
			end
		end
	end)
end

function LeaderboardService:UpdateScore(player, boardName, score)
	local store = self:_getStore(boardName)

	if not store then
		warn("[LeaderboardService] Unknown board:", tostring(boardName))
		return false, "UnknownBoard"
	end

	score = math.max(0, math.floor(tonumber(score) or 0))

	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), math.floor(score))
	end)

	if not ok then
		warn("[LeaderboardService] Failed to update", boardName, player.Name, err)
		return false, err
	end

	return true
end

function LeaderboardService:GetTop(boardName, limit)
	local store = self:_getStore(boardName)

	if not store then
		warn("[LeaderboardService] Unknown board:", tostring(boardName))
		return {}
	end

	limit = clampLimit(limit)

	local ok, pagesOrError = pcall(function()
		return store:GetSortedAsync(false, limit)
	end)

	if not ok then
		warn("[LeaderboardService] Failed to read", boardName, pagesOrError)
		return {}
	end

	local entries = {}

	for rank, entry in ipairs(pagesOrError:GetCurrentPage()) do
		local userId = tonumber(entry.key)

		table.insert(entries, {
			Rank = rank,
			UserId = userId,
			Name = if userId then self:_getPlayerName(userId) else tostring(entry.key),
			Score = entry.value,
		})
	end

	return entries
end

function LeaderboardService:GetRankMap(boardName, limit)
	local map = {}

	for _, entry in ipairs(self:GetTop(boardName, limit)) do
		if entry.UserId then
			map[entry.UserId] = entry.Rank
		end
	end

	return map
end

function LeaderboardService:Format(entries)
	local lines = {}

	for _, entry in ipairs(entries) do
		local crown = if entry.Rank == 1 then CROWN else ""
		table.insert(lines, string.format("%d%s: %s - %s", entry.Rank, crown, entry.Name, tostring(entry.Score)))
	end

	if #lines == 0 then
		return "No leaderboard data yet."
	end

	return table.concat(lines, "\n")
end

function LeaderboardService.Client:GetTop(first, second, third)
	local boardName, limit = normalizeClientArgs(first, second, third)
	return LeaderboardService:GetTop(boardName, limit)
end

function LeaderboardService.Client:GetFormattedText(first, second, third)
	local boardName, limit = normalizeClientArgs(first, second, third)
	return LeaderboardService:Format(LeaderboardService:GetTop(boardName, limit))
end

function LeaderboardService.Client:GetRankMap(first, second, third)
	local boardName, limit = normalizeClientArgs(first, second, third)
	return LeaderboardService:GetRankMap(boardName, limit)
end

return LeaderboardService

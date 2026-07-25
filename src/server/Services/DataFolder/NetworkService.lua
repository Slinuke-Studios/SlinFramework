local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")

if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local function getOrCreate(className, name)
	local obj = Remotes:FindFirstChild(name)

	if obj then
		return obj
	end

	obj = Instance.new(className)
	obj.Name = name
	obj.Parent = Remotes

	return obj
end

local RE_Full = getOrCreate("RemoteEvent", "FullData")
local RE_Delta = getOrCreate("RemoteEvent", "DeltaSync")
local RE_Request = getOrCreate("RemoteEvent", "ClientRequest")
local RE_Ready = getOrCreate("RemoteEvent", "ClientReady")

local NetworkService = {}

local Ready = {}
local PendingFullData = {}
local Handlers = {}

local function rateLimit()
	local bucket = {}
	return function(player)
		local uid = player.UserId
		local now = os.clock()

		bucket[uid] = bucket[uid] or {c = 0, t = now + 1}

		local b = bucket[uid]

		if now > b.t then
			b.c = 0
			b.t = now + 1
		end

		b.c += 1
		return b.c < 10
	end
end

local checkRate = rateLimit()

RE_Ready.OnServerEvent:Connect(function(player)
	print(player.Name, "sent ClientReady")

	Ready[player] = true

	if PendingFullData[player] then
		RE_Full:FireClient(player, PendingFullData[player])
		PendingFullData[player] = nil
	end
end)

function NetworkService.SendFullData(player, data)
	if Ready[player] then
		RE_Full:FireClient(player, data)
	else
		PendingFullData[player] = data
	end
end

function NetworkService.SendDelta(player, delta)
	if Ready[player] then
		RE_Delta:FireClient(player, delta)
	end
end

function NetworkService.OnRequest(action, fn)
	assert(type(action) == "string", "NetworkService.OnRequest expects a string action")
	assert(type(fn) == "function", "NetworkService.OnRequest expects a function handler")

	Handlers[action] = fn
end

RE_Request.OnServerEvent:Connect(function(player, action, payload)
	if type(action) ~= "string" then return end
	if not checkRate(player) then return end

	local fn = Handlers[action]
	if fn then
		local ok, err = pcall(fn, player, payload)
		if not ok then warn(err) end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Ready[player] = nil
	PendingFullData[player] = nil
end)

return NetworkService

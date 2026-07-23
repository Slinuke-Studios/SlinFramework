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
end)

function NetworkService.SendFullData(player, data)
	if Ready[player] then
		RE_Full:FireClient(player, data)
	else
		task.delay(1, function()
			if player.Parent then
				RE_Full:FireClient(player, data)
			end
		end)
	end
end

function NetworkService.SendDelta(player, delta)
	if Ready[player] then
		RE_Delta:FireClient(player, delta)
	end
end

function NetworkService.OnRequest(action, fn)
	Handlers[action] = fn
end

RE_Request.OnServerEvent:Connect(function(player, action, payload)
	if not checkRate(player) then return end

	local fn = Handlers[action]
	if fn then
		local ok, err = pcall(fn, player, payload)
		if not ok then warn(err) end
	end
end)

return NetworkService
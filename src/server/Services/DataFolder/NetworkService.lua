local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SlinNet = require(ReplicatedStorage.Shared.Slin.SlinNet)

local RE_Full = SlinNet.Event("FullData")
local RE_Delta = SlinNet.Event("DeltaSync")
local RE_Request = SlinNet.Event("ClientRequest")
local RE_Ready = SlinNet.Event("ClientReady")
local RE_SpinResult = SlinNet.Event("SpinResult")
local RE_SpinStatus = SlinNet.Event("SpinStatus")

local NetworkService = {}

local Ready = {}
local PendingFullData = {}
local Handlers = {}

-- (rateLimit, checkRate, RE_Ready.OnServerEvent:Connect(...), SendFullData, SendDelta,
--  OnRequest, RE_Request.OnServerEvent:Connect(...), PlayerRemoving — all stay exactly the same)

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
	print("SendDelta called, Ready?", Ready[player])
	if Ready[player] then
		RE_Delta:FireClient(player, delta)
	end
end

function NetworkService.OnRequest(action, fn)
	assert(type(action) == "string", "NetworkService.OnRequest expects a string action")
	assert(type(fn) == "function", "NetworkService.OnRequest expects a function handler")

	Handlers[action] = fn
end

function NetworkService.SendSpinResult(player, result)
	RE_SpinResult:FireClient(player, result)
end

function NetworkService.SendSpinStatus(player, status)
	RE_SpinStatus:FireClient(player, status)
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

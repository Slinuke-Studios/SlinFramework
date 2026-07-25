local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlinNet = require(ReplicatedStorage.Slin.SlinNet)
local TableUtil = require(ReplicatedStorage.Slin.TableUtil)

local RE_ReplicaCreate = SlinNet.Event("ReplicaCreate")
local RE_ReplicaPatch = SlinNet.Event("ReplicaPatch")
local RE_ReplicaDestroy = SlinNet.Event("ReplicaDestroy")
local RF_ReplicaRequestFull = SlinNet.Function("ReplicaRequestFull")

local SlinReplicaService = {
	_replicas = {},
}

local Replica = {}
Replica.__index = Replica

RF_ReplicaRequestFull.OnServerInvoke = function(player)
	local snapshots = {}
	local playerReplicas = SlinReplicaService._replicas[player]

	if not playerReplicas then
		return snapshots
	end

	for token, replica in pairs(playerReplicas) do
		snapshots[token] = TableUtil.DeepCopy(replica.Data)
	end

	return snapshots
end

function SlinReplicaService.NewReplica(options)
	assert(type(options) == "table", "NewReplica expects an options table")
	assert(type(options.Token) == "string", "Replica requires a Token")
	assert(typeof(options.Player) == "Instance" and options.Player:IsA("Player"), "Replica requires a Player")

	local self = setmetatable({}, Replica)

	self.Token = options.Token
	self.Player = options.Player
	self.Data = TableUtil.DeepCopy(options.Data or {})
	self._destroyed = false

	SlinReplicaService._replicas[self.Player] = SlinReplicaService._replicas[self.Player] or {}
	SlinReplicaService._replicas[self.Player][self.Token] = self

	RE_ReplicaCreate:FireClient(self.Player, self.Token, TableUtil.DeepCopy(self.Data))

	return self
end

function Replica:Get(path)
	return TableUtil.DeepCopy(TableUtil.GetPath(self.Data, path))
end

function Replica:Set(path, value)
	assert(not self._destroyed, "Cannot set data on a destroyed replica")

	local oldValue = TableUtil.SetPath(self.Data, path, value)

	RE_ReplicaPatch:FireClient(self.Player, self.Token, {
		Type = "Set",
		Path = path,
		Value = TableUtil.DeepCopy(value),
	})

	return oldValue
end

function Replica:Update(path, updater)
	local oldValue = self:Get(path)
	local newValue = updater(oldValue)

	self:Set(path, newValue)

	return newValue, oldValue
end

function Replica:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true

	if SlinReplicaService._replicas[self.Player] then
		SlinReplicaService._replicas[self.Player][self.Token] = nil
	end

	RE_ReplicaDestroy:FireClient(self.Player, self.Token)
end

function SlinReplicaService.GetReplica(player, token)
	local playerReplicas = SlinReplicaService._replicas[player]

	return playerReplicas and playerReplicas[token]
end

Players.PlayerRemoving:Connect(function(player)
	local playerReplicas = SlinReplicaService._replicas[player]

	if not playerReplicas then
		return
	end

	for _, replica in pairs(playerReplicas) do
		replica:Destroy()
	end

	SlinReplicaService._replicas[player] = nil
end)

return SlinReplicaService

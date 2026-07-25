local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Slin.Signal)
local SlinNet = require(ReplicatedStorage.Slin.SlinNet)
local TableUtil = require(ReplicatedStorage.Slin.TableUtil)

local RE_ReplicaCreate = SlinNet.Event("ReplicaCreate")
local RE_ReplicaPatch = SlinNet.Event("ReplicaPatch")
local RE_ReplicaDestroy = SlinNet.Event("ReplicaDestroy")
local RF_ReplicaRequestFull = SlinNet.Function("ReplicaRequestFull")

local SlinReplicaController = {
	ReplicaCreated = Signal.New(),
	ReplicaDestroyed = Signal.New(),
	ReplicaChanged = Signal.New(),
	_replicas = {},
}

function SlinReplicaController.Start()
	if SlinReplicaController._started then
		return
	end

	SlinReplicaController._started = true

	RE_ReplicaCreate.OnClientEvent:Connect(function(token, data)
		SlinReplicaController._replicas[token] = TableUtil.DeepCopy(data)
		SlinReplicaController.ReplicaCreated:Fire(token, SlinReplicaController:Get(token))
	end)

	RE_ReplicaPatch.OnClientEvent:Connect(function(token, patch)
		local data = SlinReplicaController._replicas[token]

		if not data or type(patch) ~= "table" then
			return
		end

		if patch.Type == "Set" and type(patch.Path) == "string" then
			local oldValue = TableUtil.SetPath(data, patch.Path, patch.Value)

			SlinReplicaController.ReplicaChanged:Fire(
				token,
				patch.Path,
				TableUtil.DeepCopy(patch.Value),
				TableUtil.DeepCopy(oldValue)
			)
		end
	end)

	RE_ReplicaDestroy.OnClientEvent:Connect(function(token)
		SlinReplicaController._replicas[token] = nil
		SlinReplicaController.ReplicaDestroyed:Fire(token)
	end)

	task.spawn(function()
		local ok, snapshots = pcall(function()
			return RF_ReplicaRequestFull:InvokeServer()
		end)

		if not ok or type(snapshots) ~= "table" then
			return
		end

		for token, data in pairs(snapshots) do
			if SlinReplicaController._replicas[token] == nil then
				SlinReplicaController._replicas[token] = TableUtil.DeepCopy(data)
				SlinReplicaController.ReplicaCreated:Fire(token, SlinReplicaController:Get(token))
			end
		end
	end)
end

function SlinReplicaController:Get(token)
	return TableUtil.DeepCopy(self._replicas[token])
end

function SlinReplicaController:GetPath(token, path)
	local replica = self._replicas[token]

	if not replica then
		return nil
	end

	return TableUtil.DeepCopy(TableUtil.GetPath(replica, path))
end

function SlinReplicaController:Subscribe(token, path, callback)
	return self.ReplicaChanged:Connect(function(changedToken, changedPath, newValue, oldValue)
		if changedToken == token and changedPath == path then
			callback(newValue, oldValue)
		end
	end)
end

return SlinReplicaController

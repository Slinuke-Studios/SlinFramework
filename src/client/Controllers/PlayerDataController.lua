local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlinClient = require(script.Parent.Parent.Slin.SlinClient)
local SlinReplicaController = require(script.Parent.Parent.Slin.SlinReplicaController)
local Signal = require(ReplicatedStorage.Shared.Slin.Signal)

local PlayerDataController = SlinClient.CreateController({
	Name = "PlayerDataController",
	Priority = 10,
	Loaded = Signal.New(),
	Changed = Signal.New(),
	_loadedData = nil,
})

function PlayerDataController:SlinInit()
	SlinReplicaController.Start()

	SlinReplicaController.ReplicaCreated:Connect(function(token, data)
		if token == "PlayerData" then
			self._loadedData = data
			self.Loaded:Fire(data)
		end
	end)

	SlinReplicaController.ReplicaChanged:Connect(function(token, path, newValue, oldValue)
		-- print("ReplicaChanged fired:", token, path, newValue, oldValue) // add this // fym add this, add what fam??
		if token == "PlayerData" then
			self.Changed:Fire(path, newValue, oldValue)
		end
	end)
end

function PlayerDataController:WaitForData()
	if self._loadedData then
		return self._loadedData
	end
	return self.Loaded:Wait()
end

function PlayerDataController:Get(path)
	if path then
		return SlinReplicaController:GetPath("PlayerData", path)
	end

	return SlinReplicaController:Get("PlayerData")
end

function PlayerDataController:Subscribe(path, callback)
	return self.Changed:Connect(function(changedPath, newValue, oldValue)
		if changedPath == path then
			callback(newValue, oldValue)
		end
	end)
end

function PlayerDataController:ClaimDaily()
	local service = SlinClient.GetService("PlayerDataService")

	return service:ClaimDaily()
end

return PlayerDataController
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlinClient = require(script.Parent.Parent.Slin.SlinClient)
local SlinReplicaController = require(script.Parent.Parent.Slin.SlinReplicaController)
local Signal = require(ReplicatedStorage.Slin.Signal)

local PlayerDataController = SlinClient.CreateController({
	Name = "PlayerDataController",
	Priority = 10,
	Loaded = Signal.New(),
	Changed = Signal.New(),
})

function PlayerDataController:SlinInit()
	SlinReplicaController.Start()

	SlinReplicaController.ReplicaCreated:Connect(function(token, data)
		if token == "PlayerData" then
			self.Loaded:Fire(data)
		end
	end)

	SlinReplicaController.ReplicaChanged:Connect(function(token, path, newValue, oldValue)
		if token == "PlayerData" then
			self.Changed:Fire(path, newValue, oldValue)
		end
	end)
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

local DataService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("DataFolder"):WaitForChild("DataService"))
local NetworkService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("DataFolder"):WaitForChild("NetworkService"))

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	DataService:Init(NetworkService)
end)
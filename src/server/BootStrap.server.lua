local DataService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("DataFolder"):WaitForChild("DataService"))
local NetworkService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("DataFolder"):WaitForChild("NetworkService"))

DataService:Init(NetworkService)

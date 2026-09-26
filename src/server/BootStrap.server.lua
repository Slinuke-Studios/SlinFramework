local ServerScriptService = game:GetService("ServerScriptService")

local SlinServer = require(ServerScriptService.Server.Slin.SlinServer)

SlinServer.LoadServices(ServerScriptService.Server.Services)
SlinServer.Start()

local DataService = require(game.ServerScriptService.Server.Services.DataFolder.DataService)
local NetworkService = require(game.ServerScriptService.Server.Services.DataFolder.NetworkService) -- ingore / player data is handled with SlinReplicaService

DataService:Init(NetworkService)

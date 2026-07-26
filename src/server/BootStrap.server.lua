local ServerScriptService = game:GetService("ServerScriptService")

local SlinServer = require(ServerScriptService.Slin.SlinServer)

SlinServer.LoadServices(ServerScriptService.Services)
SlinServer.Start()

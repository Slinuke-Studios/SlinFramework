local clientRoot = script.Parent

local SlinClient = require(clientRoot.Slin.SlinClient)

SlinClient.LoadControllers(clientRoot.Controllers)
SlinClient.Start()

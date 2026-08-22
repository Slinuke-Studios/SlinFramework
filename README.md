# SlinFramework

SlinFramework is a custom Roblox framework inspired by the ideas behind Knit, ReplicaService, and ProfileStore, without depending on those packages.

It gives you:

- `SlinServer.CreateService()` for server services
- `SlinClient.CreateController()` for client controllers
- `SlinProfileStore` for template-based player data loading and saving
- `SlinReplicaService` for server-owned data replication to clients
- `SlinReplicaController` for client-side replicated state subscriptions
- `SlinNet` for framework-owned remotes

- `Leaderboard` with chat tags to go with it. 
## Rojo Setup

```powershell
rojo serve default.project.json
```

Then connect from Roblox Studio with the Rojo plugin.

## Folder Layout

```text
src/
  shared/
    Slin/                 Shared framework modules
  server/
    Slin/                 Server-only framework modules
    Services/             Slin services
    BootStrap.server.lua  Starts server services
  client/
    Slin/                 Client-only framework modules
    Controllers/          Slin controllers
    StarterPlayerScripts/
      DataBootStrap.client.lua
```

## Service Example

```lua
local ServerScriptService = game:GetService("ServerScriptService")

local SlinServer = require(ServerScriptService.Slin.SlinServer)

local CoinsService = SlinServer.CreateService({
	Name = "CoinsService",
	Priority = 10,
	Client = {},
})

function CoinsService:SlinStart()
	print("CoinsService started")
end

function CoinsService:AddCoins(player, amount)
	print(player.Name, amount)
end

function CoinsService.Client:GetCoins(player)
	return 100
end

return CoinsService
```

## Controller Example

```lua
local SlinClient = require(script.Parent.Parent.Slin.SlinClient)

local CoinsController = SlinClient.CreateController({
	Name = "CoinsController",
	Priority = 10,
})

function CoinsController:SlinStart()
	local coinsService = SlinClient.GetService("CoinsService")
	print(coinsService:GetCoins())
end

return CoinsController
```

## Player Data

`PlayerDataService` shows the intended full pattern:

1. Load data with `SlinProfileStore`.
2. Create a `"PlayerData"` replica for the joining player.
3. Mutate data only on the server.
4. Replicate changes to the client through `SlinReplicaService`.
5. Read and subscribe on the client with `PlayerDataController`.

Client usage:

```lua
local PlayerDataController = SlinClient.GetController("PlayerDataController")

PlayerDataController.Loaded:Connect(function(data)
	print("Loaded cash:", data.Cash)
end)

PlayerDataController:Subscribe("Cash", function(newCash, oldCash)
	print("Cash changed:", oldCash, newCash)
end)
```

## Important Notes

This is a custom starter version, not a drop-in replacement for mature production libraries yet. The biggest future upgrades are:

- session locking for profiles
- autosave intervals
- retry/backoff around DataStore writes
- server-to-client event signals for services
- middleware for validating client requests
- better typed Luau annotations

Those are the exact next steps that would make SlinFramework feel more production-ready while still staying custom.

# SlinFramework

A Roblox data and networking framework built around:

- server-side profile loading through `DataService`
- client data replication through `Data_CLIENT`
- remote setup through `NetworkService`
- shared custom signals through `Packages/Signal`

## Rojo Setup

Run this from the framework folder:

```powershell
rojo serve default.project.json
```

Then connect from Roblox Studio with the Rojo plugin.

## Runtime Flow

1. `BootStrap.server.lua` starts `DataService` once.
2. `DataService` loads player profiles and sends full data through `NetworkService`.
3. `DataBootStrap.client.lua` starts `Data_CLIENT`.
4. The client fires `ClientReady`.
5. `NetworkService` sends pending full data, then future deltas.

## Client Usage

```lua
local Data = require(game.ReplicatedStorage.Clients.Data_CLIENT)

Data.Loaded:Connect(function()
	print(Data:Get("Cash"))
end)

Data:Subscribe("Cash", function(newCash, oldCash)
	print("Cash changed", oldCash, newCash)
end)

Data:Request("ClaimDaily")
```

## Server Usage

```lua
local DataService = require(game.ServerScriptService.Services.DataFolder.DataService)

DataService.ProfileLoaded.Event:Connect(function(player)
	DataService:Add(player, "Cash", 100)
end)
```

## What Was Improved

- Fixed `Signal:Connect`, added disconnect, once, wait, and destroy support.
- Fixed server bootstrap so `DataService:Init()` runs once instead of once per player.
- Fixed profile saving so it writes through the store owner instead of the profile table.
- Added default reconciliation so old saves receive new fields.
- Added safer client-ready handling so full data waits until the client is ready.
- Fixed delta sync shape between server and client.
- Added Rojo project config and framework documentation.

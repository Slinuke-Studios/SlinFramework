# DataStore Testing

This version uses a new DataStore name so it is easy to spot:

```text
SlinFramework_V3_v1_3
```

## Important

`GetDataStore()` does not create a visible DataStore by itself. Roblox usually shows the store only after a successful write such as `SetAsync`.

## Server Command Bar Test

Run this in the server Command Bar after your character joins:

```lua
local Players = game:GetService("Players")
local SlinServer = require(game.ServerScriptService.Slin.SlinServer)

local player = Players:FindFirstChild("Slinuke")
local PlayerDataService = SlinServer.GetService("PlayerDataService")

print("service", PlayerDataService)
print("cash before", PlayerDataService:Get(player, "Cash"))

local newCash = PlayerDataService:Add(player, "Cash", 100)
local saved, err = PlayerDataService:Save(player)

print("cash after", newCash)
print("saved", saved, err)
```

If `saved` is false, the Roblox output will now print the exact DataStore error.

## Direct Roblox DataStore Test

If the framework test still does not show a store, run this in the server Command Bar:

```lua
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("SlinFramework_DirectTest")

local ok, err = pcall(function()
	store:SetAsync("StudioTest_" .. game.PlaceId, {
		Cash = 123,
		Time = os.time(),
	})
end)

print("direct datastore write", ok, err)
```

If this prints `false`, the issue is Roblox/API settings, not SlinFramework.

## Things To Check

- The place is published.
- Studio access to API services is enabled in Game Settings.
- You are testing from the server Command Bar, not the client Command Bar.
- The DataStore plugin is looking at the same experience/universe.
 - You are checking for `SlinFramework_V3_v1_3`.
- Wait 30-60 seconds after a successful write.

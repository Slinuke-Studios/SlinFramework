# Leaderboard Usage

This version adds a custom leaderboard system to SlinFramework.

It uses Roblox `OrderedDataStore`, so the game must be published and Studio API access must be enabled for real testing.

## Store Names

The included boards create these ordered DataStores after a successful write:

```text
SlinLeaderboard_Cash
SlinLeaderboard_Gems
SlinLeaderboard_Level
SlinLeaderboard_DuckDamage
```

## Put Top Players In A TextLabel

Create a LocalScript near your `TextLabel`, then use:

```lua
local SlinClient = require(game.Players.LocalPlayer.PlayerScripts.Slin.SlinClient)
local LeaderboardController = SlinClient.WaitForController("LeaderboardController")

local label = script.Parent

LeaderboardController:BindTextLabel(label, {
	Board = "Cash",
	Limit = 10,
	RefreshSeconds = 60,
})
```

The label will become something like:

```text
1👑: Slinuke - 500
2: JohnDoe - 250
3: MissDoe - 150
```

Use `Limit = 50` or `Limit = 100` for bigger boards.

## World SurfaceGui Example

If your leaderboard parts are in Workspace, put the LocalScript in `StarterPlayerScripts`, not inside the Workspace model.

```lua
local Players = game:GetService("Players")

local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local SlinClient = require(playerScripts:WaitForChild("Slin"):WaitForChild("SlinClient"))
local LeaderboardController = SlinClient.WaitForController("LeaderboardController")

local boardModel = workspace:WaitForChild("Leaderboards")

local CashLabel = boardModel.Most_Cash.Face.SurfaceGui:WaitForChild("TextLabel")
local GemLabel = boardModel.Most_Gems.Face.SurfaceGui:WaitForChild("TextLabel")
local DuckDamageLabel = boardModel.Most_Duck_Damage.Face.SurfaceGui:WaitForChild("TextLabel")

LeaderboardController:BindTextLabel(CashLabel, {
	Board = "Cash",
	Limit = 10,
	RefreshSeconds = 60,
})

LeaderboardController:BindTextLabel(GemLabel, {
	Board = "Gems",
	Limit = 10,
	RefreshSeconds = 60,
})

LeaderboardController:BindTextLabel(DuckDamageLabel, {
	Board = "DuckDamage",
	Limit = 10,
	RefreshSeconds = 60,
})
```

## Enable Chat Tags

In a LocalScript after SlinClient starts:

```lua
local SlinClient = require(game.Players.LocalPlayer.PlayerScripts.Slin.SlinClient)
local LeaderboardController = SlinClient.WaitForController("LeaderboardController")

LeaderboardController:EnableChatTags({
	Board = "Cash",
	Limit = 100,
	RefreshSeconds = 60,
})
```

Players in the top 100 will appear like:

```text
[TOP 1] Slinuke: Hi!
[TOP 27] JohnDoe: Hello!
```

## Server Usage

`LeaderboardService` automatically watches `PlayerDataService.Changed`, so when this happens:

```lua
PlayerDataService:Add(player, "Cash", 100)
```

the `Cash` leaderboard updates too.

You can also manually update a board:

```lua
local SlinServer = require(game.ServerScriptService.Slin.SlinServer)
local LeaderboardService = SlinServer.GetService("LeaderboardService")

LeaderboardService:UpdateScore(player, "Cash", 500)
```

## Notes

- OrderedDataStores only show after a successful write.
- Reading top 100 too often can hit DataStore limits; keep refresh around 60 seconds or higher.
- Chat tags use `TextChatService.OnIncomingMessage`, so another script that sets this callback can override it.


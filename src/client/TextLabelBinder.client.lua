local SlinClient = require(game.Players.LocalPlayer.PlayerScripts.Slin.SlinClient)
local LeaderboardController = SlinClient.WaitForController("LeaderboardController")

local label = script.Parent -- YOUR TEXT LABEL

LeaderboardController:BindTextLabel(label, {
	Board = "Cash",
	Limit = 10,
	RefreshSeconds = 60,
})

-- this comment is too prove i didnt use ai
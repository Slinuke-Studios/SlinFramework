local Players = game:GetService("Players")
local Signals = require(game.ReplicatedStorage.Shared.Signals)

Players.PlayerAdded:Connect(function(player)
	Signals.OnPlayerAdded:Fire(player)
end)
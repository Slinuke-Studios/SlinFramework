local Players = game:GetService("Players")

local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local SlinClient = require(playerScripts:WaitForChild("Slin"):WaitForChild("SlinClient"))
local LeaderboardController = SlinClient.WaitForController("LeaderboardController")

local boardModel = workspace:WaitForChild("map"):WaitForChild("Leaderboards")

local CashSurfaceGui = boardModel.Most_Cash:WaitForChild("Face"):WaitForChild("SurfaceGui") -- YOUR SURFACE GUI
local GemSurfaceGui = boardModel.Most_Gems:WaitForChild("Face"):WaitForChild("SurfaceGui") -- YOUR SURFACE GUI

local rowStyle = {
	Limit = 10,
	RefreshSeconds = 60,
	RowSize = UDim2.new(1, 0, 0, 32),
	TextSize = 32,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextStrokeTransparency = 0.55,
	Padding = UDim.new(0, 4),
	TextPadding = 8,
	TextXAlignment = Enum.TextXAlignment.Center,
}

LeaderboardController:BindList(CashSurfaceGui, {
	Board = "Cash",
	Limit = rowStyle.Limit,
	RefreshSeconds = rowStyle.RefreshSeconds,
	RowSize = rowStyle.RowSize,
	TextSize = rowStyle.TextSize,
	TextColor3 = rowStyle.TextColor3,
	TextStrokeTransparency = rowStyle.TextStrokeTransparency,
	Padding = rowStyle.Padding,
	TextPadding = rowStyle.TextPadding,
})

LeaderboardController:BindList(GemSurfaceGui, {
	Board = "Gems",
	Limit = rowStyle.Limit,
	RefreshSeconds = rowStyle.RefreshSeconds,
	RowSize = rowStyle.RowSize,
	TextSize = rowStyle.TextSize,
	TextColor3 = rowStyle.TextColor3,
	TextStrokeTransparency = rowStyle.TextStrokeTransparency,
	Padding = rowStyle.Padding,
	TextPadding = rowStyle.TextPadding,
})

LeaderboardController:BindList(DuckDamageSurfaceGui, {
	Board = "duck_damage",
	Limit = rowStyle.Limit,
	RefreshSeconds = rowStyle.RefreshSeconds,
	RowSize = rowStyle.RowSize,
	TextSize = rowStyle.TextSize,
	TextColor3 = rowStyle.TextColor3,
	TextStrokeTransparency = rowStyle.TextStrokeTransparency,
	Padding = rowStyle.Padding,
	TextPadding = rowStyle.TextPadding,
})
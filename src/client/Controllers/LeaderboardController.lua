local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local SlinClient = require(script.Parent.Parent.Slin.SlinClient)
local Signal = require(ReplicatedStorage.Slin.Signal)

local LeaderboardController = SlinClient.CreateController({
	Name = "LeaderboardController",
	Priority = 20,
	Updated = Signal.New(),
	_bindings = {},
	_rankMap = {},
})

local function getOption(options, key, default)
	if options and options[key] ~= nil then
		return options[key]
	end

	return default
end

local function getListContainer(target)
	if target:IsA("SurfaceGui") or target:IsA("ScreenGui") or target:IsA("BillboardGui") then
		local existing = target:FindFirstChild("LeaderboardList")

		if existing and existing:IsA("GuiObject") then
			return existing
		end

		local frame = Instance.new("Frame")
		frame.Name = "LeaderboardList"
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = target

		return frame
	end

	return target
end

local function ensureListLayout(container, options)
	local layout = container:FindFirstChildOfClass("UIListLayout")

	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Parent = container
	end

	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = getOption(options, "Padding", UDim.new(0, 4))

	return layout
end

local function clearRows(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("TextLabel") and child:GetAttribute("SlinLeaderboardRow") == true then
			child:Destroy()
		end
	end
end

local function createRow(container, rank, text, options)
	local row = Instance.new("TextLabel")
	row.Name = "Rank_" .. tostring(rank)
	row:SetAttribute("SlinLeaderboardRow", true)
	row.LayoutOrder = rank
	row.BackgroundTransparency = getOption(options, "BackgroundTransparency", 1)
	row.BackgroundColor3 = getOption(options, "BackgroundColor3", Color3.fromRGB(20, 20, 20))
	row.BorderSizePixel = 0
	row.Size = getOption(options, "RowSize", UDim2.new(1, 0, 0, 32))
	row.Font = getOption(options, "Font", Enum.Font.GothamBold)
	row.TextSize = getOption(options, "TextSize", 22)
	row.TextColor3 = getOption(options, "TextColor3", Color3.fromRGB(255, 255, 255))
	row.TextStrokeTransparency = getOption(options, "TextStrokeTransparency", 0.6)
	row.TextXAlignment = getOption(options, "TextXAlignment", Enum.TextXAlignment.Center)
	row.TextYAlignment = Enum.TextYAlignment.Center
	row.TextScaled = getOption(options, "TextScaled", false)
	row.TextWrapped = false
	row.Text = text
	row.Parent = container

	local padding = getOption(options, "TextPadding", 8)
	local paddingObject = Instance.new("UIPadding")
	paddingObject.PaddingLeft = UDim.new(0, padding)
	paddingObject.PaddingRight = UDim.new(0, padding)
	paddingObject.Parent = row

	return row
end

local function formatEntry(entry)
	local crown = if entry.Rank == 1 then utf8.char(0x1F451) else ""
	return string.format("%d%s: %s - %s", entry.Rank, crown, entry.Name, tostring(entry.Score))
end


function LeaderboardController:SlinStart()
	self._service = SlinClient.GetService("LeaderboardService")
end

function LeaderboardController:_getService()
	if not self._service then
		self._service = SlinClient.GetService("LeaderboardService")
	end

	return self._service
end

function LeaderboardController:GetTop(boardName, limit)
	return self:_getService():GetTop(boardName or "Cash", limit or 10)
end

function LeaderboardController:GetFormattedText(boardName, limit)
	return self:_getService():GetFormattedText(boardName or "Cash", limit or 10)
end

function LeaderboardController:BindTextLabel(textLabel, options)
	assert(typeof(textLabel) == "Instance" and textLabel:IsA("TextLabel"), "BindTextLabel expects a TextLabel")

	options = options or {}

	local binding = {
		Label = textLabel,
		Board = getOption(options, "Board", "Cash"),
		Limit = getOption(options, "Limit", 10),
		RefreshSeconds = getOption(options, "RefreshSeconds", 60),
		Active = true,
	}

	textLabel.Text = "Loading leaderboard..."
	table.insert(self._bindings, binding)

	local function refresh()
		if not binding.Active or not textLabel.Parent then
			binding.Active = false
			return
		end

		local ok, textOrError = pcall(function()
			return self:GetFormattedText(binding.Board, binding.Limit)
		end)

		if ok then
			textLabel.Text = textOrError
			self.Updated:Fire(binding.Board, textOrError)
		else
			textLabel.Text = "Leaderboard unavailable."
			warn("[LeaderboardController] Failed to update", binding.Board, "label:", textOrError)
		end
	end

	task.spawn(function()
		while binding.Active and textLabel.Parent do
			refresh()
			task.wait(binding.RefreshSeconds)
		end
	end)

	return {
		Refresh = refresh,
		Disconnect = function()
			binding.Active = false
		end,
	}
end

function LeaderboardController:BindList(target, options)
	assert(typeof(target) == "Instance", "BindList expects a SurfaceGui, ScreenGui, BillboardGui, Frame, or ScrollingFrame")

	options = options or {}

	local container = getListContainer(target)
	assert(container:IsA("GuiObject"), "BindList target must contain or be a GuiObject")

	ensureListLayout(container, options)

	local binding = {
		Container = container,
		Board = getOption(options, "Board", "Cash"),
		Limit = getOption(options, "Limit", 10),
		RefreshSeconds = getOption(options, "RefreshSeconds", 60),
		Active = true,
	}

	table.insert(self._bindings, binding)

	local function renderLoading()
		clearRows(container)
		createRow(container, 1, "Loading leaderboard...", options)
	end

	local function refresh()
		if not binding.Active or not container.Parent then
			binding.Active = false
			return
		end

		local ok, entriesOrError = pcall(function()
			return self:GetTop(binding.Board, binding.Limit)
		end)

		clearRows(container)

		if not ok then
			createRow(container, 1, "Leaderboard unavailable.", options)
			warn("[LeaderboardController] Failed to update", binding.Board, "list:", entriesOrError)
			return
		end

		if #entriesOrError == 0 then
			createRow(container, 1, "No leaderboard data yet.", options)
			return
		end

		for _, entry in ipairs(entriesOrError) do
			createRow(container, entry.Rank, formatEntry(entry), options)
		end

		self.Updated:Fire(binding.Board, entriesOrError)
	end

	renderLoading()

	task.spawn(function()
		while binding.Active and container.Parent do
			refresh()
			task.wait(binding.RefreshSeconds)
		end
	end)

	return {
		Refresh = refresh,
		Disconnect = function()
			binding.Active = false
		end,
	}
end

function LeaderboardController:EnableChatTags(options)
	options = options or {}

	local board = getOption(options, "Board", "Cash")
	local limit = getOption(options, "Limit", 100)
	local refreshSeconds = getOption(options, "RefreshSeconds", 60)

	task.spawn(function()
		while true do
			local ok, rankMap = pcall(function()
				return self:_getService():GetRankMap(board, limit)
			end)

			if ok and type(rankMap) == "table" then
				self._rankMap = rankMap
			else
				warn("[LeaderboardController] Failed to refresh chat ranks:", rankMap)
			end

			task.wait(refreshSeconds)
		end
	end)

	TextChatService.OnIncomingMessage = function(message)
		local textSource = message.TextSource

		if not textSource then
			return nil
		end

		local rank = self._rankMap[textSource.UserId] or self._rankMap[tostring(textSource.UserId)]

		if not rank then
			return nil
		end
		
		local rankColors = {
			[1] = "#FFD700",
			[2] = "#C0C0C0",
			[3] = "#CD7F32",
		}

		local properties = Instance.new("TextChatMessageProperties")
		local color = rankColors[rank] or "#FFFFFF"
		properties.PrefixText = string.format('<font color="%s">[#%d CASH]</font> %s', color, rank, message.PrefixText)
		

		return properties
	end
end

return LeaderboardController

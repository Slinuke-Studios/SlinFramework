local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RE_FullData = Remotes:WaitForChild("FullData")
local RE_DeltaSync = Remotes:WaitForChild("DeltaSync")
local RE_ClientReady = Remotes:WaitForChild("ClientReady")
local RE_Request = Remotes:WaitForChild("ClientRequest")

local Data = {}
local Loaded = false

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}

	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end

	return copy
end

local function getNested(tbl, path)
	local current = tbl

	for key in string.gmatch(path, "[^%.]+") do
		if type(current) ~= "table" then
			return nil
		end

		current = current[key]
	end

	return current
end

local function newSignal()
	local signal = {}
	signal._connections = {}

	function signal:Connect(callback)
		local connection = {
			Callback = callback,
			Connected = true
		}

		table.insert(self._connections, connection)

		return {
			Disconnect = function()
				connection.Connected = false
			end
		}
	end

	function signal:Fire(...)
		for _, connection in ipairs(self._connections) do
			if connection.Connected then
				task.spawn(connection.Callback, ...)
			end
		end
	end

	function signal:Wait()
		local thread = coroutine.running()
		local connection

		connection = self:Connect(function(...)
			connection:Disconnect()
			task.spawn(thread, ...)
		end)

		return coroutine.yield()
	end

	return signal
end

local ClientDataService = {}

ClientDataService.Loaded = newSignal()
ClientDataService.Changed = newSignal()

function ClientDataService:Init()
	if self._initialized then
		return
	end

	self._initialized = true

	print("[ClientDataService] Initializing")

	RE_FullData.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		Data = deepCopy(data)

		if not Loaded then
			Loaded = true

			print("[ClientDataService] Full data received")

			self.Loaded:Fire()
		end
	end)

	RE_DeltaSync.OnClientEvent:Connect(function(delta)
		if type(delta) ~= "table" then
			return
		end

		for key, value in pairs(delta) do
			local oldValue = Data[key]

			Data[key] = deepCopy(value)

			self.Changed:Fire(
				key,
				deepCopy(value),
				deepCopy(oldValue)
			)
		end
	end)

	RE_ClientReady:FireServer()
end

function ClientDataService:IsLoaded()
	return Loaded
end

function ClientDataService:WaitUntilLoaded(timeout)
	if Loaded then
		return true
	end

	timeout = timeout or 30

	local finished = false

	task.delay(timeout, function()
		finished = true
	end)

	while not Loaded and not finished do
		task.wait()
	end

	return Loaded
end

function ClientDataService:Get(key)
	return deepCopy(Data[key])
end

function ClientDataService:GetNested(path)
	return deepCopy(getNested(Data, path))
end

function ClientDataService:GetAll()
	return deepCopy(Data)
end

function ClientDataService:Request(action, payload)
	RE_Request:FireServer(action, payload)
end

function ClientDataService:Subscribe(key, callback)
	return self.Changed:Connect(function(changedKey, newValue, oldValue)
		if changedKey == key then
			callback(newValue, oldValue)
		end
	end)
end

return ClientDataService
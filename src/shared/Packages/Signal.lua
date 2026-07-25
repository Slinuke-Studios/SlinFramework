local Signal = {}
Signal.__index = Signal

function Signal.New()
	return setmetatable({
		Connections = {},
		Destroyed = false,
	}, Signal)
end

function Signal:Connect(callback)
	assert(type(callback) == "function", "Signal:Connect expects a function")
	assert(not self.Destroyed, "Cannot connect to a destroyed signal")

	local connection = {
		Callback = callback,
		Connected = true,
	}

	function connection:Disconnect()
		self.Connected = false
	end

	table.insert(self.Connections, connection)
	return connection
end

function Signal:Fire(...)
	if self.Destroyed then
		return
	end

	for _, connection in ipairs(self.Connections) do
		if connection.Connected then
			task.spawn(connection.Callback, ...)
		end
	end

	local writeIndex = 1
	for _, connection in ipairs(self.Connections) do
		if connection.Connected then
			self.Connections[writeIndex] = connection
			writeIndex += 1
		end
	end

	for index = writeIndex, #self.Connections do
		self.Connections[index] = nil
	end
end

function Signal:Once(callback)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)

	return connection
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection

	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)

	return coroutine.yield()
end

function Signal:Destroy()
	self.Destroyed = true
	table.clear(self.Connections)
end

return Signal

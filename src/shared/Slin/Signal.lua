local Signal = {}
Signal.__index = Signal

function Signal.New()
	return setmetatable({
		_connections = {},
		_destroyed = false,
	}, Signal)
end

function Signal:Connect(callback)
	assert(type(callback) == "function", "Signal:Connect expects a function")
	assert(not self._destroyed, "Cannot connect to a destroyed signal")

	local connection = {
		Connected = true,
		_callback = callback,
	}

	function connection:Disconnect()
		self.Connected = false
	end

	table.insert(self._connections, connection)
	return connection
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

function Signal:Fire(...)
	if self._destroyed then
		return
	end

	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			task.spawn(connection._callback, ...)
		end
	end

	local writeIndex = 1

	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			self._connections[writeIndex] = connection
			writeIndex += 1
		end
	end

	for index = writeIndex, #self._connections do
		self._connections[index] = nil
	end
end

function Signal:Destroy()
	self._destroyed = true
	table.clear(self._connections)
end

return Signal

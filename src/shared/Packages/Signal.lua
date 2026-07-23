local Signal = {}
Signal.__index = Signal

function Signal.New()
	return setmetatable({
		Connections = {}
	}, Signal)
end

function Signal:Connect(callback)
	table.insert(self.Connections, callback)
	
	function Signal:Connect(callback)
		table.insert(self.Connections, callback)
	end
end

function Signal:Fire(...)
	print("Firing signal. Connections:", #self.Connections)

	for _, callback in self.Connections do
		callback(...)
	end
end

return Signal
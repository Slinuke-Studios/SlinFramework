local Trove = {}
Trove.__index = Trove

function Trove.New()
	return setmetatable({
		_items = {},
		_destroyed = false,
	}, Trove)
end

function Trove:Add(object, cleanupMethod)
	assert(not self._destroyed, "Cannot add to a destroyed Trove")

	table.insert(self._items, {
		Object = object,
		Method = cleanupMethod,
	})

	return object
end

function Trove:Clean()
	for index = #self._items, 1, -1 do
		local item = self._items[index]
		local object = item.Object
		local method = item.Method

		if method then
			object[method](object)
		elseif typeof(object) == "RBXScriptConnection" then
			object:Disconnect()
		elseif typeof(object) == "Instance" then
			object:Destroy()
		elseif type(object) == "function" then
			object()
		elseif type(object) == "table" and type(object.Destroy) == "function" then
			object:Destroy()
		elseif type(object) == "table" and type(object.Disconnect) == "function" then
			object:Disconnect()
		end

		self._items[index] = nil
	end
end

function Trove:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self:Clean()
end

return Trove

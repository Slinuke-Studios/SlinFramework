local DataStoreService = game:GetService("DataStoreService")

local ProfileStore = {}
ProfileStore.__index = ProfileStore

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepCopy(v) end
	return c
end

local function reconcile(target, template)
	for key, value in pairs(template) do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(target[key]) == "table" and type(value) == "table" then
			reconcile(target[key], value)
		end
	end
end

function ProfileStore.New(name, default)
	local self = setmetatable({}, ProfileStore)

	self.store = DataStoreService:GetDataStore(name)
	self.default = default
	self.sessions = {}

	return self
end

function ProfileStore:LoadProfile(player, callback)
	local key = "Player_" .. player.UserId
	local owner = self

	local data
	local ok = pcall(function()
		data = self.store:GetAsync(key)
	end)

	if not ok or not data then
		data = deepCopy(self.default)
	else
		reconcile(data, self.default)
	end

	local profile = {
		Key = key,
		Player = player,
		_data = data,
		_dirty = false,
		_released = false,
	}

	function profile:Get(k) return self._data[k] end
	function profile:Set(k, v) self._data[k] = v; self._dirty = true end
	function profile:GetData() return deepCopy(self._data) end

	function profile:Save()
		if not self._dirty or self._released then return true end

		local saved = pcall(function()
			owner.store:SetAsync(self.Key, self._data)
		end)

		if not saved then
			return false
		end

		self._dirty = false
		return true
	end

	function profile:Release()
		self:Save()
		self._released = true
		owner.sessions[player] = nil
		self.Player = nil
	end

	self.sessions[player] = profile
	callback(profile)
end

function ProfileStore:GetActiveProfile(player)
	return self.sessions[player]
end

function ProfileStore:SaveAll()
	for _, profile in pairs(self.sessions) do
		profile:Save()
	end
end

return ProfileStore

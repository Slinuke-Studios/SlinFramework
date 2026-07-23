local DataStoreService = game:GetService("DataStoreService")

local ProfileStore = {}
ProfileStore.__index = ProfileStore

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepCopy(v) end
	return c
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

	local data
	local ok = pcall(function()
		data = self.store:GetAsync(key)
	end)

	if not ok or not data then
		data = deepCopy(self.default)
	end

	local profile = {
		Key = key,
		Player = player,
		_data = data,
		_dirty = false,
	}

	function profile:Get(k) return self._data[k] end
	function profile:Set(k, v) self._data[k] = v; self._dirty = true end
	function profile:GetData() return self._data end

	function profile:Save()
		if not self._dirty then return end
		self.store:SetAsync(self.Key, self._data)
		self._dirty = false
	end

	function profile:Release()
		self:Save()
		self.Player = nil
	end

	self.sessions[player] = profile
	callback(profile)
end

function ProfileStore:GetActiveProfile(player)
	return self.sessions[player]
end

return ProfileStore
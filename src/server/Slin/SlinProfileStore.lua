local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Slin.TableUtil)

local SlinProfileStore = {}
SlinProfileStore.__index = SlinProfileStore

function SlinProfileStore.New(storeName, template)
	local self = setmetatable({}, SlinProfileStore)

	self._store = DataStoreService:GetDataStore(storeName)
	self._template = template
	self._profiles = {}

	return self
end

function SlinProfileStore:LoadAsync(player)
	local key = "Player_" .. player.UserId
	local data

	local loaded = pcall(function()
		data = self._store:GetAsync(key)
	end)

	if not loaded or type(data) ~= "table" then
		data = TableUtil.DeepCopy(self._template)
	else
		TableUtil.Reconcile(data, self._template)
	end

	local owner = self

	local profile = {
		Key = key,
		Player = player,
		Data = data,
		IsDirty = false,
		IsReleased = false,
	}

	function profile:Get(path)
		return TableUtil.DeepCopy(TableUtil.GetPath(self.Data, path))
	end

	function profile:Set(path, value)
		local oldValue = TableUtil.SetPath(self.Data, path, value)
		self.IsDirty = true

		return oldValue
	end

	function profile:Update(path, updater)
		local oldValue = self:Get(path)
		local newValue = updater(oldValue)

		self:Set(path, newValue)

		return newValue, oldValue
	end

	function profile:Save()
		if self.IsReleased or not self.IsDirty then
			return true
		end

		local saved = pcall(function()
			owner._store:SetAsync(self.Key, self.Data)
		end)

		if saved then
			self.IsDirty = false
		end

		return saved
	end

	function profile:Release()
		if self.IsReleased then
			return
		end

		self:Save()
		self.IsReleased = true
		owner._profiles[player] = nil
	end

	self._profiles[player] = profile

	return profile
end

function SlinProfileStore:Get(player)
	return self._profiles[player]
end

function SlinProfileStore:Release(player)
	local profile = self:Get(player)

	if profile then
		profile:Release()
	end
end

function SlinProfileStore:SaveAll()
	for _, profile in pairs(self._profiles) do
		profile:Save()
	end
end

return SlinProfileStore

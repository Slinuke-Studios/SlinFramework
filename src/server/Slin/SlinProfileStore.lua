local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Slin.TableUtil)

local SlinProfileStore = {}
SlinProfileStore.__index = SlinProfileStore

function SlinProfileStore.New(storeName, template, options)
	local self = setmetatable({}, SlinProfileStore)
	options = options or {}

	self.Name = storeName
	self._store = DataStoreService:GetDataStore(storeName)
	self._template = template
	self._profiles = {}
	self._debug = options.Debug == true

	return self
end

function SlinProfileStore:SetDebug(enabled)
	self._debug = enabled == true
end

function SlinProfileStore:_log(...)
	if self._debug then
		print("[SlinProfileStore:" .. self.Name .. "]", ...)
	end
end

function SlinProfileStore:LoadAsync(player)
	local key = "Player_" .. player.UserId
	local data
	local isNew = false

	local loaded, loadError = pcall(function()
		data = self._store:GetAsync(key)
	end)

	if not loaded or type(data) ~= "table" then
		if not loaded then
			warn("[SlinProfileStore:" .. self.Name .. "] Load failed for " .. key .. ":", loadError)
		else
			self:_log("No saved data for", key, "using template")
		end

		data = TableUtil.DeepCopy(self._template)
		isNew = true
	else
		TableUtil.Reconcile(data, self._template)
		self:_log("Loaded", key)
	end

	local owner = self

	local profile = {
		Key = key,
		Player = player,
		Data = data,
		IsDirty = isNew == true and true or false,
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

		local saved, saveError = pcall(function()
			owner._store:SetAsync(self.Key, self.Data)
		end)

		if saved then
			self.IsDirty = false
			owner:_log("Saved", self.Key)
		else
			warn("[SlinProfileStore:" .. owner.Name .. "] Save failed for " .. self.Key .. ":", saveError)
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

function SlinProfileStore:StartAutosave(interval)
	interval = interval or 60

	if self._autosaveStarted then
		return
	end

	self._autosaveStarted = true

	task.spawn(function()
		while self._autosaveStarted do
			task.wait(interval)
			self:SaveAll()
		end
	end)
end

return SlinProfileStore

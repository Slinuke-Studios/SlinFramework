local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ROOT_NAME = "SlinRemotes"

local SlinNet = {}

local function getRoot()
	local root = ReplicatedStorage:FindFirstChild(ROOT_NAME)

	if root then
		return root
	end

	if not RunService:IsServer() then
		return ReplicatedStorage:WaitForChild(ROOT_NAME)
	end

	root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root.Parent = ReplicatedStorage

	return root
end

local function getRemote(className, name)
	local root = getRoot()
	local remote = root:FindFirstChild(name)

	if remote then
		assert(remote.ClassName == className, name .. " is not a " .. className)
		return remote
	end

	if not RunService:IsServer() then
		remote = root:WaitForChild(name)
		assert(remote.ClassName == className, name .. " is not a " .. className)
		return remote
	end

	remote = Instance.new(className)
	remote.Name = name
	remote.Parent = root

	return remote
end

function SlinNet.Event(name)
	return getRemote("RemoteEvent", name)
end

function SlinNet.Function(name)
	return getRemote("RemoteFunction", name)
end

return SlinNet

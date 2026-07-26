local TableUtil = {}

function TableUtil.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, child in pairs(value) do
		copy[key] = TableUtil.DeepCopy(child)
	end

	return copy
end

function TableUtil.Reconcile(target, template)
	for key, value in pairs(template) do
		if target[key] == nil then
			target[key] = TableUtil.DeepCopy(value)
		elseif type(target[key]) == "table" and type(value) == "table" then
			TableUtil.Reconcile(target[key], value)
		end
	end

	return target
end

function TableUtil.GetPath(tbl, path)
	local current = tbl

	for key in string.gmatch(path, "[^%.]+") do
		if type(current) ~= "table" then
			return nil
		end

		current = current[key]
	end

	return current
end

function TableUtil.SetPath(tbl, path, value)
	local current = tbl
	local parts = {}

	for key in string.gmatch(path, "[^%.]+") do
		table.insert(parts, key)
	end

	for index = 1, #parts - 1 do
		local key = parts[index]

		if type(current[key]) ~= "table" then
			current[key] = {}
		end

		current = current[key]
	end

	local finalKey = parts[#parts]
	local oldValue = current[finalKey]
	current[finalKey] = TableUtil.DeepCopy(value)

	return oldValue
end

return TableUtil

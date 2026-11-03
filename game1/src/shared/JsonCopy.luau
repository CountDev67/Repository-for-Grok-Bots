--!strict
-- Deep copy of JSON-ish values. Drops functions, threads, and userdata.
-- Cycles are skipped so a bad blob cannot loop forever.

local function copy(value: any, seen: { [any]: boolean }): any
	local kind = type(value)
	if kind == "number" or kind == "string" or kind == "boolean" then
		return value
	end
	if kind ~= "table" then
		return nil
	end
	if seen[value] then
		return nil
	end
	seen[value] = true
	local out = {}
	for key, child in value do
		if type(key) == "string" or type(key) == "number" then
			local cloned = copy(child, seen)
			if cloned ~= nil then
				out[key] = cloned
			end
		end
	end
	return out
end

local function JsonCopy(value: any): any
	return copy(value, {})
end

return JsonCopy

--[[
		Name: component;
		Depends: [log, threading];
		Description: Provides way to register component drivers;
]]--

local drivers = {}

-- TODO by uuid

function componentAdded (uuid, t)
	kernelLog(Log.DEBUG, "Component added", t, uuid)
	t = t:gsub("_", "-")
	if drivers[t] then
		if not devfs.data[t] then
			local allocator, list = createAllocator(true, true)
			drivers[t].allocator = allocator
			devfs.data[t] = list
		end
		local d = drivers[t].allocator:new()
		d.__file = true
		d.uuid = uuid
		for k, v in pairs(drivers[t].add_callback(uuid)) do
			d[k] = v
		end
		kernelLog(Log.DEBUG, "Created device", uuid, "at path /dev/" .. t .. "/" .. d.index)
	end
end

addKenrelEventHandler({"signal", "component_added"}, componentAdded)

function register_driver(t, add_callback, remove_callback)
	kernelLog(Log.DEBUG, "Register driver for", t)
	t = t:gsub("_", "-")
	drivers[t] = {
		add_callback = add_callback,
		remove_callback = remove_callback
	}
end

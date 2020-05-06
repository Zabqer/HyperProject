--[[
		Name: component;
		Depends: [log, threading];
		Description: Provides way to register component drivers;
]]--

local drivers = {}

-- TODO by uuid

addKenrelEventHandler({"signal", "component_added"}, function (type, uuid)
	type = type:gsub("_", "-")
	if drivers[type] then
		if not devfs.data[type] then
			local allocator, list = createAllocator(true, true)
			drivers[type].allocator = allocator
			devfs.data[type] = list
		end
		local d = drivers[type].allocator:new()
		d.__file = true
		d.uuid = uuid
		for k, v in pairs(drivers[type].add_callback()) do
			d[k] = v
		end
		kernelLog(Log.DEBUG, "Created device", uuid, "at path /dev/" .. type .. "/" .. d.index)
	end
end)

function register_driver(type, add_callback, remove_callback)
	kernelLog(Log.DEBUG, "Register driver for", type)
	type = type:gsub("_", "-")
	drivers[type] = {
		add_callback = add_callback,
		remove_callback = remove_callback
	}
end

--[[
	Name: component;
	Depends: [log, threading];
	Description: Provides way to register component drivers;
]]--

local drivers = {}

addKenrelEventHandler({"signal", "component_added"}, function (...)
	dprint("COMPONENT ADDED!", ...)
end)

function register_driver(type, add_callback, remove_callback)
	kernelLog(Log.DEBUG, "Register driver for", type)
end

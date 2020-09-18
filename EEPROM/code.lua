local header = [[HyperBIOS/0.0.0.1]]
local logo = [[______  __                           ______________________________
___  / / /____  ________________________  __ )___  _/_  __ \_  ___/
__  /_/ /__  / / /__  __ \  _ \_  ___/_  __  |__  / _  / / /____ \ 
_  __  / _  /_/ /__  /_/ /  __/  /   _  /_/ /__/ /  / /_/ /____/ / 
/_/ /_/  _\__, / _  .___/\___//_/    /_____/ /___/  \____/ /____/  
         /____/  /_/               by Zabqer with Love             ]]

local config = {bootFrom=nil}

local eeprom, gpu, screen = component.list("eeprom")(), component.list("gpu")(), component.list("screen")()

local invoke = component.invoke

function computer.getBootAddress()
		return invoke(eeprom, "getData")
end

function computer.setBootAddress(address)
		return invoke(eeprom, "setData", address)
end

local function status() end

if gpu and screen then
		invoke(gpu, "bind", screen)
		local w, h = 80, 25--invoke(gpu, "getMaxResolution");
		invoke(gpu, "setResolution", w, h)
		lines = {}
		for line in logo:gmatch("[^\n]+") do
				table.insert(lines, line)
		end
		for i = 1, #lines do
				invoke(gpu, "set", (w - #lines[i]) / 2, (h - #lines) / 2 + i, lines[i])
		end
		invoke(gpu, "set", (w - #header) / 2, 2, header)
		function status(msg)
				msg = tostring(msg)
				invoke(gpu, "copy", 1, h - 2, w, 1, 0, -1)
				invoke(gpu, "fill", 1, h - 2, w, 1, " ")
				invoke(gpu, "set", (w - #msg) / 2, h - 2, msg)
		end
end

status("Reading config")

--[[TODO CONFIG]]

local bootDevice

local bootFrom = {
		filesystem = function(address)
				return (function ()
						computer.setBootAddress(address)
						local handle = invoke(address, "open", "/init.lua", "r")
						local code, buffer = ""
						repeat
								buffer = invoke(address, "read", handle, math.huge)
								code = code .. (buffer or "")
						until not buffer
						invoke(address, "close", handle)
						return load(code, "=init.lua")
				end)
		end
}

local function tryBoot(address)
		local type, reason = component.type(address)
		if not type then
				return nil, reason
		end
		if type == "filesystem" then
				if invoke(address, "exists", "/init.lua") then
						return bootFrom["filesystem"](address)
				else
						return nil, "cannot find init.lua"
				end
		else
				return nil, "unsuported component type `" .. type .. "`"
		end
end

if config.bootFrom then
		local reason
		bootDevice, reason = tryBoot(config.bootFrom)
		if not bootDevice then
				status("Boot error: " .. config.bootFrom .. " : " .. reason)
		end
end

if not bootDevice then
		status("Finding bootable devices...")
		for address, _ in component.list() do
				if bootDevice then
						break
				end
				bootDevice = tryBoot(address)
		end
end

if not bootDevice then
		status("Fatal error: no bootable device found")
else
		status("Booting...")
		local f, reason = bootDevice()
		if not f then
				status("Fatal error: load: " .. reason)
		else
				f(table.unpack(config.bootParameters or {}))
				status("Fatal error: boot program exited")
		end
end

while true do computer.pullSignal(1) end

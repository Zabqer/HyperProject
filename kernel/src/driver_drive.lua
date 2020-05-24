--[[
		Name: driver_drive;
		Depends: [component, filesystem, threading];
		Description: Provides driver for drive component;
]]--

function readData(uuid, at, len)
	local data = ""
	local sectorSize = component.invoke(uuid, "getSectorSize")
	repeat
		local atSector = math.floor(at / sectorSize) + 1
		sector = component.invoke(uuid, "readSector", atSector)
		local read = sector:sub(at % sectorSize + 1, math.min(at % sectorSize + len - #data, sectorSize))

		data = data .. read
		at = at + #read
	until #data >= len
	return data
end

function drive_added()
	return {
		open = function (handle)
			handle.pos = 0
			handle.uuid = handle.node.uuid
		end,
		write = function (handle, data)
		end,
		seek = function (handle, whence, offset)
		end,
		read = function (handle, len)
			len = math.ceil(len)
			if handle.pos >= component.invoke(handle.uuid, "getCapacity") then
				return
            		end
            		local data = readData(handle.uuid, handle.pos, len)
            		handle.pos = handle.pos + len
            		return data
		end,
		size = function (handle)
			return component.invoke(handle.uuid "getCapacity")
		end
	}
end

function drive_removed()
	
end

register_driver("drive", drive_added, drive_removed)

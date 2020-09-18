--[[
		Name: driver_drive;
		Depends: [component, filesystem, threading];
		Description: Provides driver for drive component;
]]--

local function readData(drive, at, len)
	local data = ""
	local sectorSize = component.invoke(drive, "getSectorSize")
	repeat
		local atSector = math.floor(at / sectorSize) + 1
		sector = component.invoke(drive, "readSector", atSector)
		local read = sector:sub(at % sectorSize + 1, math.min(at % sectorSize + len - #data, sectorSize))
		data = data .. read
		at = at + #read
	until #data >= len
	return data
end

local function writeSectors(drive, data, at)
	local sectorSize = component.invoke(drive, "getSectorSize")
	repeat
		local atSector = math.floor(at / sectorSize) + 1

		local inSectorStart = at % sectorSize + 1
		local writable = math.min(#data, sectorSize - inSectorStart + 1)

		local old = component.invoke(drive, "readSector", atSector)

		local before = old:sub(0, inSectorStart - 1)
		local after = old:sub(inSectorStart + writable)

		local toWrite = before .. data:sub(1, writable) .. after
		data = data:sub(writable + 1)

		component.invoke(drive, "writeSector", atSector, toWrite)

		at = at + writable
	until #data < 1
end

function drive_added(uuid)
	return {
		open = function (handle)
			handle.pos = 0
		end,
		write = function (handle, data)
			writeSectors(uuid, data, handle.pos)
			handle.pos = handle.pos + #data
			return not (handle.pos >= component.invoke(uuid, "getCapacity"))
		end,
		seek = function (handle, whence, offset)
			handle.pos = offset
		end,
		read = function (handle, len)
			len = math.ceil(len)
			if handle.pos >= component.invoke(uuid, "getCapacity") then
				return
            		end
            		local data = readData(uuid, handle.pos, len)
            		handle.pos = handle.pos + len
            		return data
		end,
		size = function ()
			return component.invoke(uuid, "getCapacity")
		end
	}
end

function drive_removed()
	
end

register_driver("drive", drive_added, drive_removed)

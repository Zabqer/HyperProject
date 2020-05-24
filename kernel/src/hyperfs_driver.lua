--[[
		Name: hyperfs_driver;
		Depends: [utils, filesystem];
		Description: Provides driver for hyper filesystem;
]]--

local MAGIC = "\x28\xFF\xF0\xAA"
local SUPERBLOCK = ""

local hyperfs = {}

function hyperfs:readData(from, len)
	return self.device:read(len)
end

function hyperfs:readSuperblock()
	local sb = self:readData(len(MAGIC), string.packsize(SUPERBLOCK))
	dprint(">", string.unpack(SUPERBLOCK, sb))
	return true
end

function hyperfs:isDirectory(path)
	return false
end

filesystems.hyperfs = {
	magic = MAGIC
}

function filesystems.hyperfs.open(device)
	local fs = setmetatable({
		device = device
	}, {__index=hyperfs})
	if not fs:readSuperblock() then
		return nil, "corrupted filesystem"
	end
	return fs
end


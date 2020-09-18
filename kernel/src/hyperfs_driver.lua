--[[
		Name: hyperfs_driver;
		Depends: [utils, allocator, filesystem];
		Description: Provides driver for hyper filesystem;
]]--

local MAGIC = "\x28\xFF\xF0\xAA"
local SUPERBLOCK = [[<c4TTTTHTT]]

--[[
c4 | Magic - 4 bytes
T  | TotalInodes - Number size_t
T  | TotalBlocks - Number size_t
T  | FreeInodes - Number size_t
T  | FreeBlocks - Number size_t
H  | BlockSize - Number uint16_t
T  | NextFreeInode - Number size_t
T  | NextFreeBlock - Number size_t
c500  | Reserved
]]

local INODE = [[<bTT]]

--[[
b | Type - Byte
T | Size - Number size_t
T | First pointer - Number size_t
]]
local TYPE_UNKNOWN = 0
local TYPE_FILE = 1
local TYPE_DIR = 2

local DIR_ENTRY = [[<T]]

--[[
T | Referenced to inode - Number size_t
z | Filename - Zero-terminated string
]]

dprint("HFS SUPERBLOCK", string.packsize(SUPERBLOCK))

dprint("HFS INODE", string.packsize(INODE))

local hyperfs = {}

function uni()
	dprint("UNIMPLEMENTED!")
	dprint(debug.traceback())
	error("UNIMPLEMENTED!")
end

function hyperfs:readData(from, len)
	self.device:seek("cur", from)
	return self.device:read(len)
end

function hyperfs:writeData(at, data)
	self.device:seek("cur", at)
	return self.device:write(data)
end

function hyperfs:readSuperblock()
	local sbd = self:readData(0, string.packsize(SUPERBLOCK))
	local sb = self.cache.superblock
	local magic
	magic, sb.totalInodes, sb.totalBlocks, sb.freeInodes, sb.freeBlocks, sb.blockSize, sb.nextFreeInode, sb.nextFreeBlock = string.unpack(SUPERBLOCK, sbd)
	if magic ~= MAGIC then
		return false, "unknown magic numbers"
	end
	return true
end

function hyperfs:writeSuperblock()
	local sb = self.cache.superblock
	local data = string.pack(SUPERBLOCK, MAGIC, sb.totalInodes, sb.totalBlocks, sb.freeInodes, sb.freeBlocks, sb.blockSize, sb.nextFreeInode, sb.nextFreeBlock)
	return self:writeData(0, data)
end

function hyperfs:readBlock(index)
	return self:readData(
		512 +
		64 * self.cache.superblock.totalInodes + 
		self.cache.superblock.blockSize * index,
		self.cache.superblock.blockSize
	)
end

function hyperfs:writeBlock(index, data)
	return self:writeData(
		512 +
		64 * self.cache.superblock.totalInodes + 
		self.cache.superblock.blockSize * index,
		data
	)
end

function hyperfs:getPointer(inode, n)
	if not inode.pointers[n] then
		if n > 16 then
			-- local data, reason = self:readBlock(inode.doublePointer)
			-- if not data then
			-- 	return nil, reason
			-- end
			panic("NEED TO RESOLVE POINTERS")
		else
			panic("READ POINTER")
		end
	end
	return inode.pointers[n]
end

function hyperfs:setPointer(inode, n, index)
	dprint("setPointer", inode.index, n, index)
	inode.pointers[n] = index
	if n > 16 then
		panic("NEED TO SAVE POINTERS")
	else
		self:writeInode(inode)
	end
end

function hyperfs:listBlocks(inode)
	local size = math.ceil(inode.size / self.cache.superblock.blockSize)
	local i = 0
	return function()
		if i >= size then
			return nil
		end
		i = i + 1
		return self:getPointer(inode, i - 1)
	end
end

function hyperfs:readInode(i)
	if self.cache.inodes[i] then
		return self.cache.inodes[i]
	end
	local id = self:readData(512 + 64 * i, 64)
	local inode = {
		index = i,
		pointers = {}
	}
	inode.type, inode.size, inode.pointers[0] = string.unpack(INODE, id)
	if inode.type == TYPE_UNKNOWN then
		kernelLog(Log.WARNING, "Inode", i, "type is UNKNOWN")
	end
	self.cache.inodes[i] = inode
	return inode
end

function hyperfs:writeInode(inode)
	local data = string.pack(INODE, inode.type, inode.size, inode.pointers[0] or 0)
	return self:writeData(512 + 64 * inode.index, data)
end

function hyperfs:readInodeFiles(inode)
	if inode.type ~= TYPE_DIR then
		return false, "file is not a directory"
	end
	-- if inode.files then
	-- 	return true
	-- end
	local buffer = ""
	local left = inode.size
	local files = {}
	-- TODO filename may be > blocksize !!!
	function readEntries()
		while left > 0 and #buffer > 0 do
			local fileInode = string.unpack(DIR_ENTRY, buffer)
			buffer = string.sub(buffer, string.packsize(DIR_ENTRY) + 1)
			local en = buffer:find("\0")
			if en then
				filename = string.sub(buffer, 1, en - 1)
				files[filename] = fileInode
		-- dprint(string.byte(buffer, 1, -1))
				buffer = string.sub(buffer, en - 1)
				left = left - string.packsize(DIR_ENTRY) - #filename
			else
				panic("TO LONG FILENAME")
			end
		end
	end
	for block in self:listBlocks(inode) do
		buffer = buffer .. self:readBlock(block)
		readEntries()
	end
	inode.files = files
	return true
end

function hyperfs:listInodes(i)
	local inode, reason = self:readInode(i)
	if not inode then
		return nil, reason
	end
	local success, reason = self:readInodeFiles(inode)
	if not success then
		return nil, reason
	end
	return inode.files
end

function hyperfs:getInode(path)
	path = type(path) == "string" and Path(path) or path
	if #path == 0 then
		return self:readInode(0)
	end
	local files, reason = self:listInodes(0)
	if not files then
		return nil, reason
	end
	local inode
	for i, f in pairs(path) do
		if not files[f] then
			return nil, "no such file or directory"
		end
		inode = files[f]
		if #path == i then
			break
		end
		files, reason = self:listInodes(inode)
		if not files then
			return nil, reason
		end
	end
	return self:readInode(inode)
end

function hyperfs:findNextInode()
	local nfi = self.cache.superblock.nextFreeInode
	if nfi > self.cache.superblock.totalInodes then
		return nil, "no space left on device"
	end
	return nfi
end

function hyperfs:allocateInode(type)
	local index, reason = self:findNextInode()
	if not index then
		return nil, reason
	end
	local inode = {
		index = index,
		type = type,
		size = 0,
		pointers = {}
	}
	local success, reason = self:writeInode(inode)
	if not success then
		return nil, reason
	end
	self.cache.superblock.freeInodes = self.cache.superblock.freeInodes - 1
	-- TODO real next index!!!!
	self.cache.superblock.nextFreeInode = self.cache.superblock.nextFreeInode + 1
	success, reason = self:writeSuperblock()
	if not success then
		return nil, reason
	end
	local block, reason = self:allocateBlock(inode)
	if not block then
		return false, reason
	end
	self:setPointer(inode, 0, block)
	return inode
end

function hyperfs:findNextBlock()
	local nfb = self.cache.superblock.nextFreeBlock
	if nfb > self.cache.superblock.totalBlocks then
		return nil, "no space left on device"
	end
	return nfb
end

function hyperfs:allocateBlock(inode)
	local index, reason = self:findNextBlock()
	if not index then
		return nil, reason
	end
	self.cache.superblock.freeBlocks = self.cache.superblock.freeBlocks - 1
	-- TODO real next index!!!!
	self.cache.superblock.nextFreeBlock = self.cache.superblock.nextFreeBlock + 1
	success, reason = self:writeSuperblock()
	if not success then
		return nil, reason
	end
	return index
end

function hyperfs:appendInodeData(inode, data)
	repeat
		local block = math.floor(inode.size / self.cache.superblock.blockSize)
		if block < math.floor((inode.size + #data) / self.cache.superblock.blockSize) then
			local index, reason = self:allocateBlock(inode)
			if not index then
				return false, reason
			end
			self:setPointer(inode, block, index)
			local d = data:sub(1, self.cache.superblock.blockSize)
			inode.size = inode.size + #d
			data = data:sub(self.cache.superblock.blockSize)
			self:writeBlock(block, d)
		else
			local bp = self:getPointer(inode, block)
			local at = inode.size % self.cache.superblock.blockSize
			local d = self:readBlock(bp)
			local w = data:sub(1, self.cache.superblock.blockSize - 1)
			d = d:sub(1, at) .. w
			inode.size = inode.size + #w
			data = data:sub(self.cache.superblock.blockSize)
			self:writeBlock(bp, d)
		end
	until #data <= 0
	self:writeInode(inode)
	return true
end

function hyperfs:makeDirectory(path)
	local inode, resaon = self:getInode(path:path())
	if not inode then
		return false, reason
	end
	local inodes, reason = self:listInodes(inode.index)
	if not inodes then
		return false, reason
	end
	local filename = path:filename()
	if inodes[filename] then
		return false, "file arleady exists"
	end
	local fileInode, reason = self:allocateInode(TYPE_DIR)
	if not fileInode then
		return false, reason
	end
	local success, reason = self:appendInodeData(inode, string.pack(DIR_ENTRY, fileInode.index) .. filename)
	if not success then
		return false, reason
	end
	return true
end

function hyperfs:isDirectory(path)
	local inode, resaon = self:getInode(path)
	if not inode then
		return false
	end
	return inode.type == TYPE_DIR
end

function hyperfs:exists(path)
	local inode, resaon = self:getInode(path)
	return not not inode
end

function hyperfs:list(path)
	local inode, resaon = self:getInode(path)
	if not inode then
		return nil, reason
	end
	local inodes, reason = self:listInodes(inode.index)
	if not inodes then
		return nil, reason
	end
	local files = {}
	for filename in pairs(inodes) do
		table.insert(files, filename)
	end
	return files
end

local allocator, handles = createAllocator(false, true)

function hyperfs:read(handle, n)
	uni()
	if handles[handle] then
	end
	return nil, "invalid handle"
end

function hyperfs:write(h, data)
	if handles[h] then
		local handle = handles[h]
		return self:appendInodeData(self:readInode(handle.inode), data)
	end
	return nil, "invalid handle"
end

function hyperfs:open(path, mode)
	local inode, resaon = self:getInode(path:path())
	if not inode then
		return nil, reason
	end
	local inodes, reason = self:listInodes(inode.index)
	if not inodes then
		return nil, reason
	end
	local filename = path:filename()
	local fileInode
	if not inodes[filename] then
		if ({r=true,rb=true})[mode] then
			return nil, "file not found: " .. path.string()
		else
			fileInode, reason = self:allocateInode(TYPE_FILE)
			if not fileInode then
				return nil, reason
			end
			local success, reason = self:appendInodeData(inode, string.pack(DIR_ENTRY, fileInode.index) .. filename)
			if not success then
				return nil, reason
			end
		end
	end
	local handle = allocator:new()
	handle.inode = fileInode.index
	return handle.index
end

filesystems.hyperfs = {
	magic = MAGIC
}

function filesystems.hyperfs.open(device)
	-- TODO enable mount ro only
	local fs = setmetatable({
		device = device,
		cache = {
			superblock = {},
			inodes = {}
		}
	}, {__index=hyperfs})
	for _, k in pairs({"open", "list", "isDirectory", "makeDirectory", "exists", "write"}) do
		fs[k] = function(...)
			-- dprint("HFS", k, ...)
			return hyperfs[k](fs, ...)
		end
	end
	local success = fs:readSuperblock()
	if not success then
		return nil, result or "corrupted filesystem"
	end
	return fs
end


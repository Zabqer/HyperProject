local filesystem = require("filesystem")

local device = "/dev/drive/0"

local MAGIC = "\x28\xFF\xF0\xAA"
local SUPERBLOCK = [[<c4TTTTH]]

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

local INODE = [[<bT]]

--[[
b | Type - Byte
T | Size - Number size_t
]]
local TYPE_UNKNOWN = 0
local TYPE_FILE = 1
local TYPE_DIR = 2

local DIR_ENTRY = [[<Tz]]

--[[
T | Referenced to inode - Number size_t
z | Filename - Zero-terminated string
]]


local availableSize = filesystem.size(device) - 512

local inodeSize = 64
local totalInodes = math.ceil(availableSize / 3 / inodeSize)
local blockSize = 64
local totalBlocks = math.ceil((availableSize - totalInodes * inodeSize) / blockSize)

print(totalInodes, totalBlocks, availableSize)

local f = assert(io.open(device, "w"))

f:write(string.pack(
	SUPERBLOCK,
	MAGIC,
	totalInodes,
	totalBlocks,
	totalInodes - 1,
	totalBlocks,
	blockSize,
	0,
	1
))

f:write(string.rep("\0", 512 - string.packsize(SUPERBLOCK)))

f:write(string.pack(
	INODE,
	TYPE_DIR,
	0
))

f:close()

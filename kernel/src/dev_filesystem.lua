--[[
		Name: dev_filesystem;
		Depends: [utils, allocator];
		Description: Provides device filesystem;
]]--

devfs = {
	label = "devfs",
	data = {}
}

local allocator, handles = createAllocator()

local function getNode(path)
	local node = devfs.data
	for _, n in pairs(path) do
		if node.__file then
			return nil, "file is not directory"
		end
		node = node[n]
		if not node then
			return nil, "no such file or directory"
		end
	end
	return node
end

function devfs.open(path)
	local node, reason = getNode(path)
	if not node.__file then
		return nil, "it's a directory"
	end
	local handle = allocator:new()
	handle.node = node
	if handle.open then
		handle.open(handle)
	end
	return handle.index
end

function devfs.read(index, ...)
	return handles[index].node.read(handles[index], ...)
end

function devfs.exists(path)
	local node = getNode(path)
	return not not node
end

function devfs.list(path)
	local node, result = getNode(path)
	if not node then
		return nil, result
	end
	if node.__file then
		return nil, "file is not directory"
	end
	local files = {}
	for n in pairs(node) do
		table.insert(files, n)
	end
	return files
end

function devfs.isDirectory(path)
	local node, result = getNode(path)
	if not node then
		return false
	end
	return not node.__file
end

devfs.data.null = {
	__file = true,
	write = function() end,
	read = function() end
}


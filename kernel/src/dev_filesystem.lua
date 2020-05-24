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
	if not node then
		return nil, reason
	end
	if not node.__file then
		return nil, "it's a directory"
	end
	local handle = allocator:new()
	handle.node = node
	if handle.node.open then
		handle.node.open(handle)
	end
	return handle.index
end

function devfs.read(index, ...)
	if not handles[index].node.read then
		return nil, "operation not permitted"
	end
	return handles[index].node.read(handles[index], ...)
end

function devfs.write(index, ...)
	if not handles[index].node.write then
		return false, "operation not permitted"
	end
	return handles[index].node.write(handles[index], ...)
end

function devfs.seek(index, ...)
	if not handles[index].node.seek then
		return false, "operation not permitted"
	end
	return handles[index].node.seek(handles[index], ...)
end

function devfs.close(index)
	if not handles[index].node.close then
		return
	end
	handles[index].node.close(handles[index])
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

-- function devfs.printNodes(node, i, name)
-- 	node = node or devfs.data
-- 	i = i or 0
-- 	name = name or "/"
-- 	dprint(string.rep(" ", i) .. ">" .. name .. " " .. (node.__file and "FILE" or "DIR"))
-- 	if not node.__file then
-- 		for m, n in pairs(node) do
-- 			devfs.printNodes(n, i + 1, m)
-- 		end
-- 	end
-- end

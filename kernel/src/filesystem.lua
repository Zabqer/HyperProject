--[[
		Name: filesystem;
		Depends: [utils];
		Description: Provides virtual filesystem methods;
]]--

local rootNode = {name="", nodes={}}

filesystem = {}

local function segmentate(path)
		local segments = {}
		for segment in path:gmatch("[^/]+") do
				if segment == ".." then
						table.remove(parts)
				elseif segment ~= "." then
						table.insert(segments, segment)
				end
		end
		return segments, path:sub(1, 1) == "/"
end

PathMethods = {}

function PathMethods:len()
		return #self.segments
end

function PathMethods:string()
		return (self.absolute and "/" or "") .. table.concat(self.segments, "/")
end

function PathMethods:absolute()
	return (self.absolute and "/" or thisThread.process.workingDirectory) .. table.concat(self.segments, "/")
end

function PathMethods:filename()
	return self.segments[#self.segments]
end

function PathMethods:append(path, index)
		checkArg(1, path, "string")
		checkArg(2, index, "number", "nil")
		index = index or #self.segments
		if index >= 0 and index <= #self.segments then
				local segments = segmentate(path)
				for i, segment in pairs(segments) do
						table.insert(self.segments, index + i, segment)
				end
				return true
		end
		return false
end

function PathMethods:remove(index)
		checkArg(1, index, "number", "nil")
		index = index or #self.segments
		if index > 0 and index <= #self.segments then
				return table.remove(self.segments, index)
		end
end

function PathMethods:pairs()
	return pairs(self.segments)
end

function PathMethods:at(index)
	checkArg(1, index, "number")
	if index > 0 and index <= #self.segments then
		return self.segments[index]
	end
end

local function Path(path)
		local obj = {}
		obj.segments, obj.absolute = segmentate(path)
		return protectObject(obj, PathMethods, "FilesystemPath")
end

local function getNode(path)
	-- Maybe rewrite?
	path = type(path) == "string" and Path(path) or path
	local outerpath = Path("")
	local node = rootNode
	while true do
		local nextNodeName = path:at(1)
		if not nextNodeName then
			return node, outerpath
		end
		local nextNode
		for _, n in pairs(node.nodes) do
			if n.name == nextNodeName then
				nextNode = n
			end
		end
		if not nextNode then
			for _, f in pairs(path) do
				outerpath:append(f)
			end
			return node, outerpath
		end
		node = nextNode
		outerpath:append(path:remove(1), 1)
	end
end

-- local function printNodes(node, i)
-- 	i = i or 0
-- 	dprint(string.rep(" ", i) .. ">" .. (node.name == "" and "/" or node.name) .. "<")
-- 	for _, n in pairs(node.nodes) do
-- 		printNodes(n, i + 1)
-- 	end
-- end

local function createNode(node, path)
	for _, f in pairs(path) do
		local n = {name = f, nodes={}}
		table.insert(node.nodes, n)
		node = n
	end
	return node
end

local filesystemHandle = {}

function filesystemHandle:read(count)
		checkArg(2, count, "number")
		return self.driver.read(self.handle, count)
end

function filesystemHandle:write(data)
	checkArg(2, data, "string")
	return self.driver.write(self.handle, data)
end

function filesystemHandle:close()
		return self.driver.close(self.handle)
end

function filesystem.mount(path, proxy)
		checkArg(1, path, "string")
		checkArg(2, proxy, "string", "table")
		path = Path(path)
		local node, fspath = getNode(path)
		if #fspath == 0 and node.drive then
				return false, "another file system mounted here"
		end
		node = createNode(node, path)
		node.driver = type(proxy) == "table" and proxy or component.proxy(proxy)
		-- push string to filesystem component, but to own drivers we push Path
		node.kernel_driver = type(proxy) == "table"
		kernelLog(Log.INFO, "Filesystem", proxy, "mounted at", path.string())
		return true
end

function filesystem.exists(path)
		checkArg(1, path, "string")
		local node, fspath = getNode(path)
		if not node then
			return false
		end
		return node.driver.exists(node.kernel_driver and fspath or fspath.string())
end

function filesystem.isDirectory(path)
		checkArg(1, path, "string")
		local node, fspath = getNode(path)
		if not node then
				return false
		end
		return node.driver.isDirectory(node.kernel_driver and fspath or fspath.string())
end


function filesystem.list(path)
		checkArg(1, path, "string")
		local node, fspath = getNode(path)
                if not node then
			return false
		end
		local files = {}
		if #fspath == 0 then
			for _, n in pairs(node.nodes) do
				table.insert(files, n.name)
			end
		end

        	local fsfiles = node.driver.list(node.kernel_driver and fspath or fspath.string())
		if fsfiles then
			for _, f in pairs(fsfiles) do
				table.insert(files, f)
			end
		end
		return files
end

function filesystem.open(path, mode)
		checkArg(1, path, "string")
		mode = mode or "r"
		checkArg(2, mode, "string")
		assert(({r=true, rb=true, w=true, wb=true, a=true, ab=true})[mode], "bad argument #2 (r[b], w[b] or a[b] expected, got " .. mode .. ")")
		local node, fspath = getNode(path)
		if not node then
				return nil, path
		end
		if ({r=true,rb=true})[mode] and not node.driver.exists(node.kernel_driver and fspath or fspath.string()) then
				return nil, "file not found: " .. fspath.string()
		end
		local handle, reason = node.driver.open(node.kernel_driver and fspath or fspath.string(), mode)
		if not handle then
				return nil, reason
		end
		local stream = {
				kernel_driver = node.kernel_driver,
				driver = node.driver,
				handle = handle
		}
		-- TODO protect
		return setmetatable(stream, {__index = filesystemHandle})
end

libs.filesystem = filesystem

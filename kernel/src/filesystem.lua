--[[
		Name: filesystem;
		Depends: [utils];
		Description: Provides virtual filesystem methods;
]]--

filesystems = {}

local rootNode = {name="", nodes={}}

filesystem = {}

-- TODO NEED TO REWORK!!!

local function segmentate(path)
		local segments = {}
		for segment in path:gmatch("[^/]+") do
				if segment == ".." then
						table.remove(segments)
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

function PathMethods:path()
	return (self.absolute and "/" or thisThread.process.workingDirectory) .. table.concat(table.pack(table.unpack(self.segments, 1, #self.segments - 1)), "/")
end

function PathMethods:filename()
	return self.segments[#self.segments]
end

function PathMethods:makeAbsolute()
	if not self.absolute then
		self.absolute = true
		local segs = segmentate(thisThread.process.envvar["PWD"])
		local i = 0
		for _, s in ipairs(segs) do
			table.insert(self.segments, s)
			i = i + 1
		end
	end
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
	if index < 0 then
		index = #self.segments - index
	end
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
	path.makeAbsolute()
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

local function printNodes(node, i)
	-- i = i or 0
	-- dprint(string.rep(" ", i) .. ">" .. (node.name == "" and "/" or node.name) .. "<")
	-- for _, n in pairs(node.nodes) do
	-- 	printNodes(n, i + 1)
	-- end
end

function GLOBAL.debugFs()
	dprint("==== DEBUG FS ====")
	local function d(path, depth)
		dprint(string.rep(" ", depth) .. (Path(path):filename() or "") .. (filesystem.isDirectory(path) and "/" or ""))
		if filesystem.isDirectory(path) then
			for _, f in ipairs(filesystem.list(path)) do
				local p = Path(path)
				p:append(f)
				d(tostring(p), depth + 1)
			end
		end
	end
	d("/", 0)
	dprint("==================")
end

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

-- TODO
function filesystemHandle:seek(whence, offset)
	return self.driver.seek(self.handle, whence, offset)
end

function filesystemHandle:close()
		return self.driver.close(self.handle)
end

function tryMountFilesystem(path)
	local handle, reason = filesystem.open(path)
	if not handle then
		return nil, reason
	end
	for name, fs in pairs(filesystems) do
		local d = handle:read(#fs.magic)
		if fs.magic == d then
			return fs.open(handle)
		end
	end
	return nil, "unknown filesystem"
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
		if type(proxy) == "table" then
			node.driver = proxy
			node.kernel_driver = true
		else
			if component.type(proxy) == "filesystem" then
				node.driver = component.proxy(proxy)
				node.kernel_driver = false
			else
				local driver, reason = tryMountFilesystem(proxy)
				if not driver then
					return false, reason
				end
				node.driver = driver
				node.kernel_driver = true
			end
		end
		kernelLog(Log.INFO, "Filesystem", proxy, "mounted at", path.string())
		return true
end

function filesystem.path(path)
	return Path(path).path()
end

function filesystem.ext(path)
	return Path(path).filename():match("^.+%.(.+)$")
end

function filesystem.file(path)
	return Path(path).filename():match("^(.+)%..+$")
end

function filesystem.filename(path)
	return Path(path).filename()
end

function filesystem.exists(path)
		checkArg(1, path, "string")
		local node, fspath = getNode(path)
		if not node then
			return false
		end
		return node.driver.exists(node.kernel_driver and fspath or fspath.string())
end

function filesystem.makeDirectory(path)
		checkArg(1, path, "string")
		local node, fspath = getNode(path)
		if not node then
			return false
		end
		if #fspath == 0 then
			return true
		end
		local p = Path("")
		for _, f in pairs(fspath) do
			p:append(f)
			if not node.driver.exists(node.kernel_driver and p or p.string()) then
				local success, reason = node.driver.makeDirectory(node.kernel_driver and p or p.string())
				if not success then
					return false, reason
				end
			else
				if not node.driver.isDirectory(node.kernel_driver and p or p.string()) then
					return false, "file is not a directory"
				end
			end
		end
		return true
end

function filesystem.size(path)
		checkArg(1, path, "string")
		local node, fspath = getNode(path)
		if not node then
			return false
		end
		return node.driver.size(node.kernel_driver and fspath or fspath.string())
end

function filesystem.isDirectory(path)
	checkArg(1, path, "string")
	local node, fspath = getNode(path)
	if not node then
		return false
	end
	if #fspath == 0 then
		return true
	end
	return node.driver.isDirectory(node.kernel_driver and fspath or fspath.string())
end

function filesystem.lastModified(path)
		checkArg(1, path, "string")
		local node, fspath = getNode(path)
		if not node then
			return false
		end
		return node.driver.lastModified(node.kernel_driver and fspath or fspath.string())
end


function filesystem.list(path)
		checkArg(1, path, "string")
		local node, fspath = getNode(path)
                if not node then
			return nil, fspath
		end
		local files = {}
		-- if node.nodes and #fspath == 0 then
		-- 	for _, n in pairs(node.nodes) do
		-- 		table.insert(files, n.name)
		-- 	end
		-- end
		if node.driver then
			local fsfiles = node.driver.list(node.kernel_driver and fspath or fspath.string())
			if fsfiles then
				for _, f in pairs(fsfiles) do
					if type(f) == "string" then
						table.insert(files, f)
					end
				end
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
		if ({r=true,rb=true})[mode] then
			local exists
			if node.kernel_driver then
				exists = node.driver.exists(fspath, mode)
			else
				exists = node.driver.exists(fspath.string(), mode)
			end
			if not exists then
				return nil, "file not found: " .. fspath.string()
			end
		end
		local handle, reason
		if node.kernel_driver then
			handle, reason = node.driver.open(fspath, mode)
		else
			handle, reason = node.driver.open(fspath.string(), mode)
		end
		if not handle then
				return nil, reason
		end
		local stream = {
				path = fspath,
				kernel_driver = node.kernel_driver,
				driver = node.driver,
				handle = handle
		}
		-- TODO protect
		return setmetatable(stream, {__index = filesystemHandle})
end

libs.filesystem = filesystem

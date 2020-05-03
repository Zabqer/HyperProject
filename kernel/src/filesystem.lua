--[[
		Name: filesystem;
		Depends: [utils];
		Description: Provides virtual filesystem methods;
]]--

local mounts = {}

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

local function Path(path)
		local obj = {}
		obj.segments, obj.absolute = segmentate(path)
		return protectObject(obj, PathMethods, "FilesystemPath")
end

local function getFilesystem(path)
		local fspath = Path("")
		path = Path(path)
		while true do
				if mounts[path.absolute()] then
						return mounts[path.absolute()].driver, fspath.absolute()
				end
				if #path == 0 then
						return nil, "no mounted filesystems"
				end
				fspath:append(path:remove(), 0)
		end
end

local filesystemHandle = {}

function filesystemHandle:read(count)
		checkArg(2, count, "number")
		return self.driver.read(self.handle, count)
end

function filesystemHandle:close()
		return self.driver.close(self.handle)
end

function filesystem.mount(path, address)
		checkArg(1, path, "string")
		checkArg(2, address, "string")
		path = Path(path).string()
		if mounts[path] then
				return false, "another file system mounted here"
		end
		mounts[path] = {
				driver = component.proxy(address)
		}
		kernelLog(Log.DEBUG, "Filesystem", address, "mounted at", path)
		return true
end

function filesystem.exists(path)
		checkArg(1, path, "string")
		local driver, path = getFilesystem(path)
		if not driver then
				return false
		end
		return driver.exists(path)
end

function filesystem.isDirectory(path)
		checkArg(1, path, "string")
		local driver, path = getFilesystem(path)
		if not driver then
				return false
		end
		return driver.isDirectory(path)
end


function filesystem.list(path)
		checkArg(1, path, "string")
		local driver, path = getFilesystem(path)
                if not driver then
			return false
		end
        	return driver.list(path)
end

function filesystem.open(path, mode)
		checkArg(1, path, "string")
		mode = mode or "r"
		checkArg(2, mode, "string")
		assert(({r=true, rb=true, w=true, wb=true, a=true, ab=true})[mode], "bad argument #2 (r[b], w[b] or a[b] expected, got " .. mode .. ")")
		local driver, path = getFilesystem(path)
		if not driver then
				return nil, path
		end
		if ({r=true,rb=true})[mode] and not driver.exists(path) then
				return nil, "file not found: " .. path
		end
		local handle, reason = driver.open(path, mode)
		if not handle then
				return nil, reason
		end
		local stream = {
				driver = driver,
				handle = handle
		}
		return setmetatable(stream, {__index = filesystemHandle})
end

libs.filesystem = filesystem

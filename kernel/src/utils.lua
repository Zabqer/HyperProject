--[[
		Name: utils;
		Depends: [config];
		Description: Provides utilites and base methods;
]]--

local UserSpace = Config.disableUserSpace and GLOBAL or setmetatable({}, {__index = GLOBAL})

function nullFunction() end

function AssignTable(t1, t2)
	local t = {}
	for k, v in pairs(t1) do
		t[k] = v
	end
	for k, v in pairs(t2) do
		t[k] = v
	end
	return t
end

function protectObject(object, methods, name)
		return setmetatable({}, {
				__metatable = name or "Object",
				__index = function (_, key)
						return methods[key] and function(_, ...)
								return methods[key](object, ...)
						end
				end,
				__newindex = nullFunction,
				__tostring = methods.string and function ()
						return methods.string(object)
				end,
				__len = methods.len and function ()
						return methods.len(object)
				end,
				__pairs = methods.pairs and function ()
					return methods.pairs(object)
				end
		})
end

function protectTable(table, read, write)
		return setmetatable({}, {
				__metatable = "ProtectedTable",
				__index = read and table or nullFunction,
				__newindex = write and table or nullFunction
		})
end

function GLOBAL.yield()
	if thisThread ~= kernelThread then
		thisThread.deadline = computer.uptime()
		coroutine.yield()
	end
end

GLOBAL.os = setmetatable({}, {__index = os})

function GLOBAL.os.getenv(key)
		checkArg(1, key, "string")
		return thisThread.process.envvar[key]
end

function GLOBAL.os.setenv(key, value)
		checkArg(1, key, "string")
		checkArg(2, value, "string", "nil")
		thisThread.process.envvar[key] = value
end

function GLOBAL.os.sleep(time)
		checkArg(1, time, "number", "nil")
		thisThread.deadline = computer.uptime() + (time or 0)
		coroutine.yield()
end

function GLOBAL.os.exit(code)
	kill(thisThread.process.pid)
	-- TODO yield!!! but we can't because we don't fully work in this thread env
end

local rtype = type
function GLOBAL.type(value)
		local mt = getmetatable(value)
		if rtype(mt) == "string" then
				return mt
		end
		return rtype(value)
end

local rload = load
function GLOBAL.load(chunk, name, mode, env)
		yield()
		return rload(chunk, name, mode, env or setmetatable({}, {__index=UserSpace}))
end

function GLOBAL.loadfile(path, mode, env)
		local file, reason = io.open(path, "r")
		if not file then
				return nil, reason
		end
		local chunk, reason = file:read("*a")
		file:close()
		if not chunk then
				return nil, reason
		end
		return load(chunk, "=" .. path, mode, env)
end

function GLOBAL.dofile(path)
  local f, reason = loadfile(path)
  if not f then
    return error(reason, 0)
  end
  return f()
end

function GLOBAL.print(...)
		local args = table.pack(...)
		for i = 1, #args do
				args[i] = tostring(args[i])
		end
		local string = table.concat(args, "\t")
		io.write(string, "\n")
end

local libcomputer = {
		pushSignal = function (name, ...)
				return computer.pushSignal(name, ...)
		end,
		pullSignal = function (timeout)
				checkArg(1, timeout, "number", "nil")
				thisThread.deadline = computer.uptime() + (timeout or math.huge)
				return coroutine.yield("signal")
		end,
		shutdown = computer.shutdown
}

local libcomponent = {
		list = component.list,
		type = component.type,
		invoke = component.invoke
}

local libunicode = {
		char = unicode.char,
		len = unicode.len,
		sub = unicode.sub
}

libs = {
		computer = libcomputer,
		component = libcomponent,
		unicode = libunicode
}

local package = {
		preload = libs,
		loading = {},
		loaded = setmetatable({}, {__mode = "v"}),
		searchers = {}
}

function package.searchpath(name, path, sep, rep)
		checkArg(1, name, "string")
		checkArg(2, path, "string")
		sep = sep or '.'
		rep = rep or '/'
		sep, rep = '%' .. sep, rep
		name = string.gsub(name, sep, rep)
		local errors = {}
		for subPath in string.gmatch(path, "([^;]+)") do
				subPath = string.gsub(subPath, "?", name)
				if filesystem.exists(subPath) then
						local file = io.open(subPath, "r")
 						if file then
 								file:close()
 								return subPath
 						end
 				end
 				table.insert(errors, "\tno file '" .. subPath .. "'")
		end
		return nil, table.concat(errors, "\n")
end

table.insert(package.searchers, function(name)
		return package.preload[name]
end)

table.insert(package.searchers, function(name)
		local path, reason = package.searchpath(name, "/lib/?.lua")--os.getenv("LIBPATH"))
		if path then
				local f
				f, reason = loadfile(path)
				if f then
        	local success
						success, reason = pcall(f)
						if success then
								return reason
     			end
				end
		end
		return nil, reason
end)

function GLOBAL.require(name)
		checkArg(1, name, "string")
		::start::
		if package.loaded[name] then
				return package.loaded[name]
		end
		if package.loading[name] then
				waitEvent("package_loaded", name)
				goto start
		end
		package.loading[name] = true
		local reason
		for _, searcher in pairs(package.searchers) do
				local success, lib
				success, lib, reason = pcall(searcher, name)
				if success and lib then
						package.loaded[name] = lib
						package.loading[name] = nil
						pushEvent("package_loaded", name)
						return lib
				elseif not success and lib then
						reason = lib
				end
		end
		package.loading[name] = nil
		error(string.format("Could not load module '%s': %s", name, reason or "module returned nil"))
end

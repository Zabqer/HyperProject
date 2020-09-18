local sh = {}
local thread = require("thread")
local filesystem = require("filesystem")

function switch(var, cases, default)
		local continue = false
		for case, func in pairs(cases) do
				if continue or var == case then
						if not func() then
								continue = true
						else
								return
						end
				end
		end
		default(var)
end

function newStepper(string)
		local stepper = {
				__data = string,
				__pos = 1
		}
		function stepper:char()
				if self.__pos <= #self.__data then
						return self.__data:sub(self.__pos, self.__pos)
				end
		end
		function stepper:next()
				if self.__pos + 1 <= #self.__data then
						self.__pos = self.__pos + 1
						return true
				else
						return false
				end
		end
		return stepper
end

function sh.parse(commandLine)
		local commands = {}
		local command = {
				name = nil,
				args = {}
		}
		local stepper = newStepper(commandLine)
		local currentName = ""
		local quoted = nil
		local function nextName()
				if #currentName == 0 then
						return
				end
				if not command.name then
						command.name = currentName
				else
						table.insert(command.args, currentName)
				end
				currentName = ""
		end
		while true do
				switch(stepper:char(), {
						["\""] = function ()
								if not quoted then
										quoted = "\""
										return true
								elseif quoted == "\"" then
										nextName()
										quoted = nil
										return true
								end
						end,
						["\'"] = function ()
								if not quoted then
										quoted = "\'"
										return true
								elseif quoted == "\'" then
										nextName()
										quoted = nil
										return true
								end
						end,
						[" "] = function()
								if not quoted then
												nextName()
										return true
								end
						end
				}, function (char)
						currentName = currentName .. char
				end)
				if not stepper:next() then
						nextName()
						break
				end
		end
		return command
end

function sh.expand(value)
	return value:gsub("%$(%w+)", os.getenv):gsub("%$%b{}", function(match) return os.getenv(sh.expand(match:sub(3, -2))) or match end), nil
end


sh.buildin = {}

function sh.buildin.cd(path)
	thread.thisProcess():setWorkingDirectory(path)
end

function sh.resolve(name)
	if sh.buildin[name] then
		return sh.buildin[name], true
	end
	for dir in string.gmatch(os.getenv("PATH"), "([^;]+)") do
		filename = string.gsub(dir, "?", name)
		if filesystem.exists(filename) then
			return filename, false
		end
	end
	return nil, "no command found"
end

function getProgramms(start)
	local progs = {}
	for pattern in string.gmatch(os.getenv("PATH"), "([^;]+)") do
		local path = filesystem.path(pattern)
		for _, prog in pairs(filesystem.list(path)) do
			if filesystem.ext(prog) == "lua" and unicode.sub(filesystem.file(prog), 1, unicode.len(start)) == start then
				table.insert(progs, filesystem.file(prog))
			end
		end
	end
	return progs
end

function getFiles(start)
	if filesystem.exists(start) then
		if unicode.sub(start, -1, -1) == "/" and filesystem.isDirectory(start) then
			local files = {}
			for _, f in pairs(filesystem.list(start)) do
				table.insert(files, f .. (filesystem.isDirectory(f) and "/" or ""))
			end
			return files
		end
		return {start..(filesystem.isDirectory(start) and "/" or "")}
	end
	local files = {}
	local fn = filesystem.filename(start)
	for _, f in pairs(filesystem.list(start .. "/../")) do
		if unicode.sub(f, 1, unicode.len(fn)) == fn then
			table.insert(files, f .. (filesystem.isDirectory(f) and "/" or ""))
		end
	end
	return files
end

function sh.hintHandler(line, cursor)
	line = unicode.sub(line, 1, cursor - 1)
	if line:find("/") then
		local prefix, path = line:match("^(.* )(.*)$")
		local files = getFiles(path)
		if #files == 1 then
			return {prefix .. files[1]}
		end
		return files
	else
		local progs = getProgramms(line)
		return progs
	end
end

function sh.execute(line)
	if #line == 0 then
		return nil, "command not found"
	end
	local command = sh.parse(line)
	local filename, reason = sh.resolve(command.name)
	if not filename then
		return nil, reason
	end
	if reason then
		filename(table.unpack(command.args))
		return true
	else
		local th, reason = thread.createProcess({
			exe = filename,
			args = command.args,
			stdin = io.stdin,
			stdout = io.stdout,
			stderr = io.stderr
		})
		if not th then
			return nil, reason
		end
		-- th:onKill(function (pid)
		-- 	io.error():write("Killed " .. pid)
		-- end)
		th:run()
		return th
	end
end

return sh

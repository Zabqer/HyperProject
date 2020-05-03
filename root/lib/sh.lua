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
	thread.thisThread().setWorkingDirectory(path)
end

function sh.resolve(name)
	if sh.buildin[name] then
		return sh.buildin[name]
	end
	for dir in string.gmatch(os.getenv("PATH"), "([^;]+)") do
		filename = string.gsub(dir, "?", name)
		if filesystem.exists(filename) then
			return filename
		end
	end
	return nil, "no command found"
end

function sh.execute(line)
	command = sh.parse(line)
	filename, reason = sh.resolve(command.name)
	if not filename then
		return nil, reason
	end
	local th, reason = thread.createProcess(filename, _, table.unpack(command.args))
	if not th then
		return nil, reason
	end
	local ios = th:IO()
	ios.stdin = io.stdin
	ios.stdout = io.stdout
	ios.stderr = io.stderr
	-- th:onKill(function (pid)
	-- 	io.error():write("Killed " .. pid)
	-- end)
	th:run()
	th:join()
	return true
end

return sh

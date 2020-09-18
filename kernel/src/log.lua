--[[
		Name: log;
		Depends: [config];
		Description: Provides logging methods
]]--

Log = {
		DEBUG = 0,
		INFO = 1,
		WARNING = 2,
		ERROR = 3
}

local levelName = {
		[0] = "DEBUG",
		[1] = "INFO",
		[2] = "WARNING",
		[3] = "ERROR"
}

local function extend(level, ...)
		local str = ""
		for _, s in pairs({...}) do
				str = str .. " " .. s
		end
		local clock = math.floor(os.clock() * 1000) / 1000
		local color = ""
		if dprint then
			if level == Log.INFO then
				color = "\x1b[34m"
			elseif level == Log.WARNING then
				color = "\x1b[33m"
			elseif level == Log.ERROR then
				color = "\x1b[31m"
			end
		end
		return color .. "[" .. clock .. "] [" .. levelName[level] .. "]" .. str .. "\x1b[0m"
end

kernelLogger = {
	buffer = "",
	write = function (self, str)
		self.buffer = self.buffer .. str
		bootLogger(str)
	end
}

local cb = Config.logToChatBox and component.list("chat_box")()

function kernelLog(level, ...)
		local args = table.pack(...)
		for i = 1, #args do
				args[i] = tostring(args[i])
		end
		if level < Config.logLevel or 0 then
		--	return
		end
		local data = extend(level, table.unpack(args))
		if dprint then
			dprint(data)
		end
		if cb then
			component.invoke(cb, "say", data)
		end
		kernelLogger:write(data)
end

local gpu, screen = component.list("gpu")(), component.list("screen")()

local invoke = component.invoke

function bootLogger() end

if gpu and screen then
		invoke(gpu, "bind", screen)
		local w, h = invoke(gpu, "getResolution")
		local y = 0
		invoke(gpu, "fill", 1, 1, w, h, " ")
		local function drawLine(str)
				if y == h then
						invoke(gpu, "copy", 1, 2, w, h - 1, 0, -1)
						invoke(gpu, "fill", 1, h, w, 1, " ")
				else
						y = y + 1
				end
				invoke(gpu, "set", 1, y, str)
		end
		function bootLogger(str)
			str = str:gsub("\t", "  ")
			if true then
				return
			end
                            local ss = ""
                            for s in str:gmatch("[^\r\n]+") do
                                    ss = ss .. s
                                    while #ss > 0 do
					if unicode.len(ss) > w then
						line = unicode.wtrunc(ss, w)
                                        else
                                        	line = ss
                                        end
                                        drawLine(line)
                                        ss = unicode.sub(ss, unicode.len(line) + 1)
                                   end
                           end
		end
end

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

local function extend(level, str)
		local clock = math.floor(os.clock() * 1000) / 1000
		return "[" .. clock .. "] [" .. levelName[level] .. "] " .. str
end

function kernelLog(level, ...)
		print(extend(level, select(1, ...)))
end
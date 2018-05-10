local args = ...

local function help()
		print("build-kernel.lua [-v] <sources directory> [-o <kernel image>]")
end

local function error(message, code)
		print("Error: " .. message)
		os.exit(code or 1)
end

local verbose = print

local sourcesDirectory = "./src/"
local kernelPath = "kernel.lua"

local sources = {
		"src/log.lua",
		"src/threading.lua",
		"src/main.lua"
}

local function readData(path)
		local handle = assert(io.open(path))
		local data = handle:read("a")
		handle:close()
		return data
end

local function writeData(path, data)
		local handle = assert(io.open(path, "w"))
		handle:write(data)
		handle:close()
end

local kernel, mainF = ""

for _, sourcePath in pairs(sources) do
		local code = readData(sourcePath)
		local s, e = code:find("function main%(.-%).*end")
		if s then
				mainF = code:sub(s, e)
				code = code:sub(0, s - 1) .. code:sub(e + 1)
		end
		kernel = kernel .. code:gsub("\n\n", "\n") .. (#code > 0 and ";" or "")
end

if not mainF then
		error("no main function found")
end

kernel = kernel .. mainF:gsub("function main%((.-)%)(.*)end", "return (function(%1)%2end)(...)")

verbose("> Writing kernel image")

writeData(kernelPath, kernel)
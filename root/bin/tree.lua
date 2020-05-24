local filesystem = require("filesystem")
local term = require("term")

local path = ...
path = path or "."

function processTree(path, isdir, a, b)
	if isdir then
		term.lightgreenFg()
		io.write(filesystem.filename(path))
		term.defaultFg()
		io.write("\n")
		local dirs = {}
		local files = {}
		for _, f in ipairs(filesystem.list(path)) do
			table.insert(filesystem.isDirectory(path .. "/" .. f) and dirs or files, f)
		end
		for i, f in pairs(dirs) do
			io.write(string.rep(" │", a), string.rep("  ", b), " ", (#dirs == i and #files == 0 and "└─" or "├─"))
	 		processTree(path .. "/" .. f, true, a + 1, b + 1)

		end
		for i, f in pairs(files) do
			io.write(string.rep(" │", a), string.rep("  ", b), " ", (#files == i and "└─" or "├─"))
	 		processTree(path .. "/" .. f, false, a, b)
		end
		
	else
		term.lightcyanFg()
		io.write(filesystem.filename(path))
		term.defaultFg()
		io.write("\n")
	end
end

processTree(path, filesystem.isDirectory(path), 0, 0)

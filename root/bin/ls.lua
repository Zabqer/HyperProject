local filesystem = require("filesystem")
local term = require("term")

local path = ...

path = path or "."

for _, name in ipairs(assert(filesystem.list(path))) do
	if filesystem.isDirectory(name) then
		term.lightcyanFg()
	else
		term.lightgreenFg()
	end
	print(name)
	term.defaultFg()
end

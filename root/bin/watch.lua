local sh = require("sh")
local term = require("term")

local args = table.pack(...)

while true do
	term.clear()
	sh.execute(table.concat(args, " "))
	os.sleep(1)
end

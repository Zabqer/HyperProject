local thread = require("thread")
local term = require("term")

local currentUser = thread.thisProcess().info().user

function processTree(th, a, b)
	info = th:info()
	if not info.process then
		term.lightgreenFg()
	end
	io.write(info.name)
	term.defaultFg()
	io.write(" ")
	term.lightcyanFg()
	io.write(info.pid)
	term.defaultFg()
	io.write(" ")
	if info.user == "root" then
		term.lightredFg()
		io.write("root")
		term.defaultFg()
	elseif info.user == currentUser then
		term.lightgreenFg()
		io.write(info.user)
		term.defaultFg()
	else
		io.write(info.user)
	end
	print()
	if info.process then
		local l = #info.childs
		for i, pid in pairs(info.childs) do
			io.write(string.rep(" │", a), string.rep("  ", b), " ", (l == i and "└─" or "├─"))
			processTree(thread.byPid(pid), l == i and a or a + 1, l == i and b + 1 or b)
		end
	end
end

processTree(thread.byPid(1), 0, 0)

local term = require("term")
local sh = require("sh")
local thread = require("thread")

os.setenv("PS", "\x1b[91m$USER\x1b[39m@\x1b[92m$HOSTNAME\x1b[39m $PWD $ ")

local currentProcess

thread.attach("interrupt", function ()
	if currentProcess then
		currentProcess:signal("interrupt")
	end
end)

local history = {}

while true do
	io.write(sh.expand(os.getenv("PS")))
	local line = term.read({
		hint = sh.hintHandler,
		history = history,
	})
     	if not line then
		io.write("exit\n")
		return
	elseif line == "exit" then
		return
    	end
	if #line > 0 then 
		history[#history+1] = line
		th, result = sh.execute(line)
		if not th then
			io.error():write(result .. "\n")
		elseif th ~= true then
			currentProcess = th
			th:join()
			currentProcess = nil
		end
	end
end

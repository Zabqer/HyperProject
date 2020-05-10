local term = require("term")
local sh = require("sh")
local thread = require("thread")

os.setenv("PWD", "/")
os.setenv("PS", sh.expand("\x1b[91m$USER\x1b[39m@\x1b[92m$HOSTNAME\x1b[39m $PWD $ "))

local currentProcess

while true do
	io.write(sh.expand("$PS"))
	local line = term.read({
	})
     	if not line then
		io.write("exit\n")
		return
	elseif line == "exit" then
		return
    	end
    	th, result = sh.execute(line)
	if not th then
		io.error():write(result .. "\n")
	else
		currentProcess = th
		th:join()
		currentProcess = nil
    	end
end

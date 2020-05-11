local term = require("term")
local thread = require("thread")
local user = require("user")


local index = 0--...

local shell

thread.onSignal("interrupt", function ()
	shell:signal("interrupt")
end)

while true do
	term.clear()
	print(_OSVERSION .. " (tty" .. index .. ")")

	local u
	while true do
		io.write(os.getenv("HOSTNAME") .. " login: ")
		io.write("zabqer\n")

		--login = term.read()
		
		login = "zabqer"
		io.write("Password: ")
		io.write("\n")
		--local password = term.read(_, "")
		password = "tester"

		local id = user.auth(login, password)
		if not id then
			print("Login incorrect")
		else
			u = user.getInfo(id)
			break
		end
	end
	os.setenv("USER", u.login)

	shell = assert(thread.createProcess({
		exe = u.shell,
		stdin = io.stdin,
		stdout = io.stdout,
		stderr = io.rewriter(function (data)
			return "\x1b[91m" .. data .. "\x1b[39m"
		end, io.stdout)
	}))
	shell:setUser(u.id)
	shell:run()
	shell:join()
	print("Exited from shell")
	os.sleep(5)
end

local c, fs = require("component"), require("filesystem")
local term = require("term")
local TC, RO, RN, RD, TPS = 2, 0, 0, 0

require("thread").attach("interrupt", function ()
	term.clear()
	os.exit(0)
end)

term.clear()

print("TPS Сервера:")
local function time()
    local f = io.open("/tmp/TF", "w")
    f:write("test")
    f:close()
    return(fs.lastModified("/tmp/TF"))
end

while true do
    RO = time()
    os.sleep(TC) 
    RN = time()
    RD = RN - RO
    TPS = 20000 * TC / RD
    TPS = string.sub(TPS, 1, 5)
    nTPS = tonumber(TPS)
    if nTPS <= 10 then
	term.lightredFg()
    elseif nTPS <= 15 then
	term.lightcyanFg()
    elseif nTPS > 15 then 
	term.lightgreenFg()
    end
    term.setCursorPosition(1, 2)
    term.eraseEndOfLine()
    io.write(TPS)
end

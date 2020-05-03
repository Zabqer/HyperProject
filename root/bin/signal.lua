local pid, signal = ...

local thread = require("thread")

local th, reason = thread.byPid(tonumber(pid))
if not th then
	error(reason)
end

local result, reason = th:signal(signal)
if not result then
	error(reason)
end

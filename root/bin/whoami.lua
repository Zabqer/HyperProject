local thread = require("thread")

print(thread.thisThread():getInfo().user)

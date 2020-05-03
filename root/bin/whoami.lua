local thread = require("thread")

print(thread.thisProcess():info().user)

assert(arg[1] and arg[2], "spec and result paths are required")
require("tests.validate").install(arg[2])
require("telemetry.busted").install()
require("plenary.busted").run(arg[1])

local testutils = require'zbus.testutils'
local zbusd = testutils.process('bin/zbusd.lua')
local echo_and_publish = testutils.process('lua test/entangled/echo_and_publish.lua')
local caller1 = testutils.process('lua test/entangled/caller.lua')
local caller2 = testutils.process('lua test/entangled/caller.lua')
assert(caller1:wait()==0)
assert(caller2:wait()==0)
echo_and_publish:kill()
echo_and_publish:wait()
zbusd:kill()
zbusd:wait()

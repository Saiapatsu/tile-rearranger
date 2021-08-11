local path = require("path")
local script = table.remove(args, 1)
local common = require(path.resolve(path.dirname(script), "common.lua")) -- infuriating drag-and-drop behavior on windows. there is no cd() in lua

for _,target in ipairs(args) do
	common.convert(target, script:match(".*%-(.*)%.lua$"))
end

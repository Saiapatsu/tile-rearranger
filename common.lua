local path = require("path")
local common = {}

-- http://www.windowsinspired.com/understanding-the-command-line-string-and-arguments-received-by-a-windows-program/
-- http://www.windowsinspired.com/how-a-windows-programs-splits-its-command-line-into-individual-arguments/
-- Will return str such that CommandLineToArgvW or parse_cmdline, if it enters in
-- InterpretSpecialChars, will consider it one continuous argument
-- and will remain in InterpretSpecialChars afterward
-- Quotes, if necessary, will be placed around the string, not inside
-- The return value will be up to double the size of the input if it
-- consists entirely of quotes or backslashes,
-- and will output [" \""] (5 chars) for [ "] (2 chars)
-- NB! Carets, redirection etc. are handled by the shell, not here!
function common.unparse(str)
	local i = 1
	local lasti = 1 -- used to reduce amount of appends needed
	local len = #str
	local out = ""
	
	local needQuotes = false
	
	local function yeah()
		out = out .. str:sub(lasti, i-1)
		lasti = i
	end
	
	while i <= len do
		local char = str:sub(i, i)
		
		if char == "\\" then
			yeah()
			-- look for runs of \
			-- if run is followed by ", escape all of it and the "
			-- else emit as-is
			repeat i = i + 1 char = str:sub(i, i) until char ~= "\\"
			if char == "\"" then
				out = out .. ("\\"):rep((i - lasti) * 2 + 1)
				lasti = i
			else
				yeah()
			end
			
		elseif char == "\"" then
			yeah()
			out = out .. "\\"
			
		elseif char == " " or char == "\t" then
			needQuotes = true
		end
		i = i + 1
	end
	yeah()
	
	if needQuotes then
		if out:sub(-1) == "\\" then
			-- trailing backslash may eat the quote
			return "\"" .. out .. "\\\""
		else
			return "\"" .. out .. "\""
		end
	else
		return out
	end
	
	return needQuotes and "\"" .. out .. "\"" or out
end

--[[
common.split(C:\Smoothing\fly_shop_empty_dot.base.111.png) = {
	dir     = C:\Smoothing
	nameext = fly_shop_empty_dot.base.111.png
	nametag = fly_shop_empty_dot
	name    = fly_shop_empty
	tag     =                dot
	ext     =                   .base.111.png
}
]]
function common.split(target)
	local split = {}
	split.dir = path.dirname(target)
	split.nameext = path.basename(target)
	split.nametag, split.ext = split.nameext:match("([^.]*)(%..*)")
	split.name, split.tag = split.nametag:match("(.*)_(.*)")
	if split.name == nil then split.name, split.tag = split.nametag, "" end
	return split
end

-- escape2 = function(...) print(common.escape(...)) end
return common

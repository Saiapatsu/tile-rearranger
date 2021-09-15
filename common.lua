local path = require("path")
local common = {}

--------------------------------------------------------------------------------
--                            Shell execution-related
--------------------------------------------------------------------------------

-- http://www.windowsinspired.com/understanding-the-command-line-string-and-arguments-received-by-a-windows-program/
-- http://www.windowsinspired.com/how-a-windows-programs-splits-its-command-line-into-individual-arguments/
-- Escapes str such that it will be received as intended after being passed through
-- shell execution (which looks for ^, >, & etc.) and CommandLineToArgvW or parse_cmdline
-- (which look for ", backslash and spaces)
-- Quotes, if necessary, will be placed around the string, not inside
function common.unparse(str)
	str = str:gsub([[(\*)"]], [[%1%1\"]]) -- escape quotes and their leading backslashes
	
	if str:find("[ \t]") then -- has whitespace, surround in quotes
		if str:sub(-1) == "\\" then str = str .. "\\" end -- escape trailing backslash
		str = "\"" .. str .. "\""
	end
	
	str = str:gsub("[&<>^|\n]", "^%0") -- escape shell characters
	
	return str
	
	-- argv in a nutshell:
	-- quote toggles space parsing instead of "delimiting" anything, and
	-- backslashes are literal except when they're followed by a quote.
	
	-- more specifically:
	-- start in an "interpreting" state
	-- when interpreting, split on spaces
	-- on backslash, count it, don't emit it
	-- on quote, emit half the counted backslashes, then toggle interpreting
	-- state if there is an even amount of backslashes or emit " if odd
	-- on quote following quote, attempt "quote escaping quote" (not relevant here)
	-- on any other character, emit all counted backslashes and the character
	
	-- it is the responsibility of the program to split its arg string
	-- into an argument list. some programs either don't do it (such as
	-- echo) or split it themselves
	-- for a demonstration, do echo "foo" > CON in the console
	-- echo does not use argv (which might've stripped those quotes), it
	-- echoes its args string as-is
	-- > is interpreted by the shell, so the stdout of echo is redirected
	-- to a file named CON, which is actually a device that prints to console
	-- echo "foo" ^> CON will echo "foo" > CON in one piece
	
	-- shell characters are separate from the quotes, spaces, backslashes
	-- etc. unparsed above
	-- for a demonstration, do echo "foo" > CON in the console
	-- echo does not use argv (which might've stripped those quotes), it
	-- echoes its args string as-is
	
	-- batch will mangle percents (and bangs if in delayed expansion mode),
	-- but that's out of the scope of this function
end

--------------------------------------------------------------------------------
--                              Filename management
--------------------------------------------------------------------------------

--[[
common.split(C:\Smoothing\fly_shop_empty_dot.base.111.png) = {
	href    = C:\Smoothing\fly_shop_empty_dot.base.111.png
	dir     = C:\Smoothing
	nameext = fly_shop_empty_dot.base.111.png
	nametag = fly_shop_empty_dot
	name    = fly_shop_empty
	tag     =                dot
	ext     =                   .base.111.png
	
	tag will be one of those described in common.layouts
}
]]
function common.split(target)
	local split = {}
	split.href = target
	split.dir = path.dirname(target)
	split.nameext = path.basename(target)
	split.nametag, split.ext = split.nameext:match("([^.]*)(%..*)")
	split.name, split.tag = split.nametag:match("(.*)_(.*)")
	if split.name == nil then split.name, split.tag = split.nametag, "" end
	
	if common.layouts[split.tag] == nil then
		split.name, split.tag = split.name .. "_" .. split.tag, ""
	end
	
	return split
end

--------------------------------------------------------------------------------
--                                  Conversion
--------------------------------------------------------------------------------

-- Generic conversion function
function common.convert(split, fromtag, totag)
	-- get layouts
	local src = assert(common.layouts[fromtag], "Unknown tag " .. fromtag)
	local dst = assert(common.layouts[totag]  , "Unknown tag " .. totag)
	
	local invsrc = {w = src.w, h = src.h} -- inverse of src
	for i,v in ipairs(src) do invsrc[v] = i end
	
	local rope = {} -- list of imagemagick operations, each generating a tile of dst
	for i,v in ipairs(dst) do rope[i] = common.get(common.unparse(split.nameext), invsrc, v) end
	
	-- output name
	local outname = split.name .. (totag == "" and "" or ("_" .. totag)) .. split.ext
	
	-- build montage command
	local command = table.concat({
		"cd " .. split.dir .. " & ",         -- cd to image (for shorter command line)
		"magick montage",                    -- arrange tiles in a grid
		"-tile " .. dst.w .. "x" .. dst.h, -- grid size is w*h
		"-background none",                  -- transparent background
		"-geometry +0+0",                    -- no space between tiles
		table.concat(rope, " "),
		"-strip",                            -- strip unnecessary png chunks
		common.unparse(outname),             -- output
	}, " ")
	
	p(command, #command)
	
	-- run
	local success, reason, exitcode = os.execute(command)
	
	if not success then
		print("Unable to convert " .. fromtag .. " to " .. totag)
		io.read()
	end
end

--------------------------------------------------------------------------------
--                                Tile composition
--------------------------------------------------------------------------------

-- blank tile
local function empty() return "-size 32x32 xc:#00000000" end

-- clip a part out of a solid tile
local function clip(geometry)
	return function(from, src, i)
		return table.concat({"(", -- separate stack from the other images
			common.get(from, src, -1), -- solid tile
			"-crop " .. geometry, -- leave only the specified area. the
			--                        "virtual canvas" position remains!
			empty(), -- a transparent image the size of one tile
			"-flatten", -- flatten into one tile-sized layer with the tile
			--            in the right spot
		")"}, " ")
	end
end

-- overlay many tiles
local function combine(...)
	local args = {...}
	return function(from, src, i)
		local args2 = {}
		for i,v in ipairs(args) do
			args2[i] = common.get(from, src, v)
		end
		return "( " .. table.concat(args2, " ") .. " +repage -flatten )"
	end
end

common.composition = {
	[ -1] = empty, -- solid tile
	[  0] = empty, -- blank tile
	-- the compass direction refers to which directions are solid
	-- corners      nw sw se ne
	[  1] = --[[   (          1),]] clip("15x15+0+0"),
	[  4] = --[[   (       4   ),]] clip("15x15+17+0"),
	[  5] = combine(       4 ,1),
	[ 16] = --[[   (   16      ),]] clip("15x15+17+17"),
	[ 17] = combine(   16    ,1),
	[ 20] = combine(   16 ,4   ),
	[ 21] = combine(   16 ,4 ,1),
	[ 64] = --[[   (64         ),]] clip("15x15+0+17"),
	[ 65] = combine(64       ,1),
	[ 68] = combine(64    ,4   ),
	[ 69] = combine(64    ,4 ,1),
	[ 80] = combine(64,16      ),
	[ 81] = combine(64,16    ,1),
	[ 84] = combine(64,16 ,4   ),
	[ 85] = combine(64,16 ,4 ,1),
	-- edges         s   w   n e
	[  7] = --[[   (           7),]] clip("15x32+0+0"),
	[ 28] = --[[   (28          ),]] clip("32x15+0+0"),
	[ 31] = combine(28        ,7),
	[112] = --[[   (   112      ),]] clip("15x32+17+0"),
	[119] = combine(   112    ,7),
	[124] = combine(28,112      ),
	[127] = combine(28,112    ,7),
	[193] = --[[   (       193  ),]] clip("32x15+0+17"),
	[199] = combine(       193,7),
	[221] = combine(28    ,193  ),
	[223] = combine(28    ,193,7),
	[241] = combine(   112,193  ),
	[247] = combine(   112,193,7),
	[253] = combine(28,112,193  ),
	[255] = combine(28,112,193,7),
}

function common.get(from, src, i)
	if src[i] then
		-- exact match
		local x = (src[i]  -1)%src.w
		local y = (src[i]-x-1)/src.w
		return from .. "[32x32+" .. x*32 .. "+" .. y*32 .. "]"
		
	elseif common.composition[i] then
		return common.composition[i](from, src, i)
		
	else
		error("Unable to find or create tile " .. i)
	end
end

common.layouts = {
	[""] = { -- single tile
		w = 1, h = 1,
		-1,
	}, dot = {
		w = 3, h = 3,
		4,  28,  16,
		7,  -1, 112,
		1, 193,  64,
	}, dothash = {
		w = 6, h = 3,
		4,  28,  16,  31, 127, 124,
		7,  -1, 112, 223, 255, 253,
		1, 193,  64, 199, 247, 241,
	}, dagger = { -- rearranged dothash without loose ends
		w = 6, h = 3,
		4,  31, 127, 124,  28,  16,
		7,  -1, 255, 253, 223, 112,
		1, 199, 247, 241, 193,  64,
	}, bruh = { -- rearranged S without loose ends
		w = 6, h = 5,
		255, 253, 81, 193, 69, 223,
		247, 241, 68,  20, 17, 199,
		 85,  80,  1,  65, 64,   5,
		119, 112,  4,  28, 16,   7,
		127, 124, 21, 221, 84,  31,
	}, S = {
		w = 16, h = 2,
		-1, 112, 193, 241, 7, 119, 199, 247, 28, 124, 221, 253, 31, 127, 223, 255,
		 0,  64,   1,  65, 4,  68,   5,  69, 16,  80,  17,  81, 20,  84,  21,  85,
	},
}

--[[
local function wallify(x)
	local wx = x & 170 -- only horizontals
	return ((x)
		| (wx >> 1) -- dilate horizontals
		| (wx << 1)
		| (wx >> 7)
		| (wx << 7)
	) & 255
end

function fixup()
	editor:BeginUndoAction()
	editor:SetText(editor:GetText():gsub("%d+", wallify))
	editor:EndUndoAction()
end
]]

--------------------------------------------------------------------------------
--                                    Export
--------------------------------------------------------------------------------

return common

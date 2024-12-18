WOWCRON_SLUG, wowCron = ...
WOWCRON_MSG_ADDONNAME = C_AddOns.GetAddOnMetadata( WOWCRON_SLUG, "Title" )
WOWCRON_MSG_VERSION   = C_AddOns.GetAddOnMetadata( WOWCRON_SLUG, "Version")
WOWCRON_MSG_AUTHOR    = C_AddOns.GetAddOnMetadata( WOWCRON_SLUG, "Author" )

-- Colours
COLOR_RED = "|cffff0000"
COLOR_GREEN = "|cff00ff00"
COLOR_BLUE = "|cff0000ff"
COLOR_PURPLE = "|cff700090"
COLOR_YELLOW = "|cffffff00"
COLOR_ORANGE = "|cffff6d00"
COLOR_GREY = "|cff808080"
COLOR_GOLD = "|cffcfb52b"
COLOR_NEON_BLUE = "|cff4d4dff"
COLOR_END = "|r"

cron_global = {}
cron_player = {}
at_global = {}
at_player = {}

cron_knownSlashCmds = {}
cron_knownEmotes = {}
wowCron.events = {}
wowCron.crons = {}  -- [nextTS] = {[1]={['event'] = 'runME', ['fullEvent'] = '* * * * * runMe'}}
-- meh, ['fullEvent'] = ts
-- meh, meh...  [1] = '* * * * * runMe', [2] = "* * * * * other"
--wowCron.nextEvent = 0
wowCron.ranges = {
	["min"]   = {0,59},
	["hour"]  = {0,23},
	["day"]   = {1,31},
	["month"] = {1,12},
	["wday"]  = {0,7}, -- 0 and 7 is sunday
}
wowCron.fieldNames = { "min", "hour", "day", "month", "wday" }
wowCron.monthNames = { "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec" }
wowCron.macros = {  -- keep a 1 to 1 mapping for macro to event.
	["@hourly"]   = { ["cron"] = "0 * * * *" },
	["@midnight"] = { ["cron"] = "0 0 * * *" },
	["@noon"]     = { ["cron"] = "0 12 * * *" },
	["@teatime"]  = { ["cron"] = "0 16 * * *" },
	["@first"]    = { ["event"] = "LOADING_SCREEN_DISABLED" },
	["@gold"]     = { ["event"] = "PLAYER_MONEY" },
	["@level"]    = { ["event"] = "PLAYER_LEVEL_UP" },
	["@zone"]     = { ["event"] = "ZONE_CHANGED_NEW_AREA" },
	["@crit"]     = { ["event"] = "COMBAT_LOG_EVENT_UNFILTERED" },
}
wowCron.chatChannels = {
	["/s"]    = "SAY",
	["/say"]  = "SAY",
	["/g"]    = "GUILD",
	["/guild"]= "GUILD",
	["/y"]    = "YELL",
	["/yell"] = "YELL",
}
wowCron.toRun = {}
-- events
function wowCron.OnLoad()
	SLASH_CRON1 = "/CRON"
	SlashCmdList["CRON"] = function(msg) wowCron.Command(msg); end
	SLASH_AT1 = "/AT"
	SlashCmdList["AT"] = function(msg) wowCron.AtCommand(msg); end
	wowCron_Frame:RegisterEvent( "ADDON_LOADED" )
	wowCron_Frame:RegisterEvent( "PLAYER_ENTERING_WORLD" )
	wowCron_Frame:RegisterEvent( "LOADING_SCREEN_DISABLED" )
end
function wowCron.OnUpdate()
	-- if there are still events in the queue to process
	if( #wowCron.toRun > 0 ) then
		wowCron.RunNowList()
	end
	local nowTS = time()
	if (wowCron.lastUpdated < nowTS) and (nowTS % 60 == 0) then
		wowCron.lastUpdated = nowTS
		wowCron.BuildRunNowList() -- This is where building the list needs to happen.
	end
end
function wowCron.ADDON_LOADED()
	wowCron_Frame:UnregisterEvent( "ADDON_LOADED" )
	wowCron.lastUpdated = time()
	wowCron.ParseAll()
	wowCron.BuildSlashCommands()
	wowCron.playerGUID = UnitGUID("player")
end
function wowCron.PLAYER_ENTERING_WORLD()
	wowCron_Frame:UnregisterEvent( "PLAYER_ENTERING_WORLD" )
	wowCron.BuildSlashCommands()
	wowCron.BuildRunNowList()
end
function wowCron.LOADING_SCREEN_DISABLED()
	-- this event is also a bit special.
	if wowCron.debug then print( "LOADING_SCREEN_DISABLED" ) end
	--print( wowCron.hasFirstBeenRun and "I've been run" or "I've NOT been run" )
	--print( wowCron.eventCmds["LOADING_SCREEN_DISABLED"] or "no commands for this event" )
	if not wowCron.hasFirstBeenRun then
		for _, cron in pairs(wowCron.crons) do
			local a, b = strfind( cron, "^@first" )
			if a then
				tinsert( wowCron.toRun, strsub( cron, b+2 ) )
			end
		end
		wowCron.hasFirstBeenRun = true
	end
	wowCron_Frame:UnregisterEvent( "LOADING_SCREEN_DISABLED" )
end
-- Support Code
-----------------------------------------
function wowCron.COMBAT_LOG_EVENT_UNFILTERED()
	local _, t, _, sourceID, sourceName, sourceFlags, sourceRaidFlags,
			destID, destName, destFlags, _, spellID, spName, _, ext1,
			ext2, ext3, swingCrit, _, _, spellCrit = CombatLogGetCurrentEventInfo()

	-- if playerGUID == sourceID then
	-- 	if t == "SWING_DAMAGE" or t == "SPELL_DAMAGE" then
	-- 		print( t, swingCrit, spellCrit )
	-- 	end
	-- end

	if wowCron.playerGUID == sourceID and (( t == "SWING_DAMAGE" and swingCrit ) or ( t == "SPELL_DAMAGE" and spellCrit )) then
		local eventMacro = "@crit"
		local eventCount = 0
		for _, cron in pairs( wowCron.crons ) do
			local a,b = strfind( cron, "^"..eventMacro )
			if a then
				tinsert( wowCron.toRun, strsub( cron, b+2 ) )
				eventCount = eventCount + 1
			end
		end
		if eventCount == 0 then
			wowCron_Frame:UnregisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
		end
	end
end
function wowCron.BuildEvent( event  )
	-- event: event name to register
	-- cmd  : command to do at that event
	--print( "BuildEvent( "..event.." )" )
	if( event == "ADDON_LOADED" or event == "VARIABLES_LOADED" ) then  -- don't let these be registereed.
		return
	end

	-- replace the eventCmds with a 'back parse' of wowCron.macros to find the macro to look for in the wowCron.crons table.
	-- when a event macro cron is removed, this means it will be removed fom the wowCron.crons table (which is recreated).
	-- Since there is a map of the macros to events, that can be parsed.
	-- record cmd in table

	-- create event code if it does not exist
	if not wowCron[event] then
		wowCron[event] = function( ... )
			--print( ">"..event.."<" )
			local eventMacro = ""
			for macro, struct in pairs( wowCron.macros ) do
				if struct.event and struct.event == event then
					eventMacro = macro
				end
			end
			local eventCount = 0
			for _, cron in pairs(wowCron.crons) do
				--print( "cron: "..cron )
				local a, b = strfind( cron, "^"..eventMacro )
				if a then
					tinsert( wowCron.toRun, strsub( cron, b+2 ) )
					eventCount = eventCount + 1
				end
			end
			if eventCount == 0 then
				--wowCron.Print( "There are no commands registerd for this event: ("..event..")" )
				wowCron_Frame:UnregisterEvent( event )
			end
		end
	end
	wowCron_Frame:RegisterEvent( event )
end
function wowCron.BuildRunNowList()
	for _, cron in pairs( wowCron.crons ) do
		runNow, cmd = wowCron.RunNow( cron )
		if runNow then
			--slash, parameters = wowCron.DeconstructCmd( cmd )
			if wowCron.debug then print("register to do now: "..cmd) end
			table.insert( wowCron.toRun, cmd )
		end
	end
	-- AT cmds
	local at_structs = { at_global, at_player }
	now = time()
	for _, at_struct in pairs( at_structs ) do
		-- print( _, at_struct )
		for ts, struct in pairs( at_struct ) do
			-- print( "ts:", ts, struct )
			if ts < time()-300 then -- missed by more than 5 minutes
				at_struct[ts] = nil
			elseif ts <= time() then -- give it a ~5 minute grace period
				for _, cmd in ipairs( struct ) do
					tinsert( wowCron.toRun, cmd )
				end
				at_struct[ts] = nil
			end
		end
	end
end
function wowCron.RunNowList()
	-- run a single item from the list per update
	if (#wowCron.toRun > 0) then
		cmd = table.remove( wowCron.toRun, 1 )
		if cmd then
			slash, parameters = wowCron.DeconstructCmd( cmd )
			if wowCron.debug then print("do now: "..slash.." "..parameters) end
			-- find the function to call based on the slashcommand
			isGood = false
			for _,func in ipairs(wowCron.actionsList) do
				isGood = isGood or func( slash, parameters )
			end
		end
	end
end
-- Begin Handle commands
wowCron.actionsList = {}
function wowCron.CallAddon( slash, parameters )
	-- loop through cron_knownSlashCmds (for other loaded addons)
	-- return true if could handle the slash command
	for k,v in pairs( cron_knownSlashCmds ) do
		if string.lower( slash ) == string.lower( k ) then
			--call the function
			v( parameters )
			return true
		end
	end
end
tinsert( wowCron.actionsList, wowCron.CallAddon )
function wowCron.CallEmote( slash, parameters )
	-- look for emote in cron_knownEmotes for emotes to call
	-- return true if could handle the slash command
	token = string.upper(strsub( slash, -(strlen( slash )-1) ))
	for _,v in pairs( cron_knownEmotes ) do
		if token == v then
			DoEmote(token)
			return true
		end
	end
end
tinsert( wowCron.actionsList, wowCron.CallEmote )
function wowCron.SendMessage( slash, parameters )
	slash = string.lower(slash)
	-- look for the standard chat commands and send the contents of parameters to the corrisponding channel
	for cmd, channel in pairs( wowCron.chatChannels ) do
		if slash == cmd then
			SendChatMessage( parameters, channel, nil, nil )
			return true
		end
	end
end
tinsert( wowCron.actionsList, wowCron.SendMessage )
function wowCron.RunScript( slash, parameters )
	slash = string.lower( slash )
	--print("RunScript( "..slash..", "..parameters.." )")
	if slash == "/run" or slash == "/script" then
		--print("Calling "..parameters)
		loadstring(parameters)()
		return true
	end
end
tinsert( wowCron.actionsList, wowCron.RunScript )
-- End Handle commands
function wowCron.BuildSlashCommands()
	local count = 0
	for k,v in pairs(SlashCmdList) do
		count = count + 1
		--wowCron.Print(string.format("% 2i : %s :: %s", count, k, type(v)))
		cron_knownSlashCmds[k] = v
		local lcv = 1
		while true do
			teststr = "SLASH_"..k..lcv
			local gggg = _G[ teststr ]
			if not gggg then break end
			--print("_G["..teststr.."] = "..gggg)
			cron_knownSlashCmds[gggg] = v
			if lcv >= 10 then break end
			lcv = lcv + 1
		end
	end
	--print(MAXEMOTEINDEX)
	for i = 1,1000 do
		cron_knownEmotes[i] = _G["EMOTE"..i.."_TOKEN"]
	end
end
function wowCron.RunNow( cmdIn, ts )
	-- @param cmdIn command to test
	-- @param ts optional ts to test with
	-- @return boolean run this command now (1, nil)
	-- @return string command to run (cmd, nil)

	-- do the macro expansion here, since I want to return true for @first if within the first ~60 seconds of being run.
	local macro, cmd = strmatch( cmdIn, "^(@%S+)%s+(.*)$" )
	if macro then
		if wowCron.debug then print( "MACRO: "..macro ) end
		if wowCron.macros[macro] then -- expand the macro
			if wowCron.macros[macro].cron then
				if wowCron.debug then print( "CRON: "..wowCron.macros[macro].cron ) end
				cmdIn = wowCron.macros[macro].cron.." "..cmd
			elseif wowCron.macros[macro].event then
				if wowCron.debug then print( "EVENT: "..wowCron.macros[macro].event ) end
				--print( "Register >"..cmd.."< to run for event: "..macro.." ("..wowCron.macros[macro].event..")")
				wowCron.BuildEvent( wowCron.macros[macro].event )
				return
			end
		else
			print("Invalid macro in: "..cmdIn)
			return
		end
	end

	-- put all six values into parsed table
	parsed = { wowCron.Parse( cmdIn ) }
	if #parsed == 0 then -- no values returned.  Invalid cron
		--print("No values parsed, bad cron entry '"..cmdIn.."'")
		return -- return nil (no run)
	end
	local ts = ts or time()
	local ts = date( "*t", ts )

	-- expand the string pattern to a keyed truth table
	for k,v in pairs( wowCron.fieldNames ) do -- 1 based array of field names, k = int, v = str
		parsed[k] = wowCron.Expand( parsed[k], v )
	end
	-- parsed[2] = {[5] = 1, [10] = 1}  2 equates to the 2nd value in fieldNames

	-- this is technically incorrect, will have to revisit this later.
	-- wday and day should be or if they are not wild cards.
	isMatch = true
	for i, fieldName in pairs( wowCron.fieldNames ) do
		isMatch = isMatch and wowCron.TableHasKey( parsed[i], ts[fieldName] )
		if not isMatch then break end -- exit the loop on first failure
	end

	return isMatch, parsed[6]
end
function wowCron.TableHasKey( table, key )
	-- loop over the table, return true if any of the keys equal the given key
	for k in pairs( table ) do
		if key == k then
			return true
		end
	end
end
function wowCron.Expand( value, fieldName )
	-- @parm value Value to expand
	-- @param fieldName The type of field to expand
	-- @return table of possible values as keys

	-- valid min/max values are in wowCron.ranges.type
	local minVal, maxVal = unpack(wowCron.ranges[fieldName])

	if fieldName == "month" then alias = wowCron.monthNames
	else alias = nil
	end
	if alias then
		for val,name in pairs( alias ) do
			value = string.gsub( value, name, val )
		end
	end

	-- Expand * to min-max
	value = string.gsub(value, "*", minVal.."-"..maxVal)
	-- split the values on ,
	valueList = { strsplit( ",", value ) }
	out = {}

	for _,value in ipairs(valueList) do
		svalue, step = strmatch( value, "^(%S*)/(%S*)$" )
		if step then value = svalue end
		step = step or 1

		s, e = strmatch( value, "^(%d+)-(%d+)$")
		s = s or value  -- if not a range, then set s to the value
		e = e or s  -- if not a range, then set e to the value

		for v = s, e, step do
			if v >= minVal and v <= maxVal then  -- @TODO should this toss an error of some sort, or just quietly fail?  Where should the error be registered?
				out[fieldName == "wday" and v+1 or v] = 1 -- add one for the wday conversion
			end
		end
	end
	return out
end
function wowCron.ParseAll()
	-- Only when starting, or changing
	-- Player specific crons should happen last.
	wowCron.crons = {}
	-- global crons
	for _, cmd in ipairs(cron_global) do
		tinsert( wowCron.crons, cmd )
	end
	-- player specific crons
	for _, cmd in ipairs(cron_player) do
		tinsert( wowCron.crons, cmd )
	end
end
function wowCron.Parse( cron )
	-- takes the cron string and returns the 5 cron patterns, and the command
	-- returns nil if this encounters a bad pattern

	-- parse the 6, space delimited values.
	local min, hour, day, month, wday, cmd =
			strmatch( cron,	"^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.*)$" )
	return min, hour, day, month, wday, cmd
end
function wowCron.DeconstructCmd( cmdIn )
	local a,b,c = strfind( cmdIn, "(%S+)" )
	if a then
		return c, (strmatch( strsub( cmdIn, b+2 ), "^%s*(%S.*)" ) or "")  -- strip leading spaces (nil if nothing, return empty string then)
	else
		return ""
	end
end
function wowCron.PrintHelp()
	wowCron.Print("Creates a crontab for WoW.")
	wowCron.Print("Used standard Cron format (min hour day month wday cmd).")
	wowCron.Print("cmd can be any currently installed addon slash command, an emote, or '/run <lua code>'.")
	for cmd, info in pairs(wowCron.CommandList) do
		wowCron.Print(string.format("%s %s %s -> %s",
				SLASH_CRON1, cmd, info.help[1], info.help[2]))
	end
end
function wowCron.List()
	cronTable = wowCron.global and cron_global or cron_player
	wowCron.Print( "Listing cron entries for "..( wowCron.global and "global" or "personal" ) )
	for i,entry in ipairs(cronTable) do
		wowCron.Print( string.format("[% 3i] %s", i, entry) )
	end
end
function wowCron.RemoveEntry( index )
	cronTable = wowCron.global and cron_global or cron_player
	index = tonumber(index)
	if index and index>0 and index<=#cronTable then
		local entry = table.remove( cronTable, index )
		wowCron.Print( COLOR_RED.."REMOVING: "..COLOR_END..entry )
		wowCron.ParseAll()
	end
end
function wowCron.AddEntry( entry )
	if strlen( entry ) >= 9 then -- VERY mimimum size of a cron is 9 char (5x * and 4 spaces)
		cronTable = wowCron.global and cron_global or cron_player
		table.insert( cronTable, entry )
		wowCron.RunNow( entry )
		wowCron.Print( string.format("Added to %s: %s", (wowCron.global and "global" or "personal"), entry ) )
	else
		wowCron.PrintHelp()
	end
	wowCron.ParseAll()
end
function wowCron.MoveEntry( strIn )
	if strlen( strIn ) >= 3 then
		cronTable = wowCron.global and cron_global or cron_player
		local _, _, srcIndex, tarIndex = strfind( strIn, "(%d+)%s(%d+)" )
		srcIndex = tonumber( srcIndex )
		tarIndex = tonumber( tarIndex )
		if srcIndex and tarIndex then
			tarIndex = math.min( tarIndex, #cronTable )
			if tarIndex <= 0 then tarIndex = 1; end
			if (#cronTable >= srcIndex) then
				mvCmd = table.remove( cronTable, srcIndex )
				wowCron.Print( "Moving "..mvCmd.." from index: "..srcIndex.." to index: "..tarIndex )
				table.insert( cronTable, tarIndex, mvCmd )
			end
			wowCron.List()
		else
			wowCron.Print( "From and to index need to be given and be numberic." )
		end
	else
		wowCron.Print( "Usage: mv fromIndex toIndex" )
	end

end
function wowCron.ListMacros()
	wowCron.Print( "Available macros:" )
	for macro, struct in pairs( wowCron.macros ) do
		wowCron.Print( string.format( "%s : %s \"%s\"",
				macro, (struct.cron and "expands to" or "run on event"), (struct.cron or struct.event) ) )
	end
end
wowCron.CommandList = {
	["help"] = {
		["func"] = wowCron.PrintHelp,
		["help"] = {"","Print this help."},
	},
	["global"] = {
		["func"] = function( msg ) wowCron.Command( msg, true ); end,
		["help"] = {"<commands>", "Sets global flag"},
	},
	["list"] = {
		["func"] = wowCron.List,
		["help"] = {"", "List cron entries."}
	},
	["rm"] = {
		["func"] = wowCron.RemoveEntry,
		["help"] = {"index", "Remove index entry."}
	},
	["mv"] = {
		["func"] = wowCron.MoveEntry,
		["help"] = {"fromIndex toIndex", "Move from to"}
	},
	["add"] = {
		["func"] = wowCron.AddEntry,
		["help"] = {"<entry>", "Adds an entry. Default action."}
	},
	["macros"] = {
		["func"] = wowCron.ListMacros,
		["help"] = {"", "List the macros."}
	},
}
function wowCron.Command( msg, isGlobal )
	wowCron.global = isGlobal
	cmd, parameters = wowCron.DeconstructCmd( msg )
	cmd = string.lower(cmd)
	local cmdFunc = wowCron.CommandList[cmd]
	if cmdFunc then
		cmdFunc.func( parameters )
	else
		wowCron.AddEntry( msg )
	end
end
function wowCron.Print( msg, showName)
	-- print to the chat frame
	-- set showName to false to suppress the addon name printing
	if (showName == nil) or (showName) then
		msg = COLOR_GOLD..WOWCRON_MSG_ADDONNAME..COLOR_END.."> "..msg
	end
	DEFAULT_CHAT_FRAME:AddMessage( msg )
end
function wowCron.spairs( t )
	local keys={}
	for k in pairs(t) do keys[#keys+1] = k end
	table.sort( keys )
	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end
function wowCron.AtList()
	atTable = wowCron.global and at_global or at_player
	wowCron.Print( "listing at entries for "..( wowCron.global and "global" or "personal" ) )
	for ts, struct in wowCron.spairs( atTable ) do
		for _, cmd in ipairs( struct ) do
			print( date( "%c", ts)..": "..cmd )
		end
	end
end
wowCron.AtCommandList = {
	["help"] = {
		["func"] = wowCron.PrintHelp,
		["help"] = { "", "Print this help." },
	},
	["global"] = {
		["func"] = function( msg ) wowCron.AtCommand( msg, true ); end,
		["help"] = { "<commands>", "Sets global flag" },
	},
	["list"] = {
		["func"] = wowCron.AtList,
		["help"] = { "", "List" },
	},
}
function wowCron.AtCommand( msg, isGlobal )
	wowCron.global = isGlobal
	cmd, parameters = wowCron.DeconstructCmd( msg )
	--print( cmd, parameters )
	cmd = string.lower( cmd )
	local cmdFunc = wowCron.AtCommandList[cmd]
	if cmdFunc then
		cmdFunc.func( parameters )
	else
		wowCron.AtAddEntry( msg )
	end
end
function wowCron.AtAddEntry( msg )
	if string.len(msg) == 0 then return; end
	msg = string.lower( msg )
	-- print( "AtAddEntry( "..msg.." )" )

	local shortcuts = { ["noon"] = "12:00:00", ["midnight"] = "00:00:00", ["teatime"] = "16:00:00" }
	local targetTime = date( "*t", time() )
	shortcuts.now = date( "%H:%M", time(targetTime) )
	shortcuts.tomorrow = date( "%m%d%Y", time()+86400 )

	local targetTime = date( "*t" )
	targetTime.sec = 0

	local plusUnits = { ["minutes"] = 60, ["hours"] = 3600, ["days"] = 86400, ["weeks"] = 604800}
	local plusValue = 0

	msgItem, msg = strsplit( " ", msg, 2 )

	while( msgItem ) do -- only parse as part of the time string.  A command starts with a "/"
		local parsed = false
		-- find and replace 'shortcut' string
		msgItem = shortcuts[msgItem] or msgItem

		-- print( "parsing: -->"..msgItem.."<-- with :"..(msg or "nil")..": left over" )
		-- find a date.  Do this first because the time string is 'funky'
		_, _, month, split, day, year = strfind( msgItem, "([%d]?%d)([/.-])([%d%d]+)[/]?([%d%d]*)" )
		if not split and (string.len( msgItem ) == 6 or string.len( msgItem ) == 8) then
			--print( "found a 6 or 8 digit date" )
			a, _, month, day, year = strfind( msgItem, "(%d%d)(%d%d)(%d[%d]+)" )
			if a then
				split = "/"
			end
		end
		-- date of the form MMDD[CC]YY, MM/DD/[CC]YY, DD.MM.[CC]YY or [CC]YY-MM-DD.
		if( split == "." ) then
			d = day
			day = month
			month = d
		end
		if( split == "-" ) then
			y = year
			year = month
			month = day
			day = y
		end

		-- print( "unswapped: "..( month or "nil").."/"..(day or "nil").."/"..(year or "nil").." split:"..( split or "nil" ) )
		if( split ) then  -- split is / . or - (making this a date)
			targetTime.month = month
			targetTime.day = day
			year = tonumber( year ) or targetTime.year
			if( tonumber( year ) < 100 ) then
				century = math.floor( targetTime.year / 100 ) * 100
				year = century + year
			end
			targetTime.year = year
			parsed = true
		end

		-- print( "After date parse: "..date( "%x %X", time( targetTime ) ) )

		if not parsed then

			-- find a time string
			-- if( tonumber( msgItem ) and tonumber( msgItem ) < 1000 ) then -- if the item is a number less than 1000, add a "0" to the start.
			-- 	msgItem = "0"..msgItem
			-- end
			a, b, hourIn, minIn = strfind( msgItem, "([%d]?%d)[:]*([%d%d]+)" )
			-- print( "msgItem (time): "..msgItem.." > "..( hourIn or "nil")..":"..( minIn or "nil" ) )
			if( hourIn ) then
				targetTime.hour = tonumber( hourIn )
			end
			if( minIn ) then
				targetTime.min = tonumber( minIn )
			end
			-- if( secIn ) then
			-- 	targetTime.sec = tonumber( secIn ) or 0
			-- end
		end

		-- find AM/PM and modify the time
		_, _, AMPM = strfind( msgItem, "([ap]m)" )
		if( AMPM and targetTime.hour <= 12 and AMPM == "pm" ) then
			targetTime.hour = targetTime.hour + 12
		end

		a, b, plusCount = strfind( msgItem, "+([%d]*)" )
		if a then
			if b == 1 then
				msgItem, msg = strsplit( " ", msg, 2 )
				plusCount = tonumber(msgItem)
			end
			-- print( "found a + ", a, b, plusCount )
			if plusCount then
				plusUnit, msg = strsplit( " ", msg, 2 )
				if plusUnits[plusUnit] then
					plusValue = plusCount * plusUnits[plusUnit]
				end
			end
		end

		if( strfind( msgItem, "^/[%a]+" ) ) then
			msg = msgItem..( msg and " "..msg or "")
			msgItem = nil
		elseif msg then
			msgItem, msg = strsplit( " ", msg, 2 )
		else msgItem = nil
		end
		-- print( date( "-->%x %X", time( targetTime ) ) )
	end
	--print( "Final -->"..(msg or "nil").."<--" )

	targetTS = time( targetTime ) + plusValue
	if( targetTS < time()-60) then
		targetTS = targetTS + 86400
		--print( date( "-->%x %X", targetTS ) )
	end

	if msg then
		print( date( "@ %x %X do: ", targetTS )..msg )
		atTable = wowCron.global and at_global or at_player
		atTable[targetTS] = atTable[targetTS] or {}
		table.insert( atTable[targetTS], msg )
		--print( "now: "..time().." target: "..targetTS )
	else
		print( "Error detected with AT command.")
	end
end

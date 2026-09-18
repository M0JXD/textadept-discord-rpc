-- Copyright 2025-2026 Jamie Drinkell. See LICENSE.

--- Discord Rich Presence for Textadept.
-- ![screenshot](assets/screenshot.png)
--
-- Install this module by copying it into your *~/.textadept/modules/* directory or Textadept's
-- *modules/* directory, and then putting the following in your *~/.textadept/init.lua*:
--
-- ```lua
-- require('discord_rpc')()
-- ```
--
-- There will be a "Help > Discord RPC" menu. On startup Textadept will try to connect to Discord.
-- Your Discord status will show information for the current buffer you are working on.
-- You can set how detailed this information is with `discord_rpc.private`.
-- A buffer statusbar section will show an emoji representing connection status, but can be
-- disabled with `discord_rpc.show_connected`.
-- If you don't want to connect automatically at startup, require the module without calling it,
-- and connect using the menu option.
--
-- #### Notes
--
-- - Your Discord client needs to be running before Textadept is started.
-- - Resetting Textadept frequently and rapidly can cause connection failures.
--
-- ## About
--
-- RPC is achieved via @harmonytf's fork of Discord's unmaintained RPC libary.
--
-- Whilst the now recommend way to implement RPC is to use the
-- [Discord Social SDK](https://discord.com/developers/docs/discord-social-sdk/overview),
-- to even download it requires stating details about your
-- "Company Name, Team Location, Role" etc. that simply don't apply for open source hobby projects.
-- Please petition Discord to provide
-- [a better solution](https://github.com/discord/discord-rpc/issues/382#issuecomment-3620635979)
-- for open source applications to integrate with RPC.
--
-- ## Building
--
-- The library is built with [Xmake](https://xmake.io/).
-- Before anything, after cloning this repo ensure the submodules are fetched:
--
-- `git submodule update --init --recursive`
--
-- You can then issue the build with `xmake`.
-- Xmake will ask you about building the DiscordRPC library first, which you will need to confirm.
-- `xmake i` will install the module you built into *~/.textadept/modules/discord_rpc*.
--
-- ## Assets
--
-- Assets and their keys are tied to the Discord "app" that can be updated with a developer account.
-- On the app page, assets are set to the same name as Textadept's lexers. Icons are from the
-- VSCord project, and checked into the repo for completion's sake. A local copy is not required.
--
-- I have made a Discord Developer Team for this project. If you would like to be added please open
-- an issue or contact me (m0jxd) via Discord with the required details.
--
-- ## Thanks
--
-- - The icons are from the VSCord project.
-- - @orbitalquark for Textadept.
-- - @harmonytf for the Discord RPC library fork.
--
-- @module discord_rpc
local M = {}

---  Display 'DRPC' status in buffer_statusbar.
-- The default value is `true`.
M.show_connected = true
--- Whether to use a privacy mode that only states file types instead of their actual names.
-- The default value is `true`.
M.private = true
--- Maximum allowed attempts to connect to Discord.
-- The default value is `20`.
M.attempts = 20

local attempts = 0 -- Current attempt number
local last_action = 'confused at ' -- Last build/run/test action
local is_connected = false -- Are we connected to Discord?
local handlers = false -- Are handlers connected?
local old_lexer = 'Untitled' -- To track what the output buffer (probably) reflects
local mt = {}

--- The base Discord RPC library object.
-- @field rpc

local lib = 'discord_rpc.discordrpc'
if OS == 'macos' then
	lib = lib .. 'osx'
elseif OS == 'linux' and io.popen('uname -m'):read() == 'aarch64' then
	lib = lib .. 'arm'
end
M.rpc = require(lib)

--- Edge case lists for lexer names that can't be capitalised or should be described with 'an'.
-- @table edge_names
-- @field names Array of lexer names that are not suitable for first letter capitalisation.
-- @field an Array of lexers that should use 'an' instead of 'a' to refer to the file.
M.edge_names = require('discord_rpc.edge_names')

--- Status fields received from RPC.
M.stats = {
	username, -- Username of connected RPC user.
	globalName, -- Global Name of connected RPC user.
	userId, -- ID of connected RPC user.
	discriminator, -- Discord's discriminator for the RPC connection.
	lastCallback, -- Last callback called by underlying library.
	errcode, -- Last error code that occured.
	errorDetails -- Details for last error code.
}

--- Status fields sent to RPC.
M.presence = {
	send_presence = true, -- Whether to send presence to Discord.
	state = '', -- Phrase for current user action.
	details = '', -- Further details on current user action.
	startTimestamp = os.time(), -- Start time for this activity.
	endTimestamp = 0, -- End time for this activity.
	smallImageKey = 'textadept', -- Key name for the small image.
	smallImageText = 'Textadept ' ..
		(UI == 'qt' and '(Qt)' or UI == 'gtk' and '(GTK)' or '(Terminal)'), -- Hover text for the small image.
	largeImageKey = '', -- Key name for the large image.
	largeImageText = '' -- Hover text for the large image.
}
-- TODO: Add Party/Match/Secret and Buttons options?

--- Insert entries into the buffer statusbar
-- @local
function string.bst_insert(str, ...)
	local text, pos, value
	local spacing = UI == 'terminal' and '  ' or '    '
	local _, count = str:gsub(spacing, spacing)
	count = count + 1

	local arg = table.pack(...)
	if arg.n == 1 then
		pos = count + 1
		value = arg[1]
	elseif arg.n == 2 then
		pos = arg[1]
		value = arg[2]
	end

	if pos <= 1 then
		text = value .. spacing .. str
	elseif pos >= (count + 1) then
		text = str .. spacing .. value
	else
		local c = 0
		text, count = str:gsub(spacing, function(match)
			c = c + 1
			if c == pos - 1 then return match .. value .. match end
			return match
		end)
	end
	return text
end

--- UPDATE_UI callback to show discord status in the buffer statusbar.
local function discord_status(updated)
	if not updated or updated & 3 == 0 then return end
	ui.buffer_statusbar_text = ui.buffer_statusbar_text:bst_insert('DRPC: ' ..
		(is_connected and '☺' or '☹'))
end

--- Attach handlers used in RPC.
local function attach_handlers()
	events.connect(events.QUIT, M.close)
	events.connect(events.RESET_BEFORE, M.close)
	events.connect(events.SAVE_POINT_REACHED, M.update)
	events.connect(events.SAVE_POINT_LEFT, M.update)
	events.connect(events.BUFFER_AFTER_SWITCH, M.update)
	events.connect(events.VIEW_AFTER_SWITCH, M.update)
	events.connect(events.LEXER_LOADED, M.update)
	events.connect(events.BUFFER_NEW, M.update)
	if M.show_connected then events.connect(events.UPDATE_UI, discord_status) end
	handlers = true
end

--- Remove handlers used in RPC.
local function remove_handlers()
	events.disconnect(events.QUIT, M.close)
	events.disconnect(events.RESET_BEFORE, M.close)
	events.disconnect(events.SAVE_POINT_REACHED, M.update)
	events.disconnect(events.SAVE_POINT_LEFT, M.update)
	events.disconnect(events.BUFFER_AFTER_SWITCH, M.update)
	events.disconnect(events.VIEW_AFTER_SWITCH, M.update)
	events.disconnect(events.LEXER_LOADED, M.update)
	events.disconnect(events.BUFFER_NEW, M.update)
	if M.show_connected then events.disconnect(events.UPDATE_UI, discord_status) end
	handlers = false
end

--- Update details in presence table with Textadept's current status.
local function update_presence_details()
	local task = buffer.modify and 'editing ' or 'viewing '
	local display_name
	local lexer_name

	if buffer:get_lexer() == 'output' then
		lexer_name = old_lexer
		task = last_action
	else
		lexer_name = buffer:get_lexer()
		old_lexer = lexer_name
	end

	if M.edge_names.names[lexer_name] then
		display_name = M.edge_names.names[lexer_name]
	else -- Capitalise it
		display_name = lexer_name:sub(1, 1):upper() .. lexer_name:sub(2)
	end

	local filestate = ' file.'
	if M.private then
		filestate = (M.edge_names.an[lexer_name] and 'an ' or 'a ') .. display_name ..
			(display_name:find('file') and '.' or filestate)
	else
		if buffer.filename then
			local their = ''
			if buffer.filename:match('.textadept/init.lua') or
				buffer.filename:match('.textadept\\init.lua') then
				their = 'their Textadept ' -- Call em out
			end
			filestate = their .. buffer.filename:match('[^/\\]+$')
		end
	end

	if task == 'building ' or task == 'testing ' then filestate = 'a project.' end
	M.presence.state = 'Currently ' .. task .. filestate

	-- IDEAS: Time since most recent commit? Git branch name?
	M.presence.details = ''
	if io.get_project_root() and not M.private then
		M.presence.details = 'Project directory: ' .. (io.get_project_root():match('[^/\\]+$'))
	end

	-- TODO: Amount of issues (LSP or from compile/run)
	if issues then
		M.presence.details = ((M.presence.details == '') and 'Issues: ' or
			(M.presence.details .. ' - Issues: ')) .. errors
	end

	M.presence.largeImageKey = buffer:get_lexer()
	M.presence.largeImageText = 'Working on ' .. (M.edge_names.an[lexer_name] and 'an ' or 'a ') ..
		display_name .. (display_name:find('file') and '.' or ' file.')
end

--- Updates presence details, sends them over RPC, receives RPC status and updates UI accordingly.
function M.update()
	update_presence_details()
	M.stats = M.rpc.update(M.presence)

	if M.stats.lastCallback == 0 then
		-- Discord hasn't run any handlers yet, try sending another update
		is_connected = false
		ui.statusbar_text = 'Attempting to connect to Discord...'
		if attempts ~= M.attempts then
			attempts = attempts + 1
			timeout(0.4, function() M.update() end)
		else
			ui.statusbar_text = 'Could not connect to Discord.'
			M.close() -- Just in case it's some weird connection issue
		end
	elseif M.stats.lastCallback == 1 then
		if is_connected == false then
			ui.statusbar_text = 'Discord: Connected to ' .. M.stats.globalName .. '.'
			is_connected = true
		end
	elseif M.stats.lastCallback == 2 then
		ui.statusbar_text = 'Discord Disconnect: ' .. M.stats.errcode .. M.stats.errorDetails
		is_connected = false
		-- M.close()
	elseif M.stats.lastCallback == 3 then
		ui.statusbar_text = 'Discord Error: ' .. M.stats.errcode .. M.stats.errorDetails
		is_connected = false
		-- M.close()
	end
end

--- Closes down RPC connection and removes handlers.
function M.close()
	is_connected = false
	if handlers then remove_handlers() end
	M.rpc.close()
end

--- Connects to RPC and attaches handlers.
-- Do not call from init.lua. Call the module instead to connect automatically at startup.
function M.connect()
	M.rpc.close()
	M.presence.startTimestamp = os.time()
	if not handlers then attach_handlers() end
	attempts = 0
	timeout(0.4, function()
		M.rpc.init()
		M.update()
	end)
end

--- Allow user to 'start' RPC in their init.lua
-- @lfunction mt.__call
mt.__call = function()
	events.connect(events.INITIALIZED, M.connect)
end
setmetatable(M, mt)

-- These are low overhead, always connect.
events.connect(events.BUILD_OUTPUT, function() last_action = 'building ' end)
events.connect(events.COMPILE_OUTPUT, function() last_action = 'compiling ' end)
events.connect(events.RUN_OUTPUT, function() last_action = 'running ' end)
events.connect(events.TEST_OUTPUT, function() last_action = 'testing ' end)

-- Menu entry.
_L['Discord RPC'] = '_Discord RPC'
_L['Connect/Reconnect'] = '_Connect/Reconnect'
_L['Disconnect'] = '_Disconnect'
_L['Status'] = '_Status'
local discord_menu = {
	title = _L['Discord RPC'], {_L['Connect/Reconnect'], M.connect}, {_L['Disconnect'], M.close}, {
		_L['Status'], function()
			ui.dialogs.message{
				title = 'Discord RPC Status', text =
				-- LuaFormatter off
				'Username: ' .. M.stats.username .. '\n' ..
				'Global Name: ' .. M.stats.globalName .. '\n' ..
				'User ID: ' .. M.stats.userId .. '\n' ..
				'Discriminator: ' .. M.stats.discriminator .. '\n' ..
				'Last Callback: ' .. M.stats.lastCallback .. '\n' ..
				'Error Code: ' .. M.stats.errcode .. '\n' ..
				'Error Message: ' .. M.stats.errorDetails .. '\n' ..
				'Connected: ' .. (is_connected and 'Yes' or 'No')
				-- LuaFormatter on
			}
		end
	}
}
local help = textadept.menu.menubar['Help']
table.insert(help, #help - 1, {''})
table.insert(help, #help - 1, discord_menu)

return M

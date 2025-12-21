-- Copyright 2025 Jamie Drinkell. See LICENSE.
-- Textadept Discord Rich Presence

M = {}
M.show_connected = true  -- Update the statusbar
M.private_mode = false  -- Be more vague with details, e.g. no file or folder names
local max_tries = 10  -- Maximum tries at startup to to connect - TODO: Let's not change this variable
local is_connected = false  -- To track whether we're connected

local lib = 'discord_rpc.discordrpc'
if OSX then
	lib = lib .. 'osx'
elseif LINUX and io.popen('uname -m'):read() == 'aarch64' then
	lib = lib .. 'arm'  -- TODO: Can Discord/ARMCord even support this?
end
M.rpc = require(lib)

M.stats = {}

M.presence = {
	send_presence = true,
	state = '',
	details = '',
	startTimestamp = os.time(),
	endTimestamp = 0,
	smallImageKey = 'textadept',
	smallImageText = 'Textadept ' .. (QT and '(Qt)' or GTK and '(GTK)' or '(curses)'),
	largeImageKey = '',
	largeImageText = ''
	-- TODO: Add Party/Match/Secret and Buttons options?
}

local function attach_handlers()
	events.connect(events.QUIT, function ()
		M.rpc.close()
		return nil
	end, 1)
	events.connect(events.RESET_BEFORE, function ()
		M.rpc.close() ; is_connected = false
	end)
	events.connect(events.UPDATE_UI, M.update)
end

local function remove_handlers()
	events.disconnect(events.UPDATE_UI, M.update)
	events.disconnect(events.RESET_BEFORE, function ()
		M.rpc.close() ; is_connected = false
	end)
	events.disconnect(events.QUIT, function ()
		M.rpc.close()
		return nil
	end, 1)  -- TODO: Is this right?
end

local function update_presence_details()
	-- TODO: Handle edge cases like CMake etc.
	local capitalised_type = buffer:get_lexer():sub(1,1):upper()..buffer:get_lexer():sub(2)

	-- State
	-- TODO: Details like running, editing, debugging etc.
	local task = buffer.modify and 'editing ' or 'viewing '

	local filestate = 'Untitled'
	if (M.private_mode) then
		filestate = 'a ' .. capitalised_type .. ' file.'
	else
		if (buffer.filename) then
			local their = ''
			if (buffer.filename:match('.textadept/init.lua')
				or buffer.filename:match('.textadept\\init.lua')) then
				their = 'their Textadept ' -- Call em out
			end
			filestate = their .. buffer.filename:match('[^/\\]+$')
		end
	end
	M.presence.state = 'Currently ' .. task .. filestate

	-- Details
	-- IDEAS: Time since most recent commit? Git branch name?
	if (io.get_project_root() and (not M.private_mode)) then
		local project_name = io.get_project_root():match('[^/\\]+$')
		M.presence.details = 'Project directory: ' .. project_name
	else
		M.presence.details = ''
	end

	-- TODO: Amount of issues (LSP or from compile/run)
	--local issues = 1
	if (issues) then
		M.presence.details = ((M.presence.details == '') and 'Issues: '
			or (M.presence.details .. ' - Issues: ')) .. errors
	end

	M.presence.largeImageKey = buffer:get_lexer()
	M.presence.largeImageText = 'Working on a ' .. capitalised_type ..
		(capitalised_type:find('file') and '.' or ' file.')

end

-- Convenience wrapper that will get current details before calling rpc.update() and update UI
function M.update()
	update_presence_details()
	M.stats = M.rpc.update(M.presence)

	-- Show the details - TODO: Seperate handling/reconnect behaviour from display code
	if (M.show_connected) then
		local spacing = CURSES and '  ' or '    '
		if (M.stats.lastCallback == 0) then
			-- Discord hasn't run any handlers yet, try sending another update
			is_connected = false
			if (max_tries ~= 0) then
				max_tries = max_tries - 1
				timeout(0.2, function ()
					ui.statusbar_text = 'Attempting to connect to Discord...'
					M.update()
				end)
			else
				ui.statusbar_text = 'Could not connect to Discord.'
				M.rpc.close()  -- Just in case it's some weird connection issue
			end
		elseif (M.stats.lastCallback == 1) then
			if (is_connected == false) then
				ui.statusbar_text = 'Discord: Connected to ' .. M.stats.username .. '.'
				is_connected = true ; attach_handlers()
			end
		elseif (M.stats.lastCallback == 2) then
			ui.statusbar_text = 'Discord Disconnect: ' .. M.stats.errcode .. M.stats.errorDetails
			is_connected = false ; remove_handlers()
			M.rpc.close()
		elseif (M.stats.lastCallback == 3) then
			ui.statusbar_text = 'Discord Error: ' .. M.stats.errcode .. M.stats.errorDetails
			is_connected = false ; remove_handlers()
			M.rpc.close()
		end

		if (ui.buffer_statusbar_text:match('DRPC') == nil) then
			ui.buffer_statusbar_text = ui.buffer_statusbar_text .. spacing .. 'DRPC: '.. (is_connected and '☺' or '☹')
		else
			local without_status = string.sub(ui.buffer_statusbar_text, 1, -4)
			ui.buffer_statusbar_text = without_status .. (is_connected and '☺' or '☹')
		end
	end
end


-- Convenience to allow user to 'start' RPC in their init.lua
-- Actually starts RPC once Textadept is fully initialised (so buffer/lexer names etc. will be present)
function M.init()
	events.connect(events.INITIALIZED, function ()
		M.rpc.init()
		M.update()
	end)
end

-- Manually connect to Discord - not suitable for calling from init.lua
-- NOTE: The Discord RPC library has it's own retry mechanism that might mean this won't run for a while
function M.connect()
	max_tries = 10
	if (is_connected) then
		M.rpc.close() ; is_connected = false
		remove_handlers()
	end

	timeout(0.2, function ()
		M.rpc.init()
		M.update()
	end)
end

-- TODO: Add a reconnect option under help menu

return M

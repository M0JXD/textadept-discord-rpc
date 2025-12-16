-- Copyright 2025 Jamie Drinkell. See LICENSE.
-- Textadept Discord Rich Presence

M = {}
M.show_connected = true  -- Update the statusbar

local lib = 'discord_rpc.discordrpc'
if OSX then
	lib = lib .. 'osx'
elseif LINUX and io.popen('uname -m'):read() == 'aarch64' then
	lib = lib .. 'arm'  -- TODO: Can discord even support this?
end
M.rpc = require(lib)

local displayed_connected = false

M.stats = {
	userdetails = '',
	disconnectedDetails = '',
	errorDetails = ''
}

M.presence = {
	send_presence = true,
	private = false,
	version = QT and 'Qt' or GTK and 'GTK' or CURSES and 'curses',
	idle = false,
	modified = false,
	runner = 'N',
	filename = 'Untitled', -- buffer.filename:match('[^/\\]+$'),
	lexer = 'text', -- buffer:get_lexer(),
	project_name = 'NA',
	errors = 0
}

-- Convenience wrapper that will get current details before calling rpc.update() and update UI
function M.update()
	M.presence.lexer = buffer:get_lexer()
	if (buffer.filename) then
		M.presence.filename = buffer.filename:match('[^/\\]+$')
	end

	if (io.get_project_root()) then
		M.presence.project_name = io.get_project_root():match('[^/\\]+$')
	else
		M.presence.project_name = 'NA'
	end

	M.stats.userdetails, M.stats.disconnectedDetails, M.stats.errorDetails = M.rpc.update(M.presence)

	if M.stats.disconnectedDetails ~= '' then
		ui.statusbar_text = M.stats.disconnectedDetails
		M.stats.userdetails = ''
	elseif M.stats.errorDetails ~= '' then
		ui.statusbar_text = M.stats.errorDetails
		M.stats.userdetails = ''
	end

	if (M.show_connected) then
		local spacing = CURSES and '  ' or '    '
		local status = M.stats.userdetails ~= '' and '☺' or '☹'
		if (ui.buffer_statusbar_text:match('DRPC') == nil) then
			ui.buffer_statusbar_text = ui.buffer_statusbar_text .. spacing .. 'DRPC: '.. status
		end
	end
end

-- Convenience to allow user to 'start' RPC in their init.lua, but actually start RPC once Textadept is fully initialised
function M.init()
	events.connect(events.INITIALIZED, function ()
		M.rpc.init()
		--M.update()
	end)

	-- Attach close handlers to shutdown Discord RPC cleanly
	events.connect(events.QUIT, function ()
		M.rpc.close()
		return nil
	end, 1)

	events.connect(events.RESET_BEFORE, function ()
		M.rpc.close()
	end)
end

-- Connect update to the right events
--events.connect(events.BUFFER_NEW, M.update)
--events.connect(events.BUFFER_AFTER_SWITCH, M.update)
events.connect(events.UPDATE_UI, function (updated)
	M.update()
	-- Discord is a little slow to respond with it's connected status,
	-- and without a good way of it emitting a Textadept event in the handler
	-- This is the best idea I have :(
	if (M.stats.userdetails ~= '' and (displayed_connected == false)) then
		ui.statusbar_text = M.stats.userdetails
		displayed_connected = true
	end
end)

return M

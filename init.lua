-- Copyright 2025 Jamie Drinkell. See LICENSE.
-- Textadept Discord Rich Presence

M = {}
M.privacy_mode = false
M.show_connected = true
M.send_presence = true  -- This can be disabled at any time

local lib = 'discord_rpc.discordrpc'
if OSX then
	lib = lib .. 'osx'
elseif LINUX and io.popen('uname -m'):read() == 'aarch64' then
	lib = lib .. 'arm'
end
M.discord_rpc = require(lib)

--local DiscordStats = {
--	username = nil,
--	globalName = nil,
--	discriminator = nil,
--	userId = nil
--}

-- Callback passed to init function
local function discord_callback(event, params)
	if event == 'error' then
		ui.statusbar_text = params
	elseif event == 'ready' then


	elseif event == 'disconnect' then
		ui.statusbar_text = params
	else
		-- This should never happen. So if it does it can't be good.
		-- Let's disconnect and wave goodbye to the sinking ship!
		discord_rpc.close()
	end
end

-- Convienience to allow user to 'start' RPC init.lua but actually start RPC once Textadept is fully initialised
-- IF YOU MANUALLY CLOSE DISCORD EARLY THINGS CAN GO WRONG!
function M.init()
	events.connect(events.INITIALIZED, function ()
		M.discord_rpc.init()
		M.discord_rpc.update()
	end)

	-- Attach a close handler
	events.connect(events.QUIT, function ()
		M.discord_rpc.close()
		return nil
	end, 1)
end


-- Get the current language being edited whenever a buffer is switched.
events.connect(events.BUFFER_AFTER_SWITCH, function ()
	--buffer:get_lexer()
	--discord_rpc.update()
end)

-- Show discord status in statusbar
--events.connect(events.UPDATE_UI, function ()
--	oldbuffstatbar = ui.buffer_statusbar_text
--	local spacing = CURSES and '  ' or '    '
--	status = username and '✅' or '❌'
--	ui.buffer_statusbar_text = ui.buffer_statusbar_text .. spacing .. 'DRPC'..spacing..status
--end)

-- Shutdown Discord RPC cleanly


return M

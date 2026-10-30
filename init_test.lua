-- Copyright 2025-2026 Jamie Drinkell. See LICENSE.

local discord_rpc = require('discord_rpc')

local discord_running = OS == 'windows' and
	os.execute('Get-Process -Name "Discord"') or os.execute('pgrep -xi "Discord" > /dev/null')

-- Run the tests in order so we connect once, do anything that requires connection while there, then disconnect.
test('discord_rpc.connect should connect to a running Discord instance', function()

	discord_rpc.connect()

	test.assert(discord_rpc.connected, 'Did not connect to Discord')
end)
if not discord_running then skip('Discord is not running') end

test('Discord connection status should not be shown in buffer statusbar if discord_rpc.show_connected is disabled', function()
	local _<close> = test.mock(discord_rpc, 'show_connected', false)

	if not discord_rpc.connected then discord_rpc.connect() end
	events.emit(events.UPDATE_UI, 3) -- Can't use plain ui.update() as does not force the buffer_statusbar to update usually.

	test.assert(not ui.buffer_statusbar_text:find('DRPC'), 'Connected status was shown in buffer statusbar')
end)
if not discord_running then skip('Discord is not running') end

test('discord_rpc.close should disconnect from a running Discord instance', function()

	if discord_rpc.connected then discord_rpc.close() end

	test.assert(discord_rpc.connected == false, 'Did not disconnect from Discord')
end)
if not discord_running then skip('Discord is not running') end

test('discord_rpc.update should update RPC presence fields', function()
	local _<close> = test.mock(discord_rpc, 'private', true)
	buffer:set_lexer('lua')

	discord_rpc.update()

	test.assert_contains(discord_rpc.presence.largeImageKey, 'lua')

	-- Change the lexer
	buffer:set_lexer('cpp')

	discord_rpc.update()

	test.assert_contains(discord_rpc.presence.largeImageKey, 'cpp')
end)

test('discord_rpc.update should not set exact details if discord_rpc.private is enabled', function()
	local _<close> = test.mock(discord_rpc, 'private', true)
	local f<close> = test.tmpfile('', 'file_content', true)

	discord_rpc.update()

	test.assert(not discord_rpc.presence.state:find(f.filename:match('[^/\\]+$')), 'Filename was sent to Discord')
end)

test('discord_rpc.update should update RPC fields respecting discord_rpc.edge_names', function()
	local _<close> = test.mock(discord_rpc.edge_names.names, 'lua', 'test')
	buffer:set_lexer('lua')

	discord_rpc.update()

	test.assert_contains(discord_rpc.presence.largeImageText, 'test')
end)

test('discord_rpc.update should set latest compile/build/edit action', function()
	buffer:set_lexer('output') -- Build status aspects are only shown when current buffer is output
	events.emit(events.TEST_OUTPUT, 'Test Mock')

	discord_rpc.update()

	test.assert_contains(discord_rpc.presence.state, 'testing')
end)

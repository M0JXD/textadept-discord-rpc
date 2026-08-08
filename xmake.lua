-- Copyright 2025-2026 Jamie Drinkell. See LICENSE.
-- Textadept Discord Rich Presence - Xmake Build
-- LuaFormatter off

add_rules('mode.release')

-- Submodules must be fetched first.
package('DiscordRPC')
	add_deps('cmake')
	set_sourcedir(path.join(os.scriptdir(), 'extern/discord-rpc'))
	-- Add required system libraries
	if is_plat('windows') then add_syslinks('Advapi32') end
	if is_plat('macosx') then
		add_frameworks('Foundation', 'CoreFoundation', 'CoreServices')
	end
	on_install(function(package)
		local configs = {}
		table.insert(configs, '-DCMAKE_BUILD_TYPE=' .. (package:debug() and 'Debug' or 'Release'))
		table.insert(configs, '-DBUILD_SHARED_LIBS=' .. (package:config('shared') and 'ON' or 'OFF'))
		import('package.tools.cmake').install(package, configs)
	end)
	on_test(function(package)
		assert(package:has_cfuncs('Discord_Initialize', {includes = 'discord_rpc.h'}))
	end)
package_end()

add_requires('DiscordRPC', {configs = {shared = false}})

target('discordrpc')
	set_kind('shared')
	add_files('ta_rpc.c')
	add_packages('DiscordRPC')
	add_includedirs('$(scriptdir)/extern/lua/')
	set_configdir('$(builddir)/$(plat)/$(arch)/$(mode)')
	add_configfiles('init.lua', 'edge_names.lua', {onlycopy = true})

	if is_plat('windows') then
		-- We need to embed the minimal copy of Lua
		add_defines('LUA_BUILD_AS_DLL', 'LUA_LIB')
		local base = 'extern/lua/'
		add_files(base .. '*.c')
		remove_files(
			base .. 'lua.c',
			base .. 'luac.c',
			base .. 'linit.c',
			base .. 'lib.c',
			base .. 'lutf8lib.c',
			base .. 'ltablib.c',
			base .. 'lstrlib.c',
			base .. 'loslib.c',
			base .. 'loadlib.c',
			base .. 'lmathlib.c',
			base .. 'liolib.c',
			base .. 'ldblib.c',
			base .. 'lcorolib.c',
			base .. 'lbaselib.c',
			base .. 'onelua.c'
		)
	elseif is_plat('linux') then
		if is_arch("x86_64", "i386") then
			set_filename('discordrpc.so')
		else
			set_filename('discordrpcarm.so')
		end
	elseif is_plat('macosx') then
		add_shflags('-undefined', 'dynamic_lookup', {force = true})
		set_filename('discordrpcosx.so')
	end

	on_install(function(target)
		local home = is_plat('windows') and os.getenv('USERPROFILE') or os.getenv('HOME')
		local dir = home .. '/.textadept/modules/discord_rpc'
		os.mkdir(dir)
		os.cp(target:targetdir() .. '/**', dir)
	end)

task('gen_readme')
	on_run(function()
		import("net.http")
		http.download(
			'https://raw.githubusercontent.com/orbitalquark/textadept/refs/heads/default/scripts/markdowndoc.lua',
			'markdowndoc.lua'
		)
		local output =
			os.iorun('ldoc --filter markdowndoc.ldoc init.lua -- --title="Textadept Discord RPC" --single')
		output = output:gsub("^%s*(.-)%s*$", "%1") .. '\n'
		io.writefile("README.md", output)
		os.rm('markdowndoc.lua')
	end)

	set_menu{
		usage = 'xmake gen_readme',
		description = 'Generate README.md from init.lua LDoc.',
		options = {}
	}

-- LuaFormatter on

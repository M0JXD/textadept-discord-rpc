-- Copyright 2025-2026 Jamie Drinkell. See LICENSE.
-- Textadept Discord Rich Presence Name Edge Cases

local M = {}

-- LuaFormatter off
-- Lexer names that are not suitable for first letter capitalisation
M.names = {
	applescript = "AppleScript",
	asm = "ASM",
	asp = "ASP",
	autoit = "AutoIt",
	cmake = "CMake",
	coffeescript = "CoffeeScript",
	cpp = "C++",
	csharp = "C#",
	css = "CSS",
	cuda = "CUDA",
	fsharp = "F#",
	glsl = "GLSL",
	html = "HTML",
	javascript = "JavaScript",
	json = "JSON",
	matlab = "MATLAB",
	moonscript = "MoonScript",
	objective_c = "Objective-C",
	php = "PHP",
	powershell = "PowerShell",
	sql = "SQL",
	toml = "TOML",
	typescript = "TypeScript",
	vb = "Visual Basic",
	vhdl = "VHDL",
	xml = "XML",
	yaml = "YAML"
}

-- Lexers that should use 'an' instead of 'a'
M.an = {
	actionscript = true,
	ada = true,
	anntlr = true,
	apdl = true,
	apl = true,
	applescript = true,
	arduino = true,
	asm = true,
	asp = true,
	autohotkey = true,
	autoit = true,
	awk = true,
	eiffel = true,
	elixir = true,
	elm = true,
	erlang = true,
	fsharp = true,
	fstab = true,
	icon = true,
	idl = true,
	inform = true,
	ini = true,
	io_lang = true,
	nsis = true,
	objeck = true,
	objective_c = true,
	org = true,
	r = true,
	rc = true,
	rhtml = true,
	rpmspec = true,
	sml = true,
	sql = true,
	strace = true,
	xml = true,
	xs = true,
	xtend = true
}
-- LuaFormatter on

return M

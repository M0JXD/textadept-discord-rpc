add_requires('DiscordRPC')

add_target('ta_drpc')
	set_kind('shared')
	add_files('ta_rpc.c')

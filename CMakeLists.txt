# Copyright 2022-2025 Jamie Drinkell. See LICENSE.

cmake_minimum_required(VERSION 3.16)

# Get Discord RPC library
include(FetchContent)
set(FETCHCONTENT_QUIET OFF)

# Get Lua
set(lua_tgz lua-5.5.0-rc1.tar.gz)
set(lua_url file://${CMAKE_BINARY_DIR}/_deps/${lua_tgz})
if(NOT EXISTS ${CMAKE_BINARY_DIR}/_deps/${lua_tgz})
	set(lua_url https://lua.org/work/${lua_tgz})
endif()
FetchContent_Declare(lua URL ${lua_url})
FetchContent_MakeAvailable(lua)

# Get Discord-RPC

# Build Discord-RPC as static library


# Build our library
project(textadept-discord-rpc)
add_library(ta_drpc SHARED)
target_sources(ta_drpc
	PRIVATE
		ta_rpc.c
)




/* Simple Discord RPC wrapper suitable for Textadept */
/* Based on the send_presence example */

/* DLL Exports for Windows */
#ifdef _WIN32
    #define _CRT_SECURE_NO_WARNINGS /* thanks Microsoft */
    #ifdef TA_DRPC_EXPORTS
        #define TA_DRPC __declspec(dllexport)
    #else
        #define TA_DRPC __declspec(dllimport)
    #endif
#else
    #define TA_DRPC
#endif

#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdbool.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "discord_rpc.h"

/* This client_id is tied to a Discord app made on my (M0JXD's) dev account for this project.
 * If you'd rather have your own ID change it here.
 * I have put this in the C code to force end users to recompile, as a different ID will not have the assets.
 */
static const char* APPLICATION_ID = "1446884816174841971";
static int64_t startTime;

static struct TAPresenceData {
    char userdetails[256];
    char disconnectedDetails[256];
    char errorDetails[256];
} taPresenceData = {NULL, NULL, NULL};

/* ============================== DISCORD HANDLERS ============================== */

/* TODO: Inform Textadept on the status of these */
static void handleDiscordReady(const DiscordUser* connectedUser) {
    if (!connectedUser->discriminator[0] || strcmp(connectedUser->discriminator, "0") == 0) {
        sprintf(taPresenceData.userdetails ,"Connected to user @%s (%s) - %s",
               connectedUser->username,
               connectedUser->globalName,
               connectedUser->userId);
    } else {
        sprintf(taPresenceData.userdetails, "Connected to user %s#%s (%s) - %s",
               connectedUser->username,
               connectedUser->discriminator,
               connectedUser->globalName,
               connectedUser->userId);
    }
    puts(taPresenceData.userdetails);
}

static void handleDiscordDisconnected(int errcode, const char* message) {
    sprintf(taPresenceData.disconnectedDetails, "Disconnected (%d: %s)", errcode, message);
    puts(taPresenceData.disconnectedDetails);
}

static void handleDiscordError(int errcode, const char* message) {
    sprintf(taPresenceData.errorDetails, "Error (%d: %s)", errcode, message);
    puts(taPresenceData.errorDetails);
}

static void populateHandlers(DiscordEventHandlers* handlers) {
    memset(handlers, 0, sizeof(handlers));
    handlers->ready = handleDiscordReady;
    handlers->disconnected = handleDiscordDisconnected;
    handlers->errored = handleDiscordError;

    /* We have no use for any of these */
    handlers->debug = NULL;
    handlers->joinGame = NULL;
    handlers->spectateGame = NULL;
    handlers->joinRequest = NULL;
    handlers->invited = NULL;
}

/* ============================== LUA API ============================== */

TA_DRPC static int initDiscord(lua_State *L) {
    DiscordEventHandlers handlers;
    startTime = time(0);
    populateHandlers(&handlers);
    Discord_Initialize(APPLICATION_ID, &handlers, 1, NULL);
    Discord_ClearPresence();
#ifdef DISCORD_DISABLE_IO_THREAD
    Discord_UpdateConnection();
#endif
    Discord_RunCallbacks();
    return 0;
}

TA_DRPC static int updateDiscordPresence(lua_State *L) {
    /* IDEAS
      - Amount of errors (LSP or from compile/run)
      - Time since most recent commit?
      - Git branch name? */

    luaL_checktype(L, 1, LUA_TTABLE);

    /* If we should send presence */
    lua_getfield(L, -1, "send_presence");
    bool send_presence = lua_toboolean(L, -1);

    /* Private mode that doesn't display file names/project folder */
    lua_getfield(L, -2, "private");
    bool private = lua_toboolean(L, -1);

    /* Qt, GTK or CURSES version */
    lua_getfield(L, -3, "version");
    const char *version = lua_tostring(L, -1);

    /* Is user idling? */
    lua_getfield(L, -4, "idle");
    bool idle = lua_toboolean(L, -1);

    /* Is the current buffer unsaved? */
    lua_getfield(L, -5, "modified");
    bool modified = lua_toboolean(L, -1);

    /* Action being run */
    lua_getfield(L, -6, "runner");
    const char *runner = lua_tostring(L, -1);  /* 'N' = No, 'E' = Executing, 'R' = Running, 'C' = Compiling, 'B' = Building, 'D' = Debugging? */

    /* Filename of the current buffer */
    lua_getfield(L, -7, "filename");
    const char *filename = lua_tostring(L, -1);  /* Will be init.lua.T for preferences? */

    /* Lexer applied to current buffer TODO: This doesn't handle edge cases like arduino, would also be nice to check for preferences init.lua */
    lua_getfield(L, -8, "lexer");
    const char *lexer = lua_tostring(L, -1);  /* TODO: Special treatment for the likes of Arduino? */

    /* The project folder name */
    lua_getfield(L, -9, "project_name");
    const char *project_name = lua_tostring(L, -1);  /* NA will be shown if Textadept can't detect a project */

    /* Amount of LSP/Compile etc. errors */
    lua_getfield(L, -10, "errors");
    int errors = lua_tointeger(L, -1);

    /* ===== Calculate Presence ===== */

    char state[128];
    char details[128];
    char smallImageText[128];
    char largeImageText[128];

    char *runner_str = NULL;
    switch (runner[0]) {
        case 'E':
            runner_str = "executing";
            break;
        case 'R':
            runner_str = "running";
            break;
        case 'C':
            runner_str = "compiling";
            break;
        case 'B':
            runner_str = "building";
            break;
        case 'D':
            runner_str = "debugging";
            break;
    }

    if (private) {
        sprintf(state, "Currently %s a %s file.", modified ? "editing." : runner[0] != 'N' ? strcat(runner_str, " a task.") : "viewing.", lexer);
        sprintf(details, "Errors: %d", errors);
    } else {
        sprintf(state, "Currently %s %s", modified ? "editing" : runner[0] != 'N' ? runner_str : "viewing", filename);
        sprintf(details, "Project folder: %s, Errors: %d", project_name, errors);
    }

    if (idle) {
        strcpy(state, "Currently idle.");
    }

    sprintf(smallImageText, "Textadept (%s)", version);

    /* ===== Send Presence ===== */

    DiscordRichPresence discordPresence;
    memset(&discordPresence, 0, sizeof(discordPresence));
    discordPresence.state = state;
    discordPresence.details = details;
    discordPresence.startTimestamp = startTime;
#ifdef __APPLE__
    discordPresence.smallImageKey = "textadept_mac";
#else
    discordPresence.smallImageKey = "textadept";
#endif
    discordPresence.smallImageText = smallImageText;
    discordPresence.largeImageKey = lexer;
    //lexer[0] -= 32;  /* Capitalise first letter */
    sprintf(largeImageText, "Editing a %c%s file.", lexer[0] - 32, &lexer[1]);
    discordPresence.largeImageText = largeImageText;
    //lexer[0] += 32;  /* Uncapitalise first letter */

    if (send_presence) {
        Discord_UpdatePresence(&discordPresence);
    } else {
        Discord_ClearPresence();
    }

#ifdef DISCORD_DISABLE_IO_THREAD
    Discord_UpdateConnection();
#endif
    Discord_RunCallbacks();

    lua_pushstring(L, taPresenceData.userdetails);
    lua_pushstring(L, taPresenceData.disconnectedDetails);
    lua_pushstring(L, taPresenceData.errorDetails);
    /* Now the data is passed forward, clear them? */
    //taPresenceData.userdetails[0] = '\0';
    //taPresenceData.disconnectedDetails[0] = '\0';
    //taPresenceData.errorDetails[0] = '\0';
    return 3;
}

TA_DRPC static int closeDiscord(lua_State *L) {
    Discord_Shutdown();
    return 0;
}

/* Entry point */
TA_DRPC static int luaopen_discordrpc(lua_State *L) {
    static const struct luaL_Reg lib[] = {
        {"init", initDiscord},
        {"update", updateDiscordPresence},
        {"close", closeDiscord},
        {NULL, NULL} /* Sentinel */
    };
    luaL_newlib(L, lib);
    return 1;
}

/* Platform entry points with names as required by Textadept modules */
LUALIB_API int luaopen_discord_rpc_discordrpc(lua_State *L) { return luaopen_discordrpc(L); }
LUALIB_API int luaopen_discord_rpc_discordrpcosx(lua_State *L) { return luaopen_discordrpc(L); }
LUALIB_API int luaopen_discord_rpc_discordrpcarm(lua_State *L) { return luaopen_discordrpc(L); }

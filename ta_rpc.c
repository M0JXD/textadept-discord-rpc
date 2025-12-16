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

/* ============================== DISCORD HANDLERS ============================== */

/* TODO: Inform Textadept on the status of these */
static void handleDiscordReady(const DiscordUser* connectedUser) {
    char buffer[256];
    if (!connectedUser->discriminator[0] || strcmp(connectedUser->discriminator, "0") == 0) {
        printf("\nDiscord: connected to user @%s (%s) - %s\n",
               connectedUser->username,
               connectedUser->globalName,
               connectedUser->userId);
    } else {
        printf("\nDiscord: connected to user %s#%s (%s) - %s\n",
               connectedUser->username,
               connectedUser->discriminator,
               connectedUser->globalName,
               connectedUser->userId);
    }
}

static void handleDiscordDisconnected(int errcode, const char* message) {
    printf("\nDiscord: disconnected (%d: %s)\n", errcode, message);
}

static void handleDiscordError(int errcode, const char* message) {
    printf("\nDiscord: error (%d: %s)\n", errcode, message);
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
    /* Get if privacy mode is set */
    /* Ideally get a callback function we can call that will emit a Textadept event? Is that even possible? */

    DiscordEventHandlers handlers;
    startTime = time(0);
    populateHandlers(&handlers);
    Discord_Initialize(APPLICATION_ID, &handlers, 1, NULL);

    Discord_ClearPresence();

    return 0;
}

TA_DRPC static int updateDiscordPresence(lua_State *L) {
    /*TODO: This should pass:
        - If we should send presence
        - Textadept version (CURSES, GTK on Linux)
        - The file's name, with extension (do a special check for preferences init.lua)
        - The current lexer?
        - If the file is modified but unsaved (editing vs viewing)
        - Are we calling due to a run/compile command?
        - Are we calling due to idle timeout?
        - The Project folder name

        - IDEAS:
        - Amount of errors (LSP or from compile/run)
        - Time since most recent commit?
        - Git branch name?
    */

    bool send_presence = true;
    bool private = false;
    char ta_type = 'Q'; /* 'Q' = Qt, 'G' = GTK 'C' = CURSES */

    bool idle     = false;
    bool modified = false;
    char runner = 'N';  /* 'N' = No, 'R' = Running, 'C' = Compiling, 'B' = Building, 'D' = Debugging? */
    char filename[128] = "init.lua";  /* Will be init.lua.T for preferences */
    char lexer[32]     = "lua";
    char project_name[128]  = "textadept-discord-rpc";
    int errors = 0;

    /* If not to send then clear and quit early */
    if (!send_presence) {
        Discord_ClearPresence();
        return 0;
    }

    /* ===== Calculate Presence ===== */

    char state[128];
    char details[128];
    char smallImageText[128];
    //char largeImageText[128];

    sprintf(state, "Editing a %s file.", lexer);
    sprintf(details, "Project folder: %s", project_name);
    sprintf(smallImageText, "Textadept %s",
        ta_type == 'Q' ? "Qt" :
        ta_type == 'C' ? "GTK" : "curses");
    //sprintf(largeImageText, "%s", lexer);

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
    discordPresence.largeImageKey = lexer;
    discordPresence.smallImageText = smallImageText;
    discordPresence.largeImageText = lexer;

    Discord_UpdatePresence(&discordPresence);
#ifdef DISCORD_DISABLE_IO_THREAD
    Discord_UpdateConnection();
#endif
    Discord_RunCallbacks();
    return 0;
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

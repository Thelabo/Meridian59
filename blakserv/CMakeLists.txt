# Meridian 59 - Game Server (blakserv)
#
# The main game server. Runs on Linux (epoll), macOS (kqueue), or Windows.
# This CMakeLists.txt targets the Linux/macOS native build.

# ---- Server sources ----
# Matches the source list from makefile.linux exactly.
# Excludes: interface.c (Windows GUI), osd_windows.c (Windows platform layer)
set(BLAKSERV_SOURCES
    main.c
    loadkod.c
    class.c
    message.c
    object.c
    sendmsg.c
    roofile.c
    bufpool.c
    ccode.c
    channel.c
    list.c
    timer.c
    session.c
    loadrsc.c
    blakres.c
    roomdata.c
    commcli.c
    string.c
    async.c
    loadgame.c
    game.c
    term.c
    account.c
    loadacco.c
    saveacco.c
    savestr.c
    loadstr.c
    nameid.c
    time.c
    dllist.c
    trysync.c
    saveall.c
    loadall.c
    synched.c
    motd.c
    admin.c
    garbage.c
    kodbase.c
    savegame.c
    user.c
    system.c
    resync.c
    gamelock.c
    config.c
    apndfile.c
    admincons.c
    builtin.c
    version.c
    systimer.c
    memory.c
    intrlock.c
    chanbuf.c
    debug.c
    saversc.c
    adminfn.c
    table.c
    parsecli.c
    maintenance.c
    block.c
    stringinthash.c
    intstringhash.c
    sprocket.c
    mutex_impl.c
    fileutil.c
    osd_linux.c
    webhook.c
)

# ---- Platform-specific I/O ----
if(APPLE)
    list(APPEND BLAKSERV_SOURCES osd_kqueue.c)
else()
    list(APPEND BLAKSERV_SOURCES osd_epoll.c)
endif()

# ---- Shared utility sources (from util/) ----
set(BLAKSERV_UTIL_SOURCES
    "${MERIDIAN59_ROOT}/util/rscload.c"
    "${MERIDIAN59_ROOT}/util/crc.c"
    "${MERIDIAN59_ROOT}/util/md5.c"
)

# ---- Target ----
add_executable(blakserv
    ${BLAKSERV_SOURCES}
    ${BLAKSERV_UTIL_SOURCES}
)

target_include_directories(blakserv PRIVATE
    "${INCLUDE_DIR}"
    "${FMTLIB_DIR}"
)

target_compile_definitions(blakserv PRIVATE
    BLAK_PLATFORM_LINUX
    FMT_UNICODE=0
    $<$<NOT:$<CONFIG:Release>>:BLAKDEBUG>
)

target_compile_options(blakserv PRIVATE
    -Wno-unused-result
    -Werror
)

target_compile_as_cxx(blakserv)

# ---- Recompile version.c on every link to embed build timestamp ----
# The original makefile recompiles version.c right before linking.
# We approximate this by marking version.c as always needing recompile.
set_source_files_properties(version.c PROPERTIES
    COMPILE_FLAGS "-DBUILD_TIMESTAMP=\\\"$<TARGET_PROPERTY:blakserv,BINARY_DIR>\\\""
)
# Force version.c to always recompile
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/version_timestamp"
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_BINARY_DIR}/version_timestamp"
    COMMENT "Updating build timestamp for version.c"
)
add_custom_target(blakserv_version_timestamp
    DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/version_timestamp"
)
add_dependencies(blakserv blakserv_version_timestamp)
set_source_files_properties(version.c PROPERTIES
    OBJECT_DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/version_timestamp"
)

# ---- Link libraries ----
# Linux needs pthreads; the server doesn't need much else natively
find_package(Threads REQUIRED)
target_link_libraries(blakserv PRIVATE Threads::Threads)

# ---- Install: copy to run/server/ ----
add_custom_command(TARGET blakserv POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${SERVER_RUN_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:blakserv>" "${SERVER_RUN_DIR}/"
    COMMENT "Copying blakserv to ${SERVER_RUN_DIR}/"
)

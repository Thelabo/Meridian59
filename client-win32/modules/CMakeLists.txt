# Module DLLs for MinGW cross-compilation
#
# All 6 modules are client plugin DLLs. They link against meridian.exe's
# import library and use .def files for ordinal exports.
#
# Modules: merintr, char, admin, dm, mailnews, chess

# ---- Common settings for all modules ----
# Each module includes clientd3d headers and links against meridian.exe

function(add_module MODULE_NAME MODULE_SOURCES MODULE_RC MODULE_DEF)
    # Enable resource compiler
    enable_language(RC)

    add_library(${MODULE_NAME} SHARED ${MODULE_SOURCES} ${MODULE_RC} ${MODULE_DEF})

    target_compile_as_cxx(${MODULE_NAME})

    target_include_directories(${MODULE_NAME} PRIVATE
        ${CLIENT_DIR}
        ${INCLUDE_DIR}
        ${FMTLIB_DIR}
        ${GENERATED_DIR}
        ${OPENAL_DIR}/include
        ${MODULE_DIR}/${MODULE_NAME}
        # Libraries needed for client.h includes (png.h, zlib.h, archive.h)
        ${ZLIB_DIR}
        ${LIBPNG_DIR}
        ${LIBARCHIVE_DIR}
        ${STB_DIR}
    )

    target_compile_definitions(${MODULE_NAME} PRIVATE
        BLAK_PLATFORM_WINDOWS
        WIN32
        FMT_UNICODE=0
        $<$<CONFIG:Debug>:BLAKDEBUG>
    )

    target_compile_options(${MODULE_NAME} PRIVATE
        -Wno-unused-result
        -Wno-multichar
        -Wno-sign-compare
        -Wno-unused-variable
        -Wno-unused-but-set-variable
        -Wno-parentheses
        -Wno-format
    )

    set_source_files_properties(${MODULE_RC} PROPERTIES
        COMPILE_FLAGS "-I ${MODULE_DIR}/${MODULE_NAME} -I ${CLIENT_DIR} -I ${INCLUDE_DIR}"
    )

    set_target_properties(${MODULE_NAME} PROPERTIES
        PREFIX ""               # No "lib" prefix on DLL name
    )

    # Link against meridian.exe's import library + Win32 libs
    target_link_libraries(${MODULE_NAME} PRIVATE
        ${MERIDIAN_IMPLIB}
        user32 gdi32 comctl32
    )

    # Module DLLs depend on meridian.exe being built first (for the import lib)
    add_dependencies(${MODULE_NAME} meridian)

    install(TARGETS ${MODULE_NAME} DESTINATION "${CLIENT_RUN_DIR}/resource")

    # Post-build: copy DLL to run/localclient/resource/ automatically
    add_custom_command(TARGET ${MODULE_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "${CLIENT_RUN_DIR}/resource"
        COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:${MODULE_NAME}>" "${CLIENT_RUN_DIR}/resource/"
        COMMENT "Copying ${MODULE_NAME}.dll to ${CLIENT_RUN_DIR}/resource/"
    )
endfunction()

# ---- merintr ----
set(MERINTR_SOURCES
    ${MODULE_DIR}/merintr/merintr.c
    ${MODULE_DIR}/merintr/mermain.c
    ${MODULE_DIR}/merintr/spells.c
    ${MODULE_DIR}/merintr/command.c
    ${MODULE_DIR}/merintr/groups.c
    ${MODULE_DIR}/merintr/userarea.c
    ${MODULE_DIR}/merintr/alias.c
    ${MODULE_DIR}/merintr/enchant.c
    ${MODULE_DIR}/merintr/inventry.c
    ${MODULE_DIR}/merintr/stats.c
    ${MODULE_DIR}/merintr/statlist.c
    ${MODULE_DIR}/merintr/statcach.c
    ${MODULE_DIR}/merintr/statbtn.c
    ${MODULE_DIR}/merintr/statmain.c
    ${MODULE_DIR}/merintr/statnum.c
    ${MODULE_DIR}/merintr/guild.c
    ${MODULE_DIR}/merintr/guildinv.c
    ${MODULE_DIR}/merintr/guildhal.c
    ${MODULE_DIR}/merintr/guildbuy.c
    ${MODULE_DIR}/merintr/guildshi.c
    ${MODULE_DIR}/merintr/guildaly.c
    ${MODULE_DIR}/merintr/guildmem.c
    ${MODULE_DIR}/merintr/guildmtr.c
    ${MODULE_DIR}/merintr/actions.c
    ${MODULE_DIR}/merintr/drawint.c
    ${MODULE_DIR}/merintr/groupdlg.c
    ${MODULE_DIR}/merintr/skills.c
)
add_module(merintr
    "${MERINTR_SOURCES}"
    "${MODULE_DIR}/merintr/merintr.rc"
    "${MODULE_DIR}/merintr/merintr.def"
)

# ---- intro ----
set(INTRO_SOURCES
    ${MODULE_DIR}/intro/intro.c
)
add_module(intro
    "${INTRO_SOURCES}"
    "${MODULE_DIR}/intro/intro.rc"
    "${MODULE_DIR}/intro/intro.def"
)

# ---- char ----
set(CHAR_SOURCES
    ${MODULE_DIR}/char/charpick.c
    ${MODULE_DIR}/char/charface.c
    ${MODULE_DIR}/char/char.c
    ${MODULE_DIR}/char/charmake.c
    ${MODULE_DIR}/char/charstat.c
    ${MODULE_DIR}/char/charname.c
    ${MODULE_DIR}/char/charspel.c
    ${MODULE_DIR}/char/charskil.c
)
add_module(char
    "${CHAR_SOURCES}"
    "${MODULE_DIR}/char/char.rc"
    "${MODULE_DIR}/char/char.def"
)

# ---- admin ----
set(ADMIN_SOURCES
    ${MODULE_DIR}/admin/admin.c
    ${MODULE_DIR}/admin/admindlg.c
    ${MODULE_DIR}/admin/adminprs.c
)
add_module(admin
    "${ADMIN_SOURCES}"
    "${MODULE_DIR}/admin/admin.rc"
    "${MODULE_DIR}/admin/admin.def"
)

# ---- dm ----
set(DM_SOURCES
    ${MODULE_DIR}/dm/dm.c
    ${MODULE_DIR}/dm/command.c
    ${MODULE_DIR}/dm/gchannel.c
    ${MODULE_DIR}/dm/qeditor.c
)
add_module(dm
    "${DM_SOURCES}"
    "${MODULE_DIR}/dm/dm.rc"
    "${MODULE_DIR}/dm/dm.def"
)

# ---- mailnews ----
set(MAILNEWS_SOURCES
    ${MODULE_DIR}/mailnews/mailnews.c
    ${MODULE_DIR}/mailnews/mailread.c
    ${MODULE_DIR}/mailnews/mailsend.c
    ${MODULE_DIR}/mailnews/mailfile.c
    ${MODULE_DIR}/mailnews/newsread.c
    ${MODULE_DIR}/mailnews/newssend.c
)
add_module(mailnews
    "${MAILNEWS_SOURCES}"
    "${MODULE_DIR}/mailnews/mailnews.rc"
    "${MODULE_DIR}/mailnews/mailnews.def"
)

# ---- chess ----
set(CHESS_SOURCES
    ${MODULE_DIR}/chess/chess.c
    ${MODULE_DIR}/chess/board.c
    ${MODULE_DIR}/chess/cmove.c
)
add_module(chess
    "${CHESS_SOURCES}"
    "${MODULE_DIR}/chess/chess.rc"
    "${MODULE_DIR}/chess/chess.def"
)

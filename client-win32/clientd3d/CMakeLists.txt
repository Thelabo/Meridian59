# meridian.exe - Game client for MinGW cross-compilation
#
# This is the main game client executable. It exports symbols via client.def
# for module DLLs to link against. Compiled as C++20.
#
# Depends on: zlib, libpng, libarchive, rscload (static libs)
# Links against: Win32 system libraries, Direct3D 9, OpenAL

# ---- Source files (matching clientd3d/makefile OBJS list) ----
set(CLIENT_SOURCES
    ${CLIENT_DIR}/client.c
    ${CLIENT_DIR}/list.c
    ${CLIENT_DIR}/modules.c
    ${CLIENT_DIR}/map.c
    ${CLIENT_DIR}/msgfiltr.c
    ${CLIENT_DIR}/loadrsc.c
    ${CLIENT_DIR}/protocol.c
    ${CLIENT_DIR}/com.c
    ${CLIENT_DIR}/draw3d.c
    ${CLIENT_DIR}/palette.c
    ${CLIENT_DIR}/object3d.c
    ${CLIENT_DIR}/overlay.c
    ${CLIENT_DIR}/moveobj.c
    ${CLIENT_DIR}/tooltip.c
    ${CLIENT_DIR}/annotate.c
    ${CLIENT_DIR}/idlist.c
    ${CLIENT_DIR}/roomanim.c
    ${CLIENT_DIR}/statconn.c
    ${CLIENT_DIR}/memmap.c
    ${CLIENT_DIR}/mapfile.c
    ${CLIENT_DIR}/boverlay.c
    ${CLIENT_DIR}/web.c
    ${CLIENT_DIR}/about.c
    ${CLIENT_DIR}/login.c
    ${CLIENT_DIR}/srvrstr.c
    ${CLIENT_DIR}/effect.c
    ${CLIENT_DIR}/bitmap.c
    ${CLIENT_DIR}/download.c
    ${CLIENT_DIR}/select.c
    ${CLIENT_DIR}/logoff.c
    ${CLIENT_DIR}/transfer.c
    ${CLIENT_DIR}/statoffl.c
    ${CLIENT_DIR}/cursor.c
    ${CLIENT_DIR}/client3d.c
    ${CLIENT_DIR}/xlat.c
    ${CLIENT_DIR}/rops.c
    ${CLIENT_DIR}/profane.c
    ${CLIENT_DIR}/object.c
    ${CLIENT_DIR}/graphics.c
    ${CLIENT_DIR}/winmsg.c
    ${CLIENT_DIR}/server.c
    ${CLIENT_DIR}/dialog.c
    ${CLIENT_DIR}/draw.c
    ${CLIENT_DIR}/graphctl.c
    ${CLIENT_DIR}/animate.c
    ${CLIENT_DIR}/config.c
    ${CLIENT_DIR}/projectile.c
    ${CLIENT_DIR}/uselist.c
    ${CLIENT_DIR}/move.c
    ${CLIENT_DIR}/startup.c
    ${CLIENT_DIR}/keyhook.c
    ${CLIENT_DIR}/toolbar.c
    ${CLIENT_DIR}/game.c
    ${CLIENT_DIR}/intrface.c
    ${CLIENT_DIR}/ownerdrw.c
    ${CLIENT_DIR}/util.c
    ${CLIENT_DIR}/table.c
    ${CLIENT_DIR}/statterm.c
    ${CLIENT_DIR}/statgame.c
    ${CLIENT_DIR}/font.c
    ${CLIENT_DIR}/textin.c
    ${CLIENT_DIR}/msgbox.c
    ${CLIENT_DIR}/editbox.c
    ${CLIENT_DIR}/gameuser.c
    ${CLIENT_DIR}/offer.c
    ${CLIENT_DIR}/maindlg.c
    ${CLIENT_DIR}/lookdlg.c
    ${CLIENT_DIR}/color.c
    ${CLIENT_DIR}/say.c
    ${CLIENT_DIR}/sound.c
    ${CLIENT_DIR}/music.c
    ${CLIENT_DIR}/audio_openal.c
    ${CLIENT_DIR}/key.c
    ${CLIENT_DIR}/buy.c
    ${CLIENT_DIR}/statstrt.c
    ${CLIENT_DIR}/dibutil.c
    ${CLIENT_DIR}/drawbsp.c
    ${CLIENT_DIR}/bspload.c
    ${CLIENT_DIR}/parse.c
    ${CLIENT_DIR}/drawbmp.c
    ${CLIENT_DIR}/winmenu.c
    ${CLIENT_DIR}/cache.c
    ${CLIENT_DIR}/ping.c
    ${CLIENT_DIR}/objdraw.c
    ${CLIENT_DIR}/lagbox.c
    ${CLIENT_DIR}/regexpr.c
    ${CLIENT_DIR}/fixed.c
    ${CLIENT_DIR}/d3dcache.c
    ${CLIENT_DIR}/d3ddriver.c
    ${CLIENT_DIR}/d3dparticle.c
    ${CLIENT_DIR}/d3drender.c
    ${CLIENT_DIR}/d3drender_bgoverlays.c
    ${CLIENT_DIR}/d3drender_fx.c
    ${CLIENT_DIR}/d3drender_lights.c
    ${CLIENT_DIR}/d3drender_materials.c
    ${CLIENT_DIR}/d3drender_objects.c
    ${CLIENT_DIR}/d3drender_skybox.c
    ${CLIENT_DIR}/d3drender_textures.c
    ${CLIENT_DIR}/d3drender_world.c
    ${CLIENT_DIR}/matrix.c
    ${CLIENT_DIR}/xform.c
    ${CLIENT_DIR}/signup.c
    ${CLIENT_DIR}/preferences.c
)

# External sources compiled into the client
set(CLIENT_EXTERNAL_SOURCES
    ${UTIL_DIR}/md5.c
    ${UTIL_DIR}/crc.c
    ${STB_DIR}/stb_vorbis.c
)

# Generated sources (from native code generators, passed via GENERATED_DIR)
set(CLIENT_GENERATED_SOURCES
    ${GENERATED_DIR}/trig.c
    ${GENERATED_DIR}/pal.c
)

# ---- Resource compilation ----
# windres handles .rc files for MinGW
set(CLIENT_RC ${CLIENT_DIR}/client.rc)

# Enable resource compiler
enable_language(RC)

# ---- Build the executable ----
add_executable(meridian WIN32
    ${CLIENT_SOURCES}
    ${CLIENT_EXTERNAL_SOURCES}
    ${CLIENT_GENERATED_SOURCES}
    ${CLIENT_RC}
)

# ---- Compile C files as C++20 ----
target_compile_as_cxx(meridian)

# stb_vorbis should stay as C++20 too (original build uses /TP globally)

# ---- Include directories ----
target_include_directories(meridian PRIVATE
    ${CLIENT_DIR}
    ${INCLUDE_DIR}
    ${FMTLIB_DIR}
    ${GENERATED_DIR}           # For trig.h
    ${OPENAL_DIR}/include
    # External libs provide their own PUBLIC include dirs
)

# ---- Compile definitions ----
target_compile_definitions(meridian PRIVATE
    BLAK_PLATFORM_WINDOWS
    WIN32
    BLAKCLIENT
    STB_VORBIS_NO_PUSHDATA_API
    FMT_UNICODE=0
    $<$<CONFIG:Debug>:BLAKDEBUG>
)

# ---- Compile options ----
target_compile_options(meridian PRIVATE
    -Wno-unused-result
    -Wno-multichar
    -Wno-sign-compare
    -Wno-unused-variable
    -Wno-unused-but-set-variable
    -Wno-parentheses
    -Wno-format
)

# ---- Resource compiler flags ----
# windres needs include paths to find resource.h and other headers
set_source_files_properties(${CLIENT_RC} PROPERTIES
    COMPILE_FLAGS "-I ${CLIENT_DIR} -I ${INCLUDE_DIR}"
)

# ---- Linker configuration ----
# Use client.def (added as source) to export symbols for module DLLs
target_link_options(meridian PRIVATE
    -Wl,--out-implib,libmeridian.dll.a
    -mwindows
    "${CLIENT_DIR}/client.def"
)

# Static libraries from our build
target_link_libraries(meridian PRIVATE
    zlib
    libpng
    libarchive
    rscload
)

# Win32 system libraries
target_link_libraries(meridian PRIVATE
    user32 gdi32 comdlg32 shell32
    ws2_32 comctl32 advapi32 winmm
    wininet ole32 d3d9
)

# OpenAL - use the pre-built Win64 import library
target_link_libraries(meridian PRIVATE
    ${OPENAL_DIR}/libs/Win64/OpenAL32.lib
)

# ---- Install ----
install(TARGETS meridian DESTINATION "${CLIENT_RUN_DIR}")

# Also copy the OpenAL DLL alongside the client
install(FILES "${OPENAL_DIR}/bin/Win64/soft_oal.dll"
        DESTINATION "${CLIENT_RUN_DIR}"
        RENAME OpenAL32.dll)

# ---- Post-build: copy to run/localclient/ ----
# This copies meridian.exe and OpenAL32.dll automatically after each build,
# matching the native targets' POST_BUILD pattern (no separate install step).
add_custom_command(TARGET meridian POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${CLIENT_RUN_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:meridian>" "${CLIENT_RUN_DIR}/"
    COMMAND ${CMAKE_COMMAND} -E copy "${OPENAL_DIR}/bin/Win64/soft_oal.dll" "${CLIENT_RUN_DIR}/OpenAL32.dll"
    COMMENT "Copying meridian.exe and OpenAL32.dll to ${CLIENT_RUN_DIR}/"
)

# Make the import library available for module DLLs
# The import library is generated during link as libmeridian.dll.a
set(MERIDIAN_IMPLIB "${CMAKE_CURRENT_BINARY_DIR}/libmeridian.dll.a"
    CACHE INTERNAL "Import library for meridian.exe exports")

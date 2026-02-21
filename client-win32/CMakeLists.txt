# Meridian 59 - Cross-Compiled Windows Client
#
# This CMakeLists.txt is invoked by the top-level superbuild via
# ExternalProject_Add with the MinGW-w64 toolchain file.
# It builds:
#   - External libraries (zlib, libpng, libarchive) as static libs
#   - rscload utility library
#   - meridian.exe (the game client)
#   - 6 module DLLs (merintr, char, admin, dm, mailnews, chess)
#
# All C code is compiled as C++20 (matching the original MSVC /TP flag),
# except zlib and libarchive which must compile as plain C.

cmake_minimum_required(VERSION 3.20)
project(Meridian59Client LANGUAGES C CXX)

# ---- Build type ----
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug)
endif()

# ---- Global paths (source tree root is one level up) ----
set(M59_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(INCLUDE_DIR "${M59_ROOT}/include")
set(EXTERNAL_DIR "${M59_ROOT}/external")
set(FMTLIB_DIR "${EXTERNAL_DIR}/fmtlib")
set(ZLIB_DIR "${EXTERNAL_DIR}/zlib")
set(LIBPNG_DIR "${EXTERNAL_DIR}/libpng")
set(LIBARCHIVE_DIR "${EXTERNAL_DIR}/libarchive")
set(OPENAL_DIR "${EXTERNAL_DIR}/openal-soft/openal-soft-1.24.3-bin")
set(STB_DIR "${EXTERNAL_DIR}/stb")
set(CLIENT_DIR "${M59_ROOT}/clientd3d")
set(MODULE_DIR "${M59_ROOT}/module")
set(UTIL_DIR "${M59_ROOT}/util")
set(CLIENT_RUN_DIR "${M59_ROOT}/run/localclient")

# Path to generated files from native build (trig.c, trig.h, pal.c)
# This is passed in by the superbuild via -DGENERATED_DIR=...
if(NOT GENERATED_DIR)
    set(GENERATED_DIR "${CMAKE_BINARY_DIR}/generated")
endif()

# ---- C++20 defaults for targets that compile C as C++ ----
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ---- Common warning flags ----
# MinGW g++ may produce different warnings than MSVC. We match the original
# -Werror behavior but suppress known harmless warnings.
add_compile_options(
    $<$<COMPILE_LANGUAGE:CXX>:-Wno-write-strings>
    $<$<COMPILE_LANGUAGE:CXX>:-Wno-narrowing>
    $<$<COMPILE_LANGUAGE:CXX>:-Wno-deprecated-enum-enum-conversion>
    $<$<COMPILE_LANGUAGE:CXX>:-fms-extensions>
)

# MinGW C++ mode does not define _cdecl (single underscore);
# MSVC code uses it throughout. Map it to __cdecl.
add_compile_definitions($<$<COMPILE_LANGUAGE:CXX>:_cdecl=__cdecl>)

# ---- Helper: compile .c files as C++20 for a target ----
function(target_compile_as_cxx TARGET)
    set_target_properties(${TARGET} PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
        LINKER_LANGUAGE CXX
    )
    get_target_property(_sources ${TARGET} SOURCES)
    foreach(_src ${_sources})
        get_filename_component(_ext "${_src}" EXT)
        if(_ext STREQUAL ".c")
            set_source_files_properties("${_src}"
                TARGET_DIRECTORY ${TARGET}
                PROPERTIES LANGUAGE CXX
            )
        endif()
    endforeach()
endfunction()

# ---- External libraries ----
# These are static libraries linked into meridian.exe

# zlib - plain C (NOT C++, matching original -TC flag)
add_subdirectory(zlib)

# libpng - compiled as C++ (inherits default /TP from original build)
add_subdirectory(libpng)

# libarchive - plain C (NOT C++, matching original -TC flag)
add_subdirectory(libarchive)

# ---- Utility library ----
add_subdirectory(rscload)

# ---- Client executable ----
add_subdirectory(clientd3d)

# ---- Module DLLs ----
add_subdirectory(modules)

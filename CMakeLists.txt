# Meridian 59 - CMake Build System
#
# This is a superbuild: native targets (server, compiler, utilities, kod) are
# built directly, while the Windows client and modules are cross-compiled via
# MinGW-w64 using ExternalProject_Add with a separate toolchain file.
#
# Usage:
#   cmake -B build
#   cmake --build build -j$(nproc)
#
# Options:
#   -DCROSS_COMPILE_CLIENT=ON   Build Windows client/modules via MinGW (default: ON)
#   -DRELEASE=ON                Build with optimizations (default: OFF)

cmake_minimum_required(VERSION 3.20)
project(Meridian59 LANGUAGES CXX)

# ---- Options ----
option(CROSS_COMPILE_CLIENT "Cross-compile Windows client and modules via MinGW-w64" ON)
option(RELEASE "Build with optimizations (Release mode)" OFF)

# ---- Build type mapping ----
if(RELEASE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
else()
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "" FORCE)
endif()

# ---- Global paths ----
set(MERIDIAN59_ROOT    "${CMAKE_SOURCE_DIR}")
set(INCLUDE_DIR        "${MERIDIAN59_ROOT}/include")
set(EXTERNAL_DIR       "${MERIDIAN59_ROOT}/external")
set(FMTLIB_DIR         "${EXTERNAL_DIR}/fmtlib")
set(BIN_DIR            "${MERIDIAN59_ROOT}/bin")
set(SERVER_RUN_DIR     "${MERIDIAN59_ROOT}/run/server")
set(CLIENT_RUN_DIR     "${MERIDIAN59_ROOT}/run/localclient")
set(KOD_DIR            "${MERIDIAN59_ROOT}/kod")
set(KOD_INCLUDE_DIR    "${KOD_DIR}/include")

# ---- Helper modules ----
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(CompileAsCXX)

# ---- Common compile flags ----
# All C files are compiled as C++20 (set per-target via target_compile_as_cxx)
# Platform define and fmtlib unicode setting are applied per-target

# ---- Native targets ----
add_subdirectory(blakcomp)
add_subdirectory(blakserv)
add_subdirectory(util)
add_subdirectory(kod)

# ---- Native code generators for the client ----
# maketrig and makepal are small programs that generate lookup tables
# (trig.c, trig.h, pal.c) consumed by the cross-compiled client build.
# They must run on the host, so they're built with the native compiler.

set(GENERATED_DIR "${CMAKE_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${GENERATED_DIR}")

# maketrig: generates trig.c and trig.h (trigonometric lookup tables)
add_executable(maketrig
    "${MERIDIAN59_ROOT}/clientd3d/maketrig.c"
)
target_compile_as_cxx(maketrig)
target_include_directories(maketrig PRIVATE
    "${INCLUDE_DIR}"
    "${MERIDIAN59_ROOT}/clientd3d"
)

# makepal: generates pal.c (palette/lighting lookup tables)
add_executable(makepal
    "${MERIDIAN59_ROOT}/clientd3d/makepal.c"
)
target_compile_as_cxx(makepal)
target_include_directories(makepal PRIVATE
    "${MERIDIAN59_ROOT}/clientd3d"
)

# Custom command: run maketrig to produce trig.c and trig.h
add_custom_command(
    OUTPUT "${GENERATED_DIR}/trig.c" "${GENERATED_DIR}/trig.h"
    COMMAND maketrig "${GENERATED_DIR}"
    DEPENDS maketrig
    COMMENT "Generating trig.c and trig.h lookup tables"
    VERBATIM
)

# Custom command: run makepal to produce pal.c from blakston.pal
add_custom_command(
    OUTPUT "${GENERATED_DIR}/pal.c"
    COMMAND makepal "${MERIDIAN59_ROOT}/blakston.pal" "${GENERATED_DIR}"
    DEPENDS makepal "${MERIDIAN59_ROOT}/blakston.pal"
    COMMENT "Generating pal.c palette lookup tables"
    VERBATIM
)

# Target to drive generation of all code-gen outputs
add_custom_target(client_codegen
    DEPENDS
        "${GENERATED_DIR}/trig.c"
        "${GENERATED_DIR}/trig.h"
        "${GENERATED_DIR}/pal.c"
)

# ---- Cross-compiled client targets (MinGW-w64) ----
if(CROSS_COMPILE_CLIENT)
    include(ExternalProject)

    # Check that the MinGW toolchain is available
    find_program(MINGW_CXX x86_64-w64-mingw32-g++)
    if(NOT MINGW_CXX)
        message(WARNING
            "MinGW-w64 cross-compiler not found (x86_64-w64-mingw32-g++).\n"
            "Skipping client cross-compilation.\n"
            "Install with: sudo apt install mingw-w64\n"
            "Or disable with: -DCROSS_COMPILE_CLIENT=OFF")
    else()
        message(STATUS "MinGW-w64 found: ${MINGW_CXX}")
        message(STATUS "Client cross-compilation enabled")

        # Determine build type for cross-compile subtree
        if(RELEASE)
            set(_client_build_type Release)
        else()
            set(_client_build_type Debug)
        endif()

        ExternalProject_Add(client_win32
            SOURCE_DIR "${CMAKE_SOURCE_DIR}/client-win32"
            BINARY_DIR "${CMAKE_BINARY_DIR}/client-win32-build"

            CMAKE_ARGS
                -DCMAKE_TOOLCHAIN_FILE=${CMAKE_SOURCE_DIR}/cmake/mingw-w64-x86_64.cmake
                -DCMAKE_BUILD_TYPE=${_client_build_type}
                -DGENERATED_DIR=${GENERATED_DIR}

            # No install step — outputs stay in the build tree
            INSTALL_COMMAND ""

            # Build in parallel
            BUILD_ALWAYS ON
        )

        # Ensure code generators run before the cross-compile build configures
        add_dependencies(client_win32 client_codegen)
    endif()
endif()

# rscload - Static utility library for MinGW cross-compilation
#
# Contains resource loading and memory-mapped file support used by the client.
# Compiled as C++20 (matching the global /TP flag in the original build).

set(RSCLOAD_SOURCES
    ${UTIL_DIR}/rscload.c
    ${UTIL_DIR}/memmap.c
)

add_library(rscload STATIC ${RSCLOAD_SOURCES})

target_include_directories(rscload PUBLIC ${INCLUDE_DIR})

target_compile_as_cxx(rscload)

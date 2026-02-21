# zlib - Static library for MinGW cross-compilation
#
# Compiled as plain C (NOT C++), matching the original Windows makefile
# which uses -TC to override the global -TP flag.

set(ZLIB_SOURCES
    ${ZLIB_DIR}/adler32.c
    ${ZLIB_DIR}/compress.c
    ${ZLIB_DIR}/crc32.c
    ${ZLIB_DIR}/deflate.c
    ${ZLIB_DIR}/gzclose.c
    ${ZLIB_DIR}/gzlib.c
    ${ZLIB_DIR}/gzread.c
    ${ZLIB_DIR}/gzwrite.c
    ${ZLIB_DIR}/infback.c
    ${ZLIB_DIR}/inffast.c
    ${ZLIB_DIR}/inflate.c
    ${ZLIB_DIR}/inftrees.c
    ${ZLIB_DIR}/trees.c
    ${ZLIB_DIR}/uncompr.c
    ${ZLIB_DIR}/zutil.c
)

add_library(zlib STATIC ${ZLIB_SOURCES})

target_include_directories(zlib PUBLIC ${ZLIB_DIR})

# Keep as plain C — do NOT set LANGUAGE CXX
set_target_properties(zlib PROPERTIES LINKER_LANGUAGE C)

# libpng - Static library for MinGW cross-compilation
#
# Compiled as C++20 (matching the original Windows build which uses /TP globally).
# Depends on zlib for include path.

set(LIBPNG_SOURCES
    ${LIBPNG_DIR}/png.c
    ${LIBPNG_DIR}/pngerror.c
    ${LIBPNG_DIR}/pngget.c
    ${LIBPNG_DIR}/pngmem.c
    ${LIBPNG_DIR}/pngpread.c
    ${LIBPNG_DIR}/pngread.c
    ${LIBPNG_DIR}/pngrio.c
    ${LIBPNG_DIR}/pngrtran.c
    ${LIBPNG_DIR}/pngrutil.c
    ${LIBPNG_DIR}/pngset.c
    ${LIBPNG_DIR}/pngtrans.c
    ${LIBPNG_DIR}/pngwio.c
    ${LIBPNG_DIR}/pngwrite.c
    ${LIBPNG_DIR}/pngwtran.c
    ${LIBPNG_DIR}/pngwutil.c
)

add_library(libpng STATIC ${LIBPNG_SOURCES})

target_include_directories(libpng PUBLIC ${LIBPNG_DIR})
target_link_libraries(libpng PUBLIC zlib)

target_compile_as_cxx(libpng)

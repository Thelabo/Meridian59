# Meridian 59 - Blakod Compiler (bc)
#
# Compiles .kod source files into .bof bytecode and .rsc resource files.
# Uses flex/bison for the scanner and parser.

find_package(FLEX REQUIRED)
find_package(BISON REQUIRED)

# ---- Generated sources (flex/bison) ----
FLEX_TARGET(BlakcompScanner
    "${CMAKE_CURRENT_SOURCE_DIR}/blakcomp.l"
    "${CMAKE_CURRENT_BINARY_DIR}/lexyy.c"
    COMPILE_FLAGS "-I -i"
)

BISON_TARGET(BlakcompParser
    "${CMAKE_CURRENT_SOURCE_DIR}/blakcomp.y"
    "${CMAKE_CURRENT_BINARY_DIR}/blakcomp.tab.c"
    DEFINES_FILE "${CMAKE_CURRENT_BINARY_DIR}/blakcomp.tab.h"
    COMPILE_FLAGS "-t"
)

ADD_FLEX_BISON_DEPENDENCY(BlakcompScanner BlakcompParser)

# Mark generated .c files as CXX so they compile under LANGUAGES CXX.
# Must be done before add_executable so CMake knows their language at target creation.
set_source_files_properties(
    "${BISON_BlakcompParser_OUTPUT_SOURCE}"
    "${FLEX_BlakcompScanner_OUTPUTS}"
    PROPERTIES LANGUAGE CXX
)

# ---- Hand-written sources ----
set(BLAKCOMP_SOURCES
    actions.c
    table.c
    kodbase.c
    codegen.c
    codeutil.c
    function.c
    util.c
    sort.c
    optimize.c
    resource.c
)

# ---- Target ----
add_executable(bc
    ${BLAKCOMP_SOURCES}
    ${FLEX_BlakcompScanner_OUTPUTS}
    ${BISON_BlakcompParser_OUTPUT_SOURCE}
    ${BISON_BlakcompParser_OUTPUT_HEADER}
)

target_include_directories(bc PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}"
    "${INCLUDE_DIR}"
)

target_compile_definitions(bc PRIVATE
    BLAK_PLATFORM_LINUX
    FMT_UNICODE=0
)

target_compile_options(bc PRIVATE
    -Wno-unused-result
    -Werror
)

target_compile_as_cxx(bc)

# ---- Install: copy to bin/ ----
add_custom_command(TARGET bc POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${BIN_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:bc>" "${BIN_DIR}/"
    COMMENT "Copying bc to ${BIN_DIR}/"
)

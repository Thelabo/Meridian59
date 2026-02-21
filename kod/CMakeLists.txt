# Meridian 59 - Blakod Script Compilation
#
# Compiles .kod game scripts into .bof bytecode using the bc compiler.
# This is a custom target (not a C compilation) that depends on the bc executable.

find_package(Python3 REQUIRED COMPONENTS Interpreter)

add_custom_target(kod ALL
    COMMAND ${Python3_EXECUTABLE}
        "${CMAKE_SOURCE_DIR}/cmake/compile_kod.py"
        "$<TARGET_FILE:bc>"
        "${KOD_DIR}"
        "${SERVER_RUN_DIR}"
    DEPENDS bc
    WORKING_DIRECTORY "${KOD_DIR}"
    COMMENT "Compiling Blakod scripts"
    USES_TERMINAL
)

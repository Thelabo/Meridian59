# Helper module to compile .c files as C++20
#
# Meridian 59 compiles all C code as C++20 (-x c++ on GCC, /TP on MSVC).
# This module provides a function to set that up for a CMake target.
#
# Usage:
#   include(CompileAsCXX)
#   target_compile_as_cxx(my_target)

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

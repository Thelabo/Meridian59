# Meridian 59 - Utilities (rscmerge, rscprint)
#
# Small utility programs for working with .rsc resource files.

# ---- Shared source ----
set(RSCLOAD_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/rscload.c")

# ---- rscmerge ----
add_executable(rscmerge
    rscmerge.c
    ${RSCLOAD_SOURCE}
)

target_include_directories(rscmerge PRIVATE
    "${INCLUDE_DIR}"
)

target_compile_definitions(rscmerge PRIVATE
    BLAK_PLATFORM_LINUX
    FMT_UNICODE=0
)

target_compile_options(rscmerge PRIVATE
    -Wno-unused-result
    -Werror
)

target_compile_as_cxx(rscmerge)

# ---- rscprint ----
add_executable(rscprint
    rscprint.c
    ${RSCLOAD_SOURCE}
)

target_include_directories(rscprint PRIVATE
    "${INCLUDE_DIR}"
)

target_compile_definitions(rscprint PRIVATE
    BLAK_PLATFORM_LINUX
    FMT_UNICODE=0
)

target_compile_options(rscprint PRIVATE
    -Wno-unused-result
    -Werror
)

target_compile_as_cxx(rscprint)

# ---- Install: copy to bin/ ----
add_custom_command(TARGET rscmerge POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${BIN_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:rscmerge>" "${BIN_DIR}/"
    COMMENT "Copying rscmerge to ${BIN_DIR}/"
)

add_custom_command(TARGET rscprint POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${BIN_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:rscprint>" "${BIN_DIR}/"
    COMMENT "Copying rscprint to ${BIN_DIR}/"
)

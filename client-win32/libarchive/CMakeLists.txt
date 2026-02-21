# libarchive - Static library for MinGW cross-compilation
#
# Compiled as plain C (NOT C++), matching the original Windows makefile
# which uses -TC to override the global -TP flag.
# Requires -DHAVE_CONFIG_H to use the vendored config.h.

set(LIBARCHIVE_SOURCES
    ${LIBARCHIVE_DIR}/archive_acl.c
    ${LIBARCHIVE_DIR}/archive_check_magic.c
    ${LIBARCHIVE_DIR}/archive_cmdline.c
    ${LIBARCHIVE_DIR}/archive_cryptor.c
    ${LIBARCHIVE_DIR}/archive_digest.c
    ${LIBARCHIVE_DIR}/archive_disk_acl_darwin.c
    ${LIBARCHIVE_DIR}/archive_disk_acl_freebsd.c
    ${LIBARCHIVE_DIR}/archive_disk_acl_linux.c
    ${LIBARCHIVE_DIR}/archive_disk_acl_sunos.c
    ${LIBARCHIVE_DIR}/archive_entry.c
    ${LIBARCHIVE_DIR}/archive_entry_copy_bhfi.c
    ${LIBARCHIVE_DIR}/archive_entry_copy_stat.c
    ${LIBARCHIVE_DIR}/archive_entry_link_resolver.c
    ${LIBARCHIVE_DIR}/archive_entry_sparse.c
    ${LIBARCHIVE_DIR}/archive_entry_stat.c
    ${LIBARCHIVE_DIR}/archive_entry_strmode.c
    ${LIBARCHIVE_DIR}/archive_entry_xattr.c
    ${LIBARCHIVE_DIR}/archive_getdate.c
    ${LIBARCHIVE_DIR}/archive_hmac.c
    ${LIBARCHIVE_DIR}/archive_match.c
    ${LIBARCHIVE_DIR}/archive_options.c
    ${LIBARCHIVE_DIR}/archive_pack_dev.c
    ${LIBARCHIVE_DIR}/archive_pathmatch.c
    ${LIBARCHIVE_DIR}/archive_ppmd7.c
    ${LIBARCHIVE_DIR}/archive_random.c
    ${LIBARCHIVE_DIR}/archive_rb.c
    ${LIBARCHIVE_DIR}/archive_read.c
    ${LIBARCHIVE_DIR}/archive_read_add_passphrase.c
    ${LIBARCHIVE_DIR}/archive_read_append_filter.c
    ${LIBARCHIVE_DIR}/archive_read_data_into_fd.c
    ${LIBARCHIVE_DIR}/archive_read_disk_entry_from_file.c
    ${LIBARCHIVE_DIR}/archive_read_disk_posix.c
    ${LIBARCHIVE_DIR}/archive_read_disk_set_standard_lookup.c
    ${LIBARCHIVE_DIR}/archive_read_disk_windows.c
    ${LIBARCHIVE_DIR}/archive_read_extract.c
    ${LIBARCHIVE_DIR}/archive_read_extract2.c
    ${LIBARCHIVE_DIR}/archive_read_open_fd.c
    ${LIBARCHIVE_DIR}/archive_read_open_file.c
    ${LIBARCHIVE_DIR}/archive_read_open_filename.c
    ${LIBARCHIVE_DIR}/archive_read_open_memory.c
    ${LIBARCHIVE_DIR}/archive_read_set_format.c
    ${LIBARCHIVE_DIR}/archive_read_set_options.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_all.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_bzip2.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_compress.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_grzip.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_gzip.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_lrzip.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_lz4.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_lzop.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_none.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_program.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_rpm.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_uu.c
    ${LIBARCHIVE_DIR}/archive_read_support_filter_xz.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_7zip.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_all.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_ar.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_by_code.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_cab.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_cpio.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_empty.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_iso9660.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_lha.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_mtree.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_rar.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_raw.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_tar.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_warc.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_xar.c
    ${LIBARCHIVE_DIR}/archive_read_support_format_zip.c
    ${LIBARCHIVE_DIR}/archive_string.c
    ${LIBARCHIVE_DIR}/archive_string_sprintf.c
    ${LIBARCHIVE_DIR}/archive_util.c
    ${LIBARCHIVE_DIR}/archive_version_details.c
    ${LIBARCHIVE_DIR}/archive_virtual.c
    ${LIBARCHIVE_DIR}/archive_windows.c
    ${LIBARCHIVE_DIR}/archive_write.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_b64encode.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_by_name.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_bzip2.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_compress.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_grzip.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_gzip.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_lrzip.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_lz4.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_lzop.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_none.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_program.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_uuencode.c
    ${LIBARCHIVE_DIR}/archive_write_add_filter_xz.c
    ${LIBARCHIVE_DIR}/archive_write_disk_posix.c
    ${LIBARCHIVE_DIR}/archive_write_disk_set_standard_lookup.c
    ${LIBARCHIVE_DIR}/archive_write_disk_windows.c
    ${LIBARCHIVE_DIR}/archive_write_open_fd.c
    ${LIBARCHIVE_DIR}/archive_write_open_file.c
    ${LIBARCHIVE_DIR}/archive_write_open_filename.c
    ${LIBARCHIVE_DIR}/archive_write_open_memory.c
    ${LIBARCHIVE_DIR}/archive_write_set_format.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_7zip.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_ar.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_by_name.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_cpio.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_cpio_newc.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_filter_by_ext.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_gnutar.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_iso9660.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_mtree.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_pax.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_raw.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_shar.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_ustar.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_v7tar.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_warc.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_xar.c
    ${LIBARCHIVE_DIR}/archive_write_set_format_zip.c
    ${LIBARCHIVE_DIR}/archive_write_set_options.c
    ${LIBARCHIVE_DIR}/archive_write_set_passphrase.c
    ${LIBARCHIVE_DIR}/filter_fork_posix.c
    ${LIBARCHIVE_DIR}/filter_fork_windows.c
    ${LIBARCHIVE_DIR}/xxhash.c
)

add_library(libarchive STATIC ${LIBARCHIVE_SOURCES})

target_include_directories(libarchive PUBLIC ${LIBARCHIVE_DIR})
target_compile_definitions(libarchive PRIVATE HAVE_CONFIG_H)
target_link_libraries(libarchive PUBLIC zlib)

# Keep as plain C — do NOT set LANGUAGE CXX
set_target_properties(libarchive PROPERTIES LINKER_LANGUAGE C)

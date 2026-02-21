#!/usr/bin/env python3
"""
Blakod compilation script for CMake.

Walks the kod/ directory tree and compiles .kod files in dependency order,
mirroring the recursive makefile structure. Each directory's makefile defines
BOFS, BOFS2, ..., BOFS8 groups that must compile in order. After compiling
local .kod files, subdirectories are recursed into (in BOFS order).

Usage:
    python3 compile_kod.py <bc_path> <kod_dir> <server_run_dir>

"""

import os
import re
import subprocess
import sys
import shutil


def parse_makefile_bofs(makefile_path):
    if not os.path.exists(makefile_path):
        return [], None

    with open(makefile_path, 'r') as f:
        content = f.read()

    content = content.replace('\\\n', ' ')

    groups = []
    depend = None

    for line in content.split('\n'):
        line = line.strip()

        m = re.match(r'^DEPEND\s*=\s*(.*)', line)
        if m:
            depend = m.group(1).strip()
            continue

        m = re.match(r'^(BOFS\d*)\s*=\s*(.*)', line)
        if m:
            group_name = m.group(1)
            bofs_str = m.group(2).strip()
            bof_files = [b for b in bofs_str.split() if b.endswith('.bof')]
            if bof_files:
                groups.append((group_name, bof_files))

    # BOFS < BOFS2 < ... < BOFS8 ordering is critical for dependency resolution
    groups.sort(key=lambda x: x[0])

    return groups, depend


def compile_directory(bc_path, kod_dir, directory, server_run_dir, kod_include_dir):
    makefile_path = os.path.join(directory, 'makefile')
    groups, depend = parse_makefile_bofs(makefile_path)

    if not groups:
        return True

    kodbase_path = os.path.join(kod_dir, 'kodbase.txt')
    loadkod_dir = os.path.join(server_run_dir, 'loadkod')
    rsc_dir = os.path.join(server_run_dir, 'rsc')

    for group_name, bof_files in groups:
        # Compile all .kod files in this group before recursing into
        # subdirectories — kodbase.txt is built incrementally and later
        # files depend on classes defined by earlier ones.
        for bof_file in bof_files:
            kod_file = bof_file.replace('.bof', '.kod')
            kod_path = os.path.join(directory, kod_file)

            if os.path.exists(kod_path):
                cmd = [
                    bc_path, '-d',
                    '-I', kod_include_dir,
                    '-K', kodbase_path,
                    kod_file
                ]
                print(f'  Compiling {os.path.relpath(kod_path, kod_dir)}')
                result = subprocess.run(cmd, cwd=directory,
                                       capture_output=True, text=True)
                if result.returncode != 0:
                    print(f'ERROR compiling {kod_path}:', file=sys.stderr)
                    if result.stdout:
                        print(result.stdout, file=sys.stderr)
                    if result.stderr:
                        print(result.stderr, file=sys.stderr)
                    return False

                bof_path = os.path.join(directory, bof_file)
                if os.path.exists(bof_path):
                    shutil.copy2(bof_path, loadkod_dir)

                rsc_file = bof_file.replace('.bof', '.rsc')
                rsc_path = os.path.join(directory, rsc_file)
                if os.path.exists(rsc_path):
                    shutil.copy2(rsc_path, rsc_dir)

        for bof_file in bof_files:
            subdir_name = bof_file.replace('.bof', '')
            subdir_path = os.path.join(directory, subdir_name)
            if os.path.isdir(subdir_path):
                if not compile_directory(bc_path, kod_dir, subdir_path,
                                         server_run_dir, kod_include_dir):
                    return False

    return True


def main():
    if len(sys.argv) != 4:
        print(f'Usage: {sys.argv[0]} <bc_path> <kod_dir> <server_run_dir>',
              file=sys.stderr)
        sys.exit(1)

    bc_path = os.path.abspath(sys.argv[1])
    kod_dir = os.path.abspath(sys.argv[2])
    server_run_dir = os.path.abspath(sys.argv[3])

    if not os.path.exists(bc_path):
        print(f'ERROR: bc compiler not found at {bc_path}', file=sys.stderr)
        sys.exit(1)

    if not os.path.isdir(kod_dir):
        print(f'ERROR: kod directory not found at {kod_dir}', file=sys.stderr)
        sys.exit(1)

    loadkod_dir = os.path.join(server_run_dir, 'loadkod')
    rsc_dir = os.path.join(server_run_dir, 'rsc')
    os.makedirs(loadkod_dir, exist_ok=True)
    os.makedirs(rsc_dir, exist_ok=True)

    kodbase_path = os.path.join(kod_dir, 'kodbase.txt')
    if os.path.exists(kodbase_path):
        os.remove(kodbase_path)

    kod_include_dir = os.path.join(kod_dir, 'include')

    print(f'Compiling Blakod scripts from {kod_dir}')
    print(f'  bc compiler: {bc_path}')
    print(f'  Output: {server_run_dir}')

    if not compile_directory(bc_path, kod_dir, kod_dir, server_run_dir,
                             kod_include_dir):
        print('ERROR: Blakod compilation failed', file=sys.stderr)
        sys.exit(1)

    if os.path.exists(kodbase_path):
        shutil.copy2(kodbase_path, server_run_dir)

    for khd_file in os.listdir(kod_include_dir):
        if khd_file.endswith('.khd'):
            shutil.copy2(os.path.join(kod_include_dir, khd_file),
                         server_run_dir)

    print('Blakod compilation complete')


if __name__ == '__main__':
    main()

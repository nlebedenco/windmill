#!/usr/bin/env python

import os
import sys
import shutil
import pathlib

from argparse import ArgumentParser


def main():
    def copy(src, dst):
        new = dst.joinpath(src.name) if dst.is_dir() else dst
        if not new.exists() or (src.stat().st_mtime - new.stat().st_mtime) > 0:
            shutil.copy(src, dst)

    # Find project root
    sentinel = 'windmill.md'
    rootdir = os.path.dirname(os.path.realpath(__file__))
    while rootdir and not os.path.exists(os.path.join(rootdir, sentinel)):
        parent = os.path.dirname(rootdir)
        rootdir = "" if rootdir == parent else parent
    if not rootdir:
        sys.stderr.write(
            'ERROR: Project root could not be determined. There should be a {0} file in one of the parent folders '
            ' of this script to serve as an indication of the project root.\n'.format(sentinel))
        sys.exit(1)
    os.chdir(rootdir)

    parser = ArgumentParser(description='A simple script to copy DLL files with their corresponding PDBs.',
                            allow_abbrev=False)
    parser.prog = os.path.splitext(os.path.basename(sys.argv[0]))[0]
    parser.add_argument('destdir', type=pathlib.Path, help='distination directory')
    parser.add_argument('files', nargs='*', type=pathlib.Path, help='DLLs to copy')
    args = parser.parse_args()

    if not args.destdir.is_dir():
        parser.exit(1, "error: directory not found: '{0}'\n".format(args.destdir))

    try:
        if args.files:
            for dllpath in args.files:
                if dllpath.suffix.lower() != '.dll':
                    parser.exit(1, "error: file is not a DLL: '{0}'\n".format(dllpath))
            for dllpath in args.files:
                copy(dllpath, args.destdir)
                pdbpath = dllpath.with_suffix('.pdb')
                if pdbpath.is_file():
                    copy(pdbpath, args.destdir)
    except Exception as e:
        parser.exit(1, 'error: {0}\n'.format(e))


if __name__ == '__main__':
    sys.exit(main())

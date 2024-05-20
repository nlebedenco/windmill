#!/usr/bin/env python3

"""
Wrapper script for compiler tools that accept arguments in the form [ARGS] <FILE>. It can can filter out undesired
arguments based on regular expressions and/or ignore specific input paths before invoking the underlying command.
tool.
"""

import argparse
import os
import re
import sys
import yaml

from subprocess import run


def main():
    i = sys.argv.index('--')
    argv = sys.argv[1:i]
    xargv = sys.argv[i + 1:]

    parser = argparse.ArgumentParser(
        usage='%(prog)s  [-h] [--config-file CONFIG] executable [-- args...]',
        description='Invoke include-what-you-use by pre-filtering compiler arguments and input files.')
    parser.add_argument('executable',
                        help='path to include-what-you-use executable')
    parser.add_argument('--config-file', dest='config', default='',
                        help='path to config file')

    args = parser.parse_args(argv)

    # Special case for include-what-you-use
    # Remove -iXiwyu options from xargs to prevent accidental exclusions
    i = len(xargv) - 1
    while i >= 0:
        if xargv[i] == '-iXiwyu':
            xargv.pop(i)
            if i < len(xargv) - 1:
                xargv.pop(i)
        else:
            i -= 1

    # Load config file
    settings = {}
    if args.config:
        with open(args.config, 'r') as file:
            settings = yaml.safe_load(file)

    # Select arguments to relay
    excluded = settings.get('ExcludeArguments', [])
    for item in excluded:
        regex = item.get('Regex', '')
        extra = item.get('Values', 0)
        if regex:
            if not xargv:
                break
            i = 0
            n = len(xargv)
            selected = []
            while i < n:
                if re.search(regex, xargv[i]):
                    m = min(n, i + extra)
                    i += 1
                    # skip extra arguments that do not start with '-'
                    while i < m and not xargv[i].startswith('-'):
                        i += 1
                else:
                    selected.append(xargv[i])
                    i += 1
            xargv = selected

    # The translation unit is assumed to be the last argument in xargv. It must exist and it must be a file. These
    # conditions are not strictly sufficient to guarantee the last argument is in fact a translation unit but should be
    # enough to cover normal use cases without having to implement a complete argument parser for the external tool.
    #
    # If command-line arguments are malformed, there is a chance the last item in xargv may point to a valid file that
    # is not the intended translation unit. For example, if the last two items in xargv are:
    #
    #   '-imacros', 'myheader.h'
    #
    # Then we will pick 'myheader.h' for the translation unit to match against exclusion rules which might lead to an
    # unintended exclusion. And this would have been a silent error. As a mitigation we also match the translation unit
    # path to what we expect to be a reasonable source file path (e.g. file name must end with .c|.cxx|.cpp|.cc). For
    # the eventual cases where the last argument is not valid but still passes our verifications the tool should
    # normally produce an error (e.g. if the last items are '-imacros', 'myheader.c' the underlying executable will
    # ultimately raise "error: no input files").
    translation_unit = xargv[-1] if xargv else ''
    if not re.match(r'(([^-/ ][^/]*)|(/[^/]+))(/[^/]+)*/.+\.(c|cpp|cxx|cc)', translation_unit):
        parser.error('invalid input file: ' + translation_unit)

    if not os.path.isfile(translation_unit):
        parser.error('file not found: ' + translation_unit)

    # Check if source file must be ignored
    ignore = False
    expressions = settings.get('IgnoreSources', [])
    for regex in expressions:
        if regex:
            if re.search(regex, translation_unit):
                ignore = True
                break

    if not ignore:
        return run([args.executable] + xargv, check=False).returncode

    return 0


if __name__ == '__main__':
    sys.exit(main())

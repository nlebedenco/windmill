#!/usr/bin/env python
"""
Utility script for common repository tasks
"""

import os
import platform
import subprocess
import sys
import tempfile

from argparse import ArgumentParser, HelpFormatter, RawDescriptionHelpFormatter
from subprocess import run


class CommandArgumentParser(ArgumentParser):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def print_help(self, file=None):
        super().print_help(file)

    def check_no_unparsed(self, unparsed):
        if unparsed:
            self.error('unrecognized arguments: {0}'.format(', '.join(f"'{x}'" for x in unparsed)))


# HACK: Prevent the formatter from putting a line break in the beginning of a help text when the action name is
#       longer than any other
class HackedHelpFormatter(HelpFormatter):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    # noinspection PyProtectedMember
    def _format_action(self, action):
        self._action_max_length += 1
        try:
            return super()._format_action(action)
        finally:
            self._action_max_length -= 1


def main():
    def git_repo_name(url):
        # The "humanish" part of the source repository is used if no directory is explicitly given
        # (repo for /path/to/repo.git and foo for host.xz:foo/.git).
        (path, extension) = os.path.splitext((':' + url).rsplit(':', maxsplit=1)[1])
        if extension == '.git':
            return os.path.basename(path)
        basename = os.path.basename(path)
        return os.path.basename(os.path.dirname(path)) if basename == '.git' else basename

    # Find project root
    sentinel = 'windmill.md'
    rootdir = os.path.dirname(os.path.realpath(__file__))
    while rootdir and not os.path.exists(os.path.join(rootdir, sentinel)):
        parent = os.path.dirname(rootdir)
        rootdir = '' if rootdir == parent else parent
    if not rootdir:
        sys.stderr.write('error: project root could not be determined: file {0} was not found in any of the parent'
                         ' folders of this script to serve as an indication of the project root.\n'.format(sentinel))
        sys.exit(1)
    os.chdir(rootdir)

    parser = ArgumentParser(description='A wrapper script for common project operations.',
                            formatter_class=HackedHelpFormatter,
                            allow_abbrev=False)
    parser.prog = os.path.splitext(os.path.basename(sys.argv[0]))[0]
    subparsers = parser.add_subparsers(dest='command', metavar='COMMAND', parser_class=CommandArgumentParser)
    commands = type('', (object,), {key: None for key in [
        'sync', 'status'
    ]})()
    # COMMAND: sync
    commands.sync = subparsers.add_parser('sync', help='sync refs from a SOURCE repository to a DESTINATION repository'
                                                       ' (does not affect the working copy; SOURCE and DESTINATION must have the same base name)',
                                          allow_abbrev=False)
    commands.sync.add_argument('source', metavar='SOURCE',
                               help='source repository to mirror (e.g. git@github.com:other/bar.git)')
    commands.sync.add_argument('dest', metavar='DESTINATION',
                               help='destination repository (e.g. git@github.com:my/bar.git)')
    # COMMAND: status
    commands.status = subparsers.add_parser('status', help='show status information of the working copy',
                                            allow_abbrev=False)
    commands.status.add_argument('--recursive', action='store_true',
                                 help='include nested submodules in the report')
    try:
        args, unparsed = parser.parse_known_args()
        if args.command == 'sync':
            commands.sync.check_no_unparsed(unparsed)
            # Source and upstream cannot be the same repository
            if args.source == args.dest:
                commands.sync.error('SOURCE and DESTINATION cannot be the same')
            # The upstream basename should match the source basename . This is not strictly required by git, but
            # it is a reasonable convention to avoid accidentally fusing completely unrelated repositories in a
            # bad sync operation.
            if git_repo_name(args.dest) != git_repo_name(args.source):
                commands.sync.error('SOURCE and DESTINATION repositories must have the same base name'
                                    ' (e.g. repo for "/path/to/repo.git" and foo for "host.xz:foo/.git")')
            # Create a bare clone in a temp directory
            with tempfile.TemporaryDirectory() as tmpdir:
                # GitHub's repositories may contain hidden refs used to track pull requests which will cause errors in
                # mirror clones, so we clone with --bare and then fetch with a refspec instead
                # See https://stackoverflow.com/a/34266401
                print("Fetching from {0}".format(args.source))
                run(['git', 'clone', '--bare', args.source, tmpdir], check=True)
                run(['git', '-C', tmpdir, 'fetch', 'origin',
                     '+refs/heads/*:refs/heads/*',
                     '+refs/tags/*:refs/tags/*'
                     ], check=True)
                # Note that large repos pushed to GitHub may time out because GitHub caps the upload speed at 1MiB/s
                # In this case the only possible workaround is to manually push refs one at a time from oldest to newest
                # and lastly push tags.
                print("Pushing to {0}".format(args.dest))
                run(['git', '-C', tmpdir, 'push', args.dest,
                     'refs/heads/*:refs/heads/*',
                     'refs/tags/*:refs/tags/*'
                     ], check=True)
        elif args.command == 'status':
            commands.status.check_no_unparsed(unparsed)
            # Print project status
            smhash = run(['git', 'rev-parse', 'HEAD'], check=True,
                         stdout=subprocess.PIPE).stdout.decode().strip()
            smtag = run(['git', 'describe', '--tags', '--always', '--long', '--dirty', '--broken'], check=True,
                        stdout=subprocess.PIPE).stdout.decode().strip()
            # It's OK for `git remote get-url` to fail (happens when the clone does not have an origin set up)
            smurl = run(['git', 'remote', 'get-url', 'origin'], check=False,
                        stdout=subprocess.PIPE).stdout.decode().strip()
            print(' {0} {1} ({2}) {3}'.format(smhash, '[root]', smtag, smurl))
            # Print submodules status
            cmdline = ['git', 'submodule', 'foreach', '-q']
            if args.recursive:
                cmdline.append('--recursive')
            cmdline.append('printf " %s %s %s\\n"'
                           ' "`git rev-parse HEAD`"'
                           ' "$displaypath (`git describe --tags --always --long --dirty --broken`)"'
                           ' "`git remote get-url origin`"')
            run(cmdline, check=True)
        else:
            parser.print_help()
            parser.exit(1)
    except subprocess.CalledProcessError as e:
        parser.exit(e.returncode)
    return 0


if __name__ == '__main__':
    sys.exit(main())

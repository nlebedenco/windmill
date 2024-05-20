#!/usr/bin/env python3

# Helper script to replace all occurences of a string in file.

import sys
from pathlib import Path

if len(sys.argv) != 2:
    print("usage: %s <filename>", sys.argv[0])
    sys.exit(1)

fname = sys.argv[1]
Path(fname).write_text(Path(fname).read_text().replace('\\\\', '/'))

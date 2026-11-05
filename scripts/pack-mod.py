#!/usr/bin/env python3
"""CLI alias for pack_mod.py (hyphenated filename for docs/habits)."""

from __future__ import annotations

import sys
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from pack_mod import main

if __name__ == "__main__":
    raise SystemExit(main())

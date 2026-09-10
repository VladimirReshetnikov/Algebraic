#!/bin/sh
cd "$(dirname "$0")" || exit 1
exec python3 download_all.py --include-candidates --zip radical_literature.zip

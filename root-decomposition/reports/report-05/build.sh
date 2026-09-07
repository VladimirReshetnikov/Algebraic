#!/bin/sh
set -eu
cd "$(dirname "$0")"
pdflatex -interaction=nonstopmode -halt-on-error root_decomposition.tex
pdflatex -interaction=nonstopmode -halt-on-error root_decomposition.tex

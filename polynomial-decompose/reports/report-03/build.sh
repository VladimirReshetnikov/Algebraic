#!/bin/sh
# Run from any directory. The LaTeX source contains its bibliography and code.
set -eu
cd "$(dirname "$0")/article"
command -v pdflatex >/dev/null 2>&1 || {
  echo 'pdfLaTeX is required to rebuild the article.' >&2
  exit 1
}
pdflatex -interaction=nonstopmode -halt-on-error article.tex
pdflatex -interaction=nonstopmode -halt-on-error article.tex
pdflatex -interaction=nonstopmode -halt-on-error article.tex
printf '\nBuilt %s/article.pdf\n' "$(pwd)"

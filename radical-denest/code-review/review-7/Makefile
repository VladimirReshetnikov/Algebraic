PYTHON ?= python
PDFLATEX ?= pdflatex
WOLFRAMSCRIPT ?= wolframscript

.PHONY: pdf independent native
pdf:
	$(PDFLATEX) -interaction=nonstopmode -halt-on-error article.tex
	$(PDFLATEX) -interaction=nonstopmode -halt-on-error article.tex

independent:
	$(PYTHON) code/build_improved.py
	$(PYTHON) tests/verify_independent.py

native:
	$(WOLFRAMSCRIPT) -file tests/run_tests.wls

.PHONY: article tests benchmark clean
article:
	python tools/build_validation_table.py
	cd article && pdflatex -interaction=nonstopmode -halt-on-error SystematicRadicals.tex
	cd article && pdflatex -interaction=nonstopmode -halt-on-error SystematicRadicals.tex
tests:
	python -m pytest -q tests
benchmark:
	python tools/benchmark.py validation/benchmark.json
clean:
	rm -f article/*.aux article/*.log article/*.out article/*.toc

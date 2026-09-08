.PHONY: test pdf examples clean

test:
	PYTHONPATH=python python -m pytest tests/test_radicalroot.py -v

examples:
	PYTHONPATH=python python examples/basic.py

pdf:
	cd article && pdflatex -interaction=nonstopmode -halt-on-error radicalroot.tex
	cd article && pdflatex -interaction=nonstopmode -halt-on-error radicalroot.tex

clean:
	rm -f article/*.aux article/*.log article/*.out article/*.toc

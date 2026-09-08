.PHONY: test article demo clean

test:
	python tests/run_validation.py

demo:
	python examples/demo.py

article:
	cd article && pdflatex -interaction=nonstopmode -halt-on-error root-radicals.tex
	cd article && pdflatex -interaction=nonstopmode -halt-on-error root-radicals.tex

clean:
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	rm -f article/*.aux article/*.log article/*.out article/*.toc

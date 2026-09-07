.PHONY: all validate clean

all: article.pdf

article.pdf: article.tex RootDecomposition.wl
	pdflatex -interaction=nonstopmode -halt-on-error article.tex
	pdflatex -interaction=nonstopmode -halt-on-error article.tex

validate:
	python validate_independently.py > validation.txt

clean:
	rm -f article.aux article.log article.out article.toc

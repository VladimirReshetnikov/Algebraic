.PHONY: pdf validate wolfram-tests clean
pdf:
	cd article && latexmk -pdf -interaction=nonstopmode -halt-on-error algebraic-decomposition.tex
validate:
	python validation/reference_validation.py
	python validation/check_wl_structure.py
wolfram-tests:
	wolframscript -file Tests/RunTests.wls
clean:
	cd article && latexmk -c algebraic-decomposition.tex

# Simplifying Square Roots of Square Roots by Denesting


Source: `denest.pdf` and its paired Mathpix LaTeX in the supplied `articles.zip`.


## Build

Run `pdflatex -interaction=nonstopmode -halt-on-error denest.tex` twice in this directory. No downloaded fonts, images, or nonstandard local style files are required.


## Corrections and editorial decisions


1. **OCR authorship.** Restored David J. Jeffrey and his affiliation, The University of Western Ontario. The OCR title block omitted this entire coauthor. Retained Albert D. Rich and Soft Warehouse, Inc. Both are visible on original p.1.

2. **OCR structure.** Restored all eight numbered footnotes at their actual anchors, including the jokes. Removed repeated book footers intruding into prose/code, rejoined paragraphs split at page boundaries, restored the TeX logo, and reconstructed the split recursive listing as one block.

3. **OCR.** In the T=3 pseudocode branch, repaired 4XY-Z^-2 to 4XY-Z^2; the original p.8 has the ordinary square.

4. **Original mathematical correction.** The product-of-radicals claim in Section 4.7.3 needs integer (or rational) radicands; it is not true for arbitrary nested radicals. Specified the positive-integer surd case actually used in that argument.

5. **Mathematical convention.** Included the arbitrary integration constant in (4.7) and its specialization. Historical statements about numerical precision and CAS behavior are retained as examples from the original software context, not universal floating-point guarantees.

6. **Original mathematical qualification.** Made the ordering A>=B explicit in (4.11), which is necessary for the principal square root to equal sqrt(A)-sqrt(B).

7. **Original algorithm qualification.** Section 4.8 is a heuristic sketch, not a termination proof. Added an explicit editorial note about X>=|Y|, the Y=0 case, base cases, cycles, a well-founded recursive descent or finite search budget, and exact candidate verification. Qualified "covers all cases" so it does not assert completeness. The historical pseudocode is retained rather than silently replaced by a different algorithm.

8. **Original bibliography correction.** Corrected the page range of Landau, A Note on Zippel Denesting, to 41--46.

9. **Typesetting.** Replaced the OCR-generated preamble with a self-contained pdfLaTeX source; embedded Latin Modern text/math fonts, microtypography, readable margins, proper display environments, continuous paragraphs, running headers, PDF metadata, and structured lists/references. Original section/equation numbering is preserved; output page numbers differ from the source.

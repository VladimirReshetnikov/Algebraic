# When Close Enough Is Close Enough


Source: `scheinerman2000.pdf` and its paired Mathpix LaTeX in the supplied `articles.zip`.


## Build

Run `pdflatex -interaction=nonstopmode -halt-on-error scheinerman2000.tex` twice in this directory. No downloaded fonts, images, or nonstandard local style files are required.


## Corrections and editorial decisions


1. **OCR.** Restored all eight section headings; converted broken paragraph/list boundaries and dialogue line breaks to normal LaTeX structure, and removed the duplicate title/caption machinery.

2. **Original mathematical error.** Proposition 3 concerns potentially complex eigenvectors. Replaced the bilinear dot product by the Hermitian inner product, including conjugation of v_i; normalized v* v rather than v·v.

3. **Original mathematical error.** Corrected the rectangular Kronecker-product dimension statement: A is p×q and B is r×s, so v has q entries and w has s entries. Made the k=0 integer bound and zero cases of Proposition 6 consistent with the positive b convention.

4. **Figure.** Redrew Figure 1 as a vector TikZ computation graph, preserving the input values, operations, and all Λ(n,b) classifications. No external image file is needed.

5. **Original numerical errors.** Replaced the unsupported Λ(9288,1893) / exponent −1892 combination by the explicit valid bound Λ(216,1979), with threshold (216·1979)^−215≈2.27×10^−1211. Corrected the matrix polynomial estimate from 11098 to 11224=6·43²+3·43+1 and its separation threshold to approximately 7.22×10^−25 (the printed exponent −23 was also wrong).

6. **Original mathematical error.** Corrected the multiple-angle substitution from theta=pi to theta=pi/7; explicitly defined beta=p(alpha) before using it in the preceding example.

7. **Original mathematical error.** In Section 7, the coefficient bound for a sum of square roots is the sum of the radicands, not their product; restored 2^t, the correct final index, positive integer radicands, and the absolute-value test.

8. **Original proof gap / verification.** Qualified every equality-by-decimal argument: a rigorous enclosure is required, not merely a printed zero or precision setting. Added verify_intervals.py, independently run using only Python integer arithmetic, outward rounding, integer roots, Machin’s formula and explicitly bounded Taylor series. It encloses the student residual, both polynomial-recognition residuals, and the trigonometric residual in absolute value below 10^−170. The code’s exact endpoint results are recorded below.

9. **Exact check results.** With denominator 10^180, the four interval numerators are respectively [−4,2], [−26,43], [−14,5], and [−7801,7811]. These enclosures are far narrower than the corresponding proven separation thresholds. This check does not use unvalidated floating-point “zero” output.

10. **Historical software/bibliography.** Restored Mathematica package-context backticks in NumberTheory`Recognize`; retained the period software example and legacy web addresses as historical material. Corrected ACM–SIAM, SIAM, Springer-Verlag, Zippel, the 41–46 page range, and the broken LEDA URL. The final author biography describes the original publication period, not a current appointment.

11. **Typesetting.** Replaced the OCR-generated preamble with a self-contained pdfLaTeX source; embedded Latin Modern text/math fonts, microtypography, readable margins, proper display environments, continuous paragraphs, running headers, PDF metadata, and structured lists/references. Original section/equation numbering is preserved; output page numbers differ from the source.

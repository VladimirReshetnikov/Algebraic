# On the denesting of nested square roots


Source: `gkioulekas2017.pdf` and its paired Mathpix LaTeX in the supplied `articles.zip`.


## Build

Run `pdflatex -interaction=nonstopmode -halt-on-error gkioulekas2017.tex` twice in this directory. No downloaded fonts, images, or nonstandard local style files are required.


## Corrections and editorial decisions


1. **Original factual correction.** Replaced the unsupported dependence on syntactic radical depth by the splitting-field requirement and the exponential running-time statement in the 1992 abstract (DOI 10.1137/0221009). This is not a claim of exponential complexity in the explicit splitting-field degree. Historical open-problem statements in the introduction/conclusion are retained as the author's 2017 discussion, not presented as a survey of 2026 literature.

2. **Original mathematical correction.** Definition 2.1 originally required a>0, contradicting Theorem 2.2 and the negative-a examples. Allowed rational a, required a positive real radicand, and separated the sign chosen in an indirect denesting from the sign of the inner radical.

3. **OCR.** Removed the spurious overbar in the application of Lemma 2.1.

4. **OCR.** Restored the missing implication arrow in Lemma 2.4, Case 1.

5. **Original cross-reference correction.** The coefficient comparison in (5) uses Lemma 2.2, not Lemma 2.3 (which concerns the roots of a quadratic).

6. **OCR reconstruction.** Reconstructed the badly scrambled equivalence chains in the proof of Theorem 2.1 from original pp.5--6, including the missing final x>y branch selection. Repaired malformed cases/braces, lost arrows, annotation placement, and paragraph joins throughout Section 2.

7. **Original mathematical qualification.** The real-valued formula (4) also needs a^2-b>=0; positivity of a and b alone does not make its discriminant real.

8. **Original arithmetic correction.** Example 3.1 ends in 5+4*sqrt(3) in the PDF; corrected to 5+2*sqrt(3), since sqrt(12)=2*sqrt(3). Squaring verifies 37+20*sqrt(3).

9. **Original formula correction.** Corrected the radical-bar placement in Example 4.1: it is the sum of two square roots, not a square root over the sum. The PDF itself has the malformed bars.

10. **Bibliography.** Corrected Blömer, Pittsburgh, and the two Landau article page ranges (41--46 and 85--110); removed the OCR copyright glyph that represented the ORCID icon.

11. **Original mathematical qualification.** Equations (9) and (11) invoke Theorems 2.1--2.2 and therefore do not cover a=0, b=0, or rational sqrt(q/p). Added those hypotheses and separated the elementary degenerate cases.

12. **Original proof qualification.** Separated the negative-discriminant case before comparing the quadratic roots with zero, so all order comparisons in the proof of Theorem 2.1 concern real numbers.

13. **Typesetting.** Replaced the OCR-generated preamble with a self-contained pdfLaTeX source; embedded Latin Modern text/math fonts, microtypography, readable margins, proper display environments, continuous paragraphs, running headers, PDF metadata, and structured lists/references. Original section/equation numbering is preserved; output page numbers differ from the source.

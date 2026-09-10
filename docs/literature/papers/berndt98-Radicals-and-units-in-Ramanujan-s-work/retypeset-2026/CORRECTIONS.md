# Radicals and units in Ramanujan's work


Source: `aa8725.pdf` and its paired Mathpix LaTeX in the supplied `articles.zip`.


## Build

Run `pdflatex -interaction=nonstopmode -halt-on-error aa8725.tex` twice in this directory. No downloaded fonts, images, or nonstandard local style files are required.


## Corrections and editorial decisions


1. **Original mathematical qualification.** In the proof of Theorem 2.1(d), specified nonnegative real a,b,c,d; squaring alone does not establish the displayed principal-square-root identity for arbitrary signed or complex numbers.

2. **Original mathematical correction.** The assertion that n*a being integral suffices for every n is false. For n=6 and a=1/6, (7/6)^(1/6)-(1/6)^(1/6) has primitive irreducible polynomial 432*x^36-3456*x^30-220824*x^24-2319392*x^18-238149*x^12-819936*x^6+432; its monic minimal polynomial has nonintegral coefficients. Replaced the general assertion by the valid sufficient hypothesis that a itself is integral. The preceding special cubic and quintic statements are retained.

3. **Original mathematical qualification.** Made the real domains a,b>=1/2 in (3.1)--(3.2) explicit.

4. **Original mathematical qualification.** Fixed the sign of the imaginary angle in Theorem 3.1 so the half-angle and principal-root equalities hold, not merely their squares.

5. **Original mathematical qualification.** Added u,v>=1 in Lemma 3.2, the positive-unit regime used in the evaluations. The product of principal differences is invariant under reciprocating u or v, but the defining equation is not.

6. **Original mathematical correction.** Removed the unsupported integrality inference for U,V,W,S. For the algebraic unit u=(1+sqrt(5))/2, U=(u^2+u^(-2))/2=3/2 is not an algebraic integer.

7. **Original mathematical qualification.** Added x>0 and u,v>=1 in Lemma 3.7. Without the factor restrictions, e.g. u=2,v=1/2, the printed principal-root product is not the positive solution of x^(-1)-x=2uv.

8. **Notation.** Expanded the traditional continued-fraction shorthand for H(q) into nested fraction bars; the OCR version looked like an ordinary sum of fractions.

9. **OCR.** Restored the four separate square-root bars in H(exp(-pi*sqrt(7))) on original p.155; the OCR incorrectly nested and extended the bars.

10. **Original mathematical correction.** Corrected the inference after (4.11): a product of two factors equal to zero does not imply that its second factor vanishes when the first is already zero. Interpreted Ramanujan's marginal equation as the alternative factor, not an extra condition on g=2^(1/5).

11. **OCR and structure.** Restored the dedication, actual section headings, continuous paragraphs, subject-classification footnote, and received/revised dates; rebuilt the bibliography and corrected prose/math-mode slips. Preserved the real fifth-root convention in (4.1) and verified the apparently unusual expression in (4.8), rather than changing correct formulas.

12. **Typesetting.** Replaced the OCR-generated preamble with a self-contained pdfLaTeX source; embedded Latin Modern text/math fonts, microtypography, readable margins, proper display environments, continuous paragraphs, running headers, PDF metadata, and structured lists/references. Original section/equation numbering is preserved; output page numbers differ from the source.

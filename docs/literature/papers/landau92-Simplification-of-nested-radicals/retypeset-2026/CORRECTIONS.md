# Simplification of Nested Radicals


Source: `landau1989.pdf` and its paired Mathpix LaTeX in the supplied `articles.zip`.


## Build

Run `pdflatex -interaction=nonstopmode -halt-on-error landau1989.tex` twice in this directory. No downloaded fonts, images, or nonstandard local style files are required.


## Corrections and editorial decisions


1. **OCR.** Restored the author support/address note and the two mathematical footnotes to their anchors, and rejoined text interrupted by the original two-column layout.

2. **Original mathematical claim.** Added an explicit front-of-paper correction to the unrestricted optimal-depth claim; the final 1992 publication makes a roots-of-unity distinction (DOI 10.1137/0221009). The 1989 article is not silently replaced by the 1992 paper.

3. **Original mathematical error.** Qualified Lemma 2.1 and Theorems 2.2, 2.5, 2.6 with a sufficient roots-of-unity hypothesis. Added the Q/cube-root-of-2/S3 counterexample to the original unrestricted Theorem 2.5 and separated its depth-zero case.

4. **Original mathematical error.** Reversed the erroneous terminal subgroup inclusion: alpha belongs to L^H_f precisely when H_f is contained in the subgroup fixing alpha.

5. **Original mathematical errors.** Corrected the fixed-field coefficient comparison (a_j=a_l), terminal field index H_l, cyclic refinement endpoints, and Hilbert-90 construction: sigma generates the quotient Galois group, beta is nonzero, xi=sigma(beta)/beta, and every exponent in sigma(beta^l_1) is l_1.

6. **Original algorithm errors.** Rebuilt Compute Denesting from the damaged line/table layout. Corrected the reversed while test, incompatible base fields, off-by-one K_j indices, wrong cyclic generator, reversed Hilbert-90 quotient, spurious K_r=L terminal condition, and the distinction between cyclic refinement length and abelian-layer depth. The revised construction explicitly adjoins adequate roots of unity and identifies the specified root; it does not claim unrestricted optimality over the original base.

7. **Original overstatement.** Replaced the conclusion’s “exponential iff” running-time statement by the supported explicit-representation/upper-bound claim. Preserved historical research questions as historical remarks, not assertions of current status.

8. **Bibliography.** Corrected Caviness–Fateman’s symposium year to 1976, the Lenstra–Lenstra–Lovász page range to 515–534, and Weinberger–Rothschild’s journal to ACM Transactions on Mathematical Software 2. These agree with the references in Landau’s final 1992 paper. Normalized publisher and journal spelling.

9. **Typesetting.** Replaced the OCR-generated preamble with a self-contained pdfLaTeX source; embedded Latin Modern text/math fonts, microtypography, readable margins, proper display environments, continuous paragraphs, running headers, PDF metadata, and structured lists/references. Original section/equation numbering is preserved; output page numbers differ from the source.

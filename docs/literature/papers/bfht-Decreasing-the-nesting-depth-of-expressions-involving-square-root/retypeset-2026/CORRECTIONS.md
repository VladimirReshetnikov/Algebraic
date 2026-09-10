# Decreasing the Nesting Depth of Expressions Involving Square Roots


Source: `symb85.pdf` and its paired Mathpix LaTeX in the supplied `articles.zip`.


## Build

Run `pdflatex -interaction=nonstopmode -halt-on-error symb85.tex` twice in this directory. No downloaded fonts, images, or nonstandard local style files are required.


## Corrections and editorial decisions


1. **OCR/structure.** Restored the final abstract sentence, all four authors and affiliations, the funding footnote, and prose displaced across page boundaries. Repaired full-width punctuation and numerous malformed mathematical/algorithmic tokens.

2. **Original branch convention.** Corrected the blanket “positive real root throughout” convention, which conflicts with the paper’s complex counterexamples and negative norm radicands. Distinguished complex field-membership statements from real algorithm outputs and from formal signed radicand records. Branch/sign checks are explicit in the corrected pseudocode.

3. **OCR mathematics.** Restored lost exponent subscripts in Lemmas 1–3 and Theorem 3; made 1/(2r) unambiguous in Lemma 2; changed the stray upper limit h to k in the degree product and removed a spurious proof square in the prose.

4. **Original mathematical sign errors.** In Theorem 1, sqrt(a²) is ±a (|a| in the real case), not always a. The induction’s multiplied square root and the final explicit expression require a sign chosen to match the selected branch. Restored the missing end-of-proof mark.

5. **Original Lemma 5 errors.** Restored the missing factor x in (x−ωb)(x−conj(ω)b); allowed the sign ± in the constant coefficient of a monic proper factor. Made the use of b^p∈L and Bézout’s identity explicit.

6. **Original proof qualifications.** Theorem 3 now states the intended positive-real domain, separates b=0 before inferring sqrt(r)∈L, removes degree-one generators before assuming all m_i≥2, and explicitly takes the positive coefficient c before sqrt(c). Rejoined the displaced “if/then” and “since” lines.

7. **Algorithm reconstruction (§2).** Reconstructed the entire first listing; removed OCR font commands and arrow corruption, fixed b_i*d[m+1] (not b_i raised to *), consistent output-array names, and clarified that N[i] versus d[i] is a syntactic/depth test rather than an inequality of equal algebraic values. Added zero, s=0 and branch guards.

8. **Original numerical error.** Restored the missing factor 2 in the final s=20 line of the Shanks example.

9. **Algorithm qualifications (§3).** Specified nonempty subsets, zero handling, the −1 sign-parity coordinate for negative rationals, repeated gcd splitting rather than an insufficient single pass, and removal of even exponents before elimination. Corrected the subset-index letter S.

10. **Severe OCR / original pseudocode errors (§4).** Reconstructed the second listing, whose formulas had become Chinese characters and fragments. Restored the norm, fourth-root denominator and control flow. Replaced the printed product of factor[i]*nested[i] (zero whenever any flag is zero) by a product over selected indices. Corrected the 1≤i<m condition, distinguished all-failure from inner-root success, and propagated the success flag back to the returned last input. Recorded unresolved implementation/completeness bookkeeping explicitly rather than presenting the original schematic listing as verified executable code.

11. **Original branch/completeness flaw (§4).** Combined signed norm radicands under one square root; the printed product-of-principal-roots interpretation contradicts the +6 example. Added real-candidate/denominator/branch/depth admissibility checks and the need to retain alternate recursive witnesses. Completeness statements are conditional on this search bookkeeping; a complete fallback can be exponential, so no new polynomial-time claim is made.

12. **Original numerical error.** Restored the missing coefficient 2 in 5+2sqrt(7) in the fourth-root example’s s=12+6sqrt(7) computation; corrected the array bound [1..3].

13. **OCR numbering / proof scope.** Restored (4.1) beside the three recursive tests in the proof, matching original p.183. Distinguished verification of each algebraic lift from the unsupported step that assumes an arbitrary recursive witness is the required one. Applied the norm-product identity to the positive combined radicand rather than assuming every signed auxiliary factor is positive.

14. **Original proof omission (§5).** Inserted removal of zero coefficients before and after pairwise combination. The linear-independence obstruction applies only to a nonempty collection with nonzero coefficients; the empty combination is zero and already denested.

15. **Original algorithm contract (§6).** Corrected the h=0 return value to the pair (d,1), with d≥0. Made the real norm test explicit, distinguished the depth≤1 target for h>0 from a promise to further simplify already-simple inputs, and replaced the incorrect “one greater than any element” depth assertion by the actual field-membership argument. Corrected the displaced “is real” line and made t>0 explicit before division.

16. **Bibliography/names.** Corrected Caviness–Fateman’s SYMSAC year from 77 to 1976, removed the spurious M.Sc hyperlink, and restored Oscar Rothaus in the acknowledgement (the scan reads Rothaus). Retained the historical references and notation rather than replacing them with a modern literature survey.

17. **Typesetting.** Replaced the OCR-generated preamble with a self-contained pdfLaTeX source; embedded Latin Modern text/math fonts, microtypography, readable margins, proper display environments, continuous paragraphs, running headers, PDF metadata, and structured lists/references. Original section/equation numbering is preserved; output page numbers differ from the source.

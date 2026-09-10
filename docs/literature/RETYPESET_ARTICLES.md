# Corrected re-typesettings of six articles

Moved from `docs/articles/` into the literature dataset on 5 September 2026. Each article now lives in
`papers/<record>/retypeset-2026/` (Berndt-Chan-Zhang under `berndt98`, Jeffrey-Rich under `jeffrey`,
Gkioulekas under `gkioulekas`, Landau 1989 under `landau92`, Scheinerman under `scheinerman`, Borodin et al. under `bfht`);
the directory names below refer to the file basenames.

The six subdirectories correspond one-to-one to the PDF/Mathpix-LaTeX pairs
in the supplied `articles.zip`. Each contains a self-contained `.tex` source,
a freshly compiled PDF with the same basename, and a `CORRECTIONS.md` log.
The original uploaded archive is unchanged and is not duplicated here.

| Directory / basename | Article | Original pages | Re-typeset pages |
|---|---|---:|---:|
| `aa8725` | B. C. Berndt, H. H. Chan, L.-C. Zhang — *Radicals and units in Ramanujan's work* (1998) | 14 | 14 |
| `denest` | David J. Jeffrey and Albert D. Rich — *Simplifying Square Roots of Square Roots by Denesting* (chapter 4) | 13 | 11 |
| `gkioulekas2017` | Eleftherios Gkioulekas — *On the denesting of nested square roots* (2017) | 12 | 11 |
| `landau1989` | Susan Landau — *Simplification of Nested Radicals* (1989) | 6 | 9 |
| `scheinerman2000` | Edward R. Scheinerman — *When Close Enough Is Close Enough* (2000) | 11 | 12 |
| `symb85` | Allan Borodin, Ronald Fagin, John E. Hopcroft, Martin Tompa — *Decreasing the Nesting Depth of Expressions Involving Square Roots* (1985) | 20 | 22 |
| **Total** | | **76** | **79** |

## What was edited

The source PDFs were used as the primary transcription reference, including
page images where mathematical notation or reading order was ambiguous.
Repairs include missing author information, radical bars, exponents and
subscripts, symbols, displaced prose, footnotes, equation references,
bibliographic details, and heavily damaged algorithm listings.

The editions also correct identifiable problems in the originals rather
than reproducing them as if they were correct. Substantive changes are
identified in the per-article logs. Longer qualifications are marked
**Editorial note** in the PDFs. In particular:

- `aa8725` corrects an overbroad algebraic-unit claim and makes real-domain
  and branch hypotheses explicit.
- `denest` restores the omitted coauthor and reconstructs the recursive
  simplification pseudocode, with its heuristic/termination limits stated.
- `gkioulekas2017` corrects definitions, proof references, discriminant
  conditions, two worked-example formulas, and the complexity wording.
- `landau1989` explicitly separates the roots-of-unity theorem from the
  stronger minimum-depth assertion made in the 1989 abstract. The finite
  number-field algorithm is presented with its fixed-field scope, not as
  a newly established unrestricted optimality theorem. The later 1992
  publication is identified in the editorial note.
- `scheinerman2000` corrects complex inner products, matrix dimensions,
  numerical separation bounds, and the difference between numerical
  agreement and a certified error bound. The computation graph is vector
  TikZ, not a raster screenshot.
- `symb85` corrects signs, norm-product notation, indices, numerical steps,
  and pseudocode contracts. For the signed-radicand reconstruction, the
  original argument does not justify discarding all alternative recursive
  witnesses; this remaining implementation/completeness issue is stated
  explicitly. The algebraic lift formulas are not represented as a proof
  of a complete polynomial-time implementation.

Historical references, author addresses, and remarks about the state of
research/software belong to the dates of the original articles. They have
not been silently updated into a survey of present-day results.

These are corrected editorial re-typesettings, not facsimiles or new
publisher-authorized editions. Section and equation numbering is retained;
page numbers and line breaks are new. Landau's two-column original has been
set in one column for readable formulas and editorial qualifications.

## Rebuilding

Use pdfLaTeX from a standard TeX Live or MiKTeX installation. From an article's
subdirectory, run the following command twice, substituting its basename:

```sh
pdflatex -interaction=nonstopmode -halt-on-error aa8725.tex
pdflatex -interaction=nonstopmode -halt-on-error aa8725.tex
```

The preambles use standard packages, including Latin Modern, AMS mathematics,
mathtools, geometry, microtype, enumitem, listings, xurl, hyperref, fancyhdr,
needspace, and TikZ. No external image, font file, bibliography database, or
local custom style file is required. Bibliographies are included in the
sources. The PDFs use embedded scalable fonts.

All six supplied PDFs were built successfully from their paired sources.
Final build logs contained no LaTeX warnings, missing-character reports,
overfull boxes, or underfull boxes. The rendered pages were visually checked;
a further automated check found no text outside page boundaries.

## Independent interval certificates

The additional file `scheinerman2000/verify_intervals.py` is an independent
verification aid written for this edition, not code taken from the article.
It needs only Python's standard library:

```sh
python scheinerman2000/verify_intervals.py
```

It uses integer fixed-point interval endpoints at scale `10^180`, outward
rounding, exact integer-root bounds, Machin's formula, and explicit Taylor
remainder bounds. It certifies that each of the four identity residuals in
the corrected discussion has absolute value less than `10^-170`. The exact
computed enclosures, with all endpoints divided by `10^180`, are:

| Residual | Lower endpoint | Upper endpoint |
|---|---:|---:|
| Student's radical identity | -4 | 2 |
| Cubic-recognition polynomial | -26 | 43 |
| Student's polynomial identity | -14 | 5 |
| Trigonometric identity | -7801 | 7811 |

Together with the separation bounds in the article, these give rigorous
identity certificates rather than relying on matching rounded decimals.

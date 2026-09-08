# Original reports

These three reports were added to `main` in commit `e0bbce026ab5b5fd52c366b5830ce6d54099a7af`
and unpacked here on 7 September 2026.

| Directory | Original archive | Retained files |
| --- | --- | ---: |
| `report-01/` | `AlgebraicDecomposition-1.0.0.zip` | 22 |
| `report-02/` | `algebraic-polynomial-decomposition.zip` | 19 |
| `report-03/` | `algebraic_polynomial_decomposition.zip` | 17 |

Each archive's single enclosing directory was removed during extraction. Every retained file
was compared byte for byte with its archive member before the archives were deleted. The three
`SHA256SUMS` files were omitted as requested. The original archives remain recoverable from the
parent Git history; no checksum ledger is maintained in this repository.

The reports' articles, implementations, licenses, tests, and historical validation results are
otherwise preserved. Their recorded claims that native Wolfram execution was unavailable
describe the report authors' environments; current validation belongs to the live project one
directory above. Some original validation scripts refer to the intentionally removed checksum
files.

The unified implementation and article are maintained outside these directories. Report 1
emphasizes capped enumeration and a Python reference; report 2 emphasizes residual certificates
and the order of right components; report 3 emphasizes h-adic obstruction certificates and
independent certificate checking. The unified article compares their shared mathematics,
implementation differences, and observed native behavior in detail.

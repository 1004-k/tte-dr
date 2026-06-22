# TTE-DR: target trial emulation diagnostic report generator

TTE-DR is an R-based diagnostic quality-assurance reporting workflow for per-protocol target trial emulation in observational studies. It is not a new causal estimator. It takes diagnostic outputs from a per-protocol analysis and generates a reproducible report: graded summaries, named flags, a one-page diagnostic snapshot, machine-readable CSV tables, templated interpretation text, and run metadata.

## What problem does TTE-DR solve?

Per-protocol target trial emulations often report diagnostics as study-specific plots, isolated weight summaries, or informal sensitivity checks. This makes it difficult to compare analyses, audit updates, or decide which additional checks are needed when protocol deviation is prognosis-dependent, overlap erodes, or estimates change across reasonable specifications. TTE-DR standardizes the reporting workflow without replacing scientific judgement.

## Quick start for reviewers

From the repository root:

```bash
Rscript scripts/run_ttedr_example.R
Rscript tests/smoke_test.R
```

The example run uses synthetic diagnostic inputs in `example_data/` and writes outputs to `example_output/`:

- `TTE_DR_snapshot_example.pdf`
- `diagnostic_summary.csv`
- `flags.csv`
- `interpretation_text.txt`
- `run_metadata.json`

The smoke test checks that the example command runs and that the expected files are created. It is intentionally dependency-light so that reviewers can validate the public interface quickly.

## Full reproducibility run

The full manuscript run is intended for a multi-core machine or cloud instance. If the full-run scripts from the main repository are present, run:

```bash
Rscript scripts/00_install_deps.R
bash scripts/98_quickcheck.sh
```

The full reference-class run used for manuscript figures and tables is computationally heavier than the smoke test. Curated manuscript outputs are provided in `paper_outputs/` or in the SoftwareX submission package.

## Repository structure

```text
R/                         Core simulation, diagnostic, grading, and reporting functions
scripts/                   Example, quickcheck, and full reproducibility scripts
tests/                     Smoke test for SoftwareX review
example_data/              Synthetic diagnostic inputs for a one-command demo
example_output/            Expected outputs from the demo run
docs/                      Quick start, input schema, and failure-mode catalogue
rules/                     Default rule files and interpretation templates
paper_outputs/             Manuscript figures and tables, if present
src/README.md              Notes on source-code layout for SoftwareX
.github/workflows/         Optional GitHub Actions smoke-test workflow
LICENSE.txt or LICENSE     MIT license text
CITATION.cff               Software citation metadata
DESCRIPTION                R project metadata
README.md                  User-facing quick start and documentation
```

## Required inputs

TTE-DR expects two classes of inputs:

1. **Target-trial metadata**: study identifier, estimand, strategy contrast, follow-up horizon, protocol-deviation definition, analysis date, and software release.
2. **Diagnostic inputs**: a time-resolved selection-pressure curve, positivity and weight-stability summaries, estimates from pre-specified reasonable alternatives, and residual-sensitivity outputs.

See `docs/input_schema.md` for the suggested minimal input schema.

## Outputs

TTE-DR writes both human-readable and machine-readable outputs. The one-page snapshot supports rapid inspection, while CSV tables and metadata files support audit, reproducibility, continuous integration, and manuscript reporting.

## Scope

The current release is a prototype focused on inverse-probability-of-censoring-weighted per-protocol target trial emulation. TTE-DR does not determine whether a study is causally valid. It provides structured diagnostic reporting and prompts for follow-up analyses.

## Archived release and citation

The SoftwareX submission version is archived as GitHub release `v1.0.0` and preserved on Zenodo.

- GitHub release: https://github.com/1004-k/tte-dr/releases/tag/v1.0.0
- Zenodo version DOI: https://doi.org/10.5281/zenodo.20350296
- Zenodo all-version DOI: https://doi.org/10.5281/zenodo.20350295

Please cite the archived release and the associated manuscript when using this code.

## License

MIT License. The license applies to the source code, scripts, and documentation in this repository unless otherwise stated.

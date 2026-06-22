# Manual repository patch notes

Copy this directory into the live `1004-k/tte-dr` repository after reviewing the diff.

Recommended sequence:

```bash
git checkout -b softwarex-final-polish
cp -R repository_patch_to_copy/. /path/to/tte-dr/
cd /path/to/tte-dr
git status
Rscript scripts/run_ttedr_example.R
Rscript tests/smoke_test.R
git add README.md CITATION.cff NEWS.md docs rules example_data example_output scripts tests src .github
git commit -m "Polish SoftwareX submission package"
git push origin softwarex-final-polish
```

If you tag a new release after this patch, update the manuscript metadata table, references, README, CITATION.cff, and cover letter so that all version numbers and DOIs match.

# Quick start

From the repository root, run the dependency-light example:

```bash
Rscript scripts/run_ttedr_example.R
```

Then check the generated files:

```bash
ls example_output/
```

Expected outputs:

- `TTE_DR_snapshot_example.pdf`
- `diagnostic_summary.csv`
- `flags.csv`
- `interpretation_text.txt`
- `run_metadata.json`

Run the smoke test:

```bash
Rscript tests/smoke_test.R
```

To use TTE-DR with your own analysis, replace the synthetic diagnostic inputs in `example_data/` with diagnostic outputs from your per-protocol target trial emulation. See `docs/input_schema.md` for the minimal expected input schema.

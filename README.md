# Cardiometabolic risk and resting-state functional connectivity by menopause status

Analysis code for a behavioural partial least squares (B-PLS) study of cardiometabolic
risk factors and resting-state functional connectivity in premenopausal and
postmenopausal middle-aged females (N = 82; 41 per group). Participant data come from
the BHAMM study and are not included in this repository.

## Run

```bash
Rscript run.R
```

Takes about a minute. Knitted reports go to `outputs/qc/`. All parameters are in
`params.yml`.

**Needs:** R 4.5 with the packages in `renv.lock` (restore them with `renv::restore()`),
and pandoc on the PATH. On a Mac without a separate pandoc, use RStudio's:
`export RSTUDIO_PANDOC=/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools/aarch64`.

B-PLS itself runs in MATLAB PLSGUI (1000 permutations, 500 bootstraps). Script 01
writes `data/matlab_io/input/<segment>/pls_export.csv` for each run. Each PLSGUI
result is saved as `data/matlab_io/output/<segment>/bpls_result.mat`.

## Inputs (not in the repository)

- `data/raw/`: `BHAMM-MTL_Master_V2024-11.sav`, `BHAMM_rsfMRI_QC_Nov14_2024.xlsx`,
  `BHAMM-MTL_rsfMRI_MotionStats_2026-10.csv`, and the Schaefer-200 + hippocampus atlas
  CSV (`atlas-schaefer_…_Reordered.csv`).
- `data/matlab_io/output/<segment>/bpls_result.mat`: one PLSGUI result per B-PLS run
  (5 runs). The R pipeline reads them and never rewrites them.
- `data/participant_exclusions.yml`: participant-level exclusions, as YAML lists of
  `{id, reason}`:
  - `sample_excl`: IDs dropped after imputation, with the reason shown in Figure 1.
  - `rsfmri_manual_excl`: manual rsfMRI removals.

`data/processed/`, `data/matlab_io/input/` and all of `outputs/` are rebuilt by `run.R`.

To move the project to another machine, copy it without `renv/library/` (it holds
platform-specific builds), then run `renv::restore()` in R from the project folder.

## Scripts

| Script | Does |
|---|---|
| `01_cleaning.Rmd` | Inclusion/exclusion, S1/S2 collation, missForest imputation, sample-level exclusions, PLSGUI inputs; Figure S1 |
| `00_consort_flow.R` | Figure 1 |
| `02_demographics.Rmd` | Table 1, PCOS MANOVAs, Table S2 (motion); age-distribution working figure (`outputs/qc/age_distribution/`) |
| `03_pls_results.Rmd` | One B-PLS run; knitted once per run. On the omnibus run: Figure 2 + Table 2 (LV2), Figure S4 + Table S4 (LV1), Table S1 |
| `04_brainscore_memory.Rmd` | Memory sub-sample (N = 78), Table 3, Table S3, Figure S3 |
| `06_cross_comparison.Rmd` | Reduced-block runs vs primary LVs (\|r\| of BSR maps); Figures S2A–D (sub-LV1); full sub-LV1 + sub-LV2 figure per run in `outputs/<segment>/` |
| `06b_difference_cis.R` | Pre − post Δr 95% CIs as a standalone CSV, plus a check of other percentile conventions |
| `00_functions.R` | Shared helpers |

## Outputs

`run.R` writes everything for the paper to two folders, each file named by its
number: `outputs/manuscript/` and `outputs/supplement/`. `FIGURES_AND_TABLES.md` lists
every table and figure with its title, file and script. `outputs/MANIFEST.csv` lists
each file with its md5 and date.

Working outputs: `outputs/<segment>/` (per-run CSVs and full reduced-block figures),
`outputs/cross_comparison/`, `outputs/qc/` (knitted reports, exclusion logs,
`age_distribution/`) and `outputs/audit/`.

## Key settings (`params.yml`)

- `participant_exclusions_file`: path to the private exclusions file (see Inputs).
- `report_lvs`: LV2 → Figure 2 / Table 2; LV1 → Figure S4 / Table S4.
- `pls_runs`: each reduced-block run's supplementary figure (`figure: S2A`–`S2D`) and file tag (`short`).
- `memory_lvs`: LVs used in the memory regressions (LV2 only).
- `lv_sign_flip`: −1 for both LVs. Positive-weight edges carry the reliable pattern.
- `ci_label`: label for the CIs on r. These are PLSGUI's `llcorr` / `ulcorr` (confidence
  level = 95). The pre − post Δr CIs are the 2.5th / 97.5th percentiles of the bootstrap
  differences.

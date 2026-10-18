# RP2 — Figures and tables (R1 resubmission, N = 82)

*Updated 16 Oct 2026. `Rscript run.R` makes every file below, under these names.
`outputs/MANIFEST.csv` lists each file with its md5 and date.*

## Main text (`outputs/manuscript/`)

| Item | Title | File | Made by |
|---|---|---|---|
| Table 1 | Demographics and Clinical Characteristics by Menopausal Group | `Table1_demographics.{docx,csv}` | `02_demographics.Rmd` |
| Table 2 | LV2 Brain–Behaviour Correlations With Bootstrap CIs (note: between-group Δr CIs) | `Table2_LV2_correlations.{docx,csv}` | `03_pls_results.Rmd` |
| Table 3 | Memory Task Performance by Reproductive-Stage Group | `Table3_memory_performance.{docx,csv}` | `04_brainscore_memory.Rmd` |
| Figure 1 | Participant Selection and Exclusions | `Figure1_participant_flow.{png,pdf}` | `00_consort_flow.R` |
| Figure 2 (A–D) | LV2 Multivariate Association Between rsFC and Risk Factors Across Reproductive-Stage Groups | `Figure2_LV2.png`; panels `Figure2A_LV2_correlations.png`, `Figure2B_LV2_scatter.png`, `Figure2C_LV2_network_density.png`, `Figure2D_LV2_reduced_block.png` | `03_pls_results.Rmd` |
| Results 3.1 | PCOS MANOVAs (values quoted in the text) | `Results3.1_PCOS_MANOVA.csv` | `02_demographics.Rmd` |

## Supplement (`outputs/supplement/`)

Order in the supplement file: Section S1 (Table S4, Figure S4) → Tables S1–S3 → Figures S1–S3.

| Item | Title | File | Made by |
|---|---|---|---|
| Section S1 | LV1: Not Significant, Reported Descriptively (Table S4 + Figure S4) | text only | — |
| Table S1 | All Latent Variables From the Primary B-PLS | `TableS1_all_LVs.{docx,csv}` | `03_pls_results.Rmd` |
| Table S2 | Head Motion by Reproductive-Stage Group | `TableS2_motion.{docx,csv}` | `02_demographics.Rmd` |
| Table S3 | Within-Group Regression: LV2 Brain Score Predicting Mean Memory Accuracy (N = 78) | `TableS3_LV2_brainscore_memory.{docx,csv}` | `04_brainscore_memory.Rmd` |
| Table S4 | LV1 Brain–Behaviour Correlations With Bootstrap CIs (not significant, reported descriptively) | `TableS4_LV1_correlations.{docx,csv}` | `03_pls_results.Rmd` |
| Figure S1 | Observed and missForest-Imputed Values for Systolic Blood Pressure and Total Cholesterol | `FigureS1_imputation.png` | `01_cleaning.Rmd` |
| Figure S2 (A–D) | Single-Variable Reduced-Block B-PLS, Sub-LV1: (A) SBP, (B) Age, (C) Total Cholesterol, (D) Education | `FigureS2A_SBP_reduced_block.png`, `FigureS2B_Age_reduced_block.png`, `FigureS2C_TC_reduced_block.png`, `FigureS2D_Edu_reduced_block.png` | `06_cross_comparison.Rmd` |
| Figure S3 | LV2 Brain Scores Versus Mean Memory Accuracy by Reproductive-Stage Group | `FigureS3_LV2_brainscore_memory.png` | `04_brainscore_memory.Rmd` |
| Figure S4 (A–D) | LV1 Multivariate Association Between rsFC and Risk Factors (not significant, reported descriptively) | `FigureS4_LV1.png`; panels `FigureS4A_LV1_correlations.png`, `FigureS4B_LV1_scatter.png`, `FigureS4C_LV1_network_density.png`, `FigureS4D_LV1_reduced_block.png` | `03_pls_results.Rmd` |

**Totals:** main text 3 tables, 2 figures. Supplement: Section S1, Tables S1–S4, Figures S1–S4.

## Working files (not in the paper)

- Full reduced-block figures, sub-LV1 and sub-LV2: `outputs/sub_pls_<run>_sept20/reduced_block_<run>_subLV1_subLV2.png`
- Reduced-block numbers (Figure 2D, Results 3.3.2): `outputs/cross_comparison/reduced_block_summary.csv`
- Pre − post Δr CIs (Table 2 note): `outputs/main_4bv_pls_sept20/difference_cis_06b.csv`
- Age distribution and overlap counts: `outputs/qc/age_distribution/`

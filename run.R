# =============================================================================
# run.R — builds every manuscript and supplement output from the raw data
# and the PLSGUI results.
#   Rscript run.R          (from the project folder)
#   source("run.R")        (from the R console)
#
# Order: 01 cleaning (+ Fig S1) -> Fig 1 -> 02 Table 1, Table S2 (motion) ->
# 03 B-PLS (each reduced-block run, then omnibus: Fig 2, Table 2, Fig S4,
# Table S4, Table S1) -> 04 memory (Table 3, Table S3, Fig S3) -> 06
# reduced-block comparison (Figs S2A-D) -> 06b pre - post difference CIs ->
# outputs/MANIFEST.csv.
#
# Manuscript items are saved to outputs/manuscript/, supplementary items to
# outputs/supplement/, each named by its number (e.g. Figure2_LV2.png).
# Knitted HTML reports go to outputs/qc/. Parameters are in params.yml.
#
# B-PLS itself runs in MATLAB PLSGUI (1000 permutations, 500 bootstraps) on
# data/matlab_io/input/<segment>/pls_export.csv; each result is saved as
# data/matlab_io/output/<segment>/bpls_result.mat.
# =============================================================================

DO_CLEANING <- TRUE   # FALSE reuses data/processed/bhamm_clean.rds

suppressPackageStartupMessages(library(rmarkdown))
source(here::here("scripts", "00_functions.R"))

knit <- function(script, html_name = NULL) {
  cat("\n→ Knitting", script, "...\n")
  rmarkdown::render(here::here("scripts", script), quiet = TRUE,
                    output_dir = shared_output_path("qc"),
                    output_file = html_name, envir = new.env())
}

if (DO_CLEANING) knit("01_cleaning.Rmd")
source(here::here("scripts", "00_consort_flow.R"))
knit("02_demographics.Rmd")

# 03 for every registered B-PLS run (reduced-block runs first: the omnibus
# run's panel D reads their results; 06 stacks their composites).
run_order <- c(pls_runs_by_role("sensitivity"), pls_runs_by_role("primary"))
for (rid in run_order) {
  Sys.setenv(RP2_ACTIVE_RUN = rid)
  knit("03_pls_results.Rmd",
       html_name = sprintf("03_pls_results_%s.html", params$pls_runs[[rid]]$segment))
}
Sys.unsetenv("RP2_ACTIVE_RUN")
setup_run(globalenv())

knit("04_brainscore_memory.Rmd")
knit("06_cross_comparison.Rmd")
source(here::here("scripts", "06b_difference_cis.R"), local = new.env())
write_manifest()

cat("\n✓ run.R done. Outputs: outputs/manuscript/, outputs/supplement/; reports: outputs/qc/\n")

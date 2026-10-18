# =============================================================================
# scripts/06b_difference_cis.R
# Pre − post difference in each brain-score × behaviour correlation, with 95%
# percentile bootstrap CIs, for the omnibus B-PLS (Table 2 note).
#   Rscript scripts/06b_difference_cis.R      (from the project folder)
#
# Same method as 03_pls_results.Rmd (diff_table): display sign (lv_sign_flip),
# bootstrap slices 2..(n_boot + 1) of boot_result.distrib (slice 1 is the
# observed correlation), 2.5th / 97.5th percentiles, quantile type 5.
# Called by run.R (after 06); can also be run on its own. Reads bpls_result.mat,
# writes CSVs only.
#
# Outputs
#   outputs/main_4bv_pls_sept20/difference_cis_06b.csv   pipeline convention
#   outputs/audit/difference_ci_variants.csv             other percentile
#     conventions, to find which one gives the manuscript's values
# =============================================================================

source(here::here("scripts", "00_functions.R"))   # params, read_bpls()

primary_id <- pls_runs_by_role("primary")
segment    <- params$pls_runs[[primary_id]]$segment
pls        <- read_bpls(here::here("data", "matlab_io", "output", segment, "bpls_result.mat"))

bv_labels <- unname(unlist(params$pls_var_labels)[params$pls_vars])
n_bv      <- length(bv_labels)
pre       <- seq_len(n_bv)
post      <- n_bv + seq_len(n_bv)
n_slices  <- dim(pls$distrib)[3]
stopifnot(n_slices == pls$n_boot + 1,
          max(abs(pls$distrib[, , 1] - pls$orig_corr)) < 1e-10)

# Bootstrap distribution of (pre − post) r for one LV, in display sign.
# slices: which slices of distrib to use; flip: sign applied to the samples.
diff_samples <- function(k, slices, flip) {
  d <- pls$distrib[pre, k, slices, drop = FALSE] - pls$distrib[post, k, slices, drop = FALSE]
  matrix(flip * d, nrow = n_bv)
}

# --- Pipeline convention -----------------------------------------------------
pipeline <- map_dfr(params$report_lv_names, function(lv) {
  k <- as.integer(sub("LV", "", lv)); f <- params$lv_sign_flip[[lv]] %||% 1
  d_bt <- diff_samples(k, 2:n_slices, f)
  tibble(LV = lv, Variable = bv_labels,
         diff_r     = f * (pls$orig_corr[pre, k] - pls$orig_corr[post, k]),
         diff_lower = apply(d_bt, 1, quantile, probs = 0.025, type = 5),
         diff_upper = apply(d_bt, 1, quantile, probs = 0.975, type = 5),
         diff_sig   = ifelse(diff_lower > 0 | diff_upper < 0, "*", ""),
         n_boot = pls$n_boot, quantile_type = 5L)
})

# Must equal the diff_* columns that 03 wrote for the same LVs.
for (lv in params$report_lv_names) {
  ref <- read_csv(here::here("outputs", segment, sprintf("%s_correlations.csv", tolower(lv))),
                  show_col_types = FALSE) %>%
    distinct(Variable, diff_r, diff_lower, diff_upper)
  new <- pipeline %>% filter(LV == lv)
  ref <- ref[match(new$Variable, ref$Variable), ]
  stopifnot(max(abs(new$diff_r - ref$diff_r)) < 1e-12,
            max(abs(new$diff_lower - ref$diff_lower)) < 1e-12,
            max(abs(new$diff_upper - ref$diff_upper)) < 1e-12)
}
cat("✓ 06b reproduces the 03 difference CIs for", paste(params$report_lv_names, collapse = ", "), "\n")

out_main <- here::here("outputs", segment, "difference_cis_06b.csv")
write_csv(pipeline, out_main)
cat("✓ Saved:", sub("^.*/outputs/", "outputs/", out_main), "\n")
print(pipeline %>% mutate(across(where(is.double), ~ round(.x, 4))), n = Inf)

# --- Variants: which convention gives the manuscript's LV2 values? -----------
# Manuscript (Table 2 note / 3.3.1), 2 dp: TC −1.39 [−1.69, −1.29];
# SBP −0.19 [−0.80, 0.30]; age 0.10 [−0.42, 0.65]; education −0.60 [−1.13, −0.25].
ms <- tibble(Variable = bv_labels,
             ms_lower = c(-1.69, -0.80, -0.42, -1.13),
             ms_upper = c(-1.29,  0.30,  0.65, -0.25))

k2 <- 2L; f2 <- params$lv_sign_flip[["LV2"]] %||% 1
variants <- expand_grid(slices = c("boot_only_500", "all_501"), type = 1:9,
                        flip_stage = c("before_quantile", "after_quantile")) %>%
  pmap_dfr(function(slices, type, flip_stage) {
    idx <- if (slices == "boot_only_500") 2:n_slices else 1:n_slices
    if (flip_stage == "before_quantile") {
      d  <- diff_samples(k2, idx, f2)
      lo <- apply(d, 1, quantile, probs = 0.025, type = type)
      hi <- apply(d, 1, quantile, probs = 0.975, type = type)
    } else {                      # percentiles of the raw (PLSGUI-sign) difference, then flip
      d  <- diff_samples(k2, idx, 1)
      q1 <- f2 * apply(d, 1, quantile, probs = 0.025, type = type)
      q2 <- f2 * apply(d, 1, quantile, probs = 0.975, type = type)
      lo <- pmin(q1, q2); hi <- pmax(q1, q2)
    }
    tibble(slices, type, flip_stage, Variable = bv_labels, lower = lo, upper = hi)
  }) %>%
  left_join(ms, by = "Variable") %>%
  mutate(match_2dp = sprintf("%.2f", lower) == sprintf("%.2f", ms_lower) &
                     sprintf("%.2f", upper) == sprintf("%.2f", ms_upper))

variant_summary <- variants %>%
  group_by(slices, type, flip_stage) %>%
  summarise(n_vars_matching = sum(match_2dp),
            age_upper = upper[Variable == "Age"],
            edu_upper = upper[Variable == "Education"], .groups = "drop") %>%
  arrange(desc(n_vars_matching), slices, type)

out_var <- here::here("outputs", "audit", "difference_ci_variants.csv")
dir.create(dirname(out_var), recursive = TRUE, showWarnings = FALSE)
write_csv(variants, out_var)
cat("✓ Saved:", sub("^.*/outputs/", "outputs/", out_var), "\n\n")
cat("Variants that reproduce all four manuscript LV2 CIs at 2 dp:\n")
print(variant_summary %>% filter(n_vars_matching == n_bv), n = Inf)
cat("\nAll variants (LV2):\n")
print(variant_summary %>% mutate(across(where(is.double), ~ round(.x, 4))), n = Inf)

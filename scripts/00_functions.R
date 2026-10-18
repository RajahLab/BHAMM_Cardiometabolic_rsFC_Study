# =============================================================================
# scripts/00_functions.R
# Libraries + shared helpers. Every Rmd starts with:
#   source(here::here("scripts", "00_functions.R")); setup_run()
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(yaml)
})


# =============================================================================
# PARAMS + ACTIVE B-PLS RUN
# =============================================================================
# setup_run() reads params.yml into `params` (in the calling environment and in
# globalenv, where the path helpers look), resolves the active B-PLS run and
# sets the seed.
#
# The active run is RP2_ACTIVE_RUN (set by run.R while it knits 03 for each
# reduced-block run) or, if unset, the run with role: "primary". It sets
#   params$run_label  — the run's segment (folder name)
#   params$pls_vars   — the run's behavioural variables
#   params$active_run_role / active_run_id / active_run_label

apply_active_run <- function(p) {
  run_id <- Sys.getenv("RP2_ACTIVE_RUN", unset = "")
  if (!nzchar(run_id)) {
    run_id <- names(Filter(function(e) identical(e$role, "primary"), p$pls_runs))
    stopifnot("params.yml needs exactly one pls_runs entry with role: primary" =
                length(run_id) == 1L)
  }
  entry <- p$pls_runs[[run_id]]
  if (is.null(entry)) stop("RP2_ACTIVE_RUN = '", run_id, "' is not in pls_runs.")

  p$run_label        <- entry$segment
  p$pls_vars         <- as.character(unlist(entry$pls_vars))
  p$active_run_id    <- run_id
  p$active_run_role  <- entry$role
  p$active_run_label <- entry$label %||% run_id
  p
}

load_params <- function() {
  p <- yaml::read_yaml(here::here("params.yml"))
  for (f in c("cs_vars", "cr_vars", "memory_lvs", "extra_cleaning_cols",
              "t1_interest_cont", "t1_interest_cat", "t1_clinical_cont",
              "t1_clinical_cat", "t1_subscales")) {
    p[[f]] <- as.character(unlist(p[[f]]))
  }
  p$report_lv_names <- names(p$report_lvs)

  # Participant-level exclusions live in a private file outside the repository
  excl_file <- here::here(p$participant_exclusions_file)
  if (!file.exists(excl_file))
    stop("Missing ", p$participant_exclusions_file, " (participant exclusions; see README).")
  excl <- yaml::read_yaml(excl_file)
  p$sample_excl        <- excl$sample_excl
  p$rsfmri_manual_excl <- excl$rsfmri_manual_excl
  apply_active_run(p)
}

setup_run <- function(target = parent.frame()) {
  p <- load_params()
  envs <- if (identical(target, globalenv())) list(target) else list(target, globalenv())
  for (env in envs) {
    if (exists("params", envir = env, inherits = FALSE) &&
        bindingIsLocked("params", env)) unlockBinding("params", env)
    assign("params", p, envir = env)
  }
  set.seed(p$seed)
  cat(sprintf("✓ active run = '%s' (segment = %s, role = %s, pls_vars = %s)\n",
              p$active_run_id, p$run_label, p$active_run_role,
              paste(p$pls_vars, collapse = ", ")))
  invisible(p)
}

# IDs of registered runs with a given role ("primary" / "sensitivity").
pls_runs_by_role <- function(role) {
  runs <- params$pls_runs
  names(runs)[vapply(runs, function(e) identical(e$role, role), logical(1))]
}

# Sample-level exclusions from params.yml as a data frame (id, reason).
sample_exclusions <- function() {
  ex <- params$sample_excl %||% list()
  data.frame(id     = vapply(ex, function(e) as.integer(e$id), integer(1)),
             reason = vapply(ex, function(e) as.character(e$reason), character(1)))
}


# =============================================================================
# PATHS
# =============================================================================
# Shared (run-independent):     data/processed/, outputs/qc/,
#                               outputs/manuscript/, outputs/supplement/
# Per run (<segment>):          data/matlab_io/{input,output}/<segment>/,
#                               outputs/<segment>/  (working files)
#
# outputs/manuscript/ and outputs/supplement/ are flat: every file is named by
# its manuscript number (Table1_..., Figure2_..., FigureS4A_...).

.make_path <- function(...) {
  path <- here::here(...)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  path
}

cleaning_path      <- function(...) .make_path("data", "processed", ...)
shared_output_path <- function(...) .make_path("outputs", ...)
run_output_path    <- function(...) .make_path("outputs", params$run_label, ...)
matlab_input_path  <- function(...) .make_path("data", "matlab_io", "input",  params$run_label, ...)
matlab_output_path <- function(...) .make_path("data", "matlab_io", "output", params$run_label, ...)

ms_path   <- function(file) shared_output_path("manuscript", file)
supp_path <- function(file) shared_output_path("supplement", file)

# Path for a numbered item: "2" -> outputs/manuscript/, "S3" -> outputs/supplement/.
#   numbered_path("Figure", "2", "LV2.png")  -> outputs/manuscript/Figure2_LV2.png
#   numbered_path("Table", "S4", "LV1_correlations.csv")
numbered_path <- function(kind, num, stem) {
  file <- sprintf("%s%s_%s", kind, num, stem)
  if (startsWith(num, "S")) supp_path(file) else ms_path(file)
}

save_png <- function(plot, path, width = 10, height = 7, dpi = 300) {
  ggplot2::ggsave(path, plot = plot, width = width, height = height, dpi = dpi,
                  limitsize = FALSE)
  cat("✓ Saved:", sub("^.*/outputs/", "outputs/", path), "\n")
  invisible(plot)
}

# outputs/MANIFEST.csv: every file in outputs/manuscript/ and outputs/supplement/,
# with the item it belongs to (from its file name), md5 and date. Rebuilt by run.R.
write_manifest <- function() {
  files <- c(list.files(shared_output_path("manuscript"), full.names = TRUE),
             list.files(shared_output_path("supplement"), full.names = TRUE))
  files <- files[!startsWith(basename(files), "~$")]      # Word lock files
  nm <- basename(files)
  m  <- regmatches(nm, regexec("^(Table|Figure)(S?)([0-9]+)([A-D]?)_", nm))
  get <- function(i) vapply(m, function(x) if (length(x)) x[i] else "", "")
  kind <- get(2); supp <- get(3); num <- get(4); panel <- get(5)
  item <- ifelse(nzchar(kind), sprintf("%s %s%s%s", kind, supp, num, panel),
                 ifelse(grepl("^Results", nm), sub("_.*", "", sub("^Results", "Results ", nm)), ""))
  info <- file.info(files)
  manifest <- tibble::tibble(
    folder = basename(dirname(files)), item = item,
    part = ifelse(nzchar(panel), "panel", ifelse(nzchar(kind), "main", "text values")),
    file = nm, md5 = unname(tools::md5sum(files)),
    size_kb = round(info$size / 1024, 1), modified = format(info$mtime, "%Y-%m-%d %H:%M")) %>%
    dplyr::arrange(folder != "manuscript", kind != "Table", suppressWarnings(as.numeric(num)), panel, file)
  readr::write_csv(manifest, shared_output_path("MANIFEST.csv"))
  cat(sprintf("✓ Saved: outputs/MANIFEST.csv (%d files)\n", nrow(manifest)))
  invisible(manifest)
}

save_session_info <- function(script_name) {
  writeLines(capture.output(sessionInfo()),
             shared_output_path("qc", "session_info", paste0(script_name, "_session_info.txt")))
}


# =============================================================================
# COLOURS & THEME
# =============================================================================

GROUP_COLORS <- c("Pre-Meno" = "salmon", "Post-Meno" = "maroon4")

theme_apa <- function(base_size = 12, base_family = "sans") {
  ggplot2::theme_bw(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      text             = ggplot2::element_text(color = "black"),
      plot.title       = ggplot2::element_text(size = base_size + 2, face = "bold",
                                               hjust = 0.5, margin = ggplot2::margin(b = 10)),
      plot.subtitle    = ggplot2::element_text(size = base_size, hjust = 0.5,
                                               margin = ggplot2::margin(b = 10)),
      axis.title       = ggplot2::element_text(size = base_size, face = "bold"),
      axis.text        = ggplot2::element_text(size = base_size - 1, color = "black"),
      panel.grid.major = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      panel.border     = ggplot2::element_rect(color = "black", fill = NA, linewidth = 1),
      panel.background = ggplot2::element_rect(fill = "white"),
      legend.position  = "right",
      legend.title     = ggplot2::element_text(size = base_size, face = "bold"),
      legend.text      = ggplot2::element_text(size = base_size - 1),
      legend.key       = ggplot2::element_rect(fill = "white", color = NA),
      strip.background = ggplot2::element_rect(fill = "grey90", color = "black", linewidth = 1),
      strip.text       = ggplot2::element_text(size = base_size, face = "bold", color = "black"),
      plot.margin      = ggplot2::margin(10, 10, 10, 10)
    )
}


# =============================================================================
# PLS EXPORT (MATLAB input)
# =============================================================================
# Writes the active run's behavioural block (raw units, rows in group-then-ID
# order) plus the PLSGUI group-ID lists.

export_pls_matrix <- function(clean_rds = cleaning_path("bhamm_clean.rds")) {
  bhamm <- readRDS(clean_rds)
  write.csv(bhamm[, params$pls_vars, drop = FALSE],
            matlab_input_path("pls_export.csv"), row.names = FALSE)

  pls_id_order <- bhamm %>%
    dplyr::select(id, group_var) %>%
    dplyr::mutate(row_index = dplyr::row_number())
  readr::write_csv(pls_id_order, cleaning_path("pls_id_order.csv"))

  matlab_labels <- c("Pre-Meno" = "MA_F_Pre", "Post-Meno" = "MA_F_Post")
  id_block <- pls_id_order %>%
    dplyr::group_by(group_var) %>%
    dplyr::summarise(line = paste0('"', matlab_labels[as.character(group_var[1])], '": [',
                                   paste0('"', id, '"', collapse = ", "), "]"),
                     .groups = "drop") %>%
    dplyr::pull(line)
  writeLines(paste(id_block, collapse = ",\n"), matlab_input_path("matlab_group_ids.txt"))

  cat(sprintf("PLS export (%s): %d rows x %d vars -> %s\n", params$run_label,
              nrow(bhamm), length(params$pls_vars),
              sub("^.*/data/", "data/", matlab_input_path("pls_export.csv"))))
}

# Export the MATLAB input for every registered run.
export_all_runs <- function() {
  prev <- Sys.getenv("RP2_ACTIVE_RUN", unset = "")
  on.exit({
    if (nzchar(prev)) Sys.setenv(RP2_ACTIVE_RUN = prev) else Sys.unsetenv("RP2_ACTIVE_RUN")
    setup_run(globalenv())
  }, add = TRUE)
  for (rid in names(params$pls_runs)) {
    Sys.setenv(RP2_ACTIVE_RUN = rid)
    setup_run(globalenv())
    export_pls_matrix()
  }
}


# =============================================================================
# MATLAB B-PLS RESULT READER
# =============================================================================
# Returns the fields of a PLSGUI bpls_result.mat that the pipeline uses.
#   usc, vsc       participants x LVs
#   orig_corr      (BV x group) x LVs brain-score/behaviour correlations
#   llcorr/ulcorr  PLSGUI's bootstrap bounds on orig_corr (the CIs reported on r)
#   clim           PLSGUI confidence level used for llcorr/ulcorr (95)
#   distrib        (BV x group) x LVs x (n_boot + 1); slice 1 = orig_corr
#   bsr            edges x LVs bootstrap ratios (compare.u)
#   perm_p         per-LV permutation p (sprob)
#   s              singular values
#   behavdata      stacked behavioural block as entered in PLSGUI
read_bpls <- function(mat_path) {
  if (!file.exists(mat_path)) stop("B-PLS result not found: ", mat_path)
  res  <- R.matlab::readMat(mat_path)$result
  get  <- function(x, nm) x[[which(dimnames(x)[[1]] == nm)]]
  boot <- get(res, "boot.result")
  perm <- get(res, "perm.result")
  list(
    usc       = get(res, "usc"),
    vsc       = get(res, "vsc"),
    orig_corr = get(boot, "orig.corr"),
    llcorr    = get(boot, "llcorr"),
    ulcorr    = get(boot, "ulcorr"),
    distrib   = get(boot, "distrib"),
    bsr       = get(boot, "compare.u"),
    perm_p    = as.numeric(get(perm, "sprob")),
    n_perm    = as.integer(get(perm, "num.perm")),
    n_boot    = as.integer(get(boot, "num.boot")),
    clim      = as.numeric(get(boot, "clim")),
    s         = as.numeric(get(res, "s")),
    behavdata = get(res, "stacked.behavdata")
  )
}

# Percent of cross-block covariance per LV.
pct_covariance <- function(s) s^2 / sum(s^2) * 100


# =============================================================================
# STATS HELPERS
# =============================================================================

# APA p-value: "= .XXX" or "< .001"
format_pval <- function(p, digits = 3) {
  p <- as.numeric(p)
  out <- rep("NA", length(p))
  out[!is.na(p) & p < .001] <- "< .001"
  reg <- !is.na(p) & p >= .001
  out[reg] <- paste0("= ", sub("^0\\.", ".", formatC(p[reg], format = "f", digits = digits)))
  out
}

# Rank-biserial r from a two-group Mann-Whitney test, signed in the direction
# of the first group minus the second (same direction as Cohen's d).
rank_biserial <- function(x, y) {
  x <- x[!is.na(x)]; y <- y[!is.na(y)]
  U <- suppressWarnings(wilcox.test(x, y, exact = FALSE))$statistic
  unname(2 * U / (length(x) * length(y)) - 1)
}

# Continuous two-group comparison. Welch t-test if Shapiro-Wilk p > .05 in both
# groups, otherwise Mann-Whitney U. Effect size: Cohen's d (pooled SD) or
# rank-biserial r, both signed group 1 minus group 2.
run_cont_test <- function(var, data, alpha = 0.05) {
  g      <- levels(data$group_var)
  x      <- data[[var]][data$group_var == g[1]]
  y      <- data[[var]][data$group_var == g[2]]
  normal <- all(vapply(list(x, y), function(v) shapiro.test(v[!is.na(v)])$p.value > alpha,
                       logical(1)))
  if (normal) {
    res <- t.test(x, y, var.equal = FALSE)
    tibble::tibble(variable = var, test = "t-test",
                   statistic = unname(res$statistic), df = unname(res$parameter),
                   p_value = res$p.value,
                   effect_size = effsize::cohen.d(x, y, na.rm = TRUE)$estimate,
                   es_type = "Cohen's d")
  } else {
    res <- wilcox.test(x, y, exact = FALSE)
    tibble::tibble(variable = var, test = "Mann-Whitney U",
                   statistic = unname(res$statistic), df = NA_real_,
                   p_value = res$p.value,
                   effect_size = rank_biserial(x, y),
                   es_type = "rank-biserial r")
  }
}

# Categorical two-group comparison. Pearson chi-square (no continuity
# correction); Fisher's exact test if any expected count is < 5. Effect size:
# Cramér's V from the uncorrected chi-square.
run_cat_test <- function(var, data) {
  tbl  <- table(data$group_var, data[[var]])
  chi  <- suppressWarnings(chisq.test(tbl, correct = FALSE))
  cramv <- sqrt(unname(chi$statistic) / (sum(tbl) * (min(dim(tbl)) - 1)))
  if (any(chi$expected < 5)) {
    tibble::tibble(variable = var, test = "Fisher's Exact",
                   statistic = NA_real_, df = NA_real_,
                   p_value = fisher.test(tbl)$p.value,
                   effect_size = cramv, es_type = "Cramér's V")
  } else {
    tibble::tibble(variable = var, test = "Chi-square",
                   statistic = unname(chi$statistic), df = unname(chi$parameter),
                   p_value = chi$p.value,
                   effect_size = cramv, es_type = "Cramér's V")
  }
}


# =============================================================================
# ROI ATLAS + EDGE INDEX
# =============================================================================
# 204-ROI atlas (Schaefer-200 + 4 Damoiseaux hippocampal nodes), rows ordered
# by ROI_NewOrder, which is the order the connectivity matrices were vectorised
# in. The 12 Limbic and 4 hippocampal ROIs form one "LimbicHippocampal"
# network, so there are 7 networks.
#
# Use only this reordered atlas. schaefer200_network_labels.csv (Draft5 era) is
# a different permutation of the same ROIs and silently mislabels every network
# block when paired with these .mat files.
roi_atlas <- function(path = here::here(
                        "data", "raw",
                        "atlas-schaefer_space-MNI_parcels-200_voxelres-2mm_yeonetworks-7_Limbic-HC_Combined_Reordered.csv")) {
  rois <- readr::read_csv(path, show_col_types = FALSE)
  rois <- rois[order(rois$ROI_NewOrder), , drop = FALSE]
  rois$network <- as.factor(rois$Network)
  rois
}

# Upper-triangle edge index in PLSGUI (column-major) order: one row per edge,
# with the ROI pair (i < j) and their networks. 20,706 rows for 204 ROIs.
build_edge_index <- function(rois) {
  ij <- which(upper.tri(matrix(0, nrow(rois), nrow(rois))), arr.ind = TRUE)
  data.frame(edge_idx  = seq_len(nrow(ij)),
             i         = ij[, 1],
             j         = ij[, 2],
             network_i = rois$network[ij[, 1]],
             network_j = rois$network[ij[, 2]])
}

# Params are available as soon as this file is sourced.
setup_run(globalenv())

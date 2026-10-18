# =============================================================================
# 00_consort_flow.R — Figure 1: participant flow diagram
#
# Reads (all written by 01_cleaning.Rmd):
#   outputs/qc/script1_start_ids.csv     assessed for eligibility
#   outputs/qc/exclusion_log.csv         health exclusions
#   outputs/qc/rsfmri_qc_exclusions.csv  rsfMRI QC exclusions
#   outputs/qc/sample_exclusions.csv     sample-level exclusions (params$sample_excl)
#   outputs/qc/script1_final_ids.csv     final analytic sample
#
# Writes: outputs/manuscript/Figure1_participant_flow.{png,pdf}
#
# Layout follows the manuscript figure: enrolment -> met inclusion -> split by
# reproductive stage -> per-group exclusions -> per-group final -> final
# sample. Every count and reason comes from the files above.
# =============================================================================

source(here::here("scripts", "00_functions.R"))
pacman::p_load(grid, glue)

read_qc <- function(f) readr::read_csv(shared_output_path("qc", f), show_col_types = FALSE)
start_ids  <- read_qc("script1_start_ids.csv")
health_log <- read_qc("exclusion_log.csv")
scan_log   <- bind_rows(read_qc("rsfmri_qc_exclusions.csv") %>% mutate(id = as.numeric(id)),
                        read_qc("sample_exclusions.csv")    %>% mutate(id = as.numeric(id)))
final_ids  <- read_qc("script1_final_ids.csv")

# Every participant must be accounted for exactly once.
stopifnot(nrow(start_ids) == nrow(health_log) + nrow(scan_log) + nrow(final_ids),
          !anyDuplicated(c(health_log$id, scan_log$id, final_ids$id)))

health_reason_labels <- c(HRT = "Menopausal hormone therapy",
                          HBC = "Hormonal birth control",
                          BMI_over_40 = "BMI > 40",
                          "HRT & BMI_over_40" = "Hormone therapy & BMI > 40",
                          hysterectomy_oophorectomy = "Hysterectomy/oophorectomy")
health_log$reason <- dplyr::recode(health_log$reason, !!!health_reason_labels)
after_health <- start_ids %>% filter(!id %in% health_log$id)

n_grp <- function(df, g) sum(df$group_var == g)
reason_lines <- function(df) {
  df %>% count(reason, sort = TRUE) %>% glue_data("{reason} (n = {n})") %>% as.character()
}

# ── Colours (as in the manuscript figure) ────────────────────────────────────
pal <- list(
  enrol    = c(fill = "#DFE7FB", border = "#6F8FE6", text = "#1F2A5C"),
  excl_top = c(fill = "#FCE3E1", border = "#D9463B", text = "#B3261E"),
  pre      = c(fill = "#ECE6FB", border = "#9C86DE", text = "#2E1F5E"),
  post     = c(fill = "#E0F3EC", border = "#5DB596", text = "#174A3A"),
  excl     = c(fill = "#FCF1D6", border = "#E3A93C", text = "#5C3D00"),
  final    = c(fill = "#E3F3DE", border = "#6DBE5E", text = "#1E4D14"))

# ── Drawing helpers (npc units inside the main viewport) ─────────────────────
LH <- 0.029   # line height
box <- function(x, y, w, h, col, title, body = character(), align = "left",
                valign = "centre", title_size = 14, body_size = 12, lwd = 2.2) {
  grid.roundrect(unit(x, "npc"), unit(y, "npc"), unit(w, "npc"), unit(h, "npc"),
                 r = unit(0.012, "snpc"),
                 gp = gpar(fill = col[["fill"]], col = col[["border"]], lwd = lwd))
  tx <- if (align == "left") x - w / 2 + 0.018 else x
  hj <- if (align == "left") 0 else 0.5
  n  <- 1 + length(body)
  ys <- if (valign == "top") y + h / 2 - 0.032 - (seq_len(n) - 1) * LH
        else y + (n - 1) * LH / 2 - (seq_len(n) - 1) * LH    # block centred in the box
  grid.text(title, unit(tx, "npc"), unit(ys[1], "npc"), hjust = hj,
            gp = gpar(fontsize = title_size, fontface = "bold", col = col[["text"]]))
  if (length(body)) {
    grid.text(body, unit(tx, "npc"), unit(ys[-1], "npc"), hjust = hj,
              gp = gpar(fontsize = body_size, col = "grey15"))
  }
}
line <- function(x, y, arrow = FALSE) {
  grid.lines(unit(x, "npc"), unit(y, "npc"),
             arrow = if (arrow) grid::arrow(length = unit(0.012, "npc"), type = "closed") else NULL,
             gp = gpar(col = "grey45", fill = "grey45", lwd = 2))
}

render_flow <- function() {
  grid.newpage()
  # Layout is drawn on a 0-1 grid that runs slightly past the bottom edge, so
  # the unused band under the legend is cropped.
  pushViewport(viewport(width = 0.96, height = 1.1, y = 0.45))
  groups <- c(pre = "Pre-Meno", post = "Post-Meno")
  titles <- c(pre = "Premenopausal", post = "Postmenopausal")
  xs     <- c(pre = 0.20, post = 0.58)
  reasons <- map(groups, ~ reason_lines(scan_log %>% filter(group_var == .x)))
  h_excl  <- 0.05 + LH * max(lengths(reasons))     # same height in both columns

  # Enrolment and health exclusions
  box(0.37, 0.93, 0.44, 0.085, pal$enrol, "Assessed for eligibility",
      glue("n = {nrow(start_ids)} (premenopausal {n_grp(start_ids, 'Pre-Meno')}, ",
           "postmenopausal {n_grp(start_ids, 'Post-Meno')})"), align = "centre")
  line(c(0.59, 0.70), c(0.93, 0.93), arrow = TRUE)
  hl <- reason_lines(health_log)
  hh <- 0.045 + LH * (length(hl) + 1)
  box(0.845, 0.975 - hh / 2, 0.29, hh, pal$excl_top,
      glue("Excluded: health criteria (n = {nrow(health_log)})"),
      c(paste("-", hl), glue("(premenopausal {n_grp(health_log, 'Pre-Meno')}, ",
                             "postmenopausal {n_grp(health_log, 'Post-Meno')})")),
      valign = "top", title_size = 13, body_size = 11)
  line(c(0.37, 0.37), c(0.8875, 0.83), arrow = TRUE)
  box(0.37, 0.79, 0.26, 0.08, pal$enrol, "Met inclusion criteria",
      glue("n = {nrow(after_health)}"), align = "centre")

  # Split by reproductive stage
  line(c(0.37, 0.37), c(0.75, 0.725))
  line(c(xs[["pre"]], xs[["post"]]), c(0.725, 0.725))
  y_excl_top <- 0.585; y_final <- y_excl_top - h_excl - 0.075
  for (g in names(xs)) {
    x <- xs[[g]]; gv <- groups[[g]]
    line(c(x, x), c(0.725, 0.70), arrow = TRUE)
    box(x, 0.66, 0.34, 0.08, pal[[g]], titles[[g]], glue("n = {n_grp(after_health, gv)}"))
    line(c(x, x), c(0.62, y_excl_top), arrow = TRUE)
    box(x, y_excl_top - h_excl / 2, 0.34, h_excl, pal$excl,
        glue("Excluded (n = {nrow(scan_log %>% filter(group_var == gv))})"), reasons[[g]],
        valign = "top", title_size = 13, body_size = 11.5)
    line(c(x, x), c(y_excl_top - h_excl, y_final + 0.04), arrow = TRUE)
    box(x, y_final, 0.34, 0.08, pal[[g]], glue("Final: {tolower(titles[[g]])}"),
        glue("n = {n_grp(final_ids, gv)}"))
    line(c(x, x), c(y_final - 0.04, y_final - 0.095))
  }
  y_merge <- y_final - 0.095
  line(c(xs[["pre"]], xs[["post"]]), c(y_merge, y_merge))
  line(c(0.39, 0.39), c(y_merge, y_merge - 0.025), arrow = TRUE)
  box(0.39, y_merge - 0.07, 0.46, 0.09, pal$final, "Final analytic sample",
      glue("N = {nrow(final_ids)} ({n_grp(final_ids, 'Pre-Meno')} premenopausal, ",
           "{n_grp(final_ids, 'Post-Meno')} postmenopausal)"),
      align = "centre", title_size = 16, body_size = 13)

  # Legend
  keys <- list(Enrolment = pal$enrol, Premenopausal = pal$pre, Postmenopausal = pal$post,
               Excluded = pal$excl, Analysed = pal$final)
  y_leg <- y_merge - 0.16
  for (i in seq_along(keys)) {
    lx <- 0.04 + (i - 1) * 0.19
    grid.circle(unit(lx, "npc"), unit(y_leg, "npc"), r = unit(0.009, "npc"),
                gp = gpar(fill = keys[[i]][["fill"]], col = keys[[i]][["border"]], lwd = 2))
    grid.text(names(keys)[i], unit(lx + 0.016, "npc"), unit(y_leg, "npc"), hjust = 0,
              gp = gpar(fontsize = 11, col = "grey30"))
  }
  popViewport()
}

png(ms_path("Figure1_participant_flow.png"), width = 12, height = 8, units = "in", res = 300)
render_flow(); invisible(dev.off())
pdf(ms_path("Figure1_participant_flow.pdf"), width = 12, height = 8)
render_flow(); invisible(dev.off())

cat(glue("✓ Figure 1 saved. Assessed {nrow(start_ids)} -> health -{nrow(health_log)} ",
         "-> {nrow(after_health)} -> rsfMRI/other -{nrow(scan_log)} -> final {nrow(final_ids)}\n"))

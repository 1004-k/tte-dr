#!/usr/bin/env Rscript

# Patterns-ready figure generator for TTE-DR, v3.
# Goal: remove all label overlap, remove unnecessary in-figure text,
# and produce clean black/white figures suitable for initial Patterns submission.
#
# Usage from repository root:
#   Rscript patterns_clean_figure_code_patch_v3.R
# Optional:
#   Rscript patterns_clean_figure_code_patch_v3.R output_paperx_main
#   OUT_DIR=output_paperx_main Rscript patterns_clean_figure_code_patch_v3.R
# Optional strict table for Figure S1:
#   STRICT_SUMMARY=/path/to/strict_summary.csv Rscript patterns_clean_figure_code_patch_v3.R

out_dir <- if (length(commandArgs(trailingOnly = TRUE)) >= 1) {
  commandArgs(trailingOnly = TRUE)[1]
} else {
  Sys.getenv("OUT_DIR", "output_paperx_main")
}

fig_dir <- file.path(out_dir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

read_first_csv <- function(paths, label) {
  hit <- paths[file.exists(paths)]
  if (length(hit) == 0) {
    stop(sprintf("Could not find %s. Tried:\n%s", label, paste(paths, collapse = "\n")))
  }
  message("Reading ", label, ": ", hit[1])
  utils::read.csv(hit[1], stringsAsFactors = FALSE,
                  na.strings = c("", "NA"), check.names = FALSE)
}

summary_paths <- c(
  file.path(out_dir, "tables", "TableX2_TTEDR_summary_main.csv"),
  file.path(out_dir, "TableX2_TTEDR_summary_main.csv"),
  file.path(out_dir, "ttdr_summary_by_scenario.csv"),
  "TableX2_TTEDR_summary_main.csv",
  "ttdr_summary_by_scenario.csv"
)
ref_paths <- c(
  file.path(out_dir, "tables", "TableX1_reference_class_map.csv"),
  file.path(out_dir, "TableX1_reference_class_map.csv"),
  "TableX1_reference_class_map.csv"
)

sum_dt <- read_first_csv(summary_paths, "scenario summary")
ref_dt <- read_first_csv(ref_paths, "reference-class map")

required_summary <- c("scenario_id", "mis_spec", "truth", "max_spd_med", "Gamma_end_med",
                      "rESS_min_med", "tail_share_max_med", "est_range", "sign_flip",
                      "delta_star_med", "grade", "flags", "template")
missing_summary <- setdiff(required_summary, names(sum_dt))
if (length(missing_summary) > 0) stop("Missing summary columns: ", paste(missing_summary, collapse = ", "))
required_ref <- c("failure_mode", "scenario_id", "fixed")
missing_ref <- setdiff(required_ref, names(ref_dt))
if (length(missing_ref) > 0) stop("Missing reference map columns: ", paste(missing_ref, collapse = ", "))

as_num <- function(x) suppressWarnings(as.numeric(x))
for (nm in c("mis_spec", "max_spd_med", "Gamma_end_med", "rESS_min_med", "tail_share_max_med", "est_range")) {
  sum_dt[[nm]] <- as_num(sum_dt[[nm]])
}
sum_dt$scenario_id <- trimws(as.character(sum_dt$scenario_id))
sum_dt$truth_clean <- tolower(trimws(as.character(sum_dt$truth)))
sum_dt$grade <- trimws(as.character(sum_dt$grade))

canon <- sum_dt[sum_dt$truth_clean %in% c("null", "causal_null", "causal null", "no_effect", "no effect") &
                  sum_dt$mis_spec == 0, , drop = FALSE]

scenario_order <- c("S01","S04","S02","S05","S03","S06",
                    "S07","S10","S08","S11","S09","S12",
                    "S13","S16","S14","S17","S15","S18")
if (length(unique(canon$scenario_id)) != 18) {
  stop("Canonical slice must contain 18 unique scenarios. Found: ",
       length(unique(canon$scenario_id)), ". Check truth labels and mis_spec.")
}
canon <- canon[match(scenario_order, canon$scenario_id), , drop = FALSE]
if (any(is.na(canon$scenario_id))) stop("Scenario IDs do not match expected S01-S18 layout.")

layout_dt <- data.frame(
  scenario_id = scenario_order,
  col = rep(1:6, times = 3),
  row = rep(1:3, each = 6),
  stringsAsFactors = FALSE
)

# Very short axis labels. Longer explanations belong in captions, not in the figure.
x_labels <- c("rho .4\nno jump", "rho .4\njump",
              "rho .7\nno jump", "rho .7\njump",
              "rho 1\nno jump", "rho 1\njump")
y_labels <- c("flat", "increasing", "late surge")

grade_cols <- c("Green" = "white", "Amber" = "grey76", "Red" = "black")
text_col_for_grade <- function(g) ifelse(g == "Red", "white", "black")
short_grade <- function(g) ifelse(g == "Green", "G", ifelse(g == "Amber", "A", ifelse(g == "Red", "R", "?")))

open_pdf <- function(file, width, height, pointsize = 10) {
  grDevices::pdf(file, width = width, height = height, pointsize = pointsize,
                 family = "Helvetica", useDingbats = FALSE)
}
fmt_num <- function(x, digits = 3, missing = "NA") {
  x <- suppressWarnings(as.numeric(x))
  if (length(x) == 0 || is.na(x) || !is.finite(x)) return(missing)
  formatC(x, format = "f", digits = digits)
}
wrap_text <- function(x, width = 78) paste(strwrap(as.character(x), width = width), collapse = "\n")

clean_flags <- function(x) {
  x <- trimws(as.character(x))
  if (is.na(x) || x == "" || tolower(x) == "none") return("none")
  parts <- trimws(unlist(strsplit(x, ";", fixed = TRUE)))
  # Direction changes around the null are reported as an informational note, not a dominant flag.
  parts <- parts[parts != "" & parts != "sign_flip_across_specs"]
  if (length(parts) == 0) return("none")
  paste(parts, collapse = "; ")
}

# -------------------------------------------------------------------------
# Heatmap drawing with absolute coordinates.
# No base axis/mtext is used, which prevents left-label overlap.
# -------------------------------------------------------------------------
draw_heatmap_panel <- function(dt, x0, y0, x1, y1, title = NULL, row_labels = TRUE,
                               cell_cex = 0.72, label_cex = 0.60, title_cex = 0.76) {
  n_col <- 6; n_row <- 3
  cell_w <- (x1 - x0) / n_col
  cell_h <- (y1 - y0) / n_row

  if (!is.null(title)) {
    text((x0 + x1) / 2, y1 + 0.045, title, cex = title_cex, font = 2)
  }

  for (i in seq_len(nrow(layout_dt))) {
    sid <- layout_dt$scenario_id[i]
    rr <- layout_dt$row[i]
    cc <- layout_dt$col[i]
    row <- dt[dt$scenario_id == sid, , drop = FALSE]
    if (nrow(row) != 1) next
    gx0 <- x0 + (cc - 1) * cell_w
    gx1 <- x0 + cc * cell_w
    gy1 <- y1 - (rr - 1) * cell_h
    gy0 <- y1 - rr * cell_h
    g <- as.character(row$grade)
    fill <- if (g %in% names(grade_cols)) grade_cols[g] else "grey90"
    rect(gx0, gy0, gx1, gy1, col = fill, border = "black", lwd = 0.75)
    text((gx0 + gx1) / 2, (gy0 + gy1) / 2,
         paste0(sid, "\n", short_grade(g)), cex = cell_cex,
         col = text_col_for_grade(g), font = 2)
  }

  # Column labels below cells.
  for (cc in seq_len(n_col)) {
    text(x0 + (cc - 0.5) * cell_w, y0 - 0.045, x_labels[cc],
         cex = label_cex, adj = c(0.5, 1))
  }

  # Row labels at left, no vertical y-axis title to avoid collisions.
  if (row_labels) {
    for (rr in seq_len(n_row)) {
      text(x0 - 0.020, y1 - (rr - 0.5) * cell_h, y_labels[rr],
           cex = 0.70, adj = c(1, 0.5))
    }
  }
}

draw_grade_legend <- function(x, y, cex = 0.70) {
  sw <- 0.018; sh <- 0.020
  labs <- c("Green", "Amber", "Red")
  for (i in seq_along(labs)) {
    yy <- y - (i - 1) * 0.045
    rect(x, yy - sh / 2, x + sw, yy + sh / 2, col = grade_cols[labs[i]], border = "black", lwd = 0.7)
    text(x + sw + 0.012, yy, labs[i], adj = c(0, 0.5), cex = cex)
  }
}

# -----------------------------
# Figure 1: grade heatmap
# -----------------------------
fig1 <- file.path(fig_dir, "Figure_1_TTEDR_grade_heatmap.pdf")
open_pdf(fig1, width = 8.2, height = 4.2, pointsize = 10)
par(mar = c(0, 0, 0, 0), xpd = NA)
plot.new(); plot.window(xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i")
text(0.50, 0.940, "TTE-DR grade: causal null, well specified", cex = 1.05, font = 2)
draw_heatmap_panel(canon, x0 = 0.115, y0 = 0.215, x1 = 0.820, y1 = 0.850,
                   title = NULL, row_labels = TRUE, cell_cex = 0.74, label_cex = 0.62)
draw_grade_legend(0.875, 0.615, cex = 0.76)
dev.off()
message("Saved: ", fig1)

# -----------------------------
# Figure S1: cutoff sensitivity
# -----------------------------
strict_path <- Sys.getenv("STRICT_SUMMARY", "")
if (nzchar(strict_path) && file.exists(strict_path)) {
  strict_dt <- utils::read.csv(strict_path, stringsAsFactors = FALSE,
                               na.strings = c("", "NA"), check.names = FALSE)
  strict_dt$scenario_id <- trimws(as.character(strict_dt$scenario_id))
  strict_dt$truth_clean <- tolower(trimws(as.character(strict_dt$truth)))
  strict_dt$mis_spec <- as_num(strict_dt$mis_spec)
  strict_dt$grade <- trimws(as.character(strict_dt$grade))
  strict <- strict_dt[strict_dt$truth_clean %in% c("null", "causal_null", "causal null", "no_effect", "no effect") &
                        strict_dt$mis_spec == 0, , drop = FALSE]
  strict <- strict[match(scenario_order, strict$scenario_id), , drop = FALSE]
} else {
  strict <- canon
}

figS1 <- file.path(fig_dir, "Figure_S1_cutoff_sensitivity.pdf")
open_pdf(figS1, width = 10.4, height = 4.35, pointsize = 10)
par(mar = c(0, 0, 0, 0), xpd = NA)
plot.new(); plot.window(xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i")
text(0.50, 0.955, "Cutoff sensitivity for canonical slice grades", cex = 1.00, font = 2)
draw_heatmap_panel(canon, x0 = 0.065, y0 = 0.210, x1 = 0.440, y1 = 0.820,
                   title = "Amber=90th, Red=97.5th", row_labels = TRUE,
                   cell_cex = 0.57, label_cex = 0.47, title_cex = 0.70)
draw_heatmap_panel(strict, x0 = 0.500, y0 = 0.210, x1 = 0.875, y1 = 0.820,
                   title = "Amber=95th, Red=99th", row_labels = FALSE,
                   cell_cex = 0.57, label_cex = 0.47, title_cex = 0.70)
draw_grade_legend(0.925, 0.570, cex = 0.62)
dev.off()
message("Saved: ", figS1)

# -----------------------------
# Figure 2: reference-class representatives
# -----------------------------
rep_dt <- merge(ref_dt, canon, by = "scenario_id", all.x = TRUE, all.y = FALSE)
rep_dt <- rep_dt[!is.na(rep_dt$failure_mode), , drop = FALSE]
rep_dt$fixed <- as.logical(rep_dt$fixed)
rep_dt$failure_id <- sub("_.*", "", rep_dt$failure_mode)

fig2 <- file.path(fig_dir, "Figure_2_reference_class_representatives.pdf")
open_pdf(fig2, width = 7.2, height = 4.4, pointsize = 10)
par(mar = c(4.0, 4.2, 2.0, 0.8), mgp = c(2.2, 0.6, 0), xpd = FALSE)
x <- rep_dt$max_spd_med
y <- rep_dt$rESS_min_med
xlim <- range(x, na.rm = TRUE); ylim <- range(y, na.rm = TRUE)
xlim <- c(max(0, xlim[1] - 0.06), xlim[2] + 0.08)
ylim <- c(max(0, ylim[1] - 0.012), min(1, ylim[2] + 0.012))
plot(x, y, type = "n", xlim = xlim, ylim = ylim,
     xlab = "Max |SPD(t)|", ylab = "Min rESS",
     main = "Reference-class representatives", cex.main = 1.0)
grid(col = "grey92", lty = "dotted")
points(x, y, pch = ifelse(rep_dt$fixed, 21, 16),
       bg = ifelse(rep_dt$fixed, "white", "black"),
       col = "black", cex = 1.2)
# Manually chosen positions for short labels. Full labels stay in Table 1/caption.
pos <- rep(4, nrow(rep_dt))
pos[rep_dt$failure_id %in% c("B4")] <- 2
pos[rep_dt$failure_id %in% c("B3")] <- 1
pos[rep_dt$failure_id %in% c("D2")] <- 3
pos[rep_dt$failure_id %in% c("B5", "C2")] <- 1
text(x, y, labels = rep_dt$failure_id, pos = pos, offset = 0.55, cex = 0.82, font = 2)
legend("bottomleft", legend = c("Representative", "Fixed anchor"), pch = c(16, 21),
       pt.bg = c("black", "white"), col = "black", bty = "n", cex = 0.82)
dev.off()
message("Saved: ", fig2)

# -----------------------------
# Figure 3: diagnostic snapshot
# -----------------------------
score_grade <- function(g) ifelse(g == "Red", 3, ifelse(g == "Amber", 2, ifelse(g == "Green", 1, 0)))
canon$grade_score <- score_grade(canon$grade)
row <- canon[order(-canon$grade_score, -canon$max_spd_med, canon$rESS_min_med), , drop = FALSE][1, ]
flags_display <- clean_flags(row$flags)
note_display <- if (isTRUE(as.logical(row$sign_flip))) "Direction change across specifications is reported as an informational note." else ""

delta_display <- function(x) {
  x_chr <- trimws(as.character(x))
  x_num <- suppressWarnings(as.numeric(x_chr))
  if (length(x_chr) == 0 || is.na(x_chr) || x_chr == "" || is.na(x_num)) {
    return(">2.0; no tipping within range")
  }
  fmt_num(x_num)
}

draw_box <- function(x0, y0, x1, y1, title, body, fill = "grey98", title_cex = 0.84, body_cex = 0.72) {
  rect(x0, y0, x1, y1, border = "black", lwd = 0.8, col = fill)
  text(x0 + 0.018, y1 - 0.028, title, adj = c(0, 0.5), cex = title_cex, font = 2)
  text(x0 + 0.018, (y0 + y1) / 2 - 0.015, body, adj = c(0, 0.5), cex = body_cex)
}

fig3 <- file.path(fig_dir, "Figure_3_TTEDR_diagnostic_snapshot.pdf")
open_pdf(fig3, width = 7.3, height = 6.8, pointsize = 10)
par(mar = c(0, 0, 0, 0), xpd = NA)
plot.new(); plot.window(xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i")
rect(0.055, 0.865, 0.945, 0.955, border = "black", lwd = 1.0, col = "grey96")
text(0.075, 0.920, "TTE-DR diagnostic snapshot", adj = c(0, 0.5), cex = 1.16, font = 2)
text(0.075, 0.888, paste0("Scenario ", row$scenario_id, " | causal null | well specified"), adj = c(0, 0.5), cex = 0.76)
rect(0.790, 0.890, 0.925, 0.938, border = "black", lwd = 1.0, col = grade_cols[as.character(row$grade)])
text(0.858, 0.914, row$grade, cex = 0.96, font = 2, col = text_col_for_grade(row$grade))
rect(0.055, 0.755, 0.945, 0.835, border = "black", lwd = 0.8, col = "white")
text(0.075, 0.810, "Dominant flags", adj = c(0, 0.5), cex = 0.84, font = 2)
text(0.075, 0.780, wrap_text(flags_display, width = 92), adj = c(0, 0.5), cex = 0.70)
module_boxes <- rbind(
  c(0.055, 0.600, 0.475, 0.725),
  c(0.525, 0.600, 0.945, 0.725),
  c(0.055, 0.445, 0.475, 0.570),
  c(0.525, 0.445, 0.945, 0.570)
)
module_titles <- c("Pressure", "Positivity", "Stability", "Sensitivity")
module_bodies <- c(
  paste0("max |SPD(t)| = ", fmt_num(row$max_spd_med), "\nend pressure = ", fmt_num(row$Gamma_end_med)),
  paste0("min rESS = ", fmt_num(row$rESS_min_med), "\nmax tail share = ", fmt_num(row$tail_share_max_med)),
  paste0("logRR range = ", fmt_num(row$est_range), "\ndirection change = note"),
  paste0("delta* = ", delta_display(row$delta_star_med))
)
for (i in 1:4) {
  b <- module_boxes[i, ]
  draw_box(b[1], b[2], b[3], b[4], module_titles[i], module_bodies[i])
}
rect(0.055, 0.175, 0.945, 0.405, border = "black", lwd = 0.8, col = "white")
text(0.075, 0.370, "Template interpretation", adj = c(0, 0.5), cex = 0.86, font = 2)
text(0.075, 0.340, wrap_text(row$template, width = 94), adj = c(0, 1), cex = 0.68)
if (nzchar(note_display)) text(0.075, 0.205, wrap_text(note_display, width = 94), adj = c(0, 0.5), cex = 0.62, col = "grey35")
text(0.055, 0.085, paste0("Generated from code. Output directory: ", out_dir), adj = c(0, 0.5), cex = 0.58, col = "grey35")
dev.off()
message("Saved: ", fig3)

# -----------------------------
# Graphical abstract: minimal, no title/body overlap
# -----------------------------
draw_ga <- function() {
  par(mar = c(0, 0, 0, 0), xpd = NA)
  plot.new(); plot.window(xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i")
  text(0.5, 0.955, "TTE-DR", cex = 1.70, font = 2)
  text(0.5, 0.915, "Diagnostic QA for per-protocol target trial emulation", cex = 0.64)

  arrow_down <- function(y0, y1) arrows(0.5, y0, 0.5, y1, length = 0.055, lwd = 1.0)
  ga_box <- function(x0, y0, x1, y1, title, body, body_cex = 0.62) {
    rect(x0, y0, x1, y1, border = "black", lwd = 1.0, col = "grey97")
    text((x0 + x1) / 2, y1 - 0.030, title, cex = 0.80, font = 2)
    text((x0 + x1) / 2, y0 + 0.038, body, cex = body_cex)
  }

  ga_box(0.16, 0.755, 0.84, 0.850, "Inputs", "trial specification + estimates")
  arrow_down(0.755, 0.715)
  ga_box(0.16, 0.620, 0.84, 0.715, "Generator", "calibrated rules + audit trail")
  arrow_down(0.620, 0.580)

  rect(0.10, 0.360, 0.90, 0.580, border = "black", lwd = 1.0, col = "grey97")
  text(0.5, 0.545, "Minimum QA panel", cex = 0.80, font = 2)
  tile_x <- c(0.15, 0.34, 0.53, 0.72)
  tile_titles <- c("Pressure", "Positivity", "Stability", "Sensitivity")
  tile_sub <- c("SPD(t)", "rESS", "specs", "delta*")
  for (i in seq_along(tile_x)) {
    rect(tile_x[i], 0.395, tile_x[i] + 0.13, 0.500, border = "black", lwd = 0.8, col = "white")
    text(tile_x[i] + 0.065, 0.462, tile_titles[i], cex = 0.50, font = 2)
    text(tile_x[i] + 0.065, 0.425, tile_sub[i], cex = 0.50)
  }

  arrow_down(0.360, 0.320)
  ga_box(0.16, 0.205, 0.84, 0.320, "Outputs", "grade + flags + snapshot + CSV")
  text(0.5, 0.095, "Continuous diagnostics remain available", cex = 0.54)
}

ga_pdf <- file.path(fig_dir, "Graphical_Abstract_TTEDR.pdf")
open_pdf(ga_pdf, width = 5.6, height = 5.6, pointsize = 10)
draw_ga()
dev.off()
message("Saved: ", ga_pdf)

ga_png <- file.path(fig_dir, "Graphical_Abstract_TTEDR.png")
grDevices::png(ga_png, width = 1600, height = 1600, res = 300, type = "cairo")
draw_ga()
dev.off()
message("Saved: ", ga_png)

message("Done. Clean v3 figure files saved to: ", fig_dir)

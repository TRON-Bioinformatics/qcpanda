#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(tidyverse)
  library(fs)
})

# Load custom_functions.R from the same bin/ directory as this script.
# Nextflow symlinks bin/ scripts into the task work directory; normalizePath()
# resolves the symlink so we can find sibling files without passing them through
# a channel.
script_self <- Filter(function(x) grepl("--file=", x, fixed = TRUE),
                      commandArgs(trailingOnly = FALSE))
script_dir  <- dirname(normalizePath(sub("--file=", "", script_self, fixed = TRUE)))
source(file.path(script_dir, "custom_functions.R"))

# -- argument parsing ----------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

parse_args <- function(args) {
  opts <- list(
    ngscm_vafs_folder = ".",
    ngscm_all_file    = "",
    ngscm_table       = "ngscm_table.tsv",
    output_dir        = "ngscm_plots",
    patient_map       = ""
  )
  i <- 1
  while (i <= length(args)) {
    key <- sub("^--", "", args[i])
    if (i + 1 <= length(args) && !startsWith(args[i + 1], "--")) {
      opts[[key]] <- args[i + 1]
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  opts
}

opts <- parse_args(args)
dir.create(opts$output_dir, showWarnings = FALSE, recursive = TRUE)

has_patient_map <- nchar(opts$patient_map) > 0

# -- pairwise correlation data -------------------------------------------------
ngscheck_pairs <- read_ngscm_pairs(opts$ngscm_all_file)

# Optionally join patient-to-sample mapping (TSV with 'patient' and 'sample' columns)
if (has_patient_map) {
  patient_df <- read_tsv(opts$patient_map,
                         col_types = cols(patient = col_character(), sample = col_character()))
  ngscheck_pairs <- ngscheck_pairs %>%
    left_join(patient_df %>% select(sample_label_1 = sample, patient_1 = patient),
              by = "sample_label_1") %>%
    left_join(patient_df %>% select(sample_label_2 = sample, patient_2 = patient),
              by = "sample_label_2") %>%
    mutate(patient_match = !is.na(patient_1) & !is.na(patient_2) & patient_1 == patient_2)
}

# 01 – pairwise correlation table
write_tsv(ngscheck_pairs, file.path(opts$output_dir, "01_ngscheck_pairs.tsv"))

# Build symmetric (complete) pairwise table, swapping both sample and patient labels
ngscheck_pairs_reversed <- ngscheck_pairs %>%
  rename(sample_label_1 = sample_label_2, sample_label_2 = sample_label_1)
if (has_patient_map) {
  ngscheck_pairs_reversed <- ngscheck_pairs_reversed %>%
    rename(patient_1 = patient_2, patient_2 = patient_1)
}
ngscheck_pairs_complete <- bind_rows(ngscheck_pairs, ngscheck_pairs_reversed)

dendrogram_condition <- nrow(ngscheck_pairs_complete) > 2
heatmaps_condition   <- nrow(ngscheck_pairs_complete) != 0 &&
                        nrow(ngscheck_pairs_complete) <= 900

# 02 – clustering dendrogram (optional)
if (dendrogram_condition) {
  cor_mat <- ngscheck_pairs_complete %>%
    arrange(sample_label_1, sample_label_2) %>%
    select(sample_label_1, sample_label_2, correlation) %>%
    pivot_wider(names_from = "sample_label_2", values_from = "correlation") %>%
    column_to_rownames("sample_label_1") %>%
    as.matrix()
  cor_mat[is.na(cor_mat)] <- 1.0
  cor_mat_reordered <- cor_mat[match(colnames(cor_mat), rownames(cor_mat)), ]
  dist_obj  <- as.dist(1 - cor_mat_reordered, diag = TRUE, upper = TRUE)
  clust_all <- hclust(dist_obj, method = "complete")

  png(file.path(opts$output_dir, "02_clustering.png"), width = 800, height = 600)
  par(plt = c(0.05, 0.95, 0.2, 0.9))
  plot(clust_all, lwd = 2, lty = 1, cex = 0.5,
       xlab = "Samples", sub = "",
       ylab = "Distance (1-Pearson correlation)",
       hang = -1, axes = TRUE)
  dev.off()
}

# 03 – correlation heatmap (optional, grouped by patient when map is provided)
if (heatmaps_condition) {
  p_hm <- ggplot(ngscheck_pairs_complete,
      aes(x = sample_label_1, y = fct_rev(sample_label_2), fill = correlation)) +
    geom_tile() +
    scale_fill_viridis_c(option = "plasma") +
    theme_bw() +
    theme(
      axis.text.x       = element_text(angle = 60, vjust = 1, hjust = 1, size = 5),
      axis.text.y       = element_text(size = 5),
      strip.text.y      = element_text(angle = 0),
      strip.text.x      = element_text(angle = 90),
      panel.spacing     = unit(0, "lines"),
      panel.grid.major  = element_blank(),
      panel.grid.minor  = element_blank()
    ) +
    labs(x = "", y = "")
  if (has_patient_map) {
    p_hm <- p_hm + facet_grid(patient_2 ~ patient_1, scales = "free", space = "free")
  }
  ggsave(file.path(opts$output_dir, "03_heatmap.png"), p_hm, width = 8, height = 6, dpi = 150)
}

# 04 – distribution of correlation values (coloured by patient_match when map is provided)
if (has_patient_map) {
  p_dist <- ggplot(ngscheck_pairs, aes(x = correlation, fill = patient_match)) +
    geom_histogram(bins = 100, color = "black") +
    scale_fill_viridis_d(option = "plasma") +
    theme_bw()
} else {
  p_dist <- ggplot(ngscheck_pairs, aes(x = correlation)) +
    geom_histogram(bins = 100, color = "black") +
    theme_bw()
}
ggsave(file.path(opts$output_dir, "04_distribution.png"), p_dist, width = 8, height = 4, dpi = 150)

# -- homozygosity rate ---------------------------------------------------------
# VAF files are staged in the work directory; use glob to select only .vaf files
ncm_all_files <- opts$ngscm_vafs_folder %>%
  dir_ls(glob = "*.vaf") %>%
  str_subset(pattern = "Undetermined", negate = TRUE)

homozygous_all_samples <- tibble(
    ncm_files    = ncm_all_files,
    sample_label = path_file(ncm_all_files) %>%
      path_ext_remove() %>%
      as.character()
  ) %>%
  write_tsv(file = opts$ngscm_table) %>%
  mutate(
    homozygous_rate = map_dbl(ncm_files, get_homozygous_fraction)
  )

# Optionally join patient column for grouping
if (has_patient_map) {
  homozygous_all_samples <- homozygous_all_samples %>%
    left_join(patient_df %>% rename(sample_label = sample), by = "sample_label")
}

# 05 – homozygosity table
homozygous_all_samples %>%
  select(sample_label, homozygous_rate) %>%
  filter(!is.nan(homozygous_rate)) %>%
  write_tsv(file.path(opts$output_dir, "05_homozygosity.tsv"))

# 06 – homozygosity bar plot (faceted by patient when map is provided)
# The 50 % threshold was derived from experimental confirmation of artificially
# cross-contaminated samples (Kämpfer et al., internal).
scaling_height <- max(6, nrow(homozygous_all_samples) / 5.6)
p_homo <- ggplot(homozygous_all_samples,
    aes(x = sample_label, y = homozygous_rate * 100,
        label = round(homozygous_rate * 100, 2))) +
  geom_col(fill = "gray") +
  geom_text(hjust = "right", size = 3) +
  geom_hline(yintercept = 50, color = "red", alpha = 0.5) +
  coord_flip() +
  theme_bw() +
  labs(y = "Homozygous SNPs [%]", x = "") +
  theme(
    strip.text.y  = element_text(angle = 0),
    axis.text.y   = element_text(size = 7)
  )
if (has_patient_map) {
  p_homo <- p_homo + facet_grid(patient ~ ., scales = "free", space = "free")
}
ggsave(file.path(opts$output_dir, "06_homozygosity.png"), p_homo,
       width = 8, height = scaling_height, dpi = 150, limitsize = FALSE)

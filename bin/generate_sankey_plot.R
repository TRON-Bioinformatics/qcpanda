#!/usr/bin/env Rscript

# Authors: Ivan Baksic
# Version: 2023-10-19

# Packages
library(highcharter)
library(htmlwidgets)
library(tidyr)

# Load custom_functions.R from the same bin/ directory as this script.
# Nextflow symlinks bin/ scripts into the task work directory; normalizePath()
# resolves the symlink so we can find sibling files without passing them through
# a channel.
script_self <- Filter(function(x) grepl("--file=", x, fixed = TRUE),
                      commandArgs(trailingOnly = FALSE))
script_dir  <- dirname(normalizePath(sub("--file=", "", script_self, fixed = TRUE)))
source(file.path(script_dir, "custom_functions.R"))

# Parameters
args = commandArgs(trailingOnly=TRUE)
if (length(args)==0) {
        stop("At least one argument must be supplied (input file)", call.=FALSE)
} else if (length(args)==1) {
        # default output file
        args[2] = "sankey_plot.html"
        args[3] = 0.9
} else if (length(args)==2) {
        args[3] = 0.9
} else if (length(args)==3) {
        if (is.na(as.numeric(args[3]))) {
                stop("Third argument must be a number!", call.=FALSE)
        }
} else {
        stop("Too many arguments supplied!", call.=FALSE)
}

# input
noise_threshold <- as.numeric(args[3])
input_df <- read.table(args[1], sep = "\t", na.strings = "", header=FALSE, fill = TRUE)

#===============================================================================

# Filter and rename taxon classes
input_df_filtered <- subset(input_df, V4 %in% names(ranks))

# Create data table with relevant columns
named_df <- data.frame(
        taxon = input_df_filtered$V4,
        name = trimws(input_df_filtered$V6),
        read_number = input_df_filtered$V2,
        read_percent = input_df_filtered$V1
)

mpa_style_df <- mpa_style_fun(named_df, noise_threshold)

# Create sankey readable format of the table
mpa_style_df$reads <- as.numeric(mpa_style_df$reads)
mpa_style_df_expanded <- uncount(mpa_style_df, reads)
sankey_format <- data_to_sankey(mpa_style_df_expanded)

# Plot and save sankey plot
sankey_format_reordered <- sankey_format_reordered_fun(sankey_format)
sankey_plot <- hchart(sankey_format_reordered, "sankey", name = "Contamination lineages")
saveWidget(sankey_plot, file = args[2], selfcontained = TRUE)

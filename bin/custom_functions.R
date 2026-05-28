# load required packages
require(tidyverse)


# functions for generate_sankey_plot.R

ranks <- c("D"="Domain", "K"="Kingdom", "P"="Phylum", "C"="Class", "O"="Order",
"F"="Family", "G"="Genus", "S"="Species")

# Transform into mpa-style dataframe
mpa_style_fun <- function(input_df, noise_threshold, input_ranks = ranks) {

        mpa_style <- sapply(1:nrow(input_df), function(x){
                # Filter out only species and remove noise under threshold value
                if (input_df$taxon[x] == "S" & input_df$read_percent[x] > noise_threshold) {
                        count <- x
                        # Add read number and percentage data to each species
                        phylo <- c(input_df$read_number[x], paste0(input_df$read_percent[x], "%"))
                        # Add phylogenetic data to each species sample
                        while (input_df$taxon[count] != "D") {
                                if (!input_df$taxon[count] %in% substr(phylo, 1, 1)) {
                                        phylo <- c(paste(input_df$taxon[count], input_df$name[count], sep=": "), phylo)
                                }
                                count <- count - 1
                        }
                        # Since Bacteria has no kingdom, paste kingdom value to the domain name
                        if (all(substr(phylo, 1, 1) != "K")) {
                                phylo <- c(paste("K", input_df$name[count], sep=": "), phylo)
                        }
                        # Add final domain info
                        phylo <- c(paste(input_df$taxon[count], input_df$name[count], sep=": "), phylo)
                        return(phylo)
                }
        })

        # Remove species with incomplete phylogenetic info and create dataframe with correct column names
        mpa_style <- mpa_style[sapply(mpa_style, function(x) length(x) == 10)]
        mpa_style_df <- as.data.frame(do.call(rbind, mpa_style))
        colnames(mpa_style_df) <- c(names(input_ranks), "reads", "percent")

        return(mpa_style_df)

}


# Recursive function that reorders sankey table so it displays lineages that are not intertwined
sankey_format_reordered_fun <- function(input_df, input_ranks = ranks, my_rank = 2, output_df = data.frame()) {

        rank_names <- names(input_ranks)

        # Create "from" and "out" subtables based on the rank name
        only_from_con <- substr(input_df$from, start = 1, stop = 1) == rank_names[my_rank]
        only_to_con <- substr(input_df$to, start = 1, stop = 1) == rank_names[my_rank]
        only_from_k <- input_df[only_from_con,]
        only_to_k <- input_df[only_to_con,]

        # Reorder "from" table based on ranks in "to" table
        reordered_vector <- lapply(only_to_k$to, function(x) which(only_from_k$from %in% x))
        reorder_from <- only_from_k[unlist(reordered_vector),]

        # Add domain ranks at the beginning
        if (my_rank == 2) {
                only_domain <- input_df[substr(input_df$from, start = 1, stop = 1) == rank_names[1],]
                my_output_df <- do.call(rbind, list(only_domain, output_df, reorder_from))
        } else {
                my_output_df <- rbind(output_df, reorder_from)
        }

        # Update input with reordered "from" table
        my_input_df <- rbind(reorder_from, input_df[!only_from_con & !only_to_con, ])

        if(my_rank == length(rank_names)) {
                return(my_output_df)
        } else {
                sankey_format_reordered_fun(input_ranks, input_df = my_input_df, my_rank = my_rank + 1, output_df = my_output_df)
        }
}


# functions for ngscm_report.R

# Read and clean the NGSCheckMate pairwise all-comparisons file.
# Filters out Undetermined samples, renames sample columns to sample_label_1/2.
read_ngscm_pairs <- function(all_file) {
  read_tsv(all_file,
    col_names = c("sample_1", "match", "sample_2", "correlation", "depth"),
    col_types  = "cccdd"
  ) %>%
    filter(!grepl("Undetermined", sample_1) & !grepl("Undetermined", sample_2)) %>%
    mutate(
      sample_label_1 = sample_1,
      sample_label_2 = sample_2
    ) %>%
    select(sample_label_1, sample_label_2, match, correlation, depth)
}

# function to get homozygous rate of SNPs from .ncm file from NGSCheckMate output
get_homozygous_fraction <- function(ncm_file, tolerated_reads = 2, min_coverage = 5){

  snps <- read_tsv(ncm_file, col_types = cols(.default = col_double()))

  snps <- snps %>%
    mutate(
      coverage = ref + alt
    ) %>%
    filter(coverage >= min_coverage) %>%
    mutate(
      is_homozygous = ref <= tolerated_reads | alt <= tolerated_reads
    )
  homozygous_rate <- sum(snps$is_homozygous) / length(snps$is_homozygous)
}

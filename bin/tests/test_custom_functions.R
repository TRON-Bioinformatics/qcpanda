#!/usr/bin/env Rscript
# Unit tests for bin/custom_functions.R
# Run with: Rscript bin/tests/test_custom_functions.R

require(testthat)

# Resolve source paths relative to this script so it works from any working directory
script_self <- Filter(function(x) grepl("--file=", x, fixed = TRUE),
                      commandArgs(trailingOnly = FALSE))
script_dir  <- dirname(normalizePath(sub("--file=", "", script_self, fixed = TRUE)))

source(file.path(script_dir, "..", "custom_functions.R"))

# ==============================================================================
# Input fixtures
# ==============================================================================

example_named_df <- data.frame(
    taxon = c("D", "K", "P", "C", "O", "F", "G", "S", "O", "F", "G", "S", "D", "P", "C", "O", "F", "G", "S"),
    name = c(
        "Eukaryota", "Metazoa", "Chordata", "Mammalia",
        "Primates", "Hominidae", "Homo", "Homo sapiens",
        "Rodentia", "Muridae", "Mus", "Mus musculus",
        "Bacteria", "Actinomycetota", "Actinomycetes",
        "Mycobacteriales", "Mycobacteriaceae", "Mycolicibacterium",
        "Mycolicibacterium austroafricanum"
    ),
    read_number  = c("8","8","8","8","3","3","3","3","5","5","5","5","2","2","2","2","2","2","2"),
    read_percent = c("80","80","80","80","30","30","30","30","50","50","50","50","20","20","20","20","20","20","20")
)

example_sankey_format <- data.frame(
    from = c(
        "D: Bacteria", "D: Eukaryota",
        "K: Bacteria", "K: Metazoa",
        "P: Actinomycetota", "P: Chordata",
        "C: Actinomycetes", "C: Mammalia", "C: Mammalia",
        "O: Mycobacteriales", "O: Primates", "O: Rodentia",
        "F: Hominidae", "F: Muridae", "F: Mycobacteriaceae",
        "G: Homo", "G: Mus", "G: Mycolicibacterium",
        "S: Homo sapiens", "S: Mus musculus", "S: Mycolicibacterium austroafricanum"
    ),
    to = c(
        "K: Bacteria", "K: Metazoa",
        "P: Actinomycetota", "P: Chordata",
        "C: Actinomycetes", "C: Mammalia",
        "O: Mycobacteriales", "O: Primates", "O: Rodentia",
        "F: Mycobacteriaceae", "F: Hominidae", "F: Muridae",
        "G: Homo", "G: Mus", "G: Mycolicibacterium",
        "S: Homo sapiens", "S: Mus musculus", "S: Mycolicibacterium austroafricanum",
        "30%", "50%", "20%"
    ),
    weight = c(2,8,2,8,2,8,2,3,5,2,3,5,3,5,2,3,5,2,3,5,2),
    id = c(
        "D: BacteriaK: Bacteria", "D: EukaryotaK: Metazoa",
        "K: BacteriaP: Actinomycetota", "K: MetazoaP: Chordata",
        "P: ActinomycetotaC: Actinomycetes", "P: ChordataC: Mammalia",
        "C: ActinomycetesO: Mycobacteriales", "C: MammaliaO: Primates", "C: MammaliaO: Rodentia",
        "O: MycobacterialesF: Mycobacteriaceae", "O: PrimatesF: Hominidae", "O: RodentiaF: Muridae",
        "F: HominidaeG: Homo", "F: MuridaeG: Mus", "F: MycobacteriaceaeG: Mycolicibacterium",
        "G: HomoS: Homo sapiens", "G: MusS: Mus musculus", "G: MycolicibacteriumS: Mycolicibacterium austroafricanum",
        "S: Homo sapiens30%", "S: Mus musculus50%", "S: Mycolicibacterium austroafricanum20%"
    )
)

# ==============================================================================
# Expected outputs
# ==============================================================================

expected_mpa_style_df <- data.frame(
    D       = c("D: Eukaryota", "D: Eukaryota", "D: Bacteria"),
    K       = c("K: Metazoa",   "K: Metazoa",   "K: Bacteria"),
    P       = c("P: Chordata",  "P: Chordata",  "P: Actinomycetota"),
    C       = c("C: Mammalia",  "C: Mammalia",  "C: Actinomycetes"),
    O       = c("O: Primates",  "O: Rodentia",  "O: Mycobacteriales"),
    F       = c("F: Hominidae", "F: Muridae",   "F: Mycobacteriaceae"),
    G       = c("G: Homo",      "G: Mus",       "G: Mycolicibacterium"),
    S       = c("S: Homo sapiens", "S: Mus musculus", "S: Mycolicibacterium austroafricanum"),
    reads   = c("3", "5", "2"),
    percent = c("30%", "50%", "20%")
)

expected_mpa_style_th_25_df <- data.frame(
    D       = c("D: Eukaryota", "D: Eukaryota"),
    K       = c("K: Metazoa",   "K: Metazoa"),
    P       = c("P: Chordata",  "P: Chordata"),
    C       = c("C: Mammalia",  "C: Mammalia"),
    O       = c("O: Primates",  "O: Rodentia"),
    F       = c("F: Hominidae", "F: Muridae"),
    G       = c("G: Homo",      "G: Mus"),
    S       = c("S: Homo sapiens", "S: Mus musculus"),
    reads   = c("3", "5"),
    percent = c("30%", "50%")
)

expected_sankey_format_reordered <- data.frame(
    from = c(
        "D: Bacteria", "D: Eukaryota",
        "K: Bacteria", "K: Metazoa",
        "P: Actinomycetota", "P: Chordata",
        "C: Actinomycetes", "C: Mammalia", "C: Mammalia",
        "O: Mycobacteriales", "O: Primates", "O: Rodentia",
        "F: Mycobacteriaceae", "F: Hominidae", "F: Muridae",
        "G: Mycolicibacterium", "G: Homo", "G: Mus",
        "S: Mycolicibacterium austroafricanum", "S: Homo sapiens", "S: Mus musculus"
    ),
    to = c(
        "K: Bacteria", "K: Metazoa",
        "P: Actinomycetota", "P: Chordata",
        "C: Actinomycetes", "C: Mammalia",
        "O: Mycobacteriales", "O: Primates", "O: Rodentia",
        "F: Mycobacteriaceae", "F: Hominidae", "F: Muridae",
        "G: Mycolicibacterium", "G: Homo", "G: Mus",
        "S: Mycolicibacterium austroafricanum", "S: Homo sapiens", "S: Mus musculus",
        "20%", "30%", "50%"
    ),
    weight = c(2,8,2,8,2,8,2,3,5,2,3,5,2,3,5,2,3,5,2,3,5),
    id = c(
        "D: BacteriaK: Bacteria", "D: EukaryotaK: Metazoa",
        "K: BacteriaP: Actinomycetota", "K: MetazoaP: Chordata",
        "P: ActinomycetotaC: Actinomycetes", "P: ChordataC: Mammalia",
        "C: ActinomycetesO: Mycobacteriales", "C: MammaliaO: Primates", "C: MammaliaO: Rodentia",
        "O: MycobacterialesF: Mycobacteriaceae", "O: PrimatesF: Hominidae", "O: RodentiaF: Muridae",
        "F: MycobacteriaceaeG: Mycolicibacterium", "F: HominidaeG: Homo", "F: MuridaeG: Mus",
        "G: MycolicibacteriumS: Mycolicibacterium austroafricanum", "G: HomoS: Homo sapiens", "G: MusS: Mus musculus",
        "S: Mycolicibacterium austroafricanum20%", "S: Homo sapiens30%", "S: Mus musculus50%"
    )
)

# ==============================================================================
# Tests
# ==============================================================================

test_that("mpa_style_fun returns correct lineages with threshold 0.1", {
    testthat::expect_equal(mpa_style_fun(example_named_df, 0.1), expected_mpa_style_df)
})

test_that("mpa_style_fun filters lineages below threshold 25", {
    testthat::expect_equal(mpa_style_fun(example_named_df, 25.0), expected_mpa_style_th_25_df)
})

test_that("sankey_format_reordered_fun reorders rows to avoid intertwined lineages", {
    result <- sankey_format_reordered_fun(example_sankey_format)
    rownames(result) <- seq_len(nrow(result))
    testthat::expect_equal(result, expected_sankey_format_reordered)
})

# ==============================================================================
# NGSCheckMate fixtures
# ==============================================================================

example_ngscm_all_file <- file.path(script_dir, "data", "test_ngscm_all.txt")
example_vaf_file        <- file.path(script_dir, "data", "test.vaf")

expected_ngscm_pairs <- tibble::tibble(
    sample_label_1 = c("SAMPLE_A", "SAMPLE_A", "SAMPLE_B"),
    sample_label_2 = c("SAMPLE_B", "SAMPLE_C", "SAMPLE_C"),
    match          = c("matched",   "unmatched", "unmatched"),
    correlation    = c(0.95, 0.12, 0.11),
    depth          = c(30,   28,   31)
)

# ==============================================================================
# NGSCheckMate tests
# ==============================================================================

test_that("read_ngscm_pairs returns cleaned pairwise table and excludes Undetermined", {
    result <- read_ngscm_pairs(example_ngscm_all_file)
    testthat::expect_equal(result, expected_ngscm_pairs)
})

test_that("get_homozygous_fraction computes correct fraction from VAF file", {
    testthat::expect_equal(get_homozygous_fraction(example_vaf_file), 0.5)
})

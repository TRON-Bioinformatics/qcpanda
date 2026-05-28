#!/usr/bin/env python3
"""Determine the most appropriate Bracken k-mer length for a FASTQ file.

Computes the mean read length from all records in a (gzipped) FASTQ file,
then returns the closest k-mer length for which a kmer_distrib file exists
in the given Kraken2/Bracken database directory.
"""

from argparse import ArgumentParser
from statistics import mean
import gzip
import os
import re

from Bio import SeqIO


def get_read_length_fastq(filename):
    """Return mean read length from all reads in *filename*."""
    opener = gzip.open if filename.endswith(".gz") else open
    lengths = []
    with opener(filename, "rt") as fh:
        for record in SeqIO.parse(fh, "fastq"):
            lengths.append(len(record.seq))
    if not lengths:
        raise ValueError(f"No reads found in {filename}")
    return int(mean(lengths))


def get_closest_kmer_length(db, read_length):
    """Return the k-mer length whose kmer_distrib file is closest to *read_length*.

    When two k-mer lengths are equally distant, the smaller one is chosen
    because the database files are sorted before comparison.
    """
    names = sorted(os.listdir(db))  # sort so ties favour the smaller k-mer
    db_klens = []
    for name in names:
        m = re.match(r"database(\d+)mers\.kmer_distrib", name)
        if m:
            db_klens.append(int(m.group(1)))
    if not db_klens:
        raise ValueError(f"No kmer_distrib files found in {db}")
    if read_length in db_klens:
        return read_length
    diffs = [abs(k - read_length) for k in db_klens]
    return db_klens[diffs.index(min(diffs))]


def main():
    parser = ArgumentParser(
        description="Select Bracken k-mer length for a FASTQ file"
    )
    parser.add_argument(
        "-d", "--database", required=True,
        help="Kraken2/Bracken database directory"
    )
    parser.add_argument(
        "-f", "--fastq", required=True,
        help="Input FASTQ (or gzipped FASTQ) file"
    )
    args = parser.parse_args()

    read_length = get_read_length_fastq(args.fastq)
    klen = get_closest_kmer_length(args.database, read_length)
    print(klen, end="")


if __name__ == "__main__":
    main()

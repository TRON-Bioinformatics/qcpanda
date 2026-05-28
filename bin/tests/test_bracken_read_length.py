"""Unit tests for bin/bracken_read_length.py."""

import os
import sys
import pytest

# Make the bin/ directory importable regardless of where pytest is invoked from
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from bracken_read_length import get_read_length_fastq, get_closest_kmer_length

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
DB_DIR = os.path.join(DATA_DIR, "db")


class TestGetReadLengthFastq:
    """Tests for get_read_length_fastq()."""

    def test_gzipped_fastq_len10(self):
        fq = os.path.join(DATA_DIR, "reads_len10.fastq.gz")
        assert get_read_length_fastq(fq) == 10

    def test_gzipped_fastq_len20(self):
        fq = os.path.join(DATA_DIR, "reads_len20.fastq.gz")
        assert get_read_length_fastq(fq) == 20

    def test_plain_fastq_len10(self, tmp_path):
        fq = tmp_path / "reads.fastq"
        fq.write_text("@r1\nTTTTTTTTTT\n+\nIIIIIIIIII\n@r2\nTTTTTTTTTT\n+\nIIIIIIIIII\n")
        assert get_read_length_fastq(str(fq)) == 10

    def test_empty_file_raises(self, tmp_path):
        fq = tmp_path / "empty.fastq"
        fq.write_text("")
        with pytest.raises(ValueError, match="No reads found"):
            get_read_length_fastq(str(fq))

    def test_mixed_lengths_returns_mean(self, tmp_path):
        # lengths: 10 and 20 → mean = 15 → int(15) = 15
        fq = tmp_path / "reads.fastq"
        fq.write_text(
            "@r1\nTTTTTTTTTT\n+\nIIIIIIIIII\n"
            "@r2\nTTTTTTTTTTTTTTTTTTTT\n+\nIIIIIIIIIIIIIIIIIIII\n"
        )
        assert get_read_length_fastq(str(fq)) == 15


class TestGetClosestKmerLength:
    """Tests for get_closest_kmer_length() using a DB with 10-mer and 20-mer files."""

    def test_exact_match_10(self):
        assert get_closest_kmer_length(DB_DIR, 10) == 10

    def test_exact_match_20(self):
        assert get_closest_kmer_length(DB_DIR, 20) == 20

    def test_rounds_to_nearest_closer_to_10(self):
        # read_length=14 → |14-10|=4, |14-20|=6 → closest = 10
        assert get_closest_kmer_length(DB_DIR, 14) == 10

    def test_rounds_to_nearest_closer_to_20(self):
        # read_length=16 → |16-10|=6, |16-20|=4 → closest = 20
        assert get_closest_kmer_length(DB_DIR, 16) == 20

    def test_tie_goes_to_smaller(self):
        # read_length=15 → |15-10|=5, |15-20|=5 → tie → sorted list picks 10
        assert get_closest_kmer_length(DB_DIR, 15) == 10

    def test_no_kmer_distrib_files_raises(self, tmp_path):
        with pytest.raises(ValueError, match="No kmer_distrib files found"):
            get_closest_kmer_length(str(tmp_path), 100)

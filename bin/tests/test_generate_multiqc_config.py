import os
import tempfile
from unittest import TestCase

from generate_multiqc_config import (
    generate_sankey_embedded_html,
    _build_bracken_section,
    _build_ngscm_section,
    _tsv_to_html_table,
    _png_to_html_img,
    build_custom_sections,
    write_custom_data,
)

# Minimal 1x1 white PNG bytes for tests
_TINY_PNG = bytes([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
    0xde, 0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41,
    0x54, 0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0x00,
    0x00, 0x00, 0x02, 0x00, 0x01, 0xe2, 0x21, 0xbc,
    0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
    0x44, 0xae, 0x42, 0x60, 0x82,
])


class TestGenerateMultiqcConfig(TestCase):

    # ------------------------------------------------------------------
    # generate_sankey_embedded_html
    # ------------------------------------------------------------------

    def test_sankey_returns_none_for_missing_dir(self):
        self.assertIsNone(generate_sankey_embedded_html("nonexistent_dir"))

    def test_sankey_returns_none_for_empty_dir(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            self.assertIsNone(generate_sankey_embedded_html(tmpdir))

    def test_sankey_returns_none_when_no_sankey_html_files(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            open(os.path.join(tmpdir, "other.html"), "w").close()
            self.assertIsNone(generate_sankey_embedded_html(tmpdir))

    def test_sankey_returns_html_for_flat_sankey_files(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            for name in ["Sample_01_sankey_plot.html", "Sample_02_sankey_plot.html"]:
                with open(os.path.join(tmpdir, name), "w") as fh:
                    fh.write("<html><body>sankey</body></html>")
            result = generate_sankey_embedded_html(tmpdir)
        self.assertIsNotNone(result)
        self.assertIn("mqc-sankey-viewer", result)
        self.assertIn("mqc-sankey-select", result)
        self.assertIn("Sample_01", result)
        self.assertIn("Sample_02", result)

    def test_sankey_contains_iframes_with_srcdoc(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            for name in ["Sample_01_sankey_plot.html", "Sample_02_sankey_plot.html"]:
                with open(os.path.join(tmpdir, name), "w") as fh:
                    fh.write("<html><body>sankey</body></html>")
            result = generate_sankey_embedded_html(tmpdir)
        self.assertIn("mqc-sankey-iframe-Sample_01", result)
        self.assertIn("mqc-sankey-iframe-Sample_02", result)
        self.assertIn("srcdoc", result)

    def test_sankey_first_iframe_visible(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            for name in ["Sample_01_sankey_plot.html", "Sample_02_sankey_plot.html"]:
                with open(os.path.join(tmpdir, name), "w") as fh:
                    fh.write("<html><body>sankey</body></html>")
            result = generate_sankey_embedded_html(tmpdir)
        self.assertIn("display:block", result)

    # ------------------------------------------------------------------
    # _tsv_to_html_table
    # ------------------------------------------------------------------

    def test_tsv_empty_file_returns_empty_string(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".tsv", delete=False) as fh:
            path = fh.name
        result = _tsv_to_html_table(path)
        os.unlink(path)
        self.assertEqual(result, "")

    def test_tsv_header_only_returns_table_with_no_rows(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".tsv", delete=False) as fh:
            fh.write("col_a\tcol_b\n")
            path = fh.name
        result = _tsv_to_html_table(path)
        os.unlink(path)
        self.assertIn("<th>col_a</th>", result)
        self.assertIn("<th>col_b</th>", result)
        self.assertNotIn("<td>", result)

    def test_tsv_data_rows_appear_in_table_body(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".tsv", delete=False) as fh:
            fh.write("sample_label_1\tsample_label_2\tcorrelation\nA\tB\t0.9\n")
            path = fh.name
        result = _tsv_to_html_table(path)
        os.unlink(path)
        self.assertIn("<td>A</td>", result)
        self.assertIn("<td>B</td>", result)
        self.assertIn("<td>0.9</td>", result)

    def test_tsv_table_id_attribute_set(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".tsv", delete=False) as fh:
            fh.write("x\ty\n1\t2\n")
            path = fh.name
        result = _tsv_to_html_table(path, table_id="my-table")
        os.unlink(path)
        self.assertIn('id="my-table"', result)

    def test_tsv_no_table_id_when_not_given(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".tsv", delete=False) as fh:
            fh.write("x\n1\n")
            path = fh.name
        result = _tsv_to_html_table(path)
        os.unlink(path)
        self.assertNotIn(' id="', result)

    # ------------------------------------------------------------------
    # _png_to_html_img
    # ------------------------------------------------------------------

    def test_png_returns_img_tag(self):
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as fh:
            fh.write(_TINY_PNG)
            path = fh.name
        result = _png_to_html_img(path)
        os.unlink(path)
        self.assertTrue(result.startswith("<img "))
        self.assertIn("data:image/png;base64,", result)

    def test_png_base64_content_is_correct(self):
        import base64
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as fh:
            fh.write(_TINY_PNG)
            path = fh.name
        result = _png_to_html_img(path)
        os.unlink(path)
        expected_b64 = base64.b64encode(_TINY_PNG).decode("ascii")
        self.assertIn(expected_b64, result)

    # ------------------------------------------------------------------
    # _build_ngscm_section
    # ------------------------------------------------------------------

    def test_ngscm_missing_dir_returns_none(self):
        self.assertIsNone(_build_ngscm_section("nonexistent_dir"))

    def test_ngscm_empty_dir_returns_none(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            self.assertIsNone(_build_ngscm_section(tmpdir))

    def test_ngscm_with_tsv_and_png_returns_dict(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            with open(os.path.join(tmpdir, "01_ngscheck_pairs.tsv"), "w") as fh:
                fh.write("sample_label_1\tsample_label_2\tcorrelation\nA\tB\t0.9\n")
            with open(os.path.join(tmpdir, "04_distribution.png"), "wb") as fh:
                fh.write(_TINY_PNG)
            result = _build_ngscm_section(tmpdir)
        self.assertIsNotNone(result)
        self.assertEqual(result["section_name"], "NGS Checkmate")
        self.assertEqual(result["plot_type"], "html")
        self.assertIn("mqc-ngscm-dt", result["data"])
        self.assertIn("<img", result["data"])

    # ------------------------------------------------------------------
    # _build_bracken_section
    # ------------------------------------------------------------------

    def test_bracken_missing_dir_returns_none(self):
        self.assertIsNone(_build_bracken_section("nonexistent_dir"))

    def test_bracken_empty_dir_returns_none(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            self.assertIsNone(_build_bracken_section(tmpdir))

    def test_bracken_no_tsv_files_returns_none(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            open(os.path.join(tmpdir, "other.txt"), "w").close()
            self.assertIsNone(_build_bracken_section(tmpdir))

    def test_bracken_returns_bargraph_section(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            with open(os.path.join(tmpdir, "SAMPLE_A.tsv"), "w") as fh:
                fh.write("name\ttaxonomy_id\ttaxonomy_lvl\tkraken_assigned_reads\tadded_reads\tnew_est_reads\tfraction_total_reads\n")
                fh.write("Escherichia coli\t562\tS\t5174\t0\t5174\t1.00000\n")
            result = _build_bracken_section(tmpdir)
        self.assertIsNotNone(result)
        self.assertEqual(result["id"], "bracken_abundance")
        self.assertEqual(result["plot_type"], "bargraph")
        self.assertIn("SAMPLE_A", result["data"])
        self.assertAlmostEqual(result["data"]["SAMPLE_A"]["Escherichia coli"], 1.0)

    def test_bracken_multiple_samples_and_species(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            with open(os.path.join(tmpdir, "S1.tsv"), "w") as fh:
                fh.write("name\ttaxonomy_id\ttaxonomy_lvl\tkraken_assigned_reads\tadded_reads\tnew_est_reads\tfraction_total_reads\n")
                fh.write("Homo sapiens\t9606\tS\t300\t0\t300\t0.30000\n")
                fh.write("Escherichia coli\t562\tS\t700\t0\t700\t0.70000\n")
            with open(os.path.join(tmpdir, "S2.tsv"), "w") as fh:
                fh.write("name\ttaxonomy_id\ttaxonomy_lvl\tkraken_assigned_reads\tadded_reads\tnew_est_reads\tfraction_total_reads\n")
                fh.write("Homo sapiens\t9606\tS\t1000\t0\t1000\t1.00000\n")
            result = _build_bracken_section(tmpdir)
        self.assertIn("S1", result["data"])
        self.assertIn("S2", result["data"])
        self.assertAlmostEqual(result["data"]["S1"]["Homo sapiens"], 0.3)
        self.assertAlmostEqual(result["data"]["S2"]["Homo sapiens"], 1.0)

    def test_bracken_skips_tsv_with_missing_columns(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            with open(os.path.join(tmpdir, "bad.tsv"), "w") as fh:
                fh.write("col1\tcol2\n")
                fh.write("foo\tbar\n")
            result = _build_bracken_section(tmpdir)
        self.assertIsNone(result)

    def test_bracken_pconfig_keys_present(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            with open(os.path.join(tmpdir, "S.tsv"), "w") as fh:
                fh.write("name\ttaxonomy_id\ttaxonomy_lvl\tkraken_assigned_reads\tadded_reads\tnew_est_reads\tfraction_total_reads\n")
                fh.write("Homo sapiens\t9606\tS\t100\t0\t100\t1.0\n")
            result = _build_bracken_section(tmpdir)
        self.assertIn("pconfig", result)
        self.assertIn("id", result["pconfig"])
        self.assertIn("title", result["pconfig"])

    # ------------------------------------------------------------------
    # build_custom_sections
    # ------------------------------------------------------------------

    def test_all_none_returns_empty(self):
        self.assertEqual(build_custom_sections(None, None, None), {})

    def test_sankey_only(self):
        result = build_custom_sections("<div>sankey</div>", None, None)
        self.assertIn("sankey_plots", result)
        self.assertNotIn("my_data_type", result)
        self.assertNotIn("bracken_abundance", result)
        self.assertEqual(result["sankey_plots"]["plot_type"], "html")
        self.assertEqual(result["sankey_plots"]["section_name"], "Bracken - Sankey Plots")

    def test_ngscm_only(self):
        ngscm = {"id": "ngscm_section", "section_name": "NGS Checkmate",
                 "plot_type": "html", "data": "<p>test</p>"}
        result = build_custom_sections(None, ngscm, None)
        self.assertNotIn("sankey_plots", result)
        self.assertIn("my_data_type", result)
        self.assertEqual(result["my_data_type"], ngscm)

    def test_bracken_only(self):
        bracken = {"id": "bracken_abundance", "section_name": "Bracken",
                   "plot_type": "bargraph", "pconfig": {}, "data": {"S": {"E. coli": 1.0}}}
        result = build_custom_sections(None, None, bracken)
        self.assertIn("bracken_abundance", result)
        self.assertNotIn("sankey_plots", result)
        self.assertNotIn("my_data_type", result)

    def test_all_present(self):
        ngscm = {"id": "ngscm_section", "section_name": "NGS Checkmate",
                 "plot_type": "html", "data": "<p>test</p>"}
        bracken = {"id": "bracken_abundance", "section_name": "Bracken",
                   "plot_type": "bargraph", "pconfig": {}, "data": {"S": {"E. coli": 1.0}}}
        result = build_custom_sections("<div>sankey</div>", ngscm, bracken)
        self.assertIn("sankey_plots", result)
        self.assertIn("my_data_type", result)
        self.assertIn("bracken_abundance", result)

    # ------------------------------------------------------------------
    # write_custom_data
    # ------------------------------------------------------------------

    def test_write_empty_sections_produces_empty_file(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as fh:
            path = fh.name
        write_custom_data(path, {})
        with open(path) as fh:
            self.assertEqual(fh.read(), "")
        os.unlink(path)

    def test_write_sankey_section(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as fh:
            path = fh.name
        sections = {
            "sankey_plots": {
                "id": "sankey_plots",
                "section_name": "Sankey Plots",
                "plot_type": "html",
                "data": "<div>hello</div>",
            }
        }
        write_custom_data(path, sections)
        with open(path) as fh:
            content = fh.read()
        self.assertIn("custom_data:", content)
        self.assertIn("sankey_plots:", content)
        self.assertIn("section_name: 'Sankey Plots'", content)
        self.assertIn("data: |\n", content)
        self.assertIn("<div>hello</div>", content)
        os.unlink(path)

    def test_write_escapes_single_quotes_in_scalars(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as fh:
            path = fh.name
        sections = {
            "s": {"id": "s", "section_name": "It's a test", "plot_type": "html", "data": "x"}
        }
        write_custom_data(path, sections)
        with open(path) as fh:
            content = fh.read()
        self.assertIn("It''s a test", content)
        os.unlink(path)

    def test_write_bargraph_data_as_nested_yaml(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as fh:
            path = fh.name
        sections = {
            "bracken_abundance": {
                "id": "bracken_abundance",
                "section_name": "Bracken Abundance Estimates",
                "plot_type": "bargraph",
                "pconfig": {"id": "bracken_bargraph_plot", "title": "Bracken: Organism Abundance", "tt_decimals": 3},
                "data": {"SAMPLE_A": {"Escherichia coli": 1.0}, "SAMPLE_B": {"Homo sapiens": 0.4, "Escherichia coli": 0.6}},
            }
        }
        write_custom_data(path, sections)
        with open(path) as fh:
            content = fh.read()
        # data block must be a nested map, not a literal block scalar
        self.assertIn("data:\n", content)
        self.assertNotIn("data: |\n", content)
        self.assertIn("'SAMPLE_A':", content)
        self.assertIn("'Escherichia coli':", content)
        # pconfig must be a nested map
        self.assertIn("pconfig:\n", content)
        self.assertIn("tt_decimals: 3", content)
        os.unlink(path)


if __name__ == "__main__":
    import unittest
    unittest.main()

#!/usr/bin/env python

from argparse import ArgumentParser
import base64
import os
import re


def generate_sankey_embedded_html(sankey_dir):
    """Build an HTML snippet with a sample dropdown and srcdoc iframes
    embedding each self-contained *_sankey_plot.html file inline.

    Expects flat files named {sample}_sankey_plot.html directly in sankey_dir.
    Returns None when no valid sankey files are found.
    """
    if not os.path.exists(sankey_dir):
        return None

    sankey_files = sorted(
        f for f in os.listdir(sankey_dir) if f.endswith("_sankey_plot.html")
    )
    sample_names = [re.sub(r"_sankey_plot\.html$", "", f) for f in sankey_files]

    if not sample_names:
        return None

    options_html = "\n".join(
        '<option value="{n}">{n}</option>'.format(n=name) for name in sample_names
    )

    iframe_parts = []
    for i, (name, fname) in enumerate(zip(sample_names, sankey_files)):
        display = "block" if i == 0 else "none"
        html_path = os.path.join(sankey_dir, fname)
        with open(html_path, "r", encoding="utf-8") as fh:
            html_content = fh.read()
        # Escape double quotes and backtick-safe encoding for srcdoc attribute
        srcdoc = html_content.replace("&", "&amp;").replace('"', "&quot;")
        iframe_parts.append(
            '<iframe id="mqc-sankey-iframe-{name}" srcdoc="{srcdoc}" '
            'style="width:100%;height:500px;border:none;display:{display};" '
            'title="Sankey plot for {name}"></iframe>'.format(
                name=name, srcdoc=srcdoc, display=display
            )
        )

    iframes_html = "\n".join(iframe_parts)

    js = (
        "function mqcShowSankey(v){"
        "var c=document.getElementById('mqc-sankey-container');"
        "var iframes=c.getElementsByTagName('iframe');"
        "for(var i=0;i<iframes.length;i++){iframes[i].style.display='none';}"
        "if(v){var t=document.getElementById('mqc-sankey-iframe-'+v);"
        "if(t)t.style.display='block';}}"
    )

    return (
        '<div id="mqc-sankey-viewer">'
        '<div style="margin-bottom:8px;">'
        '<label for="mqc-sankey-select"><strong>Sample:</strong>&nbsp;</label>'
        '<select id="mqc-sankey-select" '
        'onchange="mqcShowSankey(this.value)" '
        'style="padding:4px 8px;border-radius:4px;">'
        '<option value="">-- select sample --</option>'
        '{options}'
        '</select>'
        '</div>'
        '<div id="mqc-sankey-container">{iframes}</div>'
        '</div>'
        '<script>{js}</script>'
    ).format(options=options_html, iframes=iframes_html, js=js)


# Inline CSS + vanilla-JS for sortable / searchable / paginated tables.
# Included once per NGS Checkmate section; initialises every .mqc-ngscm-dt table.
_DT_ASSETS = (
    "<style>"
    ".mqc-ngscm-dt-wrap{margin-bottom:20px}"
    ".mqc-ngscm-dt-ctrl{display:flex;justify-content:space-between;align-items:center;"
    "margin-bottom:6px;flex-wrap:wrap;gap:4px}"
    ".mqc-ngscm-dt-ctrl input,.mqc-ngscm-dt-ctrl select"
    "{padding:2px 5px;border:1px solid #ccc;border-radius:3px}"
    "th[data-mqcsort]{cursor:pointer;user-select:none}"
    "th[data-mqcsort='']::after{content:' \u2195';font-size:.8em;color:#999}"
    "th[data-mqcsort='asc']::after{content:' \u2191';font-size:.8em;color:#333}"
    "th[data-mqcsort='desc']::after{content:' \u2193';font-size:.8em;color:#333}"
    ".mqc-ngscm-dt-pag{margin-top:6px;display:flex;gap:4px;flex-wrap:wrap;align-items:center}"
    ".mqc-ngscm-dt-pag button{padding:1px 8px;border:1px solid #ccc;"
    "border-radius:3px;cursor:pointer}"
    ".mqc-ngscm-dt-pag button.cur{background:#337ab7;color:#fff;border-color:#337ab7}"
    ".mqc-ngscm-dt-pag button:disabled{opacity:.4;cursor:default}"
    ".mqc-ngscm-dt-ellipsis{padding:1px 4px;color:#999}"
    "</style>"
    "<script>"
    "(function(){"
    "var _n=0;"
    "function init(tbl){"
    "var allRows=Array.from(tbl.tBodies[0].rows).map(function(r){"
    "return Array.from(r.cells).map(function(c){return c.textContent.trim();});});"
    "var ps=10,pg=0,sc=-1,sd=1,flt='';"
    "var uid='mqcdt'+(++_n);"
    "var wrap=document.createElement('div');"
    "wrap.className='mqc-ngscm-dt-wrap';"
    "tbl.parentNode.insertBefore(wrap,tbl);"
    "wrap.appendChild(tbl);"
    "var ctrl=document.createElement('div');"
    "ctrl.className='mqc-ngscm-dt-ctrl';"
    "var sl=document.createElement('label');"
    "sl.appendChild(document.createTextNode('Show\u00a0'));"
    "var sel=document.createElement('select');"
    "sel.id=uid+'n';"
    "[10,25,50,-1].forEach(function(v){"
    "var o=document.createElement('option');"
    "o.value=v;"
    "o.textContent=(v===-1)?'All':String(v);"
    "sel.appendChild(o);});"
    "sl.appendChild(sel);"
    "sl.appendChild(document.createTextNode('\u00a0entries'));"
    "ctrl.appendChild(sl);"
    "var ql=document.createElement('label');"
    "ql.appendChild(document.createTextNode('Search:\u00a0'));"
    "var inp=document.createElement('input');"
    "inp.type='text';"
    "inp.id=uid+'q';"
    "ql.appendChild(inp);"
    "ctrl.appendChild(ql);"
    "wrap.insertBefore(ctrl,tbl);"
    "var pag=document.createElement('div');"
    "pag.className='mqc-ngscm-dt-pag';"
    "wrap.appendChild(pag);"
    "Array.from(tbl.tHead.rows[0].cells).forEach(function(th,i){"
    "th.dataset.mqcsort='';"
    "th.addEventListener('click',function(){"
    "if(sc===i)sd*=-1;else{sc=i;sd=1;}"
    "Array.from(tbl.tHead.rows[0].cells).forEach(function(x){x.dataset.mqcsort='';});"
    "th.dataset.mqcsort=(sd>0)?'asc':'desc';"
    "pg=0;render();});});"
    "sel.addEventListener('change',function(){ps=+this.value;pg=0;render();});"
    "inp.addEventListener('input',function(){flt=this.value.toLowerCase();pg=0;render();});"
    "function render(){"
    "var rows=allRows.filter(function(r){"
    "return!flt||r.some(function(c){return c.toLowerCase().indexOf(flt)>=0;});});"
    "if(sc>=0)rows=rows.slice().sort(function(a,b){"
    "return sd*(a[sc]<b[sc]?-1:a[sc]>b[sc]?1:0);});"
    "var tot=rows.length,sz=(ps===-1)?tot:ps;"
    "var page=rows.slice(pg*sz,(pg+1)*sz);"
    "var tb=tbl.tBodies[0];tb.innerHTML='';"
    "page.forEach(function(r){"
    "var tr=document.createElement('tr');"
    "r.forEach(function(c){"
    "var td=document.createElement('td');"
    "td.textContent=c;"
    "tr.appendChild(td);});"
    "tb.appendChild(tr);});"
    "pag.innerHTML='';"
    "if(sz<tot){"
    "var np=Math.ceil(tot/sz);"
    "function ellip(){"
    "var sp=document.createElement('span');"
    "sp.className='mqc-ngscm-dt-ellipsis';"
    "sp.textContent='...';"
    "pag.appendChild(sp);}"
    "function pgBtn(idx){(function(i){"
    "var b=document.createElement('button');"
    "b.textContent=i+1;"
    "if(i===pg)b.className='cur';"
    "b.addEventListener('click',function(){pg=i;render();});"
    "pag.appendChild(b);})(idx);}"
    "var prev=document.createElement('button');"
    "prev.textContent='\u2039 Prev';"
    "prev.disabled=(pg===0);"
    "prev.addEventListener('click',function(){if(pg>0){pg--;render();}});"
    "pag.appendChild(prev);"
    "if(np<=7){for(var i=0;i<np;i++)pgBtn(i);}"
    "else if(pg<5){for(var i=0;i<5;i++)pgBtn(i);ellip();pgBtn(np-1);}"
    "else if(pg>=np-5){pgBtn(0);ellip();for(var i=np-5;i<np;i++)pgBtn(i);}"
    "else{pgBtn(0);ellip();pgBtn(pg-1);pgBtn(pg);pgBtn(pg+1);ellip();pgBtn(np-1);}"
    "var nxt=document.createElement('button');"
    "nxt.textContent='Next \u203a';"
    "nxt.disabled=(pg===np-1);"
    "nxt.addEventListener('click',function(){if(pg<np-1){pg++;render();}});"
    "pag.appendChild(nxt);}}"    # closes if(sz<tot) and render()
    "render();}"                  # initial render(); closes init(tbl)
    "function tryInit(){"
    "document.querySelectorAll('table.mqc-ngscm-dt:not([data-mqc-init])').forEach("
    "function(t){t.setAttribute('data-mqc-init','1');init(t);});}"
    "if(document.readyState==='loading'){"
    "document.addEventListener('DOMContentLoaded',tryInit);"
    "}else{tryInit();}"
    "window.addEventListener('load',tryInit);"
    "})();"
    "</script>"
)


def _tsv_to_html_table(tsv_path, table_id=None):
    """Convert a TSV file to a sortable/searchable/paginated HTML table."""
    with open(tsv_path, "r") as fh:
        lines = [line.rstrip("\n").split("\t") for line in fh if line.strip()]
    if not lines:
        return ""
    header = lines[0]
    rows = lines[1:]
    id_attr = ' id="{}"'.format(table_id) if table_id else ""
    th = "".join("<th>{}</th>".format(h) for h in header)
    trs = "".join(
        "<tr>" + "".join("<td>{}</td>".format(c) for c in row) + "</tr>"
        for row in rows
    )
    return (
        '<table{id_attr} class="table table-condensed mqc-ngscm-dt" style="font-size:12px;width:100%;">'
        "<thead><tr>{th}</tr></thead><tbody>{trs}</tbody></table>"
    ).format(id_attr=id_attr, th=th, trs=trs)


def _png_to_html_img(png_path):
    """Return an <img> tag with base64-encoded PNG content."""
    with open(png_path, "rb") as fh:
        b64 = base64.b64encode(fh.read()).decode("ascii")
    return (
        '<img src="data:image/png;base64,{b64}" '
        'style="max-width:100%;height:auto;" />'
    ).format(b64=b64)


def _build_ngscm_section(ngscm_plots_dir):
    """Build an HTML section from the NGS Checkmate plots directory."""
    if not os.path.exists(ngscm_plots_dir):
        return None
    try:
        entries = sorted(os.listdir(ngscm_plots_dir))
    except OSError:
        return None
    entries = [e for e in entries if e.endswith(".tsv") or e.endswith(".png")]
    if not entries:
        return None
    parts = [_DT_ASSETS]
    for entry in entries:
        path = os.path.join(ngscm_plots_dir, entry)
        stem = re.sub(r"^\d+_", "", entry.rsplit(".", 1)[0])
        heading = stem.replace("_", " ").title()
        parts.append("<h4>{}</h4>".format(heading))
        if entry.endswith(".tsv"):
            table_id = "mqc-ngscm-" + stem.replace("_", "-")
            parts.append(_tsv_to_html_table(path, table_id))
        else:
            parts.append(_png_to_html_img(path))
    return {
        "id": "ngscm_section",
        "section_name": "NGS Checkmate",
        "plot_type": "html",
        "data": "\n".join(parts),
    }


def _build_bracken_section(bracken_dir):
    """Parse Bracken TSV files and build a MultiQC bargraph custom_data section.

    Expects flat TSV files named {sample}.tsv directly in bracken_dir.
    Each TSV must contain 'name' and 'fraction_total_reads' columns.
    Returns None when no valid data is found.
    """
    if not os.path.exists(bracken_dir):
        return None

    tsv_files = sorted(f for f in os.listdir(bracken_dir) if f.endswith(".tsv"))
    if not tsv_files:
        return None

    sample_data = {}
    for tsv_file in tsv_files:
        sample_name = tsv_file[:-4]  # strip .tsv
        tsv_path = os.path.join(bracken_dir, tsv_file)
        with open(tsv_path) as fh:
            lines = [ln.rstrip("\n").split("\t") for ln in fh if ln.strip()]
        if len(lines) < 2:
            continue
        header = lines[0]
        try:
            name_idx = header.index("name")
            frac_idx = header.index("fraction_total_reads")
        except ValueError:
            continue
        species_dict = {}
        for cols in lines[1:]:
            if len(cols) <= max(name_idx, frac_idx):
                continue
            species = cols[name_idx]
            try:
                frac = float(cols[frac_idx])
            except ValueError:
                continue
            species_dict[species] = frac
        if species_dict:
            sample_data[sample_name] = species_dict

    if not sample_data:
        return None

    return {
        "id": "bracken_abundance",
        "section_name": "Bracken Abundance Estimates",
        "description": "Organism abundance estimated by Bracken re-estimation from Kraken2 classification",
        "plot_type": "bargraph",
        "pconfig": {
            "id": "bracken_bargraph_plot",
            "title": "Bracken: Organism Abundance",
            "ylab": "Fraction of reads",
            "stacking": "normal",
            "tt_decimals": 3,
        },
        "data": sample_data,
    }


def build_custom_sections(sankey_html, ngscm_section, bracken_section):
    """Build the custom_sections dict from optional inputs.

    Returns a dict ready to pass to write_custom_data.
    """
    sections = {}
    if bracken_section:
        sections["bracken_abundance"] = bracken_section
    if sankey_html:
        sections["sankey_plots"] = {
            "id": "sankey_plots",
            "section_name": "Bracken - Sankey Plots",
            "description": "Contamination lineage Sankey plots per sample",
            "plot_type": "html",
            "data": sankey_html,
        }
    if ngscm_section:
        sections["my_data_type"] = ngscm_section
    return sections


def write_custom_data(output_config, sections):
    """Write a single custom_data YAML block covering all provided sections.

    HTML data fields use YAML literal block scalars.
    Bargraph data fields (dicts) are written as nested YAML maps.
    pconfig dicts are written as nested YAML maps.
    All other fields are written as single-quoted scalars.
    """
    with open(output_config, "w") as fh:
        if not sections:
            return
        fh.write("custom_data:\n")
        for key, fields in sections.items():
            fh.write("  {key}:\n".format(key=key))
            for field, value in fields.items():
                if field == "pconfig" and isinstance(value, dict):
                    fh.write("    pconfig:\n")
                    for k, v in value.items():
                        if isinstance(v, bool):
                            fh.write("      {k}: {v}\n".format(k=k, v=str(v).lower()))
                        elif isinstance(v, str):
                            fh.write("      {k}: '{v}'\n".format(k=k, v=v.replace("'", "''")))
                        else:
                            fh.write("      {k}: {v}\n".format(k=k, v=v))
                elif field == "data" and isinstance(value, dict):
                    # Bargraph / table data: write as nested YAML map
                    fh.write("    data:\n")
                    for sample, species_dict in sorted(value.items()):
                        fh.write("      '{s}':\n".format(s=sample.replace("'", "''")))
                        for species, frac in sorted(species_dict.items(), key=lambda x: -x[1]):
                            fh.write("        '{sp}': {frac:.6f}\n".format(
                                sp=species.replace("'", "''"), frac=frac))
                elif field == "data" and isinstance(value, str):
                    # HTML literal block scalar
                    fh.write("    data: |\n")
                    for line in value.splitlines():
                        fh.write("      {line}\n".format(line=line))
                else:
                    # Single-quoted scalar; escape embedded single quotes
                    fh.write("    {field}: '{value}'\n".format(
                        field=field, value=str(value).replace("'", "''")))


def write_default_content(output_config):
    with open(output_config, "a") as fh:
        fh.write(
            "\n"
            "use_filename_as_sample_name:\n"
            "  - fastp\n"
            "  - sortmerna\n"
            "\n"
            # Strip the .sortmerna suffix that sortmerna adds to log filenames
            # so MultiQC shows 'SAMPLE' instead of 'SAMPLE.sortmerna'.
            # Also strip other tool-specific suffixes that MultiQC doesn't clean by default.
            "fn_clean_exts:\n"
            "  - .gz\n"                      # FastQC: SAMPLE_1.fastq.gz -> SAMPLE_1 (after default .fastq strip)
            "  - .fastp\n"                   # fastp:  SAMPLE.fastp.json -> SAMPLE (after default .json strip)
            "  - .kraken2.report.txt\n"      # Kraken2: SAMPLE.kraken2.report.txt -> SAMPLE
            "  - .sortmerna\n"               # SortMeRNA: SAMPLE.sortmerna.log -> SAMPLE (after default .log strip)
            "  - _screen.txt\n"              # FastQ Screen: SAMPLE_1_screen.txt -> SAMPLE_1
            "\n"
            "report_section_order:\n"
            "  fastqc:\n"
            "    order: 1000\n"
            "  fastp:\n"
            "    order: 900\n"
            "  sequali:\n"
            "    order: 800\n"
            "  fastq_screen:\n"
            "    order: 700\n"
            "  sortmerna:\n"
            "    order: 600\n"
            "  kraken:\n"
            "    order: 500\n"
            "  bracken_abundance:\n"
            "    order: 400\n"
            "  sankey_plots:\n"
            "    order: 300\n"
            "  ngscm_section:\n"
            "    order: 200\n"
            # nf-core boilerplate — pushed to end with negative numbers
            "  'TRON-qcpanda-methods-description':\n"
            "    order: -1000\n"
            "  'TRON-qcpanda-summary':\n"
            "    order: -1001\n"
            "  software_versions:\n"
            "    order: -1002\n"
        )


def main():
    parser = ArgumentParser(description="Create multiqc_config.yaml")

    parser.add_argument(
        "-o", "--output_config",
        dest="output_config",
        help="Path for the output multiqc_config.yaml file",
        required=True,
    )
    parser.add_argument(
        "--sankey_dir",
        dest="sankey_dir",
        default=None,
        help="Directory containing flat {sample}_sankey_plot.html files (optional)",
    )
    parser.add_argument(
        "--ngscm_plots_dir",
        dest="ngscm_plots_dir",
        default=None,
        help="Directory containing NGSCheckMate analysis plots (optional)",
    )
    parser.add_argument(
        "--bracken_dir",
        dest="bracken_dir",
        default=None,
        help="Directory containing Bracken TSV abundance files (optional)",
    )

    args = parser.parse_args()

    sankey_html      = generate_sankey_embedded_html(args.sankey_dir)   if args.sankey_dir   else None
    ngscm_section    = _build_ngscm_section(args.ngscm_plots_dir)       if args.ngscm_plots_dir else None
    bracken_section  = _build_bracken_section(args.bracken_dir)         if args.bracken_dir  else None

    custom_sections = build_custom_sections(sankey_html, ngscm_section, bracken_section)
    write_custom_data(args.output_config, custom_sections)
    write_default_content(args.output_config)


if __name__ == "__main__":
    main()

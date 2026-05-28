process FASTQSCREEN_FASTQSCREEN {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/fc/fc53eee7ca23c32220a9662fbb63c67769756544b6d74a1ee85cf439ea79a7ee/data'
        : 'community.wave.seqera.io/library/fastq-screen_perl-gdgraph:5c1786a5d5bc1309'}"

    input:
    tuple val(meta), path(reads)
    tuple val(ref_names), path(ref_dirs, name: "ref*"), val(ref_basenames), val(ref_aligners)

    output:
    tuple val(meta), path("*.txt"), emit: txt
    tuple val(meta), path("*.png"), emit: png, optional: true
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.fastq.gz"), emit: fastq, optional: true
    tuple val("${task.process}"), val('fastqscreen'), eval('fastq_screen --version 2>&1 | sed "s/^.*FastQ Screen v//;"'), emit: versions_fastqscreen, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args   = task.ext.args ?: ""
    def config_content = ref_names.withIndex().collect { name, i ->
        "DATABASE ${name} ./${ref_dirs[i]}/${ref_basenames[i]} ${ref_aligners[i]}"
    }.join('\n')

    """
    echo '${config_content}' > fastq_screen.conf

    i=1
    RENAMED=()
    for read in ${reads}; do
        target="${prefix}_\${i}.fastq.gz"
        [ "\$read" != "\$target" ] && ln -sf "\$read" "\$target"
        RENAMED+=("\$target")
        (( i++ )) || true
    done

    fastq_screen \\
        --conf fastq_screen.conf \\
        --threads ${task.cpus} \\
        "\${RENAMED[@]}" \\
        ${args}
    """

    stub:
    def prefix = task.ext.prefix ?: meta.id
    def n      = reads instanceof List ? reads.size() : 1
    """
    for i in \$(seq 1 ${n}); do
        touch ${prefix}_\${i}_screen.html
        touch ${prefix}_\${i}_screen.png
        touch ${prefix}_\${i}_screen.txt
    done
    """
}

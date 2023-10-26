process READ_CLASSIFY_KRAKEN_ONE {

    publishDir "${params.outdir}/trim_reads",
        mode: "${params.publish_dir_mode}",
        pattern: "*.tab*"
    publishDir "${params.process_log_dir}",
        mode: "${params.publish_dir_mode}",
        pattern: ".command.*",
        saveAs: { filename -> "${meta.id}.${task.process}${filename}" }

    label "process_high"
    label "process_high_memory"
    tag { "${meta.id}" }

    container "gregorysprenger/kraken@sha256:650ce8ce4a5e313dfafa1726168bb4f7942e543075743766afe1f21ae19abf9c"

    input:
    tuple val(meta), path(paired_R1_gz), path(paired_R2_gz), path(single_gz), path(qc_nonoverlap_filecheck)

    output:
    path ".command.out"
    path ".command.err"
    path "${meta.id}_kraken1.tab.gz"
    path "${meta.id}.taxonomy1-reads.tab"
    path "versions.yml"                  , emit: versions

    shell:
    '''
    source bash_functions.sh
    source summarize_kraken.sh

    # Exit if previous process fails qc filecheck
    for filecheck in !{qc_nonoverlap_filecheck}; do
      if [[ $(grep "FAIL" ${filecheck}) ]]; then
        error_message=$(awk -F '\t' 'END {print $2}' ${filecheck} | sed 's/[(].*[)] //g')
        msg "${error_message} Check failed" >&2
        exit 1
      else
        rm ${filecheck}
      fi
    done

    # If user doesn't provide a non-default db path, use the path in the Docker container,
    #  which contains a smaller minikraken database
    if [[ -d "!{params.kraken1_db}" ]]; then
      database="!{params.kraken1_db}"
      msg "INFO: Using user specified Kraken 1 database: !{params.kraken1_db}"
    else
      database="/kraken-database/"
      msg "INFO: Using pre-loaded MiniKraken database for Kraken 1"
    fi

    # Confirm the db exists
    for ext in idx kdb; do
      if ! verify_minimum_file_size "${database}/database.${ext}" 'kraken database' '10c'; then
        msg "ERROR: pre-formatted kraken database (.${ext}) for read classification is missing" >&2
        exit 1
      fi
    done

    # Investigate taxonomic identity of cleaned reads
    if [ ! -s !{meta.id}.taxonomy1-reads.tab ]; then
      msg "INFO: Performing Kraken1 classifications"
      kraken \
        --fastq-input \
        --db ${database} \
        --gzip-compressed \
        --threads !{task.cpus} \
        !{paired_R1_gz} !{paired_R2_gz} !{single_gz} \
        > !{meta.id}_kraken.output

      msg "INFO: Creating Kraken Report"
      kraken-report \
        --db ${database} \
        !{meta.id}_kraken.output \
        > kraken.tab 2>&1 | tr '^M' '\n' 1>&2

      msg "INFO: Summarizing Kraken1"
      summarize_kraken 'kraken.tab' > !{meta.id}.taxonomy1-reads.tab

      mv kraken.tab !{meta.id}_kraken1.tab
      gzip !{meta.id}_kraken1.tab
    fi

    # Get process version information
    cat <<-END_VERSIONS | sed -r 's/^ {4}//' | sed "s/\bEND_VERSIONS\b//" > versions.yml
    "!{task.process}":
        kraken: $(kraken --version | head -n 1 | awk 'NF>1{print $NF}')
    END_VERSIONS
    '''
}

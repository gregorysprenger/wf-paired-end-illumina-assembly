process EXTRACT_READ_ALIGNMENT_DEPTHS_BEDTOOLS {

    tag { "${meta.id}" }
    container "snads/bedtools@sha256:9b80fb5c5ef1b6f4a4a211d8739fa3fe107da34d1fb6609d6b70ddc7afdce12c"

    input:
    tuple val(meta), path(paired_bam), path(single_bam), path(qc_assembly_filecheck)

    output:
    path ".command.out"
    path ".command.err"
    path "versions.yml"                                                           , emit: versions
    tuple val(meta), path("${meta.id}.CleanedReads-AlnStats.tsv"), emit: summary_alignment_stats

    shell:
    '''
    source bash_functions.sh

    # Exit if previous process fails qc filecheck
    for filecheck in !{qc_assembly_filecheck}; do
      if [[ $(grep "FAIL" ${filecheck}) ]]; then
        error_message=$(awk -F '\t' 'END {print $2}' ${filecheck} | sed 's/[(].*[)] //g')
        msg "${error_message} Check failed" >&2
        exit 1
      else
        rm ${filecheck}
      fi
    done

    # Calculate and report coverage of paired-reads and singleton reads separately
    msg "INFO: Extracting read alignment depths using bedtools"

    single_cov='0 bp TooFewToMap Singleton Reads (0.0x)\t'
    if [ -s !{single_bam} ]; then
      single_cov=$(bedtools genomecov -d -split -ibam !{single_bam} |\
        awk '{sum+=$3} END{print sum " bp Singleton Reads Mapped (" sum/NR "x)\t"}')
    fi

    cov_info=$(bedtools genomecov -d -split -ibam !{meta.id}.paired.bam |\
      awk -v OFS='\t' -v SEcov="${single_cov}" 'BEGIN{sum=0} {sum+=$3} END{
      print sum " bp Paired Reads Mapped (" sum/NR "x)\t" SEcov NR " bp Genome"}')

    echo -e "!{meta.id}\t${cov_info}" \
      > !{meta.id}.CleanedReads-AlnStats.tsv

    sed -i \
      '1i Sample name\tCoverage of paired reads\tCoverage of singleton reads\tGenome size' \
      !{meta.id}.CleanedReads-AlnStats.tsv

    # Get process version information
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
      bedtools: $(bedtools --version | awk 'NF>1{print $NF}')
    END_VERSIONS
    '''
}

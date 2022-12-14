process CLEANED_COVERAGE {

    publishDir "${params.process_log_dir}",
        mode: "${params.publish_dir_mode}",
        pattern: ".command.*",
        saveAs: { filename -> "${base}.${task.process}${filename}"}

    tag { "${base}" }
    
    container "snads/bedtools@sha256:9b80fb5c5ef1b6f4a4a211d8739fa3fe107da34d1fb6609d6b70ddc7afdce12c"

    input:
        tuple val(base), val(size), path(paired_bam), path(single_bam)

    output:
        tuple val(base), path("${base}.Summary.Illumina.CleanedReads-AlnStats.tab"), emit: summary_stats
        path "${base}.Summary.Illumina.CleanedReads-AlnStats.tab", emit: summary_alnstats
        path ".command.out"
        path ".command.err"
        path "versions.yml", emit: versions

    shell:
        '''
        source bash_functions.sh

        # Calculate coverage
        msg "INFO: Running bedtools"

        single_cov='0 bp TooFewToMap Singleton Reads (0.0x)\t'
        if [ -s !{single_bam} ]; then
            single_cov=$(bedtools genomecov -d -split -ibam !{single_bam} |\
            awk '{sum+=$3} END{print sum " bp Singleton Reads Mapped (" sum/NR "x)\t"}')
        fi

        cov_nfo=$(bedtools genomecov -d -split -ibam !{base}.paired.bam |\
        awk -v SEcov="${single_cov}" 'BEGIN{sum=0} {sum+=$3} END{
            print sum " bp Paired Reads Mapped (" sum/NR "x)\t" SEcov NR " bp Genome"}')

        echo -e "!{base}\t${cov_nfo}" >> \
        !{base}.Summary.Illumina.CleanedReads-AlnStats.tab

        # Get process version
        cat <<-END_VERSIONS > versions.yml
        "!{task.process}":
            bedtools: $(bedtools --version | awk 'NF>1{print $NF}')
        END_VERSIONS
        '''
}
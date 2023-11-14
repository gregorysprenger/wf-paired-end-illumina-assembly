process REMOVE_PHIX_BBDUK {

    label "process_low"
    tag { "${meta.id}" }
    container "snads/bbtools@sha256:9f2a9b08563839cec87d856f0fc7607c235f464296fd71e15906ea1d15254695"

    input:
    tuple val(meta), path(reads)
    path phix_reference_file

    output:
    path ".command.out"
    path ".command.err"
    path "versions.yml"                                                                , emit: versions
    path "${meta.id}.Summary.PhiX.tsv"                                                 , emit: phix_summary
    path("${meta.id}.PhiX*_File.tsv")                                                  , emit: qc_filecheck
    tuple val(meta), path("${meta.id}_noPhiX-R1.fsq"), path("${meta.id}_noPhiX-R2.fsq"), emit: fastq_phix_removed

    shell:
    '''
    source bash_functions.sh

    # Verify PhiX reference file size
    if verify_minimum_file_size !{phix_reference_file} 'PhiX Genome' "!{params.min_filesize_phix_genome}"; then
      echo -e "!{meta.id}\tPhiX Genome\tPASS" >> !{meta.id}.PhiX_Genome_File.tsv
    else
      echo -e "!{meta.id}\tPhiX Genome\tFAIL" >> !{meta.id}.PhiX_Genome_File.tsv
    fi

    # Auto reformat FastQ files
    msg "INFO: Auto reformatting FastQ files.."
    for read in !{reads}; do
      reformat.sh \
        in="${read}" \
        out="reformatted.${read}" \
        tossbrokenreads=t
    done

    # Remove PhiX
    msg "INFO: Removing PhiX using BBDuk.."

    bbduk.sh \
      k=31 \
      hdist=1 \
      qout=33 \
      qin=auto \
      overwrite=t \
      in="reformatted.!{reads[0]}" \
      in2="reformatted.!{reads[1]}" \
      threads=!{task.cpus} \
      out=!{meta.id}_noPhiX-R1.fsq \
      out2=!{meta.id}_noPhiX-R2.fsq \
      ref="!{phix_reference_file}"

    for suff in R1.fsq R2.fsq; do
      if verify_minimum_file_size "!{meta.id}_noPhiX-${suff}" 'PhiX-removed FastQ Files' "!{params.min_filesize_fastq_phix_removed}"; then
        echo -e "!{meta.id}\tPhiX-removed FastQ ($suff) File\tPASS" \
          >> !{meta.id}.PhiX-removed_FastQ_File.tsv
      else
        echo -e "!{meta.id}\tPhiX-removed FastQ ($suff) File\tFAIL" \
          >> !{meta.id}.PhiX-removed_FastQ_File.tsv
      fi
    done

    # Raw input read and bp information
    TOT_READS=$(grep '^Input: ' .command.err | awk '{print $2}')
    TOT_BASES=$(grep '^Input: ' .command.err | awk '{print $4}')

    if [[ -z "${TOT_READS}" || -z "${TOT_BASES}" ]]; then
      msg 'ERROR: unable to parse input counts from bbduk log' >&2
      exit 1
    fi

    # Number of PhiX read/bp contaminants
    NUM_PHIX_READS=$(grep '^Contaminants: ' .command.err | awk '{print $2}' | sed 's/,//g')
    PERCENT_PHIX_READS=$(grep '^Contaminants: ' .command.err | awk '{print $4}' | sed 's/[()]//g')
    NUM_PHIX_BASES=$(grep '^Contaminants: ' .command.err | awk '{print $5}' | sed 's/,//g')
    PERCENT_PHIX_BASES=$(grep '^Contaminants: ' .command.err | awk '{print $7}' | sed 's/[()]//g')

    # Cleaned FastQ file information
    NUM_CLEANED_READS=$(grep '^Result: ' .command.err | awk '{print $2}')
    PERCENT_CLEANED_READS=$(grep '^Result: ' .command.err | awk '{print $4}' | sed 's/[()]//g')
    NUM_CLEANED_BASES=$(grep '^Result: ' .command.err | awk '{print $4}')
    PERCENT_CLEANED_BASES=$(grep '^Result: ' .command.err | awk '{print $7}' | sed 's/[()]//g')

    msg "INFO: Input contains ${TOT_BASES} bp and $TOT_READS reads"
    msg "INFO: ${PHIX_BASES:-0} bp of PhiX were detected and ${PHIX_READS:-0} reads were removed"

    SUMMARY_HEADER="
      Sample name\t
      # Cleaned reads\t
      % Cleaned reads\t
      # Cleaned bp\t
      % Cleaned bp\t
      # PhiX reads\t
      % PhiX reads\t
      # PhiX Bp\t
      % PhiX bp\t
      # Raw reads\t
      # Raw bp
      "

    SUMMARY_OUTPUT="
      !{meta.id}\t
      ${NUM_CLEANED_READS}\t
      ${PERCENT_CLEANED_READS}\t
      ${NUM_CLEANED_BASES}\t
      ${PERCENT_CLEANED_BASES}\t
      ${NUM_PHIX_READS}\t
      ${PERCENT_PHIX_READS}\t
      ${NUM_PHIX_BASES}\t
      ${PERCENT_PHIX_BASES}\t
      ${TOT_READS}\t
      ${TOT_BASES}
      "

    echo -e $SUMMARY_HEADER > !{meta.id}.Summary.PhiX.tsv
    echo -e $SUMMARY_OUTPUT >> !{meta.id}.Summary.PhiX.tsv

    # Get process version information
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        bbduk: $(bbduk.sh --version 2>&1 | head -n 2 | tail -1 | awk 'NF>1{print $NF}')
    END_VERSIONS
    '''
}

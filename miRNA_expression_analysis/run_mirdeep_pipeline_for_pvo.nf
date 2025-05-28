#!/usr/bin/env nextflow

// Tuesday 27, May 2025
// Name in local pc: working_prototype8.nf
// Location 1 in local pc: /media/koala/Main/prog/nextflow/2025/basic
// Location 2 in local pc: /home/koala/my_projects/miRNA_expression_analysis/run_mirdeep_pipeline_for_pvo.nf
// Name in server: run_mirdeep_pipeline_for_pvo.nf
// Location in server: /home/agpres/projects/mirna_pvo/scripts

/*
 * Execution and progress
nextflow run scripts/run_mirdeep_pipeline_for_pvo.nf -ansi-log false --reads_csv reads_paths.csv --outdir results/custom
or
nohup nextflow run scripts/run_mirdeep_pipeline_for_pvo.nf -ansi-log false --reads_csv reads_paths.csv --outdir results/custom > results/mirdeep_pipeline_for_pvo.log 2>&1 &

Check the progress using:
tail -f results/mirdeep_pipeline_for_pvo.log
 */

/*
 * Pipeline parameters
 */

// local
params.reads_csv = "dummy_paths_headers.csv" // overide with --reads new.csv
params.ref_fasta = "/media/koala/Main/pj/inia/mirna/data/transcriptome/pvo/pvolubilis_transcriptome.fasta" // Use a genome if available
params.bowtie_index_dir = "/media/koala/Main/pj/inia/mirna/data/transcriptome/pvo/bowtie_index" // local
params.bowtie_index_basename = "pvolubilis_transcriptome_index"
params.mature_this_species = "/media/koala/Main/prog/nextflow/2025/data/mature_mes_closest_to_Pvolubilis_trimmed.fasta"
params.mature_other_species = "/media/koala/Main/prog/nextflow/2025/data/mature_all_plants_miRBase_trimmed.fasta"
params.precursors_hairpin = "/media/koala/Main/prog/nextflow/2025/data/precursors_hairpin_closely_related_to_Pvolubilis_trimmed.fasta"
params.outdir = "results"  // default

// server
// params.reads_csv = "dummy_paths_headers.csv" // overide with --reads_csv new.csv
// params.ref_fasta = "/home/agpres/projects/mirna_pvo/data/transcriptome/pvo/pvolubilis_transcriptome.fasta" // Use a genome if available
// params.bowtie_index_dir = "/home/agpres/projects/mirna_pvo/data/bowtie_index/pvo"
// params.bowtie_index_basename = "pvolubilis_transcriptome_index"
// params.mature_this_species = "/home/agpres/projects/mirna_pvo/data/miRBase/mature_mes_closest_to_Pvolubilis_trimmed.fasta"
// params.mature_other_species = "/home/agpres/projects/mirna_pvo/data/miRBase/mature_all_plants_miRBase_trimmed.fasta"
// params.precursors_hairpin = "/home/agpres/projects/mirna_pvo/data/miRBase/precursors_hairpin_closely_related_to_Pvolubilis_trimmed.fasta"
// params.outdir = "results"  // default
// // /home/agpres/projects/mirna_pvo/data/miRBase

// println "mapper input: ${params.bowtie_index_dir}/${params.bowtie_index_basename}" // also works well

log.info """
Pipeline Parameters:
===================
- Read CSV file: $params.reads_csv
- Transcriptome in fasta format: $params.ref_fasta
- Transcriptome bowtie index directory: $params.bowtie_index_dir
- Transcriptome bowtie index basename: $params.bowtie_index_basename
- Mapper input -p argument (bowtie index): ${params.bowtie_index_dir}/${params.bowtie_index_basename}
- Mature miRNA reference sequences closest to this species: $params.mature_this_species
- Mature miRNA reference sequences of other species: $params.mature_other_species
- Hairpin reference sequences: $params.precursors_hairpin
- Output directory: $params.outdir
"""
.stripIndent()



process run_mapper {
    tag "${meta.id}"

    // publishDir "results/${meta.id}/mapper", mode: 'copy'
    publishDir "${params.outdir}/${meta.id}/mapper", mode: 'copy'

    // even if docker is enable, if a container is not specified, it will search and try to run the program in the host system

    // container 'limrodper/mirdeep2_with_perl5lib_available:latest' // local, doesn't work properly
    container 'limrodper/mirdeep2_with_perl5lib:updated' // local also, installation complete, works well
    // container 'limrodper/mirdeep2_with_perl5lib:updated' // server

    input:
    tuple val(meta), path(read)
    // tuple val(bowtie_index_basename), path(bowtie_index_dir) // string must be the prefix of the bowtie index
    path bowtie_index_dir // Staging. This tells Nextflow: “This is a directory. Stage (symlink or copy) it into the task’s working directory.”
    val bowtie_index_basename 
    // path(file) // This tells Nextflow: This is a file. Make it available inside the working directory of this process.

    output:
    tuple val(meta), path("${prefix}_mapper.log"), emit: mapper_log_ch
    tuple val(meta), path("${prefix}_collapsed.fa"), emit: collapsed_reads_file_ch
    tuple val(meta), path("${prefix}_vs_reference.arf"), emit: arf_file_ch

    script:
    def full_path = read.toRealPath().toString() // worked 
    prefix   = task.ext.prefix ?: "${meta.id}"

    """
    echo -e "\nSample: $prefix \n" >> '${prefix}_mapper.log'
    # Checking the PWD
    echo "$PWD" >> '${prefix}_mapper.log' # /media/koala/Main/prog/nextflow/2025/basic
    echo "\$PWD" >> '${prefix}_mapper.log' # /media/koala/Main/prog/nextflow/2025/basic/work/3c/be18df5939d4497659b2456523f266
    # Checking the bowtie_index_dir variable
    echo ">> Checking staged Bowtie index files in bowtie_index_dir:" >> '${prefix}_mapper.log'
    echo "\$ ls -l ${bowtie_index_dir}" >> '${prefix}_mapper.log'
    ls -l ${bowtie_index_dir} >> '${prefix}_mapper.log'
    echo "\$ ls -l ${bowtie_index_dir}/" >> '${prefix}_mapper.log'
    ls -l ${bowtie_index_dir}/ >> '${prefix}_mapper.log'

    # Checking the bowtie index again
    echo -e "\n>> Are the bowtie index files present (staged)?" >> '${prefix}_mapper.log'
    if ls ${bowtie_index_dir}/${bowtie_index_basename}.1.ebwt > /dev/null; then
        echo "[OK] Bowtie index files are present." >> '${prefix}_mapper.log'
    else
        echo "[ERROR] Missing index files!" >> '${prefix}_mapper.log'
    fi

    echo ">> Checking $prefix mapper log:" >> '${prefix}_mapper.log'
    echo "Read: ${read}" >> '${prefix}_mapper.log'
    echo 'mapper.pl -i $read' >> '${prefix}_mapper.log'
    echo "Mapper COMMAND:" >> '${prefix}_mapper.log'
    # echo "mapper.pl $read -e -h -i -j -l 17 -m -p "${bowtie_index_dir}/${bowtie_index_basename}" -s ${prefix}_collapsed.fa -t ${prefix}_vs_reference.arf -v" >> '${prefix}_mapper.log'
    echo "mapper.pl $read -e -h -i -j -l 17 -m -p ${bowtie_index_dir}/${bowtie_index_basename} -s ${prefix}_collapsed.fa -t ${prefix}_vs_reference.arf -v" >> '${prefix}_mapper.log'

    echo -e "\nExecuting mapper.pl command for $prefix:\n" >> '${prefix}_mapper.log'
    mapper.pl $read \\
        -e -h -i -j -l 17 -m \\
        -p "${bowtie_index_dir}/${bowtie_index_basename}" \\
        -s "${prefix}_collapsed.fa" \\
        -t "${prefix}_vs_reference.arf" \\
        -v -n -o 4 \\
        &>> '${prefix}_mapper.log'

    echo -e "\nFinished mapper.pl execution for $prefix\n" >> '${prefix}_mapper.log'
    """
}

// 2>> '${prefix}_mapper.log' // worked, likely because mapper.pl likely prints most (or all) of its messages to stderr, not stdout.
// >> '${prefix}_mapper.log' 2>&1 //==> what I use the most!

process run_mirdeep {
    // tag "miRDeep2 on $read_name"
    tag "${meta.id}"

    // publishDir "results/${meta.id}/mirdeep", mode: 'copy' // worked
    publishDir "${params.outdir}/${meta.id}/mirdeep", mode: 'copy'

    // container 'limrodper/mirdeep2_with_perl5lib_available:latest' // local, doesn't work properly
    container 'limrodper/mirdeep2_with_perl5lib:updated' // local also, installation complete, works well
    // container 'limrodper/mirdeep2_with_perl5lib:updated' // server

    input:
    tuple val(meta), path(mapper_log) // mapper log
    tuple val(meta), path(collapsed_reads_file)
    tuple val(meta), path(arf_mapping_file)
    path(ref_fasta)
    path(mature_this_species)
    path(mature_other_species)
    path(precursors_hairpin)

    output:
    // The variable is only expanded if we use ""
    // if we use '', it will be taking as the literal string
    tuple val(meta), path ("$prefix-mirdeep.log"), emit: mirdeep2_log_ch
    tuple val(meta), path ("expression_*.html"), emit: expression_html_ch
    tuple val(meta), path ("result_*.html"), emit: result_html_ch
    tuple val(meta), path ("result_*.csv"), emit: result_csv_ch
    tuple val(meta), path ("result_*.bed"), emit: result_bed_ch
    tuple val(meta), path("expression_analyses"), emit: expr_analysis_ch  // directory
    tuple val(meta), path("mirdeep_runs"), emit: mirdeep_runs_ch          // directory
    tuple val(meta), path("mirna_results_*"), emit: mirna_results_ch      // directory with timestamp
    tuple val(meta), path("pdfs_*"), emit: pdfs_ch                        // directory with timestamp

    script:
    prefix   = task.ext.prefix ?: "${meta.id}"
    """
    echo -e "\nSample: $prefix \n" >> '$prefix-mirdeep.log'
    echo ">> mapper2 process log for $prefix:" >> '$prefix-mirdeep.log'
    cat $mapper_log >> '$prefix-mirdeep.log'
    echo "=========================" >> '$prefix-mirdeep.log'
    echo ">> mirdeep2 process log for $prefix:" >> '$prefix-mirdeep.log'
    echo "Running mirdeep2" >> '$prefix-mirdeep.log'
    echo 'mirdeep2.pl -i $collapsed_reads_file' >> '$prefix-mirdeep.log' #================
    echo "=========================" >> '$prefix-mirdeep.log'

    echo -e "\nExecuting miRDeep2.pl command for $prefix:\n" >> '$prefix-mirdeep.log'
    miRDeep2.pl \\
        $collapsed_reads_file \\
        $ref_fasta \\
        $arf_mapping_file \\
        $mature_this_species \\
        $mature_other_species \\
        $precursors_hairpin \\
        -P \\
        &>> '$prefix-mirdeep.log'

    echo -e "\nFinished miRDeep2.pl execution for $prefix\n" >> '$prefix-mirdeep.log'

    # Checking the directories and files
    echo ">> List of files and directories in $prefix:" >> '$prefix-mirdeep.log'
    ls -l . >> '$prefix-mirdeep.log'
    """
}

workflow {
    // Pasing a CSV file to the channel operator
    reads_channel = Channel.fromPath(params.reads_csv)
                            // .view { csv -> "Before splitCsv: $csv"}
                            | splitCsv( header: true)
                            // .view { csv -> "After splitCsv: $csv"}
                            // https://training.nextflow.io/2.1/advanced/grouping/#grouping-using-submap
                            // Building the meta map using map
                            | map { row ->
                                meta = [id: row.id]
                                [ meta, [ file(row.path) ]]
                            }
                            // [ meta_map, [ list_of_files ] ]
                            // | view

    // reads_channel | view
    // [ meta_map, [ list_of_files ] ]
    reads_channel | view { meta_map, read_list ->
        id = meta_map.id
        read_path = read_list[0].toString()
        "Read ID: ${id}\nPath: ${read_path}"
    }


    // run mapper.pl
    // Giving the second and third arguments independently, not as a tuple
    run_mapper(
        reads_channel,
        file(params.bowtie_index_dir),
        params.bowtie_index_basename
        )
    // create channel for bowtie index, building a tuple (TO-DO)

    // run miRDeep2.pl
    run_mirdeep(
        run_mapper.out.mapper_log_ch,
        run_mapper.out.collapsed_reads_file_ch,
        run_mapper.out.arf_file_ch,
        // params.ref_fasta,
        // params.mature_this_species,
        // params.mature_other_species,
        // params.precursors_hairpin
        file(params.ref_fasta),
        file(params.mature_this_species),
        file(params.mature_other_species),
        file(params.precursors_hairpin)
    )
    
}
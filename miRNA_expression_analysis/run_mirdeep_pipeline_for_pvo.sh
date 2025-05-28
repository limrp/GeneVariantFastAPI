#!/usr/bin/env bash

# Current version in the server
# Wednesday 28, May 2025

# bash run_mirdeep_pipeline_for_pvo.sh <output_dir_name>

# Set working directories (update these paths if needed)
OUTPUT_DIR="$1"
WORK_DIR="/home/agpres/projects/mirna_pvo" # updated
MAPPER_DIR="/home/agpres/projects/mirna_pvo/results/${OUTPUT_DIR}/1_mapper" # updated
MIRDEEP2_DIR="/home/agpres/projects/mirna_pvo/results/${OUTPUT_DIR}/2_mirdeep2" # updated

#WORK_DIR="/home/agpres/projects/mirna_pvo" # updated
#MAPPER_DIR="/home/agpres/projects/mirna_pvo/results/1_mapper/transcriptome2" # updated
#MIRDEEP2_DIR="/home/agpres/projects/mirna_pvo/results/2_mirdeep2/transcriptome2/run1" # updated

# Set reference files and directories
REF_FASTA="/home/agpres/projects/mirna_pvo/data/transcriptome/pvo/pvolubilis_transcriptome.fasta" # updated
REF_INDEX="/home/agpres/projects/mirna_pvo/data/bowtie_index/pvo/pvolubilis_transcriptome_index" # updated
READS_DIR="/home/agpres/projects/mirna_pvo/data/reads_trimmed" # updated

# miRNA references
MATURE_THIS_SPECIES="/home/agpres/projects/mirna_pvo/data/miRBase/mature_mes_closest_to_Pvolubilis_trimmed.fasta" # updated
MATURE_REF="/home/agpres/projects/mirna_pvo/data/miRBase/mature_all_plants_miRBase_trimmed.fasta" # updated
PRECURSORS_REF_Q1="/home/agpres/projects/mirna_pvo/data/miRBase/precursors_hairpin_closely_related_to_Pvolubilis_trimmed.fasta" # updated

# Path to my wrapper script
MIRDEEP_TOOL_WRAPPER="/home/agpres/scripts/mirdeep_tools.sh" # updated

# * ~~~~~~~~~~~~~~~~~~~~~~~ Useful functions ~~~~~~~~~~~~~~~~~~~~~~~ * #
# Function to create a directory if it doesn't exist
create_dir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "Directory '$dir' created."
    else
        echo "Directory '$dir' already exists."
    fi
}

# * ~~~~~~~~~~~~~~~~~~~~~~~~~ Main execution ~~~~~~~~~~~~~~~~~~~~~~~ * #
echo "Working in: $WORK_DIR"

# Iterate through all FASTQ files in the input reads directory
for read in $READS_DIR/*.fq;
do
    # Extract sample name by removing suffix
    name=$(basename "${read/_r16_40.fq}")
    echo "$ Processing $name $"
    echo "> Read: $read"

    # Prepare directory for mapper results
    create_dir "${MAPPER_DIR}/${name}"
    cd "${MAPPER_DIR}/${name}"
    echo "> Current directory: $PWD"

    # Define expected output files for mapper
    collapsed_fasta_path="${name}_collapsed.fa"
    mappings_arf_path="${name}_vs_transcriptome.arf"
    report_log="report_${name}.log"
    echo "[DEBUG] Collapsed path: $collapsed_fasta_path"
    echo "[DEBUG] Collapsed path: $(realpath $collapsed_fasta_path)"
    #collapsed_fasta_path="${MAPPER_DIR}/${name}/${name}_collapsed.fa"
    #mappings_arf_path="${MAPPER_DIR}/${name}/${name}_vs_transcriptome.arf"
    #report_log="${MAPPER_DIR}/${name}/report_${name}.log"

    # ------------------ Run mapper.pl via Docker wrapper ------------------ #
    echo "> Running mapper.pl via Docker"
    echo "$MIRDEEP_TOOL_WRAPPER mapper $read -e -h -i -j -l 17 -m -p $REF_INDEX -s $collapsed_fasta_path -t $mappings_arf_path -v -n -o 10"

    $MIRDEEP_TOOL_WRAPPER mapper "$read" \
        -e -h -i -j -l 17 -m \
        -p "$REF_INDEX" \
        -s "$collapsed_fasta_path" \
        -t "$mappings_arf_path" \
        -v -n -o 10 

    # Return to main working directory
    cd "$WORK_DIR"
    echo "> Current directory: $PWD"

    # Prepare directory for miRDeep2 results
    create_dir "${MIRDEEP2_DIR}/${name}"
    cd "${MIRDEEP2_DIR}/${name}"
    echo "> Current directory: $PWD"

    # ------------------ Run miRDeep2.pl via Docker wrapper ------------------ #
    echo "> Running miRDeep2.pl via Docker"

    collapsed_fasta_path="../../1_mapper/${name}/${name}_collapsed.fa"
    mappings_arf_path="../../1_mapper/${name}/${name}_vs_transcriptome.arf"
    echo "[DEBUG] collapsed path real: $(realpath "$collapsed_fasta_path")"

    echo "$MIRDEEP_TOOL_WRAPPER mirdeep $collapsed_fasta_path $REF_FASTA $mappings_arf_path $MATURE_THIS_SPECIES $MATURE_REF $PRECURSORS_REF_Q1 -P 2> $report_log"

    $MIRDEEP_TOOL_WRAPPER mirdeep \
        "$collapsed_fasta_path" \
        "$REF_FASTA" \
        "$mappings_arf_path" \
        "$MATURE_THIS_SPECIES" \
        "$MATURE_REF" \
        "$PRECURSORS_REF_Q1" \
        -P \
        2> "$report_log"

    # Return to main working directory
    cd "$WORK_DIR"
    echo "> Current directory: $PWD"
    echo -e "> Finished with ${name}\n"

done

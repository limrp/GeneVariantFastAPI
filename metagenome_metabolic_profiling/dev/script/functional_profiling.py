# *----------------------------------------------------------------------------
# | PROGRAM NAME: Functional profiling
# | DATE: 19/09/24
# | CREATED BY: Lila Maciel Rodriguez Perez
# | PROJECT:
# | Version: 1.0
# *----------------------------------------------------------------------------

# *-------------------------------------  Libraries ---------------------------

import argparse
from collections import defaultdict
from pathlib import Path

import pandas as pd


# Load cog-24.def.tab file (COG ID to Functional Category mapping)
def load_cog_def(cog_def_file):
    cog_def_df = pd.read_csv(
        cog_def_file,
        sep="\t",
        names=[
            "COG ID",
            "COG Functional category ID",
            "COG name",
            "Gene",
            "Pathway",
            "PubMed ID",
            "PDB ID",
        ],
    )
    cog_def_df["COG ID"] = cog_def_df["COG ID"].str.strip()  # Strip any spaces
    return cog_def_df


# Load cog-24.fun.edited.tab file (Functional Category descriptions and groups)
def load_cog_fun(cog_fun_file):
    cog_fun_df = pd.read_csv(
        cog_fun_file,
        sep="\t",
        names=[
            "COG Functional category ID",
            "Functional group",
            "RGB color",
            "FC description",
        ],
    )
    return cog_fun_df


# Load sample-specific protein-COG mappings
def load_sample_protein_cog(sample_protein_cog_file):
    sample_cog_df = pd.read_csv(
        sample_protein_cog_file, sep="\t", header=None, names=["Protein", "COG"]
    )
    sample_cog_df["COG"] = sample_cog_df["COG"].str.strip()
    sample_cog_df["COG"] = sample_cog_df["COG"].str.replace(
        "COG:", ""
    )  # Clean up COG prefixes
    return sample_cog_df


# Handle combined functional categories (like EHJQ, etc.)
def map_combined_categories(cog_categories):
    return list(
        cog_categories
    )  # Split the string into individual categories (like EHJQ -> ['E', 'H', 'J', 'Q'])


# Function to summarize the functional categories for a given sample
def summarize_functional_categories(sample_cog_df, cog_def_df, cog_fun_df):
    category_counts = defaultdict(int)  # Count occurrences of each functional category

    for cog in sample_cog_df["COG"]:
        functional_categories = cog_def_df.loc[
            cog_def_df["COG ID"] == cog, "COG Functional category ID"
        ].values
        if len(functional_categories) == 0:
            print(f"COG ID {cog} not found in cog_def_df.")
            continue

        functional_categories = functional_categories[0]  # Extract the category
        num_categories = len(map_combined_categories(functional_categories))
        for category in map_combined_categories(functional_categories):
            category_counts[category] += 1 / num_categories

    # Collect rows for the summary DataFrame
    summary_rows = []
    for category, count in category_counts.items():
        group = cog_fun_df.loc[
            cog_fun_df["COG Functional category ID"] == category, "Functional group"
        ].values[0]
        description = cog_fun_df.loc[
            cog_fun_df["COG Functional category ID"] == category, "FC description"
        ].values[0]
        color = cog_fun_df.loc[
            cog_fun_df["COG Functional category ID"] == category, "RGB color"
        ].values[0]
        summary_rows.append(
            {
                "Functional category": category,
                "Functional group": group,
                "Count": count,
                "FC description": description,
                "Color": color,
            }
        )

    summary_df = pd.DataFrame(summary_rows)
    return summary_df


# Main function to process each sample and summarize the functional categories
def process_sample(sample, sample_protein_cog_file, cog_def_file, cog_fun_file):
    cog_def_df = load_cog_def(cog_def_file)
    cog_fun_df = load_cog_fun(cog_fun_file)
    sample_cog_df = load_sample_protein_cog(sample_protein_cog_file)

    summary_df = summarize_functional_categories(sample_cog_df, cog_def_df, cog_fun_df)
    summary_df["Functional group"] = summary_df["Functional group"].replace(
        {
            1: "Information storage and processing",
            2: "Cellular processes and signaling",
            3: "Metabolism",
            4: "Poorly characterized",
        }
    )
    summary_df = summary_df.sort_values(by="Functional group").reset_index(drop=True)
    non_normalized_df = summary_df[
        ["Functional group", "FC description", "Count"]
    ].copy()
    non_normalized_df = non_normalized_df.rename(columns={"Count": sample})

    normalized_df = summary_df[["Functional group", "FC description", "Count"]].copy()
    normalized_df[sample] = normalized_df["Count"] / normalized_df["Count"].sum()
    normalized_df.drop(columns=["Count"], inplace=True)
    return non_normalized_df, normalized_df


def process_all_samples(samples_cog_dir, output_dir, cog_def_file, cog_fun_file):
    non_normalized_list = []
    normalized_list = []

    for item in samples_cog_dir.iterdir():
        if item.is_file() and item.suffix == ".tsv":
            sample_protein_cog_file = item
            sample = item.stem.split("_")[0]
            print(f"Processing {sample} from file: {item}")
            non_normalized_df, normalized_df = process_sample(
                sample, sample_protein_cog_file, cog_def_file, cog_fun_file
            )
            non_normalized_list.append(non_normalized_df)
            normalized_list.append(normalized_df)

    non_normalized_combined = (
        pd.concat(non_normalized_list)
        .groupby(["Functional group", "FC description"], as_index=False)
        .sum()
    )
    normalized_combined = (
        pd.concat(normalized_list)
        .groupby(["Functional group", "FC description"], as_index=False)
        .sum()
    )

    output_dir.mkdir(parents=True, exist_ok=True)
    non_normalized_combined.to_csv(output_dir / "non_normalized.csv", index=False)
    normalized_combined.to_csv(output_dir / "normalized.csv", index=False)
    print(f"\nNon normalized CSV saved to: {output_dir / 'non_normalized.csv'}")
    print(f"Normalized CSV saved to: {output_dir / 'normalized.csv'}")

    return non_normalized_combined, normalized_combined


# Main function for argparse
def main():
    parser = argparse.ArgumentParser(
        description="Process functional profiling of metagenomic samples."
    )
    parser.add_argument(
        "-i",
        "--input_directory",
        type=str,
        required=True,
        help="Input directory with sample files (.tsv).",
    )
    parser.add_argument(
        "-o",
        "--output_directory",
        type=str,
        required=True,
        help="Output directory for saving results.",
    )
    parser.add_argument(
        "-d",
        "--cog_definitions_file",
        type=str,
        required=True,
        help="Path to COG definitions file (cog-24.def.tab).",
    )
    parser.add_argument(
        "-f",
        "--cog_functional_categories_file",
        type=str,
        required=True,
        help="Path to COG functional categories file (cog-24.fun.edited.tab).",
    )

    args = parser.parse_args()

    samples_cog_dir = Path(args.input_directory)
    output_dir = Path(args.output_directory)
    cog_def_file = args.cog_definitions_file
    cog_fun_file = args.cog_functional_categories_file

    process_all_samples(samples_cog_dir, output_dir, cog_def_file, cog_fun_file)


if __name__ == "__main__":
    main()

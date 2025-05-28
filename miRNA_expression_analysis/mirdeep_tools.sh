#!/usr/bin/env bash

# Unified wrapper to run either mapper.pl or miRDeep2.pl inside Docker
# Usage:
#   ./mirdeep_tools.sh mapper [arguments...]
#   ./mirdeep_tools.sh mirdeep [arguments...]

# ------------------------------ #
# 1. Detect if Docker needs sudo #
# ------------------------------ #
DOCKER="docker"
#if ! docker info > /dev/null 2>&1; then
#    echo "[INFO] Docker needs sudo. Using 'sudo docker' instead."
#    DOCKER="sudo docker"
#fi

if docker info > /dev/null 2>&1; then
    DOCKER="docker"
else
    echo "[INFO] Docker needs sudo. Using 'sudo docker' instead."
    DOCKER="sudo docker"
fi

# ------------------------------ #
# 2. Configuration               #
# ------------------------------ #
# DOCKER_IMAGE="limrodper/mirdeep2_image_installed"
DOCKER_IMAGE="limrodper/mirdeep2_with_perl5lib:updated"
# HOST_CWD=$(pwd)
# HOST_CWD=$(pwd -P)

# Determine which tool to run: mapper or miRDeep2
TOOL="$1"
shift  # Shift the arguments so $@ contains only the tool's args

# Map the tool keyword to the actual script name inside the container
if [[ "$TOOL" == "mapper" ]]; then
    TOOL_SCRIPT="mapper.pl"
elif [[ "$TOOL" == "mirdeep" ]]; then
    TOOL_SCRIPT="miRDeep2.pl"
else
    echo "[ERROR] Unknown tool: $TOOL"
    echo "Usage: $0 [mapper|mirdeep] [args...]"
    exit 1
fi

# ------------------------------ #
# 3. Collect args and mount dirs #
# ------------------------------ #

ARGS=()          # Store final arguments passed to the tool inside Docker
MOUNT_DIRS=()    # Track unique directories that need to be mounted

# Function to extract a directory from a file path and store it uniquely

add_mount_dir() {
    local filepath="$1"
    if [[ "$filepath" == /* && -f "$filepath" ]]; then
        dir=$(dirname "$filepath")
        if [[ ! " ${MOUNT_DIRS[*]} " =~ " ${dir} " ]]; then
            MOUNT_DIRS+=("$dir")
        fi
    fi
}

# Loop through all provided arguments

#for arg in "$@"; do
#    if [[ "$arg" == -* ]]; then
#        # It's a flag like -e, -P, etc.
#        ARGS+=("$arg")
#    elif [[ -f "$arg" ]]; then
#        # It's a file: add its directory to the mount list
#        add_mount_dir "$arg"
#        # Change the file path to /mnt<fullpath> to match the Docker mount
#        ARGS+=("/mnt$(realpath "$arg")")
#    elif [[ -e "$arg".1.ebwt ]]; then
#        # It's a Bowtie index basename, try to mount its directory
#        add_mount_dir "$arg".1.ebwt
#        ARGS+=("/mnt$(realpath "$arg")")
#    else
#        # Unrecognized input, pass through
#        ARGS+=("$arg")
#    fi
#done

for arg in "$@"; do
    if [[ "$arg" == -* ]]; then
        ARGS+=("$arg")
    else
        abs_path=$(realpath "$arg" 2>/dev/null)
        if [[ -f "$abs_path" ]]; then
	    echo "[DEBUG] Mounting parent directory of: $abs_path"
            add_mount_dir "$abs_path"
            ARGS+=("/mnt$abs_path")
        elif [[ -e "$arg".1.ebwt ]]; then
            index_path=$(realpath "$arg".1.ebwt 2>/dev/null)
            add_mount_dir "$index_path"
            ARGS+=("/mnt$(realpath "$arg")")
        else
            echo "[WARNING] File not found: $arg"
	    echo "[WARNING] File not found at absolute path: $abs_path"
            ARGS+=("$arg")
        fi
    fi
done

# ------------------------------ #
# 4. Build Docker run arguments  #
# ------------------------------ #

HOST_CWD="$(pwd -P)"
echo "[DEBUG] Current working directory seen by wrapper: $(pwd -P)"

# Always mount the current working directory
DOCKER_MOUNTS=("-v" "$HOST_CWD:/mnt${HOST_CWD}")
echo "[DEBUG] Mounting: -v $HOST_CWD:/mnt$HOST_CWD"

# Mount any other detected input file directories
for dir in "${MOUNT_DIRS[@]}"; do
    DOCKER_MOUNTS+=("-v" "$dir:/mnt$dir")
done

# ------------------------------ #
# 5. Run Docker container        #
# ------------------------------ #

echo "[DEBUG] Final docker run command:"
echo "$DOCKER run --rm -w /mnt$HOST_CWD ${DOCKER_MOUNTS[*]} $DOCKER_IMAGE bash -c \"$TOOL_SCRIPT ${ARGS[*]}\""

$DOCKER run --rm \
    "${DOCKER_MOUNTS[@]}" \
    -w "/mnt${HOST_CWD}" \
    "$DOCKER_IMAGE" \
    bash -c "$TOOL_SCRIPT ${ARGS[*]}"

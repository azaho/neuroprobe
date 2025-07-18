#!/bin/bash
#SBATCH --job-name=e_p_lite          # Name of the job
#SBATCH --ntasks=1             # 8 tasks total
#SBATCH --cpus-per-task=2    # Request 8 CPU cores per GPU
#SBATCH --mem=64G
#SBATCH -t 1:00:00         # total run time limit (HH:MM:SS) (increased to 24 hours)
#####SBATCH --gres=gpu:1
#####SBATCH --constraint=24GB
#SBATCH --exclude=dgx001,dgx002
#SBATCH --array=1-684  # 285 if doing mini btbench
#SBATCH --output data/logs/%A_%a.out # STDOUT
#SBATCH --error data/logs/%A_%a.err # STDERR
#SBATCH -p use-everything

nvidia-smi

export PYTHONUNBUFFERED=1
source .venv/bin/activate

# Use the BTBENCH_LITE_SUBJECT_TRIALS from btbench_config.py
declare -a subjects=(1 2 3 4 7 10)
declare -a trials=(1 4 1 0 1 1)

declare -a eval_names=(
    "frame_brightness"
    "global_flow"
    "local_flow"
    "global_flow_angle"
    "local_flow_angle" 
    "face_num"
    "volume"
    "pitch"
    "delta_volume"
    "delta_pitch"
    "speech"
    "onset"
    "gpt2_surprisal"
    "word_length"
    "word_gap"
    "word_index"
    "word_head_pos"
    "word_part_speech"
    "speaker"
)

declare -a preprocess_type=(
    'stft_abs' # just magnitude after FFT ("spectrogram")
)
declare -a preprocess_stft_nperseg=(
    128
    256
    400
    512
)

declare -a preprocess_stft_poverlap=(
    0.0
    0.25
    0.50
    0.75
    0.875
    0.9375
)


declare -a splits_type=(
    "SS_SM"
)

declare -a classifier_type=(
    "linear"
)

# Calculate indices for this task
EVAL_IDX=$(( ($SLURM_ARRAY_TASK_ID-1) % ${#eval_names[@]} ))
PAIR_IDX=$(( ($SLURM_ARRAY_TASK_ID-1) / ${#eval_names[@]} % ${#subjects[@]} ))
PREPROCESS_TYPE_IDX=$(( ($SLURM_ARRAY_TASK_ID-1) / ${#eval_names[@]} / ${#subjects[@]} % ${#preprocess_type[@]} ))
PREPROCESS_STFT_POVERLAP_IDX=$(( ($SLURM_ARRAY_TASK_ID-1) / ${#eval_names[@]} / ${#subjects[@]} / ${#preprocess_type[@]} % ${#preprocess_stft_poverlap[@]} ))
SPLITS_TYPE_IDX=$(( ($SLURM_ARRAY_TASK_ID-1) / ${#eval_names[@]} / ${#subjects[@]} / ${#preprocess_type[@]} / ${#preprocess_stft_poverlap[@]} % ${#splits_type[@]} ))
CLASSIFIER_TYPE_IDX=$(( ($SLURM_ARRAY_TASK_ID-1) / ${#eval_names[@]} / ${#subjects[@]} / ${#preprocess_type[@]} / ${#preprocess_stft_poverlap[@]} / ${#splits_type[@]} % ${#classifier_type[@]} ))

# Get subject, trial and eval name for this task
EVAL_NAME=${eval_names[$EVAL_IDX]}
SUBJECT=${subjects[$PAIR_IDX]}
TRIAL=${trials[$PAIR_IDX]}
PREPROCESS_TYPE=${preprocess_type[$PREPROCESS_TYPE_IDX]}
PREPROCESS_STFT_POVERLAP=${preprocess_stft_poverlap[$PREPROCESS_STFT_POVERLAP_IDX]}
SPLITS_TYPE=${splits_type[$SPLITS_TYPE_IDX]}
CLASSIFIER_TYPE=${classifier_type[$CLASSIFIER_TYPE_IDX]}


for PREPROCESS_STFT_NPERSEG_IDX in "${!preprocess_stft_nperseg[@]}"; do
    PREPROCESS_STFT_NPERSEG=${preprocess_stft_nperseg[$PREPROCESS_STFT_NPERSEG_IDX]}

    save_dir="data/analyses/input_representation/eval_results_nano_${SPLITS_TYPE}"

    echo "Running eval for eval $EVAL_NAME, subject $SUBJECT, trial $TRIAL, preprocess $PREPROCESS_TYPE, nperseg $PREPROCESS_STFT_NPERSEG, poverlap $PREPROCESS_STFT_POVERLAP, classifier $CLASSIFIER_TYPE"
    echo "Save dir: $save_dir"
    echo "Split type: $SPLITS_TYPE"

    # Add the -u flag to Python to force unbuffered output
    python -u eval_population.py \
        --eval_name $EVAL_NAME \
        --subject_id $SUBJECT \
        --trial_id $TRIAL \
        --preprocess.type $PREPROCESS_TYPE \
        --preprocess.stft.nperseg $PREPROCESS_STFT_NPERSEG \
        --preprocess.stft.poverlap $PREPROCESS_STFT_POVERLAP \
        --verbose \
        --save_dir $save_dir \
        --split_type $SPLITS_TYPE \
        --classifier_type $CLASSIFIER_TYPE \
        --only_1second \
        --nano
done
#!/usr/bin/env bash

# run weight learning performance experiments,
#i.e. collects runtime and evaluation statistics of various weight learning methods

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_DIR="${THIS_DIR}/.."
readonly BASE_OUT_DIR="${BASE_DIR}/results/weightlearning"

readonly WL_METHODS='BOWLSS'
readonly ALPHA=0.05
readonly ACQUISITION_FUNCTIONS='UCB TS PI EI'
readonly SEED=100
readonly TRACE_LEVEL='Trace'

declare -A SUPPORTED_WL_METHODS
SUPPORTED_WL_METHODS[psl]='UNIFORM CRGS HB RGS BOWLOS BOWLSS LME MLE MPLE'
SUPPORTED_WL_METHODS[tuffy]='UNIFORM DiagonalNewton CRGS HB RGS BOWLOS'

# set of currently supported examples
declare -A SUPPORTED_EXAMPLES
SUPPORTED_EXAMPLES[psl]='epinions citeseer cora jester lastfm'
SUPPORTED_EXAMPLES[tuffy]='epinions citeseer cora'
readonly SUPPORTED_MODEL_TYPES='psl tuffy'

# Evaluators to be use for each example
declare -A EXAMPLE_EVALUATORS
EXAMPLE_EVALUATORS[citeseer]='Discrete'
EXAMPLE_EVALUATORS[cora]='Discrete'
EXAMPLE_EVALUATORS[epinions]='Discrete'
EXAMPLE_EVALUATORS[jester]='Continuous'
EXAMPLE_EVALUATORS[lastfm]='Continuous'

# Evaluators to be use for each example
# todo: (Charles D.) just read this information from psl example data directory rather than hardcoding
declare -A EXAMPLE_FOLDS
EXAMPLE_FOLDS[citeseer]=8
EXAMPLE_FOLDS[cora]=8
EXAMPLE_FOLDS[epinions]=8
EXAMPLE_FOLDS[jester]=8
EXAMPLE_FOLDS[lastfm]=5

declare -A MODEL_TYPE_TO_FILE_EXTENSION
MODEL_TYPE_TO_FILE_EXTENSION[psl]="psl"
MODEL_TYPE_TO_FILE_EXTENSION[tuffy]="mln"


function run_example() {
    local srl_model_type=$1
    local example_directory=$2
    local wl_method=$3
    local evaluator=$4
    local acquistition_function=$5
    local fold=$6

    local example_name
    example_name=$(basename "${example_directory}")

    local cli_directory="${BASE_DIR}/${example_directory}/cli"

    out_directory="${BASE_OUT_DIR}/${srl_model_type}/acquistition_study/${example_name}/${wl_method}/${evaluator}/${acquistition_function}/${fold}"

    # Only make a new out directory if it does not already exist
    [[ -d "$out_directory" ]] || mkdir -p "$out_directory"

    ##### WEIGHT LEARNING #####
    echo "Running ${example_name} (#${fold}) -- ${acquistition_function}."

    # path to output files
    local out_path="${out_directory}/learn_out.txt"
    local err_path="${out_directory}/learn_out.err"
    local time_path="${out_directory}/learn_time.txt"

    if [[ -e "${out_path}" ]]; then
        echo "Output file already exists, skipping: ${out_path}"
        echo "Copying cached learned model from earlier run into cli"
        # copy the learned weights into the cli directory for inference
        cp "${out_directory}/${example_name}-learned.${MODEL_TYPE_TO_FILE_EXTENSION[${srl_model_type}]}" "${cli_directory}/"
    else
        # call weight learning script for SRL model type
        pushd . > /dev/null
            cd "${srl_model_type}_scripts" || exit
            /usr/bin/time -v --output="${time_path}" ./run_wl.sh "${example_name}" "${fold}" "${SEED}" "${ALPHA}" "${acquistition_function}" "acquistition_study" "${wl_method}" "${evaluator}" "${out_directory}" "${TRACE_LEVEL}" > "$out_path" 2> "$err_path"
#            ./run_wl.sh "${example_name}" "${fold}" "${SEED}" "${ALPHA}" "${acquistition_function}" "acquistition_study" "${wl_method}" "${evaluator}" "${out_directory}" "${TRACE_LEVEL}" > "$out_path" 2> "$err_path"
        popd > /dev/null
    fi

    ##### EVALUATION #####
    echo "Running ${example_name} ${evaluator} (#${fold}) -- Evaluation."

    # path to output files
    local out_path="${out_directory}/eval_out.txt"
    local err_path="${out_directory}/eval_out.err"
    local time_path="${out_directory}/eval_time.txt"

    if [[ -e "${out_path}" ]]; then
        echo "Output file already exists, skipping: ${out_path}"
    else
        # call inference script for SRL model type
        pushd . > /dev/null
            cd "${srl_model_type}_scripts" || exit
            /usr/bin/time -v --output="${time_path}" ./run_inference.sh "${example_name}" "eval" "${fold}" "${evaluator}" "${out_directory}" > "$out_path" 2> "$err_path"
#            ./run_inference.sh "${example_name}" "eval" "${fold}" "${evaluator}" "${out_directory}" > "$out_path" 2> "$err_path"
        popd > /dev/null
    fi

    return 0
}

function main() {
    trap exit SIGINT

    if [[ $# -le 1 ]]; then
        echo "USAGE: $0 <srl modeltype> <example dir> ..."
        echo "USAGE: SRL model types may be among: ${SUPPORTED_MODEL_TYPES}"
        exit 1
    fi

    local srl_modeltype=$1
    shift
    local example_name
    for wl_method in ${WL_METHODS}; do
        for example_directory in "$@"; do
            example_name=$(basename "${example_directory}")
            for evaluator in ${EXAMPLE_EVALUATORS[${example_name}]}; do
                for acquistition_function in ${ACQUISITION_FUNCTIONS}; do
                    for ((fold=0; fold<${EXAMPLE_FOLDS[${example_name}]}; fold++)) do
                        if [[ "${SUPPORTED_WL_METHODS[${srl_modeltype}]}" == *"${wl_method}"* ]]; then
                            if [[ "${SUPPORTED_EXAMPLES[${srl_modeltype}]}" == *"${example_name}"* ]]; then
                                run_example "${srl_modeltype}" "${example_directory}" "${wl_method}" "${evaluator}" "${acquistition_function}" "${fold}"
                            fi
                        fi
                    done
                done
            done
        done
    done

    return 0
}

main "$@"

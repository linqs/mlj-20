#!/usr/bin/env bash

# run weight learning robustness experiments,
# Runs NUM_RUNS iterations of weight learning on the FOLD^th fold of each dataset will be run and the
# resulting evaluation set performance and learned weights are recorded

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_OUT_DIR="${THIS_DIR}/../results/weightlearning"

readonly WL_METHODS='BOWLOS BOWLSS RGS HB CRGS'

declare -A SUPPORTED_WL_METHODS
SUPPORTED_WL_METHODS[psl]='BOWLSS RGS HB CRGS'
SUPPORTED_WL_METHODS[psl]='MLE BOWLSS RGS HB CRGS'
SUPPORTED_WL_METHODS[tuffy]='BOWLOS RGS HB CRGS'

# set of currently supported examples
readonly SUPPORTED_EXAMPLES='epinions citeseer cora jester lastfm'
readonly SUPPORTED_MODEL_TYPES='psl tuffy'

declare -A MODEL_TYPE_TO_FILE_EXTENSION
MODEL_TYPE_TO_FILE_EXTENSION[psl]="psl"
MODEL_TYPE_TO_FILE_EXTENSION[tuffy]="mln"

readonly NUM_RUNS=100
readonly FOLD=0
readonly ALPHA=0.05
readonly ACQUISITION='UCB'
readonly TRACE_LEVEL='info'

# Evaluators to be use for each example
declare -A EXAMPLE_EVALUATORS
EXAMPLE_EVALUATORS[citeseer]='Discrete'
EXAMPLE_EVALUATORS[cora]='Discrete'
EXAMPLE_EVALUATORS[epinions]='Discrete'
EXAMPLE_EVALUATORS[jester]='Continuous'
EXAMPLE_EVALUATORS[lastfm]='Continuous'

function run_example() {
    local srl_model_type=$1
    local example_directory=$2
    local wl_method=$3
    local iteration=$4
    local evaluator=$5

    local example_name
    example_name=$(basename "${example_directory}")

    local cli_directory="${example_directory}/cli"

    # modify runscript to run with the options for this study. iteration number will be used as random seed
    echo "Running ${srl_model_type} Robustness Study On ${example_name} ${evaluator} Iteration #${iteration} Fold #${FOLD} -- ${wl_method}."
    out_directory="${BASE_OUT_DIR}/${srl_model_type}/robustness_study/${example_name}/${wl_method}/${evaluator}/${iteration}"

    # Only make a new out directory if it does not already exist
    [[ -d "$out_directory" ]] || mkdir -p "$out_directory"

    ##### WEIGHT LEARNING #####
    echo "Running ${srl_model_type} ${example_name} ${evaluator} (#${FOLD}) -- ${wl_method}."

    # path to output files
    local out_path="${out_directory}/learn_out.txt"
    local err_path="${out_directory}/learn_out.err"
    local time_path="${out_directory}/learn_time.txt"

    if [[ -e "${out_path}" ]]; then
        echo "Output file already exists, skipping: ${out_path}"

        # copy the learned weights into the cli directory for inference
        cp "${out_directory}/${example_name}-learned.${MODEL_TYPE_TO_FILE_EXTENSION[${srl_model_type}]}" "${cli_directory}/${example_name}-learned.${MODEL_TYPE_TO_FILE_EXTENSION[${srl_model_type}]}"
    else
        # call weight learning script for SRL model type
        pushd . > /dev/null
            cd "${srl_model_type}_scripts" || exit
#              /usr/bin/time -v --output="${time_path}" ./run_wl.sh "${example_name}" "${FOLD}" "${iteration}" "${ALPHA}" "${ACQUISITION}" "robustness_study" "${wl_method}" "${evaluator}" "${out_directory}" "${TRACE_LEVEL}" > "$out_path" 2> "$err_path"
              ./run_wl.sh "${example_name}" "${FOLD}" "${iteration}" "${ALPHA}" "${ACQUISITION}" "robustness_study" "${wl_method}" "${evaluator}" "${out_directory}" "${TRACE_LEVEL}" > "$out_path" 2> "$err_path"
        popd > /dev/null
    fi

    ##### EVALUATION #####
    echo "Running ${srl_model_type} ${example_name} ${evaluator} (#${FOLD}) -- ${wl_method}."

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
#            /usr/bin/time -v --output="${time_path}" ./run_inference.sh "${example_name}" "eval" "${FOLD}" "${evaluator}" "${out_directory}" > "$out_path" 2> "$err_path"
            ./run_inference.sh "${example_name}" "eval" "${FOLD}" "${evaluator}" "${out_directory}" > "$out_path" 2> "$err_path"
        popd > /dev/null
    fi
}

function main() {
    if [[ $# -le 1 ]]; then
        echo "USAGE: $0 <srl modeltype> <example dir> ..."
        echo "USAGE: SRL model types may be among: ${SUPPORTED_MODEL_TYPES}"
        echo "USAGE: Example Directories can be among: ${SUPPORTED_EXAMPLES}"
        exit 1
    fi

    local srl_modeltype=$1
    shift

    echo "$srl_modeltype"

    trap exit SIGINT

    for i in $(seq -w 1 ${NUM_RUNS}); do
      for exampleDir in "$@"; do
        for wl_method in ${WL_METHODS}; do
          example_name=$(basename "${exampleDir}")
          for evaluator in ${EXAMPLE_EVALUATORS[${example_name}]}; do
            if [[ "${SUPPORTED_WL_METHODS[${srl_modeltype}]}" == *"${wl_method}"* ]]; then
              run_example "${srl_modeltype}" "${exampleDir}" "${wl_method}" "${i}" "${evaluator}"
            fi
          done
         done
      done
    done
}

main "$@"
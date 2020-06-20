#!/usr/bin/python
import pandas as pd
import numpy as np
import sys
import os
import subprocess

# generic helpers
from helpers import load_truth_frame
from helpers import load_observed_frame
from helpers import load_target_frame

# helpers for experiment specific processing
from tuffy_scripts.helpers import load_prediction_frame as load_tuffy_prediction_frame
from psl_scripts.helpers import load_prediction_frame as load_psl_prediction_frame

# evaluators implemented for this study
from evaluators import evaluate_accuracy
from evaluators import evaluate_f1
from evaluators import evaluate_mse
from evaluators import evaluate_roc_auc_score

dataset_properties = {'jester': {'evaluation_predicate': 'rating'},
                      'epinions': {'evaluation_predicate': 'trusts'},
                      'cora': {'evaluation_predicate': 'hasCat'},
                      'citeseer': {'evaluation_predicate': 'hasCat'},
                      'lastfm': {'evaluation_predicate': 'rating'}}

evaluator_name_to_method = {
    'Categorical': evaluate_accuracy,
    'Discrete': evaluate_f1,
    'Continuous': evaluate_mse,
    'Ranking': evaluate_roc_auc_score
}

FOLD = 0

ROBUSTNESS_COLUMNS = ['Dataset', 'Wl_Method', 'Evaluation_Method', 'Mean', 'Standard_Deviation']

def main(method):
    # in results/weightlearning/{}/robustness_study write
    # a performance.csv file with columns 
    # Dataset | WL_Method | Evaluation_Method | Mean | Standard_Deviation

    # we are going to overwrite the file with all the most up to date information
    robustness_frame = pd.DataFrame(columns=ROBUSTNESS_COLUMNS)

    # extract all the files that are in the results directory
    # path to this file relative to caller
    dirname = os.path.dirname(__file__)
    path = '{}/../results/weightlearning/{}/robustness_study'.format(dirname, method)
    datasets = [dataset for dataset in os.listdir(path) if os.path.isdir(os.path.join(path, dataset))]

    # iterate over all datasets adding the results to the performance_frame
    for dataset in datasets:
        # extract all the wl_methods that are in the directory
        path = '{}/../results/weightlearning/{}/robustness_study/{}'.format(dirname, method, dataset)
        wl_methods = [wl_method for wl_method in os.listdir(path) if os.path.isdir(os.path.join(path, wl_method))]

        for wl_method in wl_methods:
            # extract all the metrics that are in the directory
            path = '{}/../results/weightlearning/{}/robustness_study/{}/{}'.format(dirname, method, dataset, wl_method)
            evaluators = [evaluator for evaluator in os.listdir(path) if os.path.isdir(os.path.join(path, evaluator))]

            for evaluator in evaluators:
                # extract all the iterations that are in the directory
                path = '{}/../results/weightlearning/{}/robustness_study/{}/{}/{}'.format(dirname, method, dataset,
                                                                                           wl_method, evaluator)
                iters = [iter for iter in os.listdir(path) if os.path.isdir(os.path.join(path, iter))]

                # calculate experiment performance and append to performance frame
                robustness_series = calculate_experiment_robustness(dataset, wl_method, evaluator, iters)
                robustness_frame = robustness_frame.append(robustness_series, ignore_index=True)

    # write performance_frame and timing_frame to results/weightlearning/{}/robustness_study
    robustness_frame.to_csv(
        '{}/../results/weightlearning/{}/robustness_study/{}_robustness.csv'.format(dirname, method, method),
        index=False)


def calculate_experiment_robustness(dataset, wl_method, evaluator, iters):
    # initialize the experiment list that will be populated in the following for
    # loop with the performance outcome of each fold
    experiment_performance = np.array([])

    # truth dataframe
    truth_df = load_truth_frame(dataset, FOLD, dataset_properties[dataset]['evaluation_predicate'])
    # observed dataframe
    observed_df = load_observed_frame(dataset, FOLD, dataset_properties[dataset]['evaluation_predicate'])
    # target dataframe
    target_df = load_target_frame(dataset, FOLD, dataset_properties[dataset]['evaluation_predicate'])

    for iter in iters:
        # load the prediction dataframe
        try:
            # prediction dataframe
            if method == 'psl':
                predicted_df = load_psl_prediction_frame(dataset, wl_method, evaluator, iter,
                                                         dataset_properties[dataset]['evaluation_predicate'],
                                                         "robustness_study")
            elif method == 'tuffy':
                predicted_df = load_tuffy_prediction_frame(dataset, wl_method, evaluator, iter,
                                                           dataset_properties[dataset]['evaluation_predicate'],
                                                           "robustness_study", )
            else:
                raise ValueError("{} not supported. Try: ['psl', 'tuffy']".format(method))

        except FileNotFoundError as err:
            print(err)
            continue

        experiment_performance = np.append(experiment_performance,
                                           evaluator_name_to_method[evaluator](predicted_df,
                                                                               truth_df,
                                                                               observed_df,
                                                                               target_df))

    # organize into a performance_series
    robustness_series = pd.Series(index=ROBUSTNESS_COLUMNS,
                                   dtype=float)
    robustness_series['Dataset'] = dataset
    robustness_series['Wl_Method'] = wl_method
    robustness_series['Evaluation_Method'] = evaluator
    robustness_series['Mean'] = experiment_performance.mean()
    robustness_series['Standard_Deviation'] = experiment_performance.std()

    return robustness_series


def _load_args(args):
    executable = args.pop(0)
    if len(args) != 1 or ({'h', 'help'} & {arg.lower().strip().replace('-', '') for arg in args}):
        print("USAGE: python3 {} <SRL method>".format(executable), file=sys.stderr)
        sys.exit(1)

    method = args.pop(0)

    return method


if __name__ == '__main__':
    method = _load_args(sys.argv)
    main(method)

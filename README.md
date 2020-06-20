This folder contains all the code to run the SRL weight Learning Experiments.

# Simple Execution
All experiments can be reproduced using the `run.sh` script in the top level of this repository
```
.\run.sh
```

# File explanation:

* `run.sh`
    * The `run.sh` script will fetch the necessary data and models and then run the PSL weight learing performance experiments and the PSL weight learning robustness experiments on the PSL example datasets citeseer, cora, epinions, lastfm, and jester

* `scripts/run_weight_learning_performance_experiments.sh`
    * This script will run the weight learning performance experiments on the datasets who's paths where provided via the command line argument
    * Weight learning and evaluation is completed across each of the example folds and the evaluation performance, inferred-predicates, and timing is recorded
    * Example Directories can be among: citeseer cora epinions jester lastfm
    
* `scripts/run_weight_learning_robustness_experiments.sh`
    * This script will run the weight learning robustness experiments on the datasets who's paths where provided via the command line argument
    * 100 iterations of weight learning on the 0^th fold of each dataset will be run and the resulting evaluation set performance and learned weights are recorded  
    * Example Directories can be among: citeseer cora epinions jester lastfm
    
* `scripts/setup_psl_examples.sh`
    * Fetches the PSL examples and modifies the CLI configuration for theses experiments
    
* `*.psl`
    * PSL model files. e.g. Citeseer.psl, Cora.psl, ...
    * fetched from 'https://github.com/linqs/psl-examples.git' repository in `scripts/setup_psl_examples.sh`
    
* `*.data`
    * data file required to run PSL. e.g. Citeseer-learn-0.data, Citeseer-eval-0.data,...
    * fetched from 'https://github.com/linqs/psl-examples.git' repository in `scripts/setup_psl_examples.sh`
    
    
* `data/`
    * folder containing all data.
    * fetched in the run scripts of the PSL examples in 'https://github.com/linqs/psl-examples.git'
    
* `psl-cli-2.2.0.jar` Jar file compiled using the code in psl_code.zip


# PSL

# Tuffy

The user manual for Tuffy can be found here 'http://i.stanford.edu/hazy/tuffy/doc/tuffy-manual.pdf'

The following sections describe some of the pertinent information that is required to understand the translation 
from the PSL models and data to the Tuffy models and data.

## Tuffy Data Files

There are 2 data files that are required to run Tuffy experiements, an *Evidence* file and a *Queries* file.

### Evidence

Evidence files consist of a list of atoms that are provided as evidence to the MLN model.
An atom in the evidence file can preceded can be preceded by an `!` character to indicate that it is false or by 
a floating point number in the range `[0, 1.0]` that acts as 'soft evidence' for the truth value of the atom.
A floating point number can be seen as a prior probability.

### Queries

Query files contain either a predicate or a list of ground atoms that are to be inferred by the MLN model.

## Tuffy Models

In both PSL and Tuffy, predicates can be either open or closed

Closed predicates are those that are assumed to be fully observed, i.e. the evidence presented to the program is all there is and those ground atoms missing from the set of possible ground atoms are assumed to be false. 
This is commonly referred to as the closed world assumption. 
A closed predicate can be specified in PSL models via the .data files.
In Tuffy closed predicates can be declared by a preceding asterisk in the .mln file

Open predicates are those with partially observed evidence, that is to say that ground atoms not included in the evidence file are assumed to be simply unknown and will be inferred by the model during inference.
In Tuffy models predicates that are declared without an asterik are open.

### Scoping

Rather than ground the entire cross product of predicate arguments for both PSL and Tuffy models, which would lead to intractably large models in many cases, the technique of scoping is used.
Scoping can cut down the number of ground atoms by adding restricition on which arguments to a predict are actually sensible.  

In PSL scoping predicates are included in the logical rules and can be specified in the .data file.
Tuffy models explicitly declare scoping predicates using datalog syntax.

## Tuffy Weight Learning
All atoms in the evidence file matching the atoms the query file will be considered training data.  
Also note that a close world assumption is made, i.e. atoms not appearing in evidence will be regarded 
as negative atoms.

By default, Tuffy uses the average weight of all the iterations of weight learning as the weight learning solution.
We keep this default for the Tuffy provided weight learning method experiments, but use the optimal point for the 
search based methods implemented specifically for these experiments. 

#!/usr/bin/python

# =======================================================================
# This file is part of MCLRE.
#
# MCLRE is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# MCLRE is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with MCLRE.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2015 Augusto Queiroz de Macedo <augustoqmacedo@gmail.com>
# =======================================================================

"""
Hybrid Recommenders Execution
"""
import os
import logging
import multiprocessing
import subprocess, shlex
from argparse import ArgumentParser

from run_rec_functions import read_experiment_atts
from hybrids.merge_ranked_lists_mr import merge_ranked_lists, MissingDataError
import hybrids.learning_to_rank.ranklib_recommender as ranklib

##############################################################################
# GLOBAL VARIABLES
##############################################################################

# Define the Logging
logging.basicConfig(format='%(asctime)s : %(levelname)s : %(name)s : %(message)s',
                    level=logging.INFO)
LOGGER = logging.getLogger('run_rec_hybrids')

DICT_ALG_RANKFILE = {}
ENSEMBLE_LIST = []

##############################################################################
# CLASSES
##############################################################################
class HybridModelConf(object):
    def __init__(self, algorithm, model_name, hyper_params):
        self.algorithm = algorithm
        self.model_name = model_name
        self.hyper_params = hyper_params

##############################################################################
# FUNCTIONS
##############################################################################
def get_dict_alg_files(region):
    """ Select the algorithm files based on the REGION """
    region = region.upper()
    dict_alg_file = {'GROUP-RSVPS': 'heuristic_models/GROUP-RSVPS.tsv',
                     'MRBPR': 'mrbpr/MRBPR_300-0.1-1500-0.1:0.22:0.68.tsv',
                     'HIST-SIZE-USER': None,
                     'HIST-SIZE-EVENT': None}

    dict_alg_region_file = {'USER-KNN-TIME': {"CHICAGO": 'heuristic_models/USER-KNN-TIME_65.tsv',
                                              "PHOENIX": 'heuristic_models/USER-KNN-TIME_50.tsv',
                                              "SAN_JOSE": 'heuristic_models/USER-KNN-TIME_100.tsv'},
                            'CB-TFIDF': {"CHICAGO": 'content_based_models/CB-TFIDF:PP-FEW:UP-TIME_name-desc-punc-stop:6:0.005.tsv',
                                         "PHOENIX": 'content_based_models/CB-TFIDF:PP-FEW:UP-TIME_name-desc-punc-stop:6:0.01.tsv',
                                         "SAN_JOSE": 'content_based_models/CB-TFIDF:PP-FEW:UP-TIME_name-desc-punc-stop:6:0.005.tsv'},
                            'LOC-GEO-PROFILE': {'CHICAGO': 'heuristic_models/LOC-GEO-PROFILE_0.001.tsv',
                                                'PHOENIX': 'heuristic_models/LOC-GEO-PROFILE_0.00075.tsv',
                                                'SAN_JOSE': 'heuristic_models/LOC-GEO-PROFILE_0.00075.tsv'}}

    for alg in dict_alg_region_file:
        dict_alg_file[alg] = dict_alg_region_file[alg][region]

    return dict_alg_file

def get_hybrid_models(hybrid_algorithms):
    """ Generate HybridModelConf objects """

    ensembled_algs_list = [["CB-TFIDF", "LOC-GEO-PROFILE", "USER-KNN-TIME", "MRBPR", "HIST-SIZE-EVENT", "GROUP-RSVPS"]]

    # RANK-NET
    net_layers = [1]
    net_nodes = [3]
    net_learning_rates = ["0.0001"]
    net_epochs = [100]
    # net_layers = [1]
    # net_nodes = [15, 10, 5, 3, 1]
    # net_learning_rates = ["0.0001", "0.001", "0.01"]
    # net_epochs = [100]

    # COORDINATE-ASCENT
    coord_restarts = [1]
    coord_iterations = [25, 10]
    coord_tolerance = [0.001]
    coord_regularization = [None]
    # coord_restarts = [5, 1]
    # coord_iterations = [25, 10, 5, 1]
    # coord_tolerance = [0.001]
    # coord_regularization = [None, "0.001", "0.01"]

    # MART
    mart_trees = [1000]
    mart_leaves = [20]
    mart_shrinkage = [0.1]
    # mart_trees = [500, 1000]
    # mart_leaves = [10, 20]
    # mart_shrinkage = [0.05, 0.1]

    for ensembled_algs in ensembled_algs_list:
        ensembled_algs = sorted(ensembled_algs)
        for hybrid_alg in hybrid_algorithms:

            if hybrid_alg == "RANK-NET":
                for layer in net_layers:
                    for node in net_nodes:
                        for learning_rate in net_learning_rates:
                            for epoch in net_epochs:
                                hyper_params = {"ensemble_list": ensembled_algs,
                                                "layer": layer,
                                                "node": node,
                                                "learning_rate": float(learning_rate),
                                                "epoch": epoch}

                                model_name = "%s_%s:%s:%s:%s:%s" % (hybrid_alg,
                                                                    layer,
                                                                    node,
                                                                    learning_rate,
                                                                    epoch,
                                                                    ".".join(ensembled_algs))

                                yield HybridModelConf(hybrid_alg, model_name, hyper_params)

            elif hybrid_alg == "COORDINATE-ASCENT":
                for restarts in coord_restarts:
                    for iterations in coord_iterations:
                        for tolerance in coord_tolerance:
                            for reg in coord_regularization:
                                hyper_params = {"ensemble_list": ensembled_algs,
                                                "restarts": restarts,
                                                "iterations": iterations,
                                                "tolerance": tolerance,
                                                "regularization": reg}

                                model_name = "%s_%s:%s:%s:%s:%s" % (hybrid_alg,
                                                                    restarts,
                                                                    iterations,
                                                                    tolerance,
                                                                    reg,
                                                                    ".".join(ensembled_algs))

                                yield HybridModelConf(hybrid_alg, model_name, hyper_params)

            elif hybrid_alg == "MART":
                for trees in mart_trees:
                    for leaves in mart_leaves:
                        for shrinkage in mart_shrinkage: # Learning Rate
                            hyper_params = {"ensemble_list": ensembled_algs,
                                            "tree": trees,
                                            "leaves": leaves,
                                            "shrinkage": shrinkage}

                            model_name = "%s_%s:%s:%s:%s" % (hybrid_alg,
                                                             trees,
                                                             leaves,
                                                             shrinkage,
                                                             ".".join(ensembled_algs))
                            yield HybridModelConf(hybrid_alg, model_name, hyper_params)

            else:
                hyper_params = {"ensemble_list": ensembled_algs}
                model_name = "%s_%s" % (hybrid_alg,
                                        ".".join(ensembled_algs))

                yield HybridModelConf(hybrid_alg, model_name, hyper_params)


def generate_features_file(partition_dir, rec_region_data_dir, partition_name, rec_result_dir,
                           dict_ensemble_ranks, data_names, train_or_test):

    csv_merged_filepath = merge_ranked_lists(dict_model_rank_files=dict_ensemble_ranks,
                                             rec_partition_dir=os.path.join(rec_region_data_dir, partition_name),
                                             parsed_result_dir=rec_result_dir)
    csv_data_filename = os.path.basename(csv_merged_filepath)

    output_features_file = os.path.join(rec_region_data_dir, partition_name, rec_result_dir,
                                        "%s_%s-features.txt" % (".".join(data_names), train_or_test))
    if not os.path.exists(output_features_file):
        subprocess.call(shlex.split("Rscript %s %s %s %s %s %s %s %s" %
                                    (os.path.join("src", "recommender_execution", "hybrids", "learning_to_rank", "rank_features_generator.R"),
                                     partition_dir, rec_region_data_dir,
                                     partition_name, rec_result_dir, csv_data_filename, ','.join(data_names), train_or_test)))
    return output_features_file, csv_data_filename

#
# Parallelism Functions
#
def get_models_to_experiment(partitions, algorithms, partitioned_region_data_dir,
                             rec_region_data_dir, rec_result_dir):
    """ Work Creator """

    for model_conf in get_hybrid_models(algorithms):
        for i in range(len(partitions)-1):
            # Train with the last PARTITION and Predict with the current one
            train_partition_name = "partition_%d" % partitions[i]
            test_partition_name = "partition_%d" % partitions[i+1]

            try:

                # -------------------------------------------------------------------------
                # TRAIN DATASET
                # -------------------------------------------------------------------------
                LOGGER.info("Generating the TRAIN dataset (%s)", train_partition_name)
                LOGGER.info("Data List: %s", ' '.join(ENSEMBLE_LIST))
                train_features_file, train_csv_filename = generate_features_file(partitioned_region_data_dir, rec_region_data_dir,
                                                                                 train_partition_name, rec_result_dir,
                                                                                 DICT_ALG_RANKFILE, ENSEMBLE_LIST, "train")
                LOGGER.info("TRAIN features file saved at [%s]", train_features_file)

                # -------------------------------------------------------------------------
                # TEST DATASET
                # -------------------------------------------------------------------------
                LOGGER.info("Generating the TEST dataset (%s)", test_partition_name)
                LOGGER.info("Data List: %s", ' '.join(ENSEMBLE_LIST))
                test_features_file, _ = generate_features_file(partitioned_region_data_dir, rec_region_data_dir,
                                                               test_partition_name, rec_result_dir,
                                                               DICT_ALG_RANKFILE, ENSEMBLE_LIST, "test")
                LOGGER.info("TEST features file saved at [%s]", test_features_file)

            except MissingDataError as error:
                print error
                print 'No Problem!'
                continue

            yield (model_conf, partitioned_region_data_dir, rec_region_data_dir,
                   train_partition_name, test_partition_name, rec_result_dir,
                   train_csv_filename, train_features_file, test_features_file)


def create_models_and_recommend((model_conf, partitioned_region_data_dir, rec_region_data_dir,
                                 train_partition_name, test_partition_name, rec_result_dir,
                                 train_csv_filename, train_features_file, test_features_file)):

    LOGGER.info("%s", model_conf.model_name)

    if os.path.exists(os.path.join(rec_region_data_dir, test_partition_name,
                                   rec_result_dir, model_conf.model_name + ".tsv")):
        LOGGER.info("Model already experimented (DONE!)")
    else:
        LOGGER.info(">> TEST %s", test_partition_name)

        # Run the Learning to Rank Algorithm and PREDICT the event ranks in the current PARTITION
        hybrids_dir = os.path.join(rec_region_data_dir, test_partition_name, rec_result_dir)
        partition_dir = os.path.join(partitioned_region_data_dir, test_partition_name)

        ranklib.train_and_predict(model_conf, ENSEMBLE_LIST,
                                  train_features_file, test_features_file, hybrids_dir, partition_dir)



if __name__ == '__main__':

    # -------------------------------------------------------------------------
    # Argument Parsing
    # -------------------------------------------------------------------------
    PARSER = ArgumentParser(description="Script that runs the hybrid recommender 'algorithms' for" \
                                        " a given 'experiment_name' with data from a given 'region'")
    PARSER.add_argument("-e", "--experiment_name", type=str, required=True,
                        help="The Experiment Name (e.g. recsys-15)")
    PARSER.add_argument("-r", "--region", type=str, required=True,
                        help="The data Region (e.g. san_jose)")
    PARSER.add_argument("-a", "--algorithms", type=str, required=True, nargs="+",
                        help="The algorithms to execute (e.g. COORDINATE-ASCENT)")
    PARSER.add_argument("-p", "--max-parallel", type=int, default=multiprocessing.cpu_count() - 1,
                        help="Parallelism!")
    ARGS = PARSER.parse_args()

    EXPERIMENT_NAME = ARGS.experiment_name
    REGION = ARGS.region
    ALGORITHMS = ARGS.algorithms
    MAX_PARALLEL = ARGS.max_parallel


    DATA_DIR = "data"
    PARTITIONED_REGION_DATA_DIR = os.path.join(DATA_DIR, "partitioned_data", REGION)
    EXPERIMENT_DIR = os.path.join(DATA_DIR, "experiments", EXPERIMENT_NAME)
    REC_REGION_DATA_DIR = os.path.join(EXPERIMENT_DIR, REGION, "recommendations")
    REC_RESULT_DIR_NAME = "hybrid_models"

    LOGGER.info("HYBRID Algorithms")
    LOGGER.info(ALGORITHMS)

    # Read the experiment attributes
    PARTITIONS = read_experiment_atts(EXPERIMENT_DIR)["partitions"]

    DICT_ALG_RANKFILE = get_dict_alg_files(REGION)

    ENSEMBLE_LIST = sorted(DICT_ALG_RANKFILE.keys())

    if MAX_PARALLEL > 1:
        # Define the Multiprocessing Pool (with size equals to CPU_COUNT -1)
        EXPERIMENT_POOL = multiprocessing.Pool(MAX_PARALLEL)
        # Starts the multiple processes
        EXPERIMENT_POOL.map(create_models_and_recommend,
                            get_models_to_experiment(PARTITIONS, ALGORITHMS,
                                                     PARTITIONED_REGION_DATA_DIR, REC_REGION_DATA_DIR, REC_RESULT_DIR_NAME))
    else:
        for experiment_data in get_models_to_experiment(PARTITIONS, ALGORITHMS,
                                                        PARTITIONED_REGION_DATA_DIR, REC_REGION_DATA_DIR, REC_RESULT_DIR_NAME):
            create_models_and_recommend(experiment_data)

    LOGGER.info("DONE!")

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
Run Content-Based Models
"""

import logging
import multiprocessing
from os import path
from argparse import ArgumentParser

from run_rec_functions import read_experiment_atts
from content_based.event_recommender import ContentBasedModelConf, UserProfileConf, PostProcessConf, \
                                            cb_train, cb_recommend, persist_recommendations

# Define the Logging
logging.basicConfig(format='%(asctime)s : %(levelname)s : %(name)s : %(message)s',
                    level=logging.INFO)
LOGGER = logging.getLogger('run_rec_content_based')

# Model configuration parameters
# These parameters define the way the model is trained/queried
# A small variation here could potentially improve the model recomendation result
# These are the configuration variables:
#   - Algorithms and Hyper-Parameters
#   - User Profile
#       * e.g. bag of words of all past events, bow of only the last event, time decay
#   - Pre-Processment
#       * e.g. remove numbers AND/OR remove punctuation AND/OR remove low frequency words
#   - Post-Processment
#       * e.g. term selection by information theory metrics
#   - Data
#       * e.g. name AND/OR description

MODEL_NAME_PREFIX = "CB"
POST_PROCESS_PREFIX = "PP"
USER_PROFILE_PREFIX = "UP"

# -------------------------------------------------------------------------
# Auxiliar Functions
def get_cb_model_confs(algorithm):
    """
    Function Generator that yields the model names to experiment
    This generator is going to be consumed during the experimentation loop
    """
    num_topics = [250]
    num_iterations = [250]
    num_corpus_passes = [10]
    input_data_types = [["name", "description"]]

    for input_data in input_data_types:
        input_type_name = '-'.join([data_type[:4] for data_type in input_data])

        if algorithm == "TFIDF":
            pre_process = {"text":[],
                           "word":['strip_punctuations', 'remove_stop_words']}
            pre_process_name = 'punc-stop'

            cb_model_conf = ContentBasedModelConf(algorithm=algorithm,
                                                  hyper_parameters={},
                                                  params_name="%s-%s" % (input_type_name,
                                                                         pre_process_name),
                                                  pre_processment=pre_process,
                                                  input_data=input_data)
            yield cb_model_conf

        if algorithm == "LSI":
            pre_process = {"text":[],
                           "word":['strip_punctuations', 'remove_stop_words', 'get_stemmed_words']}
            pre_process_name = 'punc-stop-stem'

            for n_topics in num_topics:
                cb_model_conf = ContentBasedModelConf(algorithm=algorithm,
                                                      hyper_parameters={"num_topics": n_topics},
                                                      params_name="%d-%s-%s" % (n_topics,
                                                                                input_type_name,
                                                                                pre_process_name),
                                                      pre_processment=pre_process,
                                                      input_data=input_data)
                yield cb_model_conf

        if algorithm == "LDA":
            pre_process = {"text":[],
                           "word":['strip_punctuations', 'remove_stop_words', 'get_stemmed_words']}
            pre_process_name = 'punc-stop-stem'

            for n_topics in num_topics:
                for n_iterations in num_iterations:
                    for n_corpus_passes in num_corpus_passes:
                        cb_model_conf = ContentBasedModelConf(algorithm=algorithm,
                                                              hyper_parameters={"num_topics": n_topics,
                                                                                "num_corpus_passes": n_corpus_passes,
                                                                                "num_iterations": n_iterations},
                                                              params_name="%d-%d-%d-%s-%s" % (n_topics,
                                                                                              n_corpus_passes,
                                                                                              n_iterations,
                                                                                              input_type_name,
                                                                                              pre_process_name),
                                                              pre_processment=pre_process,
                                                              input_data=input_data)
                        yield cb_model_conf


def get_post_process_confs():
    """
    Generates all Term Selections
    """

    # ------------------------------------------------------------------------
    # PP0) NO POST PROCESSMENT
    # yield PostProcessConf(name='NO',
    #                       params_name="",
    #                       types=[],
    #                       params={})


    # ------------------------------------------------------------------------
    # PP1) FILTER EXTREME WORDS
    names = ["FEW"]
    types = ["filter_extreme_words"]

    # min_word_frequencies = [2, 4, 6, 8, 10]
    min_word_frequencies = [6]
    for freq in min_word_frequencies:
        params = {'no_below_freq': freq}

        yield PostProcessConf(name='-'.join(names),
                              params_name='-'.join([str(params['no_below_freq'])]),
                              types=types,
                              params=params)


def get_user_profile_confs():
    """
    Generates all User Profiles
    """

    # SUM
    # user_profile_conf = UserProfileConf(name="SUM",
    #                                     params={},
    #                                     params_name="")
    # yield user_profile_conf

    # TIME
    # daily_decay = 0.01 (~60 days to approach zero)
    # daily_decay = 0.07 (~365 days to approach zero)
    DAILY_DECAY_VALUES = ["0.005", "0.01"]
    for daily_decay in DAILY_DECAY_VALUES:
        user_profile_conf = UserProfileConf(name="TIME",
                                            params={"daily_decay": float(daily_decay)},
                                            params_name="%s" % daily_decay)
        yield user_profile_conf

    # INVERSE-POPULARITY
    # user_profile_conf = UserProfileConf(name="INV-POPULARITY",
    #                                     params={},
    #                                     params_name="")
    # yield user_profile_conf


#
# Parallelism Functions
#
def get_models_to_experiment(partitions, algorithms, partitioned_region_data_dir, experiment_region_data_dir):
    """ Work Creator """
    for partition in partitions:
        part_name = "partition_%d" % partition

        db_partition_dir = path.join(partitioned_region_data_dir, part_name,
                                     "content_based_models")
        rec_result_dir = path.join(experiment_region_data_dir, "recommendations",
                                   part_name, "content_based_models")

        for algorithm in algorithms:
            for cb_model_conf in get_cb_model_confs(algorithm):
                for post_process_conf in get_post_process_confs():
                    yield (partition, db_partition_dir, rec_result_dir, cb_model_conf, post_process_conf)


def create_models_and_recommend((partition, db_partition_dir, rec_result_dir, cb_model_conf, post_process_conf)):
    """ Worker Executor (as parameter it expects a single tuple with all the arguments inside of it """
    cb_model = None
    dict_event_content = None
    for user_profile_conf in get_user_profile_confs():
        model_profile_name = "%s-%s:%s-%s:%s-%s_%s:%s:%s" % (MODEL_NAME_PREFIX,
                                                             cb_model_conf.algorithm,
                                                             POST_PROCESS_PREFIX,
                                                             post_process_conf.name,
                                                             USER_PROFILE_PREFIX,
                                                             user_profile_conf.name,
                                                             cb_model_conf.params_name,
                                                             post_process_conf.params_name,
                                                             user_profile_conf.params_name)


        LOGGER.info("%s - partition %d - %s", REGION, partition, model_profile_name)

        if path.exists(path.join(rec_result_dir, model_profile_name + ".tsv")):
            LOGGER.info("Model already experimented (DONE!)")
        else:
            if not cb_model:
                cb_model, dict_event_content = cb_train(cb_model_conf, post_process_conf, db_partition_dir)

            dict_user_rec_events = cb_recommend(cb_model, user_profile_conf,
                                                dict_event_content, db_partition_dir, partition)

            persist_recommendations(dict_user_rec_events, model_profile_name, rec_result_dir)


if __name__ == "__main__":

    # -------------------------------------------------------------------------
    # Define the argument parser
    PARSER = ArgumentParser(description="Script that runs the content-based event recommender algorithms for" \
                                        " a given 'experiment_name' with data from a given 'region'")
    PARSER.add_argument("-e", "--experiment_name", type=str, required=True,
                        help="The Experiment Name (e.g. recsys-15)")
    PARSER.add_argument("-r", "--region", type=str, required=True,
                        help="The data Region (e.g. san_jose)")
    PARSER.add_argument("-a", "--algorithms", type=str, required=True, nargs="+",
                        help="The algorithm to experiment (i.e. TFIDF, LDA or LSI)")
    PARSER.add_argument("--not-parallel", dest="not_parallel", action="store_true",
                        help="Not-Parallel!")
    ARGS = PARSER.parse_args()

    EXPERIMENT_NAME = ARGS.experiment_name
    REGION = ARGS.region
    ALGORITHMS = ARGS.algorithms
    PARALLEL_EXECUTION = not ARGS.not_parallel

    DATA_DIR = "data"
    PARTITIONED_REGION_DATA_DIR = path.join(DATA_DIR, "partitioned_data", REGION)
    EXPERIMENT_DIR = path.join(DATA_DIR, "experiments", EXPERIMENT_NAME)
    EXPERIMENT_REGION_DATA_DIR = path.join(EXPERIMENT_DIR, REGION)

    LOGGER.info("Content-Based Algorithms")
    LOGGER.info(ALGORITHMS)

    # Read the experiment attributes
    PARTITIONS = read_experiment_atts(EXPERIMENT_DIR)["partitions"]

    if PARALLEL_EXECUTION:
        # Define the Multiprocessing Pool (with size equals to CPU_COUNT -1)
        EXPERIMENT_POOL = multiprocessing.Pool(multiprocessing.cpu_count() - 1)
        # Starts the multiple processes
        EXPERIMENT_POOL.map(create_models_and_recommend,
                            get_models_to_experiment(PARTITIONS, ALGORITHMS,
                                                     PARTITIONED_REGION_DATA_DIR, EXPERIMENT_REGION_DATA_DIR))
    else:
        for experiment_data in get_models_to_experiment(PARTITIONS, ALGORITHMS,
                                                        PARTITIONED_REGION_DATA_DIR, EXPERIMENT_REGION_DATA_DIR):
            create_models_and_recommend(experiment_data)

    LOGGER.info("DONE!")

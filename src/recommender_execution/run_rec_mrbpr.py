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
MRBPR Runner
"""
from os import path
from argparse import ArgumentParser
import shlex
import subprocess
import multiprocessing
import logging

from run_rec_functions import read_experiment_atts

from mrbpr.mrbpr_runner import create_meta_file, run

##############################################################################
# GLOBAL VARIABLES
##############################################################################
# Define the Logging
logging.basicConfig(format='%(asctime)s : %(levelname)s : %(name)s : %(message)s',
                    level=logging.INFO)
LOGGER = logging.getLogger('mrbpr.run_rec_mrbpr')
LOGGER.setLevel(logging.INFO)

##############################################################################
# AUXILIAR FUNCTIONS
##############################################################################
def get_mrbpr_confs():
    """ Yield the MRBPR Models Configurations """
    pass


##############################################################################
# MAIN
##############################################################################

if __name__ == '__main__':

    # ------------------------------------------------------------------------
    # Define the argument parser
    PARSER = ArgumentParser(description="Script that runs the mrbpr event recommender algorithms for" \
                                        " a given 'experiment_name' with data from a given 'region'")
    PARSER.add_argument("-e", "--experiment_name", type=str, required=True,
                        help="The Experiment Name (e.g. recsys-15)")
    PARSER.add_argument("-r", "--region", type=str, required=True,
                        help="The data Region (e.g. san_jose)")
    PARSER.add_argument("-a", "--algorithm", type=str, required=True,
                        help="The algorithm name (used only to differenciate our proposed MRBPR to the others")
    ARGS = PARSER.parse_args()

    EXPERIMENT_NAME = ARGS.experiment_name
    REGION = ARGS.region
    ALGORITHM_NAME = ARGS.algorithm

    LOGGER.info(ALGORITHM_NAME)

    DATA_DIR = "data"
    PARTITIONED_DATA_DIR = path.join(DATA_DIR, "partitioned_data")
    PARTITIONED_REGION_DATA_DIR = path.join(PARTITIONED_DATA_DIR, REGION)
    EXPERIMENT_DIR = path.join(DATA_DIR, "experiments", EXPERIMENT_NAME)
    EXPERIMENT_REGION_DATA_DIR = path.join(EXPERIMENT_DIR, REGION)

    # LOGGER.info('Defining the MRBPR relation weights file...')
    subprocess.call(shlex.split("Rscript %s %s %s" %
                                (path.join("src", "recommender_execution", "mrbpr", "mrbpr_relation_weights.R"),
                                 EXPERIMENT_NAME, ALGORITHM_NAME)))

    # ------------------------------------------------------------------------
    # Reading and Defining the Experiment Attributes
    EXPERIMENT_ATTS = read_experiment_atts(EXPERIMENT_DIR)

    PARALLEL_RUNS = multiprocessing.cpu_count() - 1
    TRAIN_RELATION_NAMES = EXPERIMENT_ATTS['%s_relation_names' % ALGORITHM_NAME.lower()]
    TRAIN_RELATION_FILES = ["%s_train.tsv" % name for name in TRAIN_RELATION_NAMES]
    PARTITIONS = reversed(EXPERIMENT_ATTS['partitions'])

    # ------------------------------------------------------------------------
    # Reading and Defining the Experiment Attributes
    META_FILE = path.join(EXPERIMENT_DIR, "%s_meetup.meta" % ALGORITHM_NAME.lower())

    LOGGER.info('Creating the META relations file...')
    create_meta_file(TRAIN_RELATION_NAMES, META_FILE, PARTITIONED_DATA_DIR)

    # ------------------------------------------------------------------------
    # Fixed parameters
    # ------------------------------------------------------------------------
    # Algorithm (0 - MRBPR)
    ALGORITHM = 0

    # Size of the Ranked list of events per User
    RANK_SIZE = 100

    # Save Parameters
    SAVE_MODEL = 0

    # Hyper Parameters
    REGULARIZATION_PER_ENTITY = ""
    REGULARIZATION_PER_RELATION = ""
    RELATION_WEIGHTS_FILE = path.join(EXPERIMENT_DIR, "%s_relation_weights.txt" % ALGORITHM_NAME.lower())

    # ------------------------------------------------------------------------

    if ALGORITHM_NAME == "MRBPR":
        LEARN_RATES = [0.1]
        NUM_FACTORS = [300]
        NUM_ITERATIONS = [1500]
    elif ALGORITHM_NAME == "BPR-NET":
        LEARN_RATES = [0.1]
        NUM_FACTORS = [200]
        NUM_ITERATIONS = [600]
    else:
        LEARN_RATES = [0.1]
        NUM_FACTORS = [10]
        NUM_ITERATIONS = [10]

    MRBPR_BIN_PATH = path.join("src", "recommender_execution", "mrbpr", "mrbpr.bin")

    LOGGER.info("Start running MRBPR Process Scheduler!")
    run(PARTITIONED_REGION_DATA_DIR, EXPERIMENT_REGION_DATA_DIR,
        REGION, ALGORITHM, RANK_SIZE, SAVE_MODEL, META_FILE,
        REGULARIZATION_PER_ENTITY, REGULARIZATION_PER_RELATION,
        RELATION_WEIGHTS_FILE, TRAIN_RELATION_FILES,
        PARTITIONS, NUM_ITERATIONS, NUM_FACTORS, LEARN_RATES,
        MRBPR_BIN_PATH, PARALLEL_RUNS, ALGORITHM_NAME)

    LOGGER.info("DONE!")

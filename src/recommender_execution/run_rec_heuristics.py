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
Heuristic Recommenders Execution
"""
from os import path
import shlex
import subprocess
import logging
from argparse import ArgumentParser

from run_rec_functions import read_experiment_atts


# Define the Logging
logging.basicConfig(format='%(asctime)s : %(levelname)s : %(name)s : %(message)s',
                    level=logging.INFO)
LOGGER = logging.getLogger('run_rec_heuristics')

if __name__ == '__main__':

    # -------------------------------------------------------------------------
    # Argument Parsing
    # -------------------------------------------------------------------------
    PARSER = ArgumentParser(description="Script that runs the heuristic recommender algorithms for" \
                                        " a given 'experiment_name' with data from a given 'region'")
    PARSER.add_argument("-e", "--experiment_name", type=str, required=True,
                        help="The Experiment Name (e.g. recsys-15)")
    PARSER.add_argument("-r", "--region", type=str, required=True,
                        help="The data Region (e.g. san_jose)")
    PARSER.add_argument("-a", "--algorithms", type=str, required=True, nargs="+",
                        help="The data Region (e.g. san_jose)")
    ARGS = PARSER.parse_args()

    EXPERIMENT_NAME = ARGS.experiment_name
    REGION = ARGS.region
    ALGORITHMS = ARGS.algorithms

    LOGGER.info("Heuristic Based Algorithms")

    DATA_DIR = "data"
    PARTITIONED_REGION_DATA_DIR = path.join(DATA_DIR, "partitioned_data", REGION)
    EXPERIMENT_DIR = path.join(DATA_DIR, "experiments", EXPERIMENT_NAME)
    EXPERIMENT_REGION_DATA_DIR = path.join(EXPERIMENT_DIR, REGION)

    # -------------------------------------------------------------------------
    # Read the experiment attributes
    EXPERIMENT_ATTS = read_experiment_atts(EXPERIMENT_DIR)

    for part in EXPERIMENT_ATTS['partitions']:

        part_name = "partition_%d" % part

        db_partition_dir = path.join(PARTITIONED_REGION_DATA_DIR, part_name, "heuristic_models")
        rec_result_dir = path.join(EXPERIMENT_REGION_DATA_DIR, "recommendations", part_name, "heuristic_models")

        for algorithm in ALGORITHMS:

            if algorithm.startswith("USER-KNN-TIME"):
                LOGGER.info("%s - partition %d - %s", REGION, part, algorithm)

                if REGION == 'chicago':
                    NEIGHBOORHOOD_SIZE = [65]
                elif REGION == 'phoenix':
                    NEIGHBOORHOOD_SIZE = [50]
                else:
                    NEIGHBOORHOOD_SIZE = [100]

                subprocess.call(shlex.split("Rscript %s %s %s %d %s %s" %
                                            (path.join("src", "recommender_execution", "heuristic_based", "user_knn_time.R"),
                                             db_partition_dir, rec_result_dir, part, algorithm, ','.join([str(s) for s in NEIGHBOORHOOD_SIZE]))))

            elif algorithm.startswith("LOC-GEO-PROFILE"):
                if REGION == 'chicago':
                    BANDWIDTHS = ["0.001"]
                else:
                    BANDWIDTHS = ["0.00075"]

                for bandwidth in BANDWIDTHS:
                    MODEL_NAME = "%s_%s" % (algorithm, bandwidth)

                    LOGGER.info("%s - partition %d - %s", REGION, part, MODEL_NAME)

                    if path.exists(path.join(rec_result_dir, "%s.tsv" % MODEL_NAME)):
                        LOGGER.info("Model already experimented (DONE!)")
                    else:
                        subprocess.call(shlex.split("Rscript %s %s %s %s" %
                                                    (path.join("src", "recommender_execution", "heuristic_based", "location_aware.R"),
                                                     db_partition_dir, rec_result_dir, MODEL_NAME)))

            elif algorithm.startswith("GROUP"):
                LOGGER.info("%s - partition %d - %s", REGION, part, algorithm)

                if path.exists(path.join(rec_result_dir, "%s.tsv" % algorithm)):
                    LOGGER.info("Model already experimented (DONE!)")
                else:
                    subprocess.call(shlex.split("Rscript %s %s %s %s" %
                                                (path.join("src", "recommender_execution", "heuristic_based", "group_aware.R"),
                                                 db_partition_dir, rec_result_dir, algorithm)))


    LOGGER.info("DONE!")

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

from os import makedirs, path, getcwd, chdir
import shlex
import subprocess
import sys

from run_rec_functions import read_experiment_atts

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print "usage: python src/recommender_execution/run_rec_my_media.py <EXPERIMENT_NAME> <REGION (e.g. chicago)> <ALGORITHM>"
        exit(1)

    EXPERIMENT_NAME = sys.argv[1]
    REGION = sys.argv[2]
    ALGORITHM = sys.argv[3]

    print "=================== My Media Lite Algorithms ==================="

    # Define the data directories
    DATA_DIR = "data"
    PARTITIONED_REGION_DATA_DIR = path.join(DATA_DIR, "partitioned_data", REGION)
    EXPERIMENT_DIR = path.join(DATA_DIR, "experiments", EXPERIMENT_NAME)
    EXPERIMENT_REGION_DATA_DIR = path.join(EXPERIMENT_DIR, REGION)

    # -------------------------------------------------------------------------
    # Read the experiment attributes
    EXPERIMENT_ATTS = read_experiment_atts(EXPERIMENT_DIR)

    for part in EXPERIMENT_ATTS['partitions']:

        part_name = "partition_%d" % part

        db_partition_dir = path.join(PARTITIONED_REGION_DATA_DIR, part_name, "my_media")
        rec_result_dir = path.join(EXPERIMENT_REGION_DATA_DIR, "recommendations", part_name, "my_media")

        if not path.exists(rec_result_dir):
            makedirs(rec_result_dir)

        # -------------------------------------------------------------------------
        # Run all variations (grid-search) of the algorithm
        print "  %s - partition %d - %s" % (REGION, part, ALGORITHM)

        subprocess.call(shlex.split("mono %s %s %s %s" %
                                    (path.join("src", "recommender_execution", "my_media", "TrainRecommend.exe"),
                                     db_partition_dir, rec_result_dir, ALGORITHM)))


    print "======================= DONE ========================"

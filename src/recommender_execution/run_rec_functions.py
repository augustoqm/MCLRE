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
General Runner Functions
"""

from os import path
import csv

def read_experiment_atts(experiment_dir):
    """ Read the Experiment Attributes from CSV """
    with open(path.join(experiment_dir, "experiment_atts.csv"), 'r') as atts_file:
        exp_atts_file = csv.reader(atts_file)

        exp_atts = {}

        exp_atts_file.next()
        for row in exp_atts_file:
            exp_atts[row[0]] = row[1]

        # Parse the used attributes: relation_names AND partitions
        for att in exp_atts:
            if att.endswith("relation_names"):
                exp_atts[att] = exp_atts[att].split(",")

        exp_atts['partitions'] = [int(number) for number in exp_atts['partitions'].split(",")]

        return exp_atts

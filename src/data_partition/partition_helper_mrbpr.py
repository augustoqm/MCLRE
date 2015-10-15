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
Partition Helper Script: MRBPR USER-USER relations
"""
import os
import csv
import random
import argparse
import itertools
from collections import defaultdict

def generate_relation(data_dir, input_filename, output_filename, relation_id, max_members):
    """ Generate the weight files """

    dict_network_users = defaultdict(set)

    # Read the Data and store its grouping variables in GROUP -> USERS and USER -> GROUPs
    with open(os.path.join(data_dir, input_filename), "r") as data_file:
        data_reader = csv.reader(data_file, delimiter="\t")
        for row in data_reader:
            user_id, group_id = int(row[0]), int(row[1])
            dict_network_users[group_id].add(user_id)

    # Define the user RELATIONS and PERSIT them
    relation_file = os.path.join(data_dir, output_filename)
    if not os.path.exists(relation_file):
        with open(relation_file, "w") as relation_file:
            relation_tsv = csv.writer(relation_file, delimiter="\t")
            for group_id in sorted(dict_network_users):
                if len(dict_network_users[group_id]) > max_members:
                    dict_network_users[group_id] = random.sample(dict_network_users[group_id], max_members)
                for user1, user2 in itertools.combinations(dict_network_users[group_id], 2):
                    # Bi-directional edges
                    relation_tsv.writerow([relation_id, user1, user2, 1])
                    relation_tsv.writerow([relation_id, user2, user1, 1])

if __name__ == "__main__":

    PARSER = argparse.ArgumentParser()
    PARSER.add_argument("-d", "--data_dir", type=str, required=True,
                        help="Data Directory")
    PARSER.add_argument("-i", "--input_filename", type=str, required=True,
                        help="Input Filename (TSV format)")
    PARSER.add_argument("-o", "--output_filename", type=str, required=True,
                        help="Output Filename")
    PARSER.add_argument("-r", "--relation_id", type=int, required=True,
                        help="MRBPR Relation Id")
    PARSER.add_argument("-m", "--max_members", type=int, default=10000000,
                        help="Maximum numbers of members in one network")
    ARGS = PARSER.parse_args()

    generate_relation(ARGS.data_dir, ARGS.input_filename, ARGS.output_filename, ARGS.relation_id, ARGS.max_members)

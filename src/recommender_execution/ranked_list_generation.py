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
Ranked List Generation
"""
from os import path, makedirs
import csv
import glob
import sys

from run_rec_functions import read_experiment_atts

def read_map_event_ids(partition_dir):
    map_event_ids = {}
    with open(path.join(partition_dir, "map_event_ids.csv"), 'r') as map_file:
        map_events_csv = csv.reader(map_file, delimiter=',', quotechar='"')
        # Read the header
        map_events_csv.next()
        for row in map_events_csv:
            map_event_ids[int(row[1])] = row[0] # (int)new_event_id -> (string)event_id

    return map_event_ids


def read_map_user_ids(partition_dir):
    map_user_ids = {}
    with open(path.join(partition_dir, "map_user_ids.csv"), 'r') as map_file:
        map_users_csv = csv.reader(map_file, delimiter=',', quotechar='"')
        # Read the header
        map_users_csv.next()
        for row in map_users_csv:
            map_user_ids[int(row[1])] = int(row[0]) # (int)new_user_id -> (int)user_id

    return map_user_ids


def read_map_user_events_test(partition_dir):
    user_events = {}
    with open(path.join(partition_dir, "user-event-rsvp_test.tsv"), 'r') as map_file:
        map_users_events_test_csv = csv.reader(map_file, delimiter='\t', quotechar='"')

        for row in map_users_events_test_csv:
            user_id = int(row[0])
            event_id = int(row[1])

            if user_id in user_events.keys():
                user_events[user_id].append(event_id)
            else:
                user_events[user_id] = [event_id] # (int)user_id -> list((int)event_id)

    return user_events

def select_relevant_ranks(rank_tsv_file, relevant_rank_tsv,
                          map_user_ids, map_event_ids, map_user_events_test):

    for row in rank_tsv_file:
        new_user_id = int(row[0])

        # Get the relevant events per user
        new_event_ids_test = map_user_events_test[new_user_id]
        ranked_events = []

        # Check if the model was capable of predicting a ranked list or not
        #   There is a predicted value different from ''
        if len(row) > 1 and row[1]:
            ranked_event_list = row[1].split(',')

            # Find the relevant events (from new_event_ids_test) in the ranked recommended list and get its ranks
            for i in range(len(ranked_event_list)):
                if ranked_event_list[i]:
                    # Separate the new_event_id from the predicted score (use only the 1st one)
                    new_event_id = int(ranked_event_list[i].split(':')[0])
                    event_score = float(ranked_event_list[i].split(':')[1])
                    if new_event_id in new_event_ids_test and event_score > 0:
                        relevant_rank_tsv.writerow([map_user_ids[new_user_id], map_event_ids[new_event_id], i+1])
                        ranked_events.append(new_event_id)

        # IDEA: If the Model was not capable of recommeding this event to the user we consider a NA rank
        #   * Therefore, we consider ranking larger that limit (e.g. 100) the same as didn't ranking any event to the user
        for relevant_event in new_event_ids_test:
            if relevant_event not in ranked_events:
                relevant_rank_tsv.writerow([map_user_ids[new_user_id], map_event_ids[relevant_event], 'NA'])


if __name__ == '__main__':

    # Read the Data Format as input
    if len(sys.argv) != 3:
        print "usage: python ranked_list_generation.py <EXPERIMENT_NAME> <REGION (e.g. chicago)>"
        exit(1)

    EXPERIMENT_NAME = sys.argv[1]
    REGION = sys.argv[2]

    DATA_DIR = "data"
    PARTITIONED_DATA_DIR = path.join(DATA_DIR, "partitioned_data", REGION)
    EXPERIMENT_DATA_DIR = path.join(DATA_DIR, "experiments", EXPERIMENT_NAME)
    RECOMMENDATION_DATA_DIR = path.join(EXPERIMENT_DATA_DIR, REGION, "recommendations")

    # Reading the Experiment Attributes
    EXPERIMENT_ATTS = read_experiment_atts(EXPERIMENT_DATA_DIR)

    # Iterate over the EXPERIMENT partitions
    for part in EXPERIMENT_ATTS['partitions']:
        print "Partition %s" % part

        # Define the DB partition dir and the RESULT partition dir
        db_partition_dir = path.join(PARTITIONED_DATA_DIR, "partition_%s" % part)
        result_partition_dir = path.join(RECOMMENDATION_DATA_DIR, "partition_%s" % part)

        # Define the partition ranks directory
        partition_rank_dir = path.join(result_partition_dir, "ranks")

        print "\tReading the mapping files..."
        # Read the mapping user_id files
        map_event_ids = read_map_event_ids(db_partition_dir)
        map_user_ids = read_map_user_ids(db_partition_dir)

        # Read the mapped user-events test dataset
        map_user_events_test = read_map_user_events_test(db_partition_dir)

        # Iterate over all data by FORMAT (e.g. my_media, mrbpr and heuristic_models)
        for result_format_dir in glob.iglob(result_partition_dir + path.sep + "*"):

            if not path.isdir(result_format_dir):
                continue

            data_format = result_format_dir.replace(result_partition_dir + path.sep, "")

            if data_format == "ranks":
                continue

            # Iterate over the model result files
            for model_rank_file_path in glob.iglob(result_partition_dir + path.sep + data_format + path.sep + "*.tsv"):
                if path.isdir(model_rank_file_path):
                    continue

                model_rank_file = model_rank_file_path.replace(result_partition_dir + path.sep + data_format + path.sep, "").replace(".tsv", "")
                print '\t%s - %s' % (data_format, model_rank_file)

                if path.exists(path.join(partition_rank_dir, model_rank_file + ".csv")):
                    continue

                # Create the partition ranks directory
                if not path.exists(partition_rank_dir):
                    makedirs(partition_rank_dir)

                with open(model_rank_file_path, 'r') as all_rank_file:

                    rank_tsv_file = csv.reader(all_rank_file, delimiter='\t', quotechar='"')

                    # Create the model rank file with the relevant ranks only
                    with open(path.join(partition_rank_dir, model_rank_file + ".csv"), 'w') as relevant_rank_file:
                        relevant_rank_tsv = csv.writer(relevant_rank_file, delimiter=',', quotechar='"')

                        select_relevant_ranks(rank_tsv_file, relevant_rank_tsv,
                                              map_user_ids, map_event_ids, map_user_events_test)

    print 'DONE!'

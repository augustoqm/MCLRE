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
MRBPR Recommender
"""

from os import makedirs, path
from collections import namedtuple
import csv
import shlex
import subprocess
import time
import logging

##############################################################################
# GLOBAL VARIABLES
##############################################################################
# Define the Logging
logging.basicConfig(format='%(asctime)s : %(levelname)s : %(name)s : %(message)s',
                    level=logging.INFO)
LOGGER = logging.getLogger('mrbpr.event_recommender')
LOGGER.setLevel(logging.INFO)

ENTITY = namedtuple("entity", ["entity_id",
                               "name"])
RELATION = namedtuple("relation", ["relation_id",
                                   "name",
                                   "entity1_name",
                                   "entity2_name",
                                   "is_target"])

MRBPR_MODEL_CONF = namedtuple("mrbpr_model_conf", ["hyper_parameters",
                                                   "params_name"])

##############################################################################
# PUBLIC FUNCTIONS
##############################################################################
def process_scheduler(running_processes_list, max_parallel_runs):
    """ Schedule the Processes """
    has_printed = False
    secs_to_wait = 1
    spent_time_waiting = 0
    finished_processes = []

    while True:
        # Check the amount of processes still running
        for p in list(running_processes_list):
            return_code = p.poll()
            if return_code is not None:
                # Remove from the running processes the already done
                running_processes_list.remove(p)
                finished_processes.append(p)

                if return_code < 0:
                    LOGGER.info("Scheduler: The process %d ended with error %d", p.pid, return_code)

        if len(running_processes_list) >= max_parallel_runs:
            # Stop for some secs
            if not has_printed:
                LOGGER.info("Scheduler: Waiting... (%d running)", max_parallel_runs)
                has_printed = True

            spent_time_waiting += secs_to_wait
            time.sleep(secs_to_wait)
        else:
            if spent_time_waiting > 0:
                LOGGER.info("Scheduler: Processor RELEASED (%d secs waiting)", spent_time_waiting)
            break

    return running_processes_list, finished_processes


def create_meta_file(relation_names, meta_file_path, partitioned_data_dir):
    """ Create the Meta File """

    # ENTITY NAME -> ENTITY namedtuple
    entities = {}
    # RELATION NAME -> RELATION namedtuple
    relations = {}

    # Read and Parse Entities
    with open(path.join(partitioned_data_dir, "mrbpr_entities.csv"), 'r') as ent_file:
        entities_csv = csv.reader(ent_file)

        entities_csv.next()
        for row in entities_csv:
            entities.setdefault(row[1], ENTITY(entity_id=row[0],
                                               name=row[1]))

    # Read and Parse Relations
    with open(path.join(partitioned_data_dir, "mrbpr_relations.csv"), 'r') as rel_file:
        relations_csv = csv.reader(rel_file)

        relations_csv.next()
        for row in relations_csv:
            full_relation_name = '%s-%s-%s' % (row[2], row[3], row[1])
            relations[full_relation_name] = RELATION(relation_id=row[0],
                                                     name=row[1],
                                                     entity1_name=row[2],
                                                     entity2_name=row[3],
                                                     is_target=row[4])

    # Write Meta file
    with open(meta_file_path, 'w') as meta_file:
        entity_names = set()
        for rel in relation_names:
            entity_names.add(relations[rel].entity1_name)
            entity_names.add(relations[rel].entity2_name)

        meta_file.write('%d\n' % len(entity_names))
        for ent_name in entity_names:
            meta_file.write('%s\t%s\n' % (entities[ent_name].entity_id, ent_name))

        meta_file.write('%d\n' % len(relation_names))
        for rel_name in relation_names:
            meta_file.write('%s\t%s\t2\t%s\t%s\n' % (relations[rel_name].relation_id,
                                                     rel_name,
                                                     entities[relations[rel_name].entity1_name].entity_id,
                                                     entities[relations[rel_name].entity2_name].entity_id))


def run(partitioned_region_data_dir, exp_region_data_dir, region, algorithm, rank_size, save_model, meta_file, regularization_per_entity,
        regularization_per_relation, relation_weights_file, train_relation_files, partitions,
        num_iterations, num_factors, learning_rates, mrbpr_bin_path, parallel_runs, algorithm_name):
    """ MRBPR Runner """

    # Create the process list
    running_processes = []

    # -------------------------------
    # LOOP: PARTITIONS
    for part in partitions:

        # Output Directory
        output_dir = path.join(exp_region_data_dir, "recommendations", "partition_%s" % part, "mrbpr")

        # -------------------------------
        # LOOP: NUM_ITERATIONS
        for num_iter in num_iterations:

            # -------------------------------
            # LOOP: NUM_FACTORS
            for num_fact in num_factors:

                # -------------------------------
                # LOOP: LEARNING_RATES
                for learn_rate in learning_rates:

                    # -------------------------------
                    # LOOP: RELATION WEIGHTS
                    with open(relation_weights_file, 'r') as weight_csv_file:

                        rel_weight_reader = csv.reader(weight_csv_file, delimiter=',', quotechar='"')

                        for row_weight in rel_weight_reader:

                            if len(row_weight) <= 0:
                                break

                            # Define the relation_weights
                            relation_weights = ','.join(row_weight)

                            # Input Files
                            partition_dir = path.join(partitioned_region_data_dir, "partition_%s" % part, "mrbpr")
                            test_users_file = path.join(partition_dir, "users_test.tsv")
                            test_candidates_file = path.join(partition_dir, "event-candidates_test.tsv")

                            # Define the train_files
                            train_files = []
                            for i in range(len(row_weight)):
                                if row_weight[i] != '0':
                                    train_files.append(path.join(partition_dir, train_relation_files[i]))
                            train_files = ','.join(train_files)

                            # Check and Waits for the first process to finish...
                            running_processes, _ = process_scheduler(running_processes, parallel_runs)

                            if not path.exists(output_dir):
                                makedirs(output_dir)

                            model_name = "%s_%s-%s-%s-%s" % (algorithm_name, num_fact, learn_rate, num_iter, relation_weights.replace(",", ":"))

                            LOGGER.info("%s - partition %d - %s", region, part, model_name)

                            # Check ig the model was already trained/ranked (reuse previous executions)
                            if path.exists(path.join(output_dir, model_name + ".tsv")):
                                LOGGER.info("Model already experimented (DONE!)")
                            else:
                                # Start the new process
                                mrbpr_cmd_args = '%s -m %s -d %s -u %s -n %s -o %s -k %d -s %d -h %d -l %f -f %d -i %d -a %s -e "%s" -r "%s" -M %s' \
                                                % (mrbpr_bin_path, meta_file, train_files, test_users_file, test_candidates_file, output_dir, rank_size, \
                                                    save_model, algorithm, learn_rate, num_fact, num_iter, relation_weights, regularization_per_entity, \
                                                    regularization_per_entity, model_name)

                                proc = subprocess.Popen(shlex.split(mrbpr_cmd_args))

                                # Append to the process list
                                running_processes.append(proc)

    LOGGER.info("DONE! All processes have already been started!")

    if len(running_processes) > 0:
        LOGGER.info("Waiting for the last processes to finish")
        while len(running_processes) > 0:
            running_processes, _ = process_scheduler(running_processes, parallel_runs)

            # Check every 5 secs
            time.sleep(5)


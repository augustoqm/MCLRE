#!/usr/bin/env python

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
Merge Ranked Lists with MapReduce (MRJob)
"""
import csv
import subprocess
import shlex
import shutil
from os import path, makedirs

from mrjob.job import MRJob
from mrjob import protocol

class MissingDataError(Exception):
    """ Missing Data Error """
    def __init__(self, rank_file):
        self.rank_file = rank_file

    def __str__(self):
        return "Unexistent Model Ranked File (%s). Please guarantee that all models have " \
               "been executed before merging them." % self.rank_file

class MRMergeRankedLists(MRJob):

    # INPUT_PROTOCOL = protocol.JSONProtocol
    INPUT_PROTOCOL = protocol.RawValueProtocol
    INTERNAL_PROTOCOL = protocol.JSONProtocol
    OUTPUT_PROTOCOL = protocol.JSONValueProtocol

    def steps(self):
        return [self.mr(mapper=self.mapper_user_event_scores,
                        reducer=self.merge_user_event_scores)]

    def configure_options(self):
        super(MRMergeRankedLists, self).configure_options()
        self.add_passthrough_option('--num-models', default='1')
        self.add_passthrough_option('--model-names', default='MOST-POPULAR')

    def mapper_user_event_scores(self, _, value):
        user, event_list, model = value.split("\t")
        if event_list:
            for es in event_list.split(','):
                event, score = es.split(':')
                yield ("%s#%s" % (user, event), "%s#%s" % (model, score))

    def merge_user_event_scores(self, key, value):
        user, event = key.split('#')
        scores = ['0'] * int(self.options.num_models)
        model_names = self.options.model_names.split(",")

        for model_score in value:
            model, score = model_score.split('#')
            scores[model_names.index(model)] = score

        yield None, user + "," + event + ',' + ','.join(scores)

def merge_ranked_lists(dict_model_rank_files, rec_partition_dir, parsed_result_dir):
    """
    Merge the Ranked Lists of all models in a unique file
    """
    # Copy the model ranked lists to the temporary directory and add the model name to it
    data_names = sorted([name for name in dict_model_rank_files.keys() if dict_model_rank_files[name]])

    full_parsed_filepath = path.join(rec_partition_dir, parsed_result_dir,
                                     '%s.csv' % '.'.join(data_names))

    if path.exists(full_parsed_filepath):
        return full_parsed_filepath

    # Create a temporary directory to work on
    tmp_parse_dir = path.join(rec_partition_dir, parsed_result_dir, 'tmp')
    if not path.exists(tmp_parse_dir):
        makedirs(tmp_parse_dir)


    for model_name in data_names:
        model_rank_file = path.join(rec_partition_dir, dict_model_rank_files[model_name])
        if not path.exists(model_rank_file):
            raise MissingDataError(model_rank_file)

        new_model_rank_file = path.join(tmp_parse_dir, model_name + '.tsv')
        shutil.copy(model_rank_file, new_model_rank_file)
        subprocess.call(shlex.split("sed -i -E 's/$/\t%s/g' %s" % (model_name, new_model_rank_file)))

    # Add the MODEL_NAME as the last value of the ranked list to all RANKED_LIST_FILE in every line with 'sed ...'
    input_args = [path.join(tmp_parse_dir, model + '.tsv')
                  for model in data_names]
    input_args += ['--num-models', len(data_names)]
    input_args += ['--model-names', ','.join(data_names)]
    input_args += ['--no-output']

    # Merging the model scores by ranked user-event with MAP-REDUCE (MRJob)
    mr_job = MRMergeRankedLists(args=input_args)
    with mr_job.make_runner() as runner:
        runner.run()
        with open(full_parsed_filepath, 'w') as parsed_file:
            parsed_csv = csv.writer(parsed_file)
            parsed_csv.writerow(["user_id", "event_id"] + data_names)
            for line in runner.stream_output():
                _, value = mr_job.parse_output_line(line)
                parsed_csv.writerow(value.split(","))

    # Remove the temporary directory
    shutil.rmtree(tmp_parse_dir)

    return full_parsed_filepath

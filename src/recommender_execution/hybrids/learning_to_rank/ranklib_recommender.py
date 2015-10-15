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
Run RankLib.jar
"""
import os
import csv
import heapq
import logging
import shutil
import subprocess, shlex
from collections import defaultdict

##############################################################################
# GLOBAL VARIABLES
##############################################################################
# Define the Logging
logging.basicConfig(format='%(asctime)s : %(levelname)s : %(name)s : %(message)s',
                    level=logging.INFO)
LOGGER = logging.getLogger('learning_to_rank.ranklib_recommender')
LOGGER.setLevel(logging.INFO)

MAX_RECS_PER_USER = 100

DICT_MODEL_ID = {
    "MART": 0,
    "RANK-NET": 1,
    # "RANK-BOOST": 2,
    "ADA-RANK": 3,
    "COORDINATE-ASCENT": 4,
    "LAMBDA-MART": 6,
    "LIST-NET": 7,
    # "RANDOM-FOREST": 8, # Bug found!
    "LINEAR-REG": 9
}

##############################################################################
# PRIVATE FUNCTIONS
##############################################################################
def _get_test_users(partition_dir):
    """ Read the Test Users TSV file """
    test_users_tsv_path = os.path.join(partition_dir, "users_test.tsv")
    with open(test_users_tsv_path, "r") as users_test_file:
        users_test_reader = csv.reader(users_test_file, delimiter="\t")
        return sorted(set([int(row[0]) for row in users_test_reader]))


def _parse_and_persist_user_ranked_list(scores_filepath, test_features_file,
                                        user_recs_filepath, partition_dir):
    """ Read the event indexes, read the user-event scores, sort and persist the recommendations """

    # Read the event indexes
    dict_userid_index_eventid = {}
    with open(test_features_file, "r") as features_file:
        index = 0
        last_user_id = None
        for row in features_file:
            row_data = row.split(" ")
            user_id, event_id = row_data[1].split(":")[1], row_data[-1]

            if last_user_id and last_user_id != user_id:
                # Update the index counter
                index = 0

            dict_userid_index_eventid.setdefault((int(user_id), int(index)), int(event_id))

            last_user_id = user_id
            index += 1

    # Read the user, event_indexes and scores
    dict_user_eventheap = defaultdict(list)
    with open(scores_filepath, "r") as scores_file:
        for row in scores_file:
            user_id, index, score = row.split("\t")
            user_id, index, score = int(user_id), int(index), float(score)
            event_id = dict_userid_index_eventid[(user_id, index)]

            heapq.heappush(dict_user_eventheap[user_id], (score, event_id))

    # Read the test users
    test_users = _get_test_users(partition_dir)

    # Persist the recommendations
    with open(user_recs_filepath, "w") as rec_out_file:
        for user in test_users:
            top_recs = []
            if user in dict_user_eventheap:
                top_recs = heapq.nlargest(MAX_RECS_PER_USER, dict_user_eventheap[user])
            rec_out_file.write("%d\t%s\n" % (user,
                                             ','.join(["%d:%.6f" % (event_id, score)
                                                       for score, event_id in top_recs])))

##############################################################################
# PUBLIC FUNCTIONS
##############################################################################

def _get_feature_column_ids(ensemble_list, selected_features):
    """ Get the ID of the Selected Features based on the Ensemble List (+ USER and EVENT count)"""
    feature_ids = []
    index = 0
    for feature in ensemble_list:
        index += 1
        if feature in selected_features:
            feature_ids.append(index)
    return feature_ids

def _get_extra_train_model_params(model_conf):
    """ GET the extra parameters to TRAIN certain models """
    extra_params = ""
    hyper_params = model_conf.hyper_params
    if model_conf.algorithm == "RANK-NET":
        extra_params = " -layer %s -node %s -lr %s -epoch %s " % (hyper_params['layer'],
                                                                  hyper_params['node'],
                                                                  hyper_params['learning_rate'],
                                                                  hyper_params['epoch'])
    elif model_conf.algorithm == "COORDINATE-ASCENT":
        regularization = ""
        if hyper_params['regularization']:
            regularization = "-reg %s" % hyper_params['regularization']
        extra_params = " -r %s -i %s -tolerance %s %s " % (hyper_params['restarts'],
                                                           hyper_params['iterations'],
                                                           hyper_params['tolerance'],
                                                           regularization)
    elif model_conf.algorithm == "MART":
        extra_params = " -tree %s -leaf %s -shrinkage %s " % (hyper_params['tree'],
                                                              hyper_params['leaves'],
                                                              hyper_params['shrinkage'])

    return extra_params


def train_and_predict(model_conf, full_ensemble_list, train_features_file, test_features_file,
                      hybrids_dir, partition_dir):
    """ TRAIN and PREDICT with Learning to Rank Algorithms """

    ranklib_jar_filepath = os.path.join("src", "recommender_execution", "hybrids", "learning_to_rank", "RankLib.jar")
    hybrids_tmp_dir = os.path.join(hybrids_dir, "tmp")

    if not os.path.exists(hybrids_tmp_dir):
        os.makedirs(hybrids_tmp_dir)

    # -------------------------------------------------------------------------
    # Generate features list
    # -------------------------------------------------------------------------
    LOGGER.info("Generate the features_list file based on the model_ranks")
    feature_list_filepath = os.path.join(hybrids_tmp_dir, "%s_features-list.txt" % model_conf.model_name)

    selected_features = model_conf.hyper_params['ensemble_list']
    with open(feature_list_filepath, "w") as feature_list_file:
        for feature_id in _get_feature_column_ids(full_ensemble_list, selected_features):
            feature_list_file.write("%d\n" % feature_id)

    # -------------------------------------------------------------------------
    # Train the model and persist it
    # -------------------------------------------------------------------------
    LOGGER.info("Train the model and persist it")

    model_filepath = os.path.join(hybrids_tmp_dir, "%s_model.txt" % model_conf.model_name)

    validation_features_file = train_features_file.replace("_train-", "_validation-")
    model_extra_atts = _get_extra_train_model_params(model_conf)
    subprocess.call(shlex.split("java -jar %s -train %s -validate %s -ranker %d -save %s -feature %s %s -silent -metric2t NDCG@10 -norm zscore" %
                                (ranklib_jar_filepath, train_features_file, validation_features_file,
                                 DICT_MODEL_ID[model_conf.algorithm], model_filepath, feature_list_filepath,
                                 model_extra_atts)))

    # -------------------------------------------------------------------------
    # Score the test features
    # -------------------------------------------------------------------------
    LOGGER.info("Score the test features")

    scores_filepath = os.path.join(hybrids_tmp_dir, "%s_scores.txt" % model_conf.model_name)

    subprocess.call(shlex.split("java -jar %s -load %s -rank %s -score %s -feature %s -norm zscore" %
                                (ranklib_jar_filepath, model_filepath, test_features_file,
                                 scores_filepath, feature_list_filepath)))

    # -------------------------------------------------------------------------
    # Parse the score file and generate the recomendations
    # -------------------------------------------------------------------------
    LOGGER.info("Parse the score file and generate the recomendations")

    user_rank_filepath = os.path.join(hybrids_dir, "%s.tsv" % model_conf.model_name)
    _parse_and_persist_user_ranked_list(scores_filepath, test_features_file, user_rank_filepath,
                                        partition_dir)

    # Remove the tmp dir
    # if os.path.exists(hybrids_tmp_dir):
    #     shutil.rmtree(hybrids_tmp_dir)

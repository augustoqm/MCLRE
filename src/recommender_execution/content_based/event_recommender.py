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
Train and Recommend Events to Users
"""
import logging
import csv

from os import path, makedirs

from model import EventContentModel
from user_profiles import UserProfileSum, UserProfileTimeWeighted, UserProfileInversePopularity

##############################################################################
# GLOBAL VARIABLES
##############################################################################
# Define the Logging
logging.basicConfig(format='%(asctime)s : %(levelname)s : %(name)s : %(message)s',
                    level=logging.INFO)
LOGGER = logging.getLogger('content_based.event_recommender')
LOGGER.setLevel(logging.INFO)

MAX_RECS_PER_USER = 100

##############################################################################
# PRIVATE FUNCTIONS
##############################################################################
def _get_set_test_users(partition_dir):
    """ Read the Test Users TSV file """
    test_users_tsv_path = path.join(partition_dir, "users_test.tsv")
    with open(test_users_tsv_path, "r") as users_test_file:
        users_test_reader = csv.reader(users_test_file, delimiter="\t")
        return set([row[0] for row in users_test_reader])

def _get_list_test_events(partition_dir):
    """ Read the Test Events TSV file """
    test_events_tsv_path = path.join(partition_dir, "event-candidates_test.tsv")
    with open(test_events_tsv_path, "r") as event_test_file:
        events_test_reader = csv.reader(event_test_file, delimiter="\t")
        return [row[0] for row in events_test_reader]

def _get_dict_user_events_train(partition_dir):
    """ Read the Train User-Event TSV file """
    train_user_events_tsv_path = path.join(partition_dir, "user-event-rsvptime_train.tsv")
    with open(train_user_events_tsv_path, "r") as user_event_train_file:
        user_event_train_reader = csv.reader(user_event_train_file, delimiter="\t")

        dict_user_event = {}
        for row in user_event_train_reader:
            user_id = row[0]
            event_id = row[1]
            rsvp_time = int(row[2])
            dict_user_event.setdefault(user_id, {'event_id_list': [], 'rsvp_time_list': []})
            dict_user_event[user_id]['event_id_list'].append(event_id)
            dict_user_event[user_id]['rsvp_time_list'].append(rsvp_time)
        return dict_user_event

def _get_dict_event_rsvp_count_train(partition_dir):
    """ Read the count_users_per_train-event_train.csv  """
    dict_event_count = {}
    count_rsvps_filename = path.join(partition_dir, "..", "count_users_per_test-event_train.tsv")
    with open(count_rsvps_filename, "r") as count_rsvps_file:
        count_rsvps_reader = csv.reader(count_rsvps_file, delimiter="\t")
        for row in count_rsvps_reader:
            dict_event_count.setdefault(row[0], int(row[1]))
    return dict_event_count

def _get_partition_time(partition_dir, partition_number):
    """ Read the Partition Times CSV File and extract the partition_time """
    partition_times_path = path.join(partition_dir, "..", "..", "..", "partition_times.csv")
    partition_time = None
    with open(partition_times_path, "r") as partition_times_file:
        partition_times_reader = csv.reader(partition_times_file)
        partition_times_reader.next()
        for row in partition_times_reader:
            if int(row[0]) == partition_number:
                partition_time = int(row[2])

    return partition_time

##############################################################################
# PUBLIC CLASSES
##############################################################################

class ContentBasedModelConf(object):

    def __init__(self, algorithm, hyper_parameters, params_name, pre_processment, input_data):
        self.algorithm = algorithm
        self.hyper_parameters = hyper_parameters
        self.params_name = params_name
        self.pre_processment = pre_processment
        self.input_data = input_data

class PostProcessConf(object):

    def __init__(self, name, params_name, types, params):
        self.name = name
        self.params_name = params_name
        self.types = types
        self.params = params

class UserProfileConf(object):

    def __init__(self, name, params, params_name):
        self.name = name
        self.params = params
        self.params_name = params_name


##############################################################################
# PUBLIC FUNCTIONS
##############################################################################

def cb_train(cb_model_conf, post_process_conf, partition_dir):
    """
    Function that trains and recommend events to all test users
    For that it uses an EventContentModel object
    """

    LOGGER.info("Creating Model [%s]", cb_model_conf.algorithm)
    event_cb_model = EventContentModel(cb_model_conf.pre_processment,
                                       cb_model_conf.algorithm,
                                       cb_model_conf.hyper_parameters,
                                       cb_model_conf.params_name)

    # Read the Corpus
    filename = path.join(partition_dir, "event-name-desc_all.tsv")
    LOGGER.info("Reading Corpus from [%s]", filename)
    dict_event_content = event_cb_model.read_and_pre_process_corpus(filename, cb_model_conf.input_data)

    # Post Process Corpus
    event_cb_model.post_process_corpus(post_process_types=post_process_conf.types,
                                       params=post_process_conf.params,
                                       dict_event_content=dict_event_content,
                                       content_columns=cb_model_conf.input_data)

    # Train the model
    LOGGER.info("Training the Model")
    event_cb_model.train_model()

    return event_cb_model, dict_event_content

def cb_recommend(event_cb_model, user_profile_conf, dict_event_content,
                 partition_dir, partition_number):
    """
    Recommend events to users
    Given a trained Content Based Model are generated N recommendations to the same User
    One recommendation for each user profile type (i.e. for each personalization approach)
    """

    LOGGER.info("Reading the Partition data (test users, test events and train user-event pairs)")
    test_users = _get_set_test_users(partition_dir)
    test_events = _get_list_test_events(partition_dir)
    dict_user_events_train = _get_dict_user_events_train(partition_dir)

    LOGGER.info("Reading extra data for User Profiles")
    dict_count_rsvps_events_train = _get_dict_event_rsvp_count_train(partition_dir)
    partition_time = _get_partition_time(partition_dir, partition_number)

    LOGGER.info("Creating the Index to submit the User Profile Queries")
    event_cb_model.index_events(test_events)

    LOGGER.info("Recommending the Test Events to Test Users")
    dict_user_rec_events = {}
    user_count = 0
    for user in test_users:
        # Log progress
        if user_count % 1000 == 0:
            LOGGER.info("PROGRESS: at user #%d", user_count)
        user_count += 1

        # Every user has at least an empty recommendation
        dict_user_rec_events.setdefault(user, [])

        # The user receives no recommendation if it doesn't have at least one event in train
        if user not in dict_user_events_train:
            continue

        # -------------------------------------------------------------------------
        # Call the Recommendation function based on the User Profile Type

        if user_profile_conf.name == 'SUM':
            # Create the User Profile
            user_profile = UserProfileSum(user_profile_conf.params, dict_user_events_train[user],
                                          event_cb_model, dict_event_content)
            # Submit the query passing the User Profile Representation
            dict_user_rec_events[user] = event_cb_model.query_model(user_profile.get(), test_events,
                                                                    dict_user_events_train[user]['event_id_list'],
                                                                    MAX_RECS_PER_USER)

        elif user_profile_conf.name == 'TIME':
            # Add the partition time to the user_event_train data
            dict_user_events_train[user]['partition_time'] = partition_time
            # Create the User Profile
            user_profile = UserProfileTimeWeighted(user_profile_conf.params, dict_user_events_train[user],
                                                   event_cb_model, dict_event_content)
            # Submit the query passing the User Profile Representation
            dict_user_rec_events[user] = event_cb_model.query_model(user_profile.get(), test_events,
                                                                    dict_user_events_train[user]['event_id_list'],
                                                                    MAX_RECS_PER_USER)

        elif user_profile_conf.name == 'INV-POPULARITY':
            # Add the rsvp_count_list to the train events
            dict_user_events_train[user]['rsvp_count_list'] = [dict_count_rsvps_events_train.get(event_id, 0)
                                                               for event_id in dict_user_events_train[user]['event_id_list']]
            # Create the User Profile
            user_profile = UserProfileInversePopularity(user_profile_conf.params, dict_user_events_train[user],
                                                        event_cb_model, dict_event_content)
            # Submit the query passing the User Profile Representation
            dict_user_rec_events[user] = event_cb_model.query_model(user_profile.get(), test_events,
                                                                    dict_user_events_train[user]['event_id_list'],
                                                                    MAX_RECS_PER_USER)

    return dict_user_rec_events

def persist_recommendations(dict_user_rec_events, model_name, result_dir):
    """
    Persist the recommendation results in the given 'result_dir' with the
    given TSV file named 'model_name'.tsv
    Each line has the following format:
    <user_id>\t<event_id1>:<similarity1>,<event_id2>:<similarity2>,...,<event_id100>:<similarity100>
    """
    LOGGER.info("Persisting the Recommendations")
    if not path.exists(result_dir):
        makedirs(result_dir)

    with open(path.join(result_dir, "%s.tsv" % model_name), "w") as rec_out_file:
        for user in dict_user_rec_events:
            rec_out_file.write("%s\t%s\n" % (user,
                                             ','.join(["%s:%.6f" % (rec['event_id'], rec['similarity'])
                                                       for rec in dict_user_rec_events[user]])))


##############################################################################
# MAIN
##############################################################################

if __name__ == "__main__":

    cb_model_conf = ContentBasedModelConf(algorithm='LSI',
                                          hyper_parameters={'num_topics': 3,
                                                            'num_corpus_passes' : 1,
                                                            'num_iterations': 20},
                                          params_name="name",
                                          pre_processment={"text": [],
                                                           # "word": ["strip_punctuations", "remove_stop_words"]},
                                                           "word": ["strip_punctuations"]},
                                          input_data=["name"])
    post_process_conf = PostProcessConf(name='NO',
                                        params_name="",
                                        types=[],
                                        params={})
    user_profile_conf = UserProfileConf(name="SUM",
                                        params={"daily_decay": 0.01},
                                        params_name="name")
    partition = 1
    region = "phoenix"
    partition_dir = "/home/augusto/git/masters-code-2014/event_recommendation/data/" \
                    "partitioned_data/%s/partition_%d/content_based_models" % (region, partition)
    result_dir = "/home/augusto/git/masters-code-2014/event_recommendation/data/" \
                    "experiments/content-based/%s/recommendations/partition_%d/content_based_models" % (region, partition)

    model_profile_name = "%s-%s:%s-%s:%s-%s_%s:%s:%s" % ("CB",
                                                         cb_model_conf.algorithm,
                                                         "PP",
                                                         post_process_conf.name,
                                                         "UP",
                                                         user_profile_conf.name,
                                                         cb_model_conf.params_name,
                                                         post_process_conf.params_name,
                                                         user_profile_conf.params_name)

    # Train
    event_cb_model, dict_event_content = cb_train(cb_model_conf, post_process_conf, partition_dir)
    # Get User Recs
    dict_user_rec_events = cb_recommend(event_cb_model, user_profile_conf,
                                        dict_event_content, partition_dir, partition)
    # Persist them
    persist_recommendations(dict_user_rec_events, model_profile_name, result_dir)

    # Save the dictionary for future corpus studies
    # event_cb_model.dictionary.save_as_text("/home/augusto/dictionary_%s_part-%d.tsv" % (region, partition))

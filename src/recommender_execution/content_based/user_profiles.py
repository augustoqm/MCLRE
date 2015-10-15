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
User Profile Functions
"""
import math
import logging

from abc import ABCMeta, abstractmethod

##############################################################################
# GLOBAL VARIABLES
##############################################################################
# Define the Logging
logging.basicConfig(format='%(asctime)s : %(levelname)s : %(name)s : %(message)s',
                    level=logging.INFO)
LOGGER = logging.getLogger('content_based.user_profiles')
LOGGER.setLevel(logging.INFO)

##############################################################################
# CLASSES
##############################################################################
class BaseUserProfile(object):
    """
    Base (Abstract) User Profile
    """
    __metaclass__ = ABCMeta

    @abstractmethod
    def __init__(self, profile_params, train_events_data, event_cb_model, dict_event_content):
        """ Constructor (Abstract Method) """
        self._representation = []

    def get(self):
        """Return the User Profile Representation"""
        return self._representation

    @classmethod
    def _transform_and_sum_event_bows(cls, event_bows, event_weights, event_cb_model):
        """
        Sum the Vector Representations
        """
        if len(event_bows) != len(event_weights):
            return []

        # Apply the weighting factor over the model representation
        dict_termid_weighttf = {}
        for i in range(len(event_bows)):
            bow = event_bows[i]
            weight = event_weights[i]

            # Do a (vector x scalar) multiplication
            for term_id, term_frequency in bow:
                dict_termid_weighttf.setdefault(term_id, 0)
                dict_termid_weighttf[term_id] += term_frequency * weight

        big_weighted_bow = [(term_id, dict_termid_weighttf[term_id])
                            for term_id in sorted(dict_termid_weighttf.keys())]

        # Apply the TFIDF Transformation over the Weighted Bows (if necessary)
        if event_cb_model.tfidf_model:
            # Return the MODEL[TFIDF[Big Bow]]
            return event_cb_model.model[event_cb_model.tfidf_model[big_weighted_bow]]
        else:
            # Return the MODEL[Big Bow]
            return event_cb_model.model[big_weighted_bow]


class UserProfileSum(BaseUserProfile):
    """
    User Profile formed by the Sum of the Vector Representations of all Past Events
    """

    def __init__(self, profile_params, train_events_data, event_cb_model, dict_event_content):

        # Select the event text based on the train_events_data
        train_event_bows = []
        for event_id in train_events_data['event_id_list']:
            train_event_bows.append(event_cb_model.corpus_of_bows[event_cb_model.dict_event_id_index[event_id]])

        # Sum all representations with EQUAL weights
        self._representation = self._transform_and_sum_event_bows(event_bows=train_event_bows,
                                                                  event_weights=[1] * len(train_event_bows),
                                                                  event_cb_model=event_cb_model)

class UserProfileTimeWeighted(BaseUserProfile):
    """
    User Profile formed by the Weighted Sum of:
        (Vector Representations) x (Weight based on the Time Distance from the RSVP to the Partition Time)
    """

    def __init__(self, profile_params, train_events_data, event_cb_model, dict_event_content):

        # Select the event text based on the train_events_data
        train_event_bows = []
        for event_id in train_events_data['event_id_list']:
            train_event_bows.append(event_cb_model.corpus_of_bows[event_cb_model.dict_event_id_index[event_id]])

        # Calculate the event weights based on the time value of each Yes RSVP
        event_weights = []
        for rsvp_time in train_events_data['rsvp_time_list']:
            days_from_rsvp = math.floor((train_events_data['partition_time'] - rsvp_time)/float(60 * 60 * 24)) # Day in Sec
            event_weights.append(self._time_value_of_money(money_value=1,
                                                           time_step_decay=profile_params['daily_decay'],
                                                           time_steps_in_the_future=days_from_rsvp))
        # Sum the representations with its respective weights
        self._representation = self._transform_and_sum_event_bows(event_bows=train_event_bows,
                                                                  event_weights=event_weights,
                                                                  event_cb_model=event_cb_model)

    @classmethod
    def _time_value_of_money(cls, money_value=1, time_step_decay=0, time_steps_in_the_future=0):
        """
        Calculate the Time Value of Money
        Concept (from http://moneyterms.co.uk/time-value-of-money/)
            "The time value of money is one of the fundamental concepts of financial theory.
            It is a very simple idea: a given amount of money now is worth more than the certainty
            of receiving the same amount of money at some time in the future."

        Based on:
            Thomas Sandholm and Hang Ung. 2011.
            Real-time, location-aware collaborative filtering of web content.
            In Proceedings of the 2011 Workshop on Context-awareness in Retrieval and Recommendation (CaRR '11)
        """
        return money_value/float((1 + time_step_decay)**time_steps_in_the_future)


class UserProfileInversePopularity(BaseUserProfile):
    """
    User Profile formed by the Weighted Sum of: (Event Vector Representations) x (1/log(|Event RSVPs| + 2, 2))
    The intuition behind it is that the event importance to the user is inversely proportional to the event size
    Based on the results of the Content-Based Recommender (a baseline model)
    in the paper "Item Cold-Start Recommendations: Learning Local Collective Embeddings" (RecSys 2014)
    """

    def __init__(self, profile_params, train_events_data, event_cb_model, dict_event_content):

        # Select the event text based on the train_events_data
        train_event_bows = []
        for event_id in train_events_data['event_id_list']:
            train_event_bows.append(event_cb_model.corpus_of_bows[event_cb_model.dict_event_id_index[event_id]])

        # Calculate the event weights based on the time value of each Yes RSVP
        event_weights = []
        for rsvp_count in train_events_data['rsvp_count_list']:
            # Inverse of the popularity
            event_weights.append(1 / math.log(rsvp_count + 2, 2))

        # Sum the representations with its respective weights
        self._representation = self._transform_and_sum_event_bows(event_bows=train_event_bows,
                                                                  event_weights=event_weights,
                                                                  event_cb_model=event_cb_model)

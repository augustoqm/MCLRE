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
Content-Based MODEL
"""
import re
import os
import logging
import unicodecsv
import unicodedata

from gensim import corpora, models, similarities
from nltk.corpus import stopwords
from nltk.stem.porter import PorterStemmer
from csv import QUOTE_NONNUMERIC
from string import punctuation, digits
from HTMLParser import HTMLParser

##############################################################################
# GLOBAL VARIABLES
##############################################################################
logging.basicConfig(format='%(asctime)s : %(levelname)s : %(name)s : %(message)s',
                    level=logging.INFO)
LOGGER = logging.getLogger('content_based.model')
LOGGER.setLevel(logging.INFO)

##############################################################################
# Private CLASSES and FUNCTIONS
##############################################################################
class _HTMLStripper(HTMLParser):
    "Remove tags and keeps HTML entities intact."
    def __init__(self):
        self.reset()
        self.fed = []

    def handle_starttag(self, tag, attrs):
        # We took the decision that all/any tag is a word-splitter and thus
        # is converted to spaces.
        self.fed.append(' ')

    def handle_data(self, d):
        self.fed.append(d)

    def handle_charref(self, number):
        self.fed.append('&#%s;' % number)

    def handle_entityref(self, name):
        self.fed.append('&%s;' % name)

    def get_data(self):
        return u''.join(self.fed)

##############################################################################
# Public CLASSES
##############################################################################

class EventContentModel(object):
    """
    Event Content Model
    """

    _ENGLISH_STOPWORDS = stopwords.words('english')
    _STEMMER = PorterStemmer()
    _REGEX_NO_DIGIT = re.compile('[%s]' % re.escape(digits))

    def __init__(self, pre_processment, algorithm, hyper_parameters, params_name):
        self.model_name = "%s_%s" % (algorithm, params_name)
        self.pre_processment = pre_processment
        self.algorithm = algorithm
        self.hyper_parameters = hyper_parameters

        self.dict_index_event_id = {} # Index in the Corpus of BOWs!
        self.dict_event_id_index = {}
        self.dictionary = corpora.Dictionary()
        self.corpus_of_bows = []
        self.model = None
        self.tfidf_model = None
        self.corpus_query_index = None

    def extract_content(self, event_data, columns):
        """
        Extract the Content from event_data given the columns
        Text and Word pre-processment, basically.
        """
        def strip_html_and_convert_entities(html):
            """ Remove HTML tags and Convert Entities to Text """
            # http://stackoverflow.com/questions/753052/strip-html-from-strings-in-python
            # http://stackoverflow.com/questions/2087370/decode-html-entities-in-python-string
            parser = _HTMLStripper()
            parser.feed(html)
            # HTML parser breaks if parsing ends/EOF on a single-letter broken entities
            # such as 'at&t'. Adding an extra space fixes this.
            parser.feed(' ')
            parser.close()
            return parser.unescape(parser.get_data())

        def normalize_diacritics(text):
            """ Remove Accents and other Diacritics """
            # References:
            # http://stackoverflow.com/questions/517923/what-is-the-best-way-to-remove-accents-in-a-python-unicode-string
            # http://stackoverflow.com/questions/9042515/normalizing-unicode-text-to-filenames-etc-in-python
            nkfd_form = unicodedata.normalize('NFKD', unicode(text))
            return u"".join([c for c in nkfd_form if not unicodedata.combining(c)])

        def normalize_to_plain_ascii(text):
            """ Normalize to Plain ASCII """
            only_ascii = text.encode('ASCII', 'replace')  # unencodable chars become '?'
            return unicode(only_ascii)

        def replace_number_space(text):
            """ Replace numbers with spaces """
            return EventContentModel._REGEX_NO_DIGIT.sub(' ', text)

        def strip_punctuations(word):
            """ Strip leading and trailing punctuations """
            return word.strip(punctuation)

        def stem_word(word):
            """ Return a word stemmed """
            return EventContentModel._STEMMER.stem(word)

        def remove_stop_word(word):
            """ Filter the words in the English Stop Words List """
            if word not in EventContentModel._ENGLISH_STOPWORDS:
                return word
            else:
                return ''

        dict_pre_process = {'text': {'replace_numbers_with_spaces': replace_number_space},
                            'word': {'get_stemmed_words': stem_word,
                                     'remove_stop_words': remove_stop_word,
                                     'strip_punctuations': strip_punctuations}}
        word_list = []
        # Pre-Process Texts
        for col in columns:
            text = event_data[col]

            # Normalize the Text String (HTML + DIACRITICS + ASCII)
            text = strip_html_and_convert_entities(text)
            text = normalize_diacritics(text)
            text = normalize_to_plain_ascii(text)

            for text_process in self.pre_processment.get('text', []):
                text = dict_pre_process['text'][text_process](text)

            word_list.extend(text.split())

        # Pre-Process Words
        final_words = []
        for word in word_list:
            # All words are lowered!
            word = word.lower()
            for word_process in self.pre_processment.get('word', []):
                word = dict_pre_process['word'][word_process](word)
            # We assume that words with less than 1 character have no meaning.
            if len(word) > 1:
                final_words.append(word)

        return final_words

    def read_and_pre_process_corpus(self, filename, content_columns, no_below_freq=0):
        """
        Read the corpus
        """
        with open(filename, "r") as csv_file:
            csv_reader = unicodecsv.reader(csv_file, encoding="utf-8",
                                           delimiter='\t', escapechar='\\',
                                           quoting=QUOTE_NONNUMERIC)
            doc_index = 0
            dict_event_content = {}
            for row in csv_reader:
                event_id = str(int(row[0]))
                self.dict_index_event_id[doc_index] = event_id
                self.dict_event_id_index[event_id] = doc_index

                dict_event_content[event_id] = {'name': row[1], 'description': row[2]}

                # Extract the Words from the Event Description
                event_words = self.extract_content(dict_event_content[event_id], content_columns)

                # Update the dictionary
                self.dictionary.doc2bow(event_words, allow_update=True)

                doc_index += 1

        return dict_event_content

    def post_process_corpus(self, post_process_types, params, dict_event_content, content_columns):
        """
        Apply the Corpus Post Processments
        Why? This step requires the dictionary be already generated
        """

        # Filter extremes words from dictionary (based on the Corpus Document Frequecy)
        if "filter_extreme_words" in post_process_types:
            print params['no_below_freq']
            self.dictionary.filter_extremes(no_below=params['no_below_freq'])

        # Generate the corpus of bows
        for doc_index in sorted(self.dict_index_event_id.keys()):
            event_id = self.dict_index_event_id[doc_index]

            # Extract the Words from the Event Description
            event_words = self.extract_content(dict_event_content[event_id], content_columns)

            # Create the Event Bows
            event_bow = self.dictionary.doc2bow(event_words, allow_update=False)

            # Store the BOW in memory
            self.corpus_of_bows.append(event_bow)


        # Apply TFIDF Transformation (or NOT) in the corpus (LSI only)
        if self.algorithm == "LSI":
            LOGGER.info("Applying the TFIDF Transformation in the corpus (LSI only)")
            self.tfidf_model = models.TfidfModel(self.corpus_of_bows, normalize=True)


    def train_model(self):
        """
        Train the model and create the corpus query index
        """
        # Applying the TFIDF Transformation (if necessary)
        if self.tfidf_model:
            transformed_corpus = self.tfidf_model[self.corpus_of_bows]
        else:
            transformed_corpus = self.corpus_of_bows

        if self.algorithm == "TFIDF":
            LOGGER.info("Creating the TFIDF Transformation")
            self.model = models.TfidfModel(transformed_corpus, normalize=True)

        elif self.algorithm == "LSI":
            LOGGER.info("Creating the LSI Transformation")

            # More information about the hyper parameter selection read the source code below:
            # https://github.com/piskvorky/gensim/blob/develop/gensim/models/lsimodel.py
            self.model = models.LsiModel(transformed_corpus,                                    # Chaining: LSI (TFIDF or NOT (BOW))
                                         num_topics=self.hyper_parameters['num_topics'],
                                         id2word=self.dictionary,
                                         chunksize=20000,                                       # BIGGER = higher speed | SMALLER = lower memory footprint (default)
                                         decay=1.0,                                             # Decay to old documents, less than 1.0 it gives less emphasis to old observations (default)
                                         distributed=False,                                     # Single machine is enough (default)
                                         onepass=True,                                          # One pass over data = faster (default)
                                         power_iters=5,                                         # More Power Iterations to improve accuracy
                                         extra_samples=None)                                    # None, so it will be dinamically defined (i.e. 2 * num_topics)

        elif self.algorithm == "LDA":
            LOGGER.info("Creating the LDA Transformation")
            # More information about the hyper parameter selection read the souce code below:
            # https://github.com/piskvorky/gensim/blob/develop/gensim/models/ldamodel.py
            self.model = models.LdaModel(transformed_corpus,                                    # Chaining: LDA (TFIDF or NOT(BOW))
                                         num_topics=self.hyper_parameters['num_topics'],
                                         id2word=self.dictionary,
                                         distributed=False,                                     # Single machine is enough (default: False)
                                         chunksize=2000,                                        # Number of documents per inference cicle (default: 2000)
                                         passes=self.hyper_parameters['num_corpus_passes'],     # Passes over the Full Corpus, increased to improve accuracy (default: 1)
                                         update_every=1,                                        # Update the model every 1 document chunk (default: 1)
                                         alpha='auto',                                          # Defines the gamma priors of the Dirichlet distributions
                                                                                                #   Auto: learns asymmetric priors directly from the corpus data in every update
                                                                                                #       This improves the model convergence
                                                                                                #       Uses Newton's method, described in
                                                                                                #       Huang: Maximum Likelihood Estimation of Dirichlet Distribution Parameters.
                                                                                                #       (http://www.stanford.edu/~jhuang11/research/dirichlet/dirichlet.pdf)
                                         eta=None,                                              # Defines the eta priors of the Dirichlet distributions
                                                                                                #   The default (None) sets a symmetric prior (1.0/num_topics) over the topic/word distribution
                                         decay=0.5,                                             # Decay to old documents,
                                                                                                #   decay=0.0 the new documents replace completely the old documents in every update
                                                                                                #   decay=1.0 the new documents decrease its importance exponentially in every update
                                                                                                #   (Hoffman et al. updates guarantees convergence in interval[0.5, 1)) (default: 0.5)
                                         eval_every=10,                                         # Evaluate the Perplexity of the Model every N updates (default: 10)
                                         iterations=self.hyper_parameters['num_iterations'],    # Number of Inference iterations over each chunk of documents (default: 50)
                                         gamma_threshold=0.00001)                               # Convergence Threshold, diff between two subsequent gamma values.
                                                                                                #   Decreased to force all iterations (default: 0.001)


    def index_events(self, event_id_list=None):
        """
        Index the Events based on its indexes
        """

        # Event selection by Id (if provided)
        if event_id_list:
            event_corpus = [self.corpus_of_bows[self.dict_event_id_index[event_id]]
                            for event_id in event_id_list]
        else:
            event_corpus = self.corpus_of_bows

        # Applying the TFIDF Transformation (if necessary)
        if self.tfidf_model:
            transformed_corpus = self.model[self.tfidf_model[event_corpus]]
        else:
            transformed_corpus = self.model[event_corpus]

        # Create the index of the transformed_corpus to submit queries
        # We use the SparseMatrixSimilarity that uses a sparse data structure instead of a dense one
        # That's why we have to provide the num_features parameter
        self.corpus_query_index = similarities.SparseMatrixSimilarity(transformed_corpus,
                                                                      num_features=len(self.dictionary))


    def query_model(self, query_model_format, candidate_event_ids, ignore_event_ids, query_limit=None):
        """
        Query the model given the query representation already in the model format
        """
        # Perform the query against the hole corpus using the index
        query_similarities = self.corpus_query_index[query_model_format]

        # enumerate(query_similarities) => 2-tuples: (document_number, document_similarity)
        index_similarities = sorted(enumerate(query_similarities),
                                    key=lambda item: -item[1])

        if not query_limit:
            query_limit = len(index_similarities)

        query_result = []
        ignore_event_ids = set(ignore_event_ids)
        for index, similarity in index_similarities:
            rec_event_id = candidate_event_ids[index]
            # Exclude the events in the ignore set (i.e. events already consumed in the train)
            if not rec_event_id in ignore_event_ids:
                if query_limit > 0:
                    query_result.append({'event_id': rec_event_id,
                                         'similarity': similarity})
                    query_limit -= 1
                else:
                    break

        return query_result

    def save_model(self, output_dir):
        """
        Save the Model in the specified output_dir, with the format: <self.model_name>.model
        """
        model_filename = "%s.model" % self.model_name
        model_filepath = os.path.join(output_dir, model_filename)

        if self.model:
            self.model.save(model_filepath)

    def load_model(self, input_dir):
        """
        Load the Model in the specified input_dir, with the format: <self.model_name>.model
        """
        model_filename = "%s.model" % self.model_name
        model_filepath = os.path.join(input_dir, model_filename)
        if os.path.exists(model_filepath):
            if self.algorithm == "TFIDF":
                self.model = models.TfidfModel.load(model_filepath)
            elif self.algorithm == "LSI":
                self.model = models.LsiModel.load(model_filepath)
            elif self.algorithm == "LDA":
                self.model = models.LdaModel.load(model_filepath)
            else:
                return False
        else:
            return False
        return True


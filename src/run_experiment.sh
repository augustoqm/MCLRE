#!/bin/bash

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


echo "0) DATABASE TABLES are CREATED and LOADED"
# SEE: src/db_scripts/create_tables.sql
# SEE: src/db_scripts/load_tables.sql

echo "1) DATASET PARTITION"
Rscript src/data_partition/partition_main.R

# EXPERIMENT NAME
if [ -z "$1" ]
  then
    echo "No argument supplied. Usage: bash src/run_experiment.sh <EXPERIMENT_NAME>"
    exit 1
  else
    EXPERIMENT_NAME=$1
    echo "================== EXPERIMENT : $EXPERIMENT_NAME =================="
fi

# EXPERIMENT DIRECTORY and EXPERIMENT_ATTS definition
EXPERIMENT_ATTS="data/experiments/$EXPERIMENT_NAME/experiment_atts.csv"

if [ ! -e $EXPERIMENT_ATTS ]
  then
    echo "Please create experiment_atts.csv before running the experiment"
    exit 1
fi

# RUN THE EXPERIMENT PER REGION
declare -a REGIONS=("san_jose" "phoenix" "chicago")

for region in ${REGIONS[*]}
do
  echo "========================= $region ========================="

  echo  "2) MODEL TRAINING and RANKED PREDICTION"
  # Baseline: BPR-NET Algorithm
  python src/recommender_execution/run_rec_mrbpr.py -e $EXPERIMENT_NAME -r $region -a 'BPR-NET'

  # MRBPR Algorithm
  python src/recommender_execution/run_rec_mrbpr.py -e $EXPERIMENT_NAME -r $region -a 'MRBPR'

  # Content-Based Algorithms
  python src/recommender_execution/run_rec_content_based.py -e $EXPERIMENT_NAME -r $region -a 'TFIDF'

  # Heuristic Based Algorithms
  python src/recommender_execution/run_rec_heuristics.py -e $EXPERIMENT_NAME -r $region -a 'LOC-GEO-PROFILE'
  python src/recommender_execution/run_rec_heuristics.py -e $EXPERIMENT_NAME -r $region -a 'USER-KNN-TIME'
  python src/recommender_execution/run_rec_heuristics.py -e $EXPERIMENT_NAME -r $region -a 'GROUP-RSVPS'


  # My Media Algorithms
  python src/recommender_execution/run_rec_my_media.py $EXPERIMENT_NAME $region 'MOST-POPULAR'

  echo "3) EXTRACT THE RELEVANT RANKS (FOR HYBRIDS)"
  # python src/recommender_execution/ranked_list_generation.py $EXPERIMENT_NAME $region

  # # Hybrid Algorithms
  python src/recommender_execution/run_rec_hybrids.py -e $EXPERIMENT_NAME -r $region -a 'COORDINATE-ASCENT' -p 1
  wait

  echo "3) EXTRACT THE RELEVANT RANKS"
  python src/recommender_execution/ranked_list_generation.py $EXPERIMENT_NAME $region

  echo "4) MODEL EVALUATION"
  Rscript src/recommender_evaluation/ranked_list_evaluation.R $EXPERIMENT_NAME $region
done

echo "DONE =D"

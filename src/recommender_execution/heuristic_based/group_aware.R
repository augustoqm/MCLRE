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

rm(list=ls())

################################################################################
# SOURCE and LIBRARIES
################################################################################
source("src/common.R")

################################################################################
# FUNCTIONS
################################################################################

GroupRSVPsScore <- function(user.events.data){
    group.score <- count(user.events.data, "group_id")
    group.score$score <- group.score$freq / sum(group.score$freq)
    group.score$freq <- NULL
    group.score
}

GroupRSVPsRecommender <- function(user.events.data, event.cand.test){
  # -----------------------------------------------------------------------------
  # Group RSVPs
  # Prediction: Weight the events in terms of the number of past Yes RSVPs in its group, then order by event_time

  # -----------------------------------------------------------------------------
  # Calculate the Group Weight in Train based on the RSVPs in that group
  group.score.train <- GroupRSVPsScore(user.events.data)

  # Remove the Candidate already consumed by the user
  event.cand.test <- subset(event.cand.test, ! event_id %in% unique(user.events.data$event_id))

  # Weight the Candidate Events
  event.cand.test <- merge(event.cand.test, group.score.train, by="group_id")

  # Remove events with NA scores (the heuristic doesn't know how to score it)
#   event.cand.test <- subset(event.cand.test, ! is.na(event.cand.test$score))

  # Sort the Candidate Events by Score
  event.cand.test <- event.cand.test[order(event.cand.test$score, -event.cand.test$event_time,
                                           decreasing=T, na.last=T),]

  # Get the first values only
  event.cand.test <- head(event.cand.test, n=max.ranked.list.size)

  result <- data.frame(ranked_events=paste(event.cand.test$event_id,
                                           round(event.cand.test$score, 6),
                                           sep=":", collapse=","))

  result
}


################################################################################
# MAIN
################################################################################
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3){
  stop(paste("Argument Error. Usage: Rscript src/recommender_execution/heuristic_based/time_aware.R",
             "<DB_PARTITION_DIR> <REC_RESULT_DIR> <MODEL_NAME>"))
}
db.partition.dir <- args[1]
rec.result.dir <- args[2]
model.name <- args[3]
# db.partition.dir <- "data/partitioned_data/chicago/partition_1/heuristic_models"
# rec.result.dir <- "data/experiments/hybrids-experiment/chicago/recommendations/partition_1/heuristic_models"
# model.name <- "GROUP-RSVPS"

max.ranked.list.size <- 100

# -----------------------------------------------------------------------------
# Reading data
# -----------------------------------------------------------------------------
# TRAIN
user.event.train <- read.table(paste0(db.partition.dir, "/user-event_train.tsv"), sep="\t")
colnames(user.event.train) <- c("user_id", "event_id", "mtime")
user.event.train <- user.event.train[,c("user_id", "event_id")]

event.features <- read.table(paste0(db.partition.dir, "/event-features_all.tsv"), sep="\t")
colnames(event.features) <- c("event_id", "event_created", "event_time", "event_hour", "event_day_of_week", "group_id")
event.features <- event.features[,c("event_id", "event_time", "group_id")]

# TEST
users.test <- read.table(paste0(db.partition.dir, "/users_test.tsv"), sep="\t")
colnames(users.test) <- c("user_id")

event.candidates.test <- read.table(paste0(db.partition.dir, "/event-candidates_test.tsv"), sep="\t")
colnames(event.candidates.test) <- c("event_id")

# -----------------------------------------------------------------------------
# Pre-Processing data
# -----------------------------------------------------------------------------
# Merging the RSVPs with the EVENT Features
user.event.train <- merge(user.event.train, event.features, by="event_id")

# Merging the CANDIDATES EVENTs with the EVENT Features
event.candidates.test <- merge(event.candidates.test, event.features, by="event_id")

# Filtering out the users that are not in test set
user.event.train <- subset(user.event.train, user_id %in% users.test$user_id)

# Selecting the Users without Train
users.without.train <- users.test$user_id[! users.test$user_id %in% unique(user.event.train$user_id)]

# -----------------------------------------------------------------------------
# Running recommenders
# -----------------------------------------------------------------------------
switch(model.name,
       "GROUP-RSVPS"={
         user.ranked.list <- ddply(user.event.train, .(user_id), GroupRSVPsRecommender, event.candidates.test,
                                   .progress="text", .parallel=F)
       }
)

# Bind Empty Recs to the Users without Train data
user.ranked.list <- rbind(user.ranked.list, data.frame(user_id=users.without.train,
                                                       ranked_events=rep("", length(users.without.train))))
user.ranked.list <- user.ranked.list[order(user.ranked.list$user_id),]

# -----------------------------------------------------------------------------
# Persisting result
# -----------------------------------------------------------------------------
dir.create(rec.result.dir, recursive=T, showWarnings=F)
write.table(user.ranked.list, paste0(rec.result.dir, "/", model.name, ".tsv"),
            row.names=F, col.names=F, sep="\t", quote=F)

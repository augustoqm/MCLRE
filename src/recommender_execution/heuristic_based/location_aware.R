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
LoadMe("KernSmooth")
LoadMe("fields")
LoadMe("geosphere")

################################################################################
# FUNCTIONS
################################################################################
DistanceLonLat <- function(lon.lat1, lon.lat2){
  # Argument Example:
  # lon.lat1 = c(-121.83000183105469, 37.33000183105469)
  # lon.lat2 = matrix(c(-121.855115, 37.281473,
  #                     -121.985104, 37.216458,
  #                     -121.939613, 37.287079), ncol=2, byrow=T)

  distances <- distMeeus(lon.lat1, lon.lat2)

  # Treat the NA values generated when lon.lat1 is equal to lon.lat2
  this.lon <- as.numeric(lon.lat1[1])
  this.lat <- as.numeric(lon.lat1[2])
  distances[is.na(distances) & (lon.lat2$longitude == this.lon) & (lon.lat2$latitude == this.lat)] <- 0

  # Output in Kilometers
  distances/1000
}

Distance <- function(user, event){
  log(DistanceLonLat(as.vector(user[,2:3]), event[,2:3]) + 2, base=2)
}

Proximity <- function(user, event){
  1/Distance(user, event)
}

GeoProfileRecommender <- function(user, event.cand.test, h){

  # User-Events in Train
  events.train <- subset(user.event.train, user_id == user$user_id, c(event_id, longitude, latitude))

  if (nrow(events.train) > 0){
    # -----------------------------------------------------------------------
    # Users with train data receive PERSONALIZED GEOGRAPHIC recommendations
    # -----------------------------------------------------------------------

    # Remove the candidate events that were already consumed
    event.cand.test <- subset(event.cand.test, !event_id %in% unique(events.train$event_id))
    # Estimate a Gaussian Kernel for each X,Y then sum them up
    est.kernel <- bkde2D(events.train[,2:3], bandwidth=c(h, h), gridsize = c(128,128))
    # DEBUG: Plotting!
    # contour(est.kernel$x1, est.kernel$x2, est.kernel$fhat, xlab="Longitude", ylab="Latitude",
    #         main=paste0("User ", user$user_id[1]))

    # SCORE = Weight in the Distribution
    event.cand.test$score <- interp.surface(list(x=est.kernel$x1, y=est.kernel$x2, z=est.kernel$fhat),
                                            event.cand.test[,2:3])

    # Normalize the score (min-max normalization)
    min.estimation <- min(est.kernel$fhat)
    max.estimation <- max(est.kernel$fhat)
    event.cand.test$score <- (event.cand.test$score - min.estimation)/(max.estimation - min.estimation)

  } else{
    if (!is.na(user$longitude) & !is.na(user$latitude)){
      # -----------------------------------------------------------------------
      # Users without train data BUT with location receive NEAREST recommendations
      # -----------------------------------------------------------------------
      # SCORE = PROXIMITY
      event.cand.test$score <- Proximity(user, event.cand.test)
    }else{
      # -----------------------------------------------------------------------
      # Users without location DO NOT receive recommendation
      # -----------------------------------------------------------------------
      result <- data.frame(ranked_events="")

      return (result)
    }
  }

  # Remove events with NA scores (the heuristic doesn't know how to score it)
  event.cand.test <- subset(event.cand.test, ! is.na(event.cand.test$score))

  # Sort the Candidate Events by SCORE then by EVENT_TIME
  event.cand.test <- event.cand.test[order(event.cand.test$score, -event.cand.test$event_time,
                                           decreasing=T),]

  # Get the first values only
  event.cand.test <- head(event.cand.test, n=max.ranked.list.size)

  result <- data.frame(ranked_events=paste(event.cand.test$event_id,
                                           round(event.cand.test$score, 6),
                                           sep=":", collapse=","))
  result
}


NearestRecommender <- function(user, event.cand.test){
  if (!is.na(user$longitude) & !is.na(user$latitude)){

    # SCORE = PROXIMITY
    event.cand.test$score <- Proximity(user, event.cand.test)

    # Remove events with NA scores (the heuristic doesn't know how to score it)
    event.cand.test <- subset(event.cand.test, ! is.na(event.cand.test$score))

    # Sort the Candidate Events by SCORE then by EVENT_TIME
    event.cand.test <- event.cand.test[order(event.cand.test$score, -event.cand.test$event_time,
                                             decreasing=T),]

    # Get the first values only
    event.cand.test <- head(event.cand.test, n=max.ranked.list.size)

    result <- data.frame(ranked_events=paste(event.cand.test$event_id,
                                             round(event.cand.test$score, 6),
                                             sep=":", collapse=","))

  }else{
    # -----------------------------------------------------------------------
    # Users without location DO NOT receive recommendation
    # -----------------------------------------------------------------------
    result <- data.frame(ranked_events="")
  }
  result
}


################################################################################
# MAIN
################################################################################
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3){
  stop(paste("Argument Error. Usage: Rscript src/recommender_execution/heuristic_based/location_aware.R",
             "<DB_PARTITION_DIR> <REC_RESULT_DIR> <MODEL_NAME>"))
}
db.partition.dir <- args[1]
rec.result.dir <- args[2]
model.name <- args[3]
algorithm <- strsplit(model.name, "_")[[1]][1]

max.ranked.list.size <- 100
# -----------------------------------------------------------------------------
# Reading data
# -----------------------------------------------------------------------------
# TRAIN
user.event.train <- read.table(paste0(db.partition.dir, "/user-event_train.tsv"), sep="\t")
colnames(user.event.train) <- c("user_id", "event_id", "mtime")
user.event.train <- user.event.train[,c("user_id", "event_id")]

user.lon.lat <- read.table(paste0(db.partition.dir, "/user-long-lat_all.tsv"), sep="\t")
colnames(user.lon.lat) <- c("user_id", "longitude", "latitude")

event.lon.lat <- read.table(paste0(db.partition.dir, "/event-long-lat_all.tsv"), sep="\t")
colnames(event.lon.lat) <- c("event_id", "longitude", "latitude")

event.features <- read.table(paste0(db.partition.dir, "/event-features_all.tsv"), sep="\t")
colnames(event.features) <- c("event_id", "event_created", "event_time", "event_hour", "event_day_of_week", "group_id")
event.features <- event.features[,c("event_id", "event_time")]

# TRAIN
users.test <- read.table(paste0(db.partition.dir, "/users_test.tsv"), sep="\t")
colnames(users.test) <- c("user_id")

event.candidates.test <- read.table(paste0(db.partition.dir, "/event-candidates_test.tsv"), sep="\t")
colnames(event.candidates.test) <- c("event_id")

# -----------------------------------------------------------------------------
# Processing data
# -----------------------------------------------------------------------------
# Merging the User-Event-RSVP_Train with the Event-Lon-Lat (events without longitude and latitude receive NA values)
user.event.train <- merge(user.event.train, event.lon.lat, by="event_id", all.x=T)

# Remove the User-Events without location
user.event.train <- subset(user.event.train, !is.na(longitude) & !is.na(latitude))

# Merging the Event-Candidates_Test with the Event-Lon-Lat (events without longitude and latitude receive NA values)
event.candidates.test <- merge(event.candidates.test, event.lon.lat, by="event_id", all.x=T)

# Add the event_time to solve the TIES of the score function
event.candidates.test <- merge(event.candidates.test, event.features, by="event_id", all.x=T)

# Merging the Users_Test with the User-Lon-Lat (users without longitude and latitude receive NA values)
users.test <- merge(users.test, user.lon.lat, by="user_id", all.x=T)

# Filtering out the events without location data (longitude AND latitude)
event.candidates.test <- subset(event.candidates.test,
                                ! is.na(event.candidates.test$longitude) & ! is.na(event.candidates.test$latitude))

# -----------------------------------------------------------------------------
# Running Recommenders
# -----------------------------------------------------------------------------
switch (algorithm,
          "LOC-GEO-PROFILE"={
            h <- as.numeric(strsplit(model.name, "_")[[1]][2])
            user.ranked.list <- ddply(users.test, .(user_id), GeoProfileRecommender, event.candidates.test, h, .progress="text", .parallel=F)
          })

# -----------------------------------------------------------------------------
# Persisting result
# -----------------------------------------------------------------------------
dir.create(rec.result.dir, recursive=T, showWarnings=F)
write.table(user.ranked.list, paste0(rec.result.dir, "/", model.name, ".tsv"),
            row.names=F, col.names=F, sep="\t", quote=F)

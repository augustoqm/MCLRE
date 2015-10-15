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

################################################################################
# This scripts create timed partitions from the meetup_db data
#
# Its main arguments are:
# * The REGION from where the event groups are (e.g. SAN JOSE, DALLAS)
# * The NUMBER Of PARTITIONS
################################################################################
rm(list = ls())

# ==============================================================================
# LIBRARY() and SOURCE()
# ==============================================================================
source("src/common.R")
source("src/data_partition/db_queries.R")
source("src/data_partition/partition_functions.R")
source("src/data_partition/partition_functions_mrbpr.R")

# ==============================================================================
# MAIN
# ==============================================================================
cat("================= DATA PARTITIONING =================\n")

# DEFINE THE REGIONs
regions <- c("CHICAGO", "PHOENIX", "SAN JOSE")

# MIN PARTITION TIME: 2010-01-01 (Jan/2010)
min.partition.time <- RunQuery(QUERIES['timestamp_to_epoch'], '2010-01-01 00:00:00')[1,1]

# FINAL: last RSVP mtime
max.rsvp.time <- RunQuery(QUERIES['max_rsvp_mtime'])[1,1] - 1
partition.num <- 12

# TRAIN data interval size in seconds (6 months, or half a year)
train.time.interval <- ((364/2) * 24 * 60 * 60)

# partition.times in seconds
# This way the max.rsvp.time will never be a partition.time (if it were there will be no test data)
partition.times <- sort(max.rsvp.time - as.integer((max.rsvp.time - min.partition.time)/(partition.num+1) * 1:partition.num))
initial.times <- partition.times - train.time.interval

# Define the Experiment dir
partitioned.data.dir <- "data/partitioned_data"
dir.create(partitioned.data.dir, recursive=T, showWarnings=F)

# Persisting the Partition Date and Time
cat("Persist the Partition Times...\n")

partitions.df <- NULL
for (i in 1:length(partition.times)){
  part.time <- partition.times[i]
  date.time <- RunQuery(QUERIES['epoch_to_timestamp'], part.time)[1,1]
  partitions.df <- rbind(partitions.df, data.frame(partition=i,
                                                   time=date.time,
                                                   time_epoch=part.time))
}
write.csv(partitions.df, paste(partitioned.data.dir, "/partition_times.csv", sep=""),
          row.names=F)

cat("\n")
for (i in 1:length(partition.times)){
  event.ids <- NULL
  user.ids <- NULL

  initial.time <- initial.times[i]
  part.time <- partition.times[i]
  cat("====== Partition ", i, "======\n")

  for (this.region in regions){
    cat(" ", this.region, "\n")

    region.dbdata.dir <- paste0(partitioned.data.dir, "/",
                                gsub(" ", "_", tolower(this.region)))
    partition.dir <- paste(region.dbdata.dir, "/partition_", i, sep="")
    dir.create(partition.dir, recursive=T, showWarnings=F)

    # BASIC DATA
    cat("    Test data...\n")
    query <- gsub("@SQL_QUERY_NAME", "test_rsvps", QUERIES[['partition_data']])
    data.test <- RunQuery(query, c(initial.time, part.time, this.region))

    query <- gsub("@SQL_QUERY_NAME", "test_event_candidates", QUERIES[['partition_data']])
    data.event.candidates.test <- RunQuery(query, c(initial.time, part.time, this.region))

    cat("      Persisting...\n")
    write.csv(data.test, paste(partition.dir, "/user-event-rsvp_test.csv", sep=""), row.names=F)
    write.csv(data.event.candidates.test, paste(partition.dir, "/event-candidates_test.csv", sep=""), row.names=F)


    cat("    Basic Train data - All RSVPs...\n")
    query <- gsub("@SQL_QUERY_NAME", "train_rsvps_between", QUERIES[['partition_data']])
    all.rsvps.train <- RunQuery(query, c(initial.time, part.time, this.region))

    cat("    Defining Mapping: new user/event/group ids...\n")
    old.event.ids <- sort(unique(as.character(c(all.rsvps.train$event_id, data.test$event_id,
                                                data.event.candidates.test$event_id))))
    event.ids <- data.frame(event_id = old.event.ids,
                            new_event_id = 1:length(old.event.ids))

    old.user.ids <- sort(unique(as.numeric(c(all.rsvps.train$user_id, data.test$user_id))))
    user.ids <- data.frame(user_id = old.user.ids,
                           new_user_id = 1:length(old.user.ids))

    query <- gsub("@SQL_QUERY_NAME", "all_groups", QUERIES[['partition_data']])
    all.groups <- RunQuery(query, c(initial.time, part.time, this.region))

    old.group.ids <- sort(unique(all.groups$group_id))
    group.ids <- data.frame(group_id = old.group.ids,
                            new_group_id = 1:length(old.group.ids))

    cat("      Persisting...\n")
    write.csv(user.ids, paste(partition.dir, "/map_user_ids.csv", sep=""), row.names=F)
    write.csv(event.ids, paste(partition.dir, "/map_event_ids.csv", sep=""), row.names=F)
    write.csv(group.ids, paste(partition.dir, "/map_group_ids.csv", sep=""), row.names=F)


    cat("    Mapping Test Data...\n")
    data.test.mapped <- merge(data.test, user.ids, by="user_id")
    data.test.mapped <- merge(data.test.mapped, event.ids, by="event_id")
    data.test.mapped <- data.test.mapped[,c("new_user_id", "new_event_id")]

    users.test.mapped <- data.frame(new_user_id=sort(unique(data.test.mapped$new_user_id)))

    event.candidates.test.mapped <- merge(data.event.candidates.test, event.ids, by="event_id")
    event.candidates.test.mapped <- data.frame(new_event_id=event.candidates.test.mapped$new_event_id)

    cat("      Persisting...\n")
    write.table(data.test.mapped, paste0(partition.dir, "/user-event-rsvp_test.tsv"),
                row.names=F, col.names=F, sep="\t", quote=F)
    write.table(users.test.mapped, paste0(partition.dir, "/users_test.tsv"),
                row.names=F, col.names=F, sep="\t", quote=F)
    write.table(event.candidates.test.mapped, paste0(partition.dir, "/event-candidates_test.tsv"),
                row.names=F, col.names=F, sep="\t", quote=F)

    cat("\n")
    # --------------------------------------------------------------------------
    # SPECIFIC DATA PARTITION
    # --------------------------------------------------------------------------
    # MY MEDIA DATA
    my.media.dir <- paste0(partition.dir, "/my_media")
    dir.create(my.media.dir, recursive=T, showWarnings=F)
    MyMediaDBData(initial.time, part.time, this.region, my.media.dir,
                  subset(all.rsvps.train, response == 'yes', c("user_id", "event_id")),
                  data.event.candidates.test, user.ids, event.ids, group.ids, users.test.mapped)

    # HEURISTIC MODELS DATA
    heuristic.models.dir <- paste0(partition.dir, "/heuristic_models")
    dir.create(heuristic.models.dir, recursive=T, showWarnings=F)
    HeuristicModelsDBData(initial.time, part.time, this.region, partition.dir,
                          heuristic.models.dir,
                          subset(all.rsvps.train, response == 'yes', c("user_id", "event_id", "mtime")),
                          data.event.candidates.test,
                          user.ids, event.ids, group.ids, users.test.mapped)

    # CONTENT-BASED MODELS DATA
    content.based.models.dir <- paste0(partition.dir, "/content_based_models")
    dir.create(content.based.models.dir, recursive=T, showWarnings=F)
    ContentBasedModelsDBData(initial.time, part.time, this.region, partition.dir,
                             content.based.models.dir,
                             subset(all.rsvps.train, response == 'yes', c("user_id", "event_id", "mtime")),
                             data.event.candidates.test, user.ids, event.ids, users.test.mapped)

    # MRBPR DATA
    mrbpr.dir <- paste0(partition.dir, "/mrbpr")
    dir.create(mrbpr.dir, recursive=T, showWarnings=F)

    MrbprDBData(initial.time, part.time, this.region,
                partitioned.data.dir, mrbpr.dir,
                all.rsvps.train[, c("user_id", "event_id", "response")],
                data.event.candidates.test, user.ids, event.ids, group.ids, data.test.mapped)

    # AUXILIAR DATA
    AuxiliarDBData(initial.time, part.time, this.region, partition.dir,
                   subset(all.rsvps.train, response == 'yes', c("user_id", "event_id")),
                   data.test, data.event.candidates.test, user.ids, event.ids)
  }
}
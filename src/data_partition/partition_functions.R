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

MyMediaDBData <- function(initial.time, part.time, data.region, my.media.dir,
                          yes.rsvps.train, data.event.candidates.test,
                          user.ids, event.ids, group.ids, users.test.mapped){

  cat("    MY MEDIA\n")

  cat("      Defining Test Candidates and Users...\n")
  # Event Candidates to be recommended mapping
  data.event.candidates.test.mapped <- merge(data.event.candidates.test, event.ids, by="event_id")
  data.event.candidates.test.mapped$fake_id <- rep(1, nrow(data.event.candidates.test.mapped))
  data.event.candidates.test.mapped <- data.event.candidates.test.mapped[,c("fake_id", "new_event_id")]

  # Users to Recommended mapping
  data.users.test <- as.data.frame(users.test.mapped)
  data.users.test$fake_id <- rep(1, nrow(users.test.mapped))
  data.users.test <- data.users.test[,c("new_user_id", "fake_id")]

  cat("        Persisting...\n")
  write.table(data.event.candidates.test.mapped, paste0(my.media.dir, "/event-candidates_test.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)
  write.table(data.users.test, paste0(my.media.dir, "/users_test.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)

  cat("      Defining Train Data...\n")

  # Train mapping
  yes.rsvps.train.mapped <- merge(yes.rsvps.train, user.ids, by="user_id")
  yes.rsvps.train.mapped <- merge(yes.rsvps.train.mapped, event.ids, by="event_id")
  yes.rsvps.train.mapped <- yes.rsvps.train.mapped[,c("new_user_id", "new_event_id")]

  cat("        Persisting...\n")
  write.table(yes.rsvps.train.mapped, paste0(my.media.dir, "/user-event-rsvp_train.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)

  cat("\n")
}

HeuristicModelsDBData <- function(initial.time, part.time, data.region, partition.dir,
                                  heuristic.models.dir, yes.rsvps.train, data.event.candidates.test,
                                  user.ids, event.ids, group.ids, users.test.mapped){

  cat("    Heuristic Models\n")

  cat("      Defining Test Candidates and Users...\n")
  # Event Candidates to be recommended mapping
  data.event.candidates.test.mapped <- merge(data.event.candidates.test, event.ids, by="event_id")
  data.event.candidates.test.mapped <- data.event.candidates.test.mapped[,"new_event_id"]

  cat("        Persisting...\n")
  write.table(data.event.candidates.test.mapped, paste0(heuristic.models.dir, "/event-candidates_test.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)
  write.table(users.test.mapped, paste0(heuristic.models.dir, "/users_test.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)

  cat ("      Reading User/Event Locations...\n")
  query <- gsub("@SQL_QUERY_NAME", "all_events_location", QUERIES[['partition_data']])
  all.events.locations <- RunQuery(query, c(initial.time, part.time, data.region))

  query <- gsub("@SQL_QUERY_NAME", "all_users_location", QUERIES[['partition_data']])
  all.users.locations <- RunQuery(query, c(initial.time, part.time, data.region))

  cat ("      Reading Events Features...\n")
  query <- gsub("@SQL_QUERY_NAME", "all_events_features", QUERIES[['partition_data']])
  all.events.features <- RunQuery(query, c(initial.time, part.time, data.region))
  all.events.features <- all.events.features[,c("event_id", "event_created", "event_time",
                                                "event_hour", "event_day_of_week", "group_id")]

  cat ("      Mapping Train data...\n")
  user.event.train <- merge(yes.rsvps.train, user.ids, by="user_id")
  user.event.train <- merge(user.event.train, event.ids, by="event_id")
  user.event.train <- user.event.train[,c("new_user_id", "new_event_id", "mtime")]

  cat ("      Mapping Event Features data...\n")
  all.events.features <- merge(all.events.features, event.ids, by="event_id")
  all.events.features <- merge(all.events.features, group.ids, by="group_id")
  all.events.features <- all.events.features[,c("new_event_id",
                                                "event_created", "event_time",
                                                "event_hour", "event_day_of_week",
                                                "new_group_id")]

  cat ("      Mapping Location data...\n")
  all.events.locations <- merge(all.events.locations, event.ids, by="event_id")
  all.events.locations <- all.events.locations[,c("new_event_id", "longitude", "latitude")]

  all.users.locations <- merge(all.users.locations, user.ids, by="user_id")
  all.users.locations <- all.users.locations[,c("new_user_id", "longitude", "latitude")]

  cat ("        Persisting...\n")
  write.table(user.event.train, paste0(heuristic.models.dir, "/user-event_train.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)
  write.table(all.users.locations, paste0(heuristic.models.dir, "/user-long-lat_all.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)
  write.table(all.events.locations, paste0(heuristic.models.dir, "/event-long-lat_all.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)
  write.table(all.events.features, paste0(heuristic.models.dir, "/event-features_all.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)
  cat("\n")
}

ContentBasedModelsDBData <- function(initial.time, part.time, data.region, partition.dir,
                                     content.based.models.dir, yes.rsvps.train, data.event.candidates.test,
                                     user.ids, event.ids, users.test.mapped){
  cat("    Content-Based Models\n")

  cat("      Defining Test Candidates and Users...\n")
  # Event Candidates to be recommended mapping
  data.event.candidates.test.mapped <- merge(data.event.candidates.test, event.ids, by="event_id")
  data.event.candidates.test.mapped <- data.event.candidates.test.mapped[,"new_event_id"]

  cat("        Persisting...\n")
  write.table(data.event.candidates.test.mapped, paste0(content.based.models.dir, "/event-candidates_test.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)
  write.table(users.test.mapped, paste0(content.based.models.dir, "/users_test.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)

  cat ("      Reading Events Content: Name and Description...\n")
  query <- gsub("@SQL_QUERY_NAME", "all_events_name_description", QUERIES[['partition_data']])
  all.events.names.desc <- RunQuery(query, c(initial.time, part.time, data.region))

  cat ("      Mapping Train data...\n")
  user.event.train <- merge(yes.rsvps.train, user.ids, by="user_id")
  user.event.train <- merge(user.event.train, event.ids, by="event_id")
  user.event.train <- user.event.train[,c("new_user_id", "new_event_id", "mtime")]

  cat ("      Mapping Event Content data...\n")
  all.events.names.desc <- merge(all.events.names.desc, event.ids, by="event_id")
  all.events.names.desc <- all.events.names.desc[,c("new_event_id", "name", "description")]

  cat ("        Persisting...\n")
  write.table(user.event.train, paste0(content.based.models.dir, "/user-event-rsvptime_train.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)
  write.table(all.events.names.desc, paste0(content.based.models.dir, "/event-name-desc_all.tsv"),
              row.names=F, col.names=F, sep="\t", quote=T)

  cat("\n")
}

AuxiliarDBData <- function(initial.time, part.time, data.region, partition.dir,
                           yes.rsvps.train,
                           data.test, data.event.candidates.test,
                           user.ids, event.ids){

  cat("    Reading Auxiliar DB Data...\n")

  cat("      Counting the historical data size per test user and per test event (YES RSVPs only)...\n")
  test.user.ids <- unique(data.test$user_id)
  count.train.per.test.user <- count(subset(yes.rsvps.train, user_id %in% test.user.ids, "user_id"))
  count.train.per.test.user <- merge(count.train.per.test.user, data.frame(user_id=test.user.ids),
                                     by="user_id", all.y=T)
  count.train.per.test.user[is.na(count.train.per.test.user$freq),]$freq <- 0

  count.train.per.test.event <- count(subset(yes.rsvps.train, event_id %in% data.event.candidates.test$event_id), "event_id")
  count.train.per.test.event <- merge(count.train.per.test.event, data.event.candidates.test,
                                      by="event_id", all.y=T)
  count.train.per.test.event[is.na(count.train.per.test.event$freq),]$freq <- 0

  cat("        Persisting...\n")
  write.csv(count.train.per.test.user, paste(partition.dir, "/count_events_per_test-user_train.csv", sep=""), row.names=F)
  write.csv(count.train.per.test.event, paste(partition.dir, "/count_users_per_test-event_train.csv", sep=""), row.names=F)

  cat("      Mapping Count data...\n")
  count.train.per.test.user.mapped <- merge(count.train.per.test.user, user.ids, by="user_id")
  count.train.per.test.user.mapped <- count.train.per.test.user.mapped[,c("new_user_id", "freq")]

  count.train.per.test.event.mapped <- merge(count.train.per.test.event, event.ids, by="event_id")
  count.train.per.test.event.mapped <- count.train.per.test.event.mapped[,c("new_event_id", "freq")]

  cat("        Persisting...\n")
  write.table(count.train.per.test.user.mapped, paste(partition.dir, "/count_events_per_test-user_train.tsv", sep=""),
              row.names=F, col.names=F, sep="\t", quote=F)
  write.table(count.train.per.test.event.mapped, paste(partition.dir, "/count_users_per_test-event_train.tsv", sep=""),
              row.names=F, col.names=F, sep="\t", quote=F)

  cat("\n")
}
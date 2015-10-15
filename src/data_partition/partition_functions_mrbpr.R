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

MrbprDBData <- function(initial.time, part.time, this.region,
                        partitioned.data.dir, mrbpr.dir,
                        all.rsvps.train, data.event.candidates.test,
                        user.ids, event.ids, group.ids, data.test.mapped){

  cat("    MRBPR\n")
  # Read the relation and entity ids
  all.relations.atts <- read.csv(paste0(partitioned.data.dir, "/mrbpr_relations.csv"),
                                 stringsAsFactors=F)
  all.relations.atts$full_name <- paste(all.relations.atts$entity1, all.relations.atts$entity2,
                                        all.relations.atts$name, sep="-")

  # ---------------------------------------------------------------------------
  # TEST DEFINITION
  # ---------------------------------------------------------------------------
  cat("      Defining Test Candidates and Users...\n")

  # Users to Recommended
  test.users <- data.frame(new_user_id = sort(unique(data.test.mapped$new_user_id)))
  test.users$relation_id <- subset(all.relations.atts, entity1 == "user" & entity2 == "event" & name == "rsvp")$id
  test.users <- test.users[,c("relation_id", "new_user_id")]

  # Event Candidates to be recommended
  test.event.candidates <- merge(data.event.candidates.test, event.ids, by="event_id")
  test.event.candidates$relation_id <- subset(all.relations.atts, entity1 == "user" & entity2 == "event" & name == "rsvp")$id
  test.event.candidates <- test.event.candidates[,c("relation_id", "new_event_id")]

  cat("        Persisting...\n")
  write.table(test.users, paste0(mrbpr.dir, "/users_test.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)
  write.table(test.event.candidates, paste0(mrbpr.dir, "/event-candidates_test.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)

  rm(data.test.mapped, test.users, test.event.candidates)

  # ---------------------------------------------------------------------------
  # TRAIN DEFINITION
  # ---------------------------------------------------------------------------
  cat("      Defining the Train data...\n")
  yes.rsvps.train <- subset(all.rsvps.train, response == 'yes')

  # ----------------------------------------------------------------------------
  # TARGET CONTEXT
  # ----------------------------------------------------------------------------
  tryCatch({
    UserEvent.RSVPRelations(initial.time, part.time, this.region, mrbpr.dir,
                            all.rsvps.train, yes.rsvps.train,
                            user.ids, event.ids, all.relations.atts, data.test.mapped)
  }, error = function(e){print(e)})

  # ----------------------------------------------------------------------------
  # SOCIAL CONTEXT
  # ----------------------------------------------------------------------------
  tryCatch({
    UserUser.SameGroup(initial.time, part.time, this.region, mrbpr.dir, yes.rsvps.train,
                       user.ids, event.ids, all.relations.atts)
  }, error = function(e){print(e)})

  tryCatch({
    UserUser.SameEvent(initial.time, part.time, this.region, mrbpr.dir, yes.rsvps.train,
                       user.ids, event.ids, all.relations.atts)
  }, error = function(e){print(e)})

  # ----------------------------------------------------------------------------
  # GROUP based RELATIONS
  # ----------------------------------------------------------------------------

  tryCatch({
    UserGroup.Participate(initial.time, part.time, this.region, mrbpr.dir,
                          yes.rsvps.train, user.ids, event.ids, group.ids, all.relations.atts)
  }, error = function(e){print(e)})

  tryCatch({
    GroupEvent.Created(initial.time, part.time, this.region, mrbpr.dir,
                       yes.rsvps.train, user.ids, event.ids, group.ids, all.relations.atts)
  }, error = function(e){print(e)})

  cat("\n")
}

UserEvent.RSVPRelations <- function(initial.time, part.time, this.region, mrbpr.dir,
                                    all.rsvps.train, yes.rsvps.train,
                                    user.ids, event.ids, all.relations.atts,
                                    data.test.mapped){

  # ---------------------------------------------------------------------------
  # Yes RSVP
  cat("        User-Event-RSVP...\n")
  relation.atts <- subset(all.relations.atts, entity1 == "user" & entity2 == "event" & name == "rsvp")

  user.event.train <- merge(yes.rsvps.train, user.ids, by="user_id")
  user.event.train <- merge(user.event.train, event.ids, by="event_id")
  user.event.train$relation_id <- relation.atts$id
  user.event.train$value <- 1
  user.event.train <- user.event.train[,c("relation_id", "new_user_id", "new_event_id", "value")]

  cat("          Persisting...\n")
  write.table(user.event.train, paste0(mrbpr.dir, "/", relation.atts$full_name, "_train.tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)

}


UserUser.SameGroup <- function(initial.time, part.time, this.region, mrbpr.dir,
                               yes.rsvps.train, user.ids, event.ids, all.relations.atts, user.event.train){
  cat("        User-User-Same-Group...\n")

  relation.atts <- subset(all.relations.atts,
                          entity1 == "user" & entity2 == "user" & name == "same-group")
  relation.out.file <- paste0(mrbpr.dir, "/", relation.atts$full_name, "_train.tsv")

  if (file.exists(relation.out.file)){
    cat("          Data Already Created!\n")
    return (NULL)
  }

  query <- gsub("@SQL_QUERY_NAME", "all_user_groups", QUERIES[['partition_data']])
  all.user.groups <- RunQuery(query, c(initial.time, part.time, this.region))

  all.user.groups <- merge(all.user.groups, user.ids, by="user_id")
  all.user.groups <- merge(all.user.groups, group.ids, by="group_id")
  all.user.groups <- all.user.groups[,c("new_user_id", "new_group_id")]

  cat("      Persisting temporary file (USER-GROUP)...\n")
  tmp.user.group.file <- paste0(mrbpr.dir, "/user-group_all_tmp.tsv")
  write.table(all.user.groups, tmp.user.group.file, row.names=F, col.names=F, sep="\t", quote=F)

  cat("      Processing the User-User Groups...\n")
  max.members <- 100
  system(paste0("python src/data_partition/partition_helper_mrbpr.py -d ",
                mrbpr.dir, " -i user-group_all_tmp.tsv -o ", relation.atts$full_name, "_train.tsv -r ", relation.atts$id,
                " -m ", max.members))

  cat("      Removing temporary file...\n")
  file.remove(tmp.user.group.file)

}

UserUser.SameEvent <- function(initial.time, part.time, this.region, mrbpr.dir,
                               yes.rsvps.train, user.ids, event.ids, all.relations.atts){
  cat("        User-User-Same-Event...\n")

  relation.atts <- subset(all.relations.atts,
                          entity1 == "user" & entity2 == "user" & name == "same-event")
  relation.out.file <- paste0(mrbpr.dir, "/", relation.atts$full_name, "_train.tsv")

  if (file.exists(relation.out.file)){
    cat("          Data Already Created!\n")
    return (NULL)
  }

  yes.rsvps.train <- merge(yes.rsvps.train, user.ids, by="user_id")
  yes.rsvps.train <- merge(yes.rsvps.train, event.ids, by="event_id")
  yes.rsvps.train <- yes.rsvps.train[,c("new_user_id", "new_event_id")]

  user.user.same.event <- ddply(yes.rsvps.train, .(new_event_id), function(data){
    if (nrow(data) > 1){
      t(combn(data$new_user_id, 2))
    }
  }, .progress="text")

  colnames(user.user.same.event) <- c("event_id", "new_user_id1", "new_user_id2")
  user.user.same.event$event_id <- NULL
  user.user.same.event <- user.user.same.event[!duplicated(user.user.same.event),]

  # Bidirectional Edges
  user.user.same.event <- rbind(user.user.same.event,
                                data.frame(new_user_id1=user.user.same.event$new_user_id2,
                                           new_user_id2=user.user.same.event$new_user_id1))
  user.user.same.event$relation_id <- relation.atts$id
  user.user.same.event$value <- 1
  user.user.same.event <- user.user.same.event[,c("relation_id", "new_user_id1", "new_user_id2", "value")]

  cat("          Persisting...\n")
  write.table(user.user.same.event, relation.out.file, row.names=F, col.names=F, sep="\t", quote=F)
}

UserGroup.Participate <- function(initial.time, part.time, this.region, mrbpr.dir,
                                  yes.rsvps.train, user.ids, event.ids, group.ids, all.relations.atts){
  cat("        User-Group-Participate\n")

  relation.atts <- subset(all.relations.atts,
                          entity1 == "user" & entity2 == "group" & name == "participate")
  relation.out.file <- paste0(mrbpr.dir, "/", relation.atts$full_name, "_train.tsv")

  if (file.exists(relation.out.file)){
    cat("          Data Already Created!\n")
    return (NULL)
  }

  query <- gsub("@SQL_QUERY_NAME", "all_user_groups", QUERIES[['partition_data']])
  all.user.groups <- RunQuery(query, c(initial.time, part.time, this.region))

  all.user.groups <- merge(all.user.groups, user.ids, by="user_id")
  all.user.groups <- merge(all.user.groups, group.ids, by="group_id")
  all.user.groups <- all.user.groups[,c("new_user_id", "new_group_id")]

  all.user.groups$relation_id <- relation.atts$id
  all.user.groups$value <- 1
  all.user.groups <- all.user.groups[,c("relation_id", "new_user_id", "new_group_id", "value")]

  cat("          Persisting...\n")
  write.table(all.user.groups, relation.out.file,
              row.names=F, col.names=F, sep="\t", quote=F)
}

GroupEvent.Created <- function(initial.time, part.time, this.region, mrbpr.dir,
                               yes.rsvps.train, user.ids, event.ids, group.ids, all.relations.atts){
  cat("        Group-Event-Created\n")

  relation.atts <- subset(all.relations.atts,
                          entity1 == "group" & entity2 == "event" & name == "created")
  relation.out.file <- paste0(mrbpr.dir, "/", relation.atts$full_name, "_train.tsv")

  if (file.exists(relation.out.file)){
    cat("          Data Already Created!\n")
    return (NULL)
  }

  query <- gsub("@SQL_QUERY_NAME", "all_group_events", QUERIES[['partition_data']])
  all.groups.events <- RunQuery(query, c(initial.time, part.time, this.region))

  # Map the event_ids
  all.groups.events <- merge(all.groups.events, event.ids, by="event_id")

  all.groups.events <- merge(all.groups.events, group.ids, by="group_id")
  all.groups.events <- all.groups.events[,c("new_group_id", "new_event_id")]

  all.groups.events$relation_id <- relation.atts$id
  all.groups.events$value <- 1
  all.groups.events <- all.groups.events[,c("relation_id", "new_group_id", "new_event_id", "value")]

  cat("          Persisting...\n")
  write.table(all.groups.events, relation.out.file,
              row.names=F, col.names=F, sep="\t", quote=F)
}
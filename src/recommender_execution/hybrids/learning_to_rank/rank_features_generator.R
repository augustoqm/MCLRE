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
source("src/common.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 7){
  stop(paste("Argument Error. Usage: Rscript src/recommender_execution/heuristic_based/generate_letor_features.R",
             "<DATA_REGION_DIR> <REC_REGION_DIR> <PARTITION> <REC_RESULT_DIR_NAME> \
              <MODEL_DATA_FILE> <DATA_NAMES> <TRAIN_OR_TEST>"))
}
data.region.dir <- args[1]
rec.region.dir <- args[2]
partition <- args[3]
rec.result.dir.name <- args[4]
model.data.file <- args[5]
data.names <- gsub("-", ".", strsplit(args[6], ",")[[1]])
model.names <- data.names[!data.names %in% c("HIST.SIZE.USER", "HIST.SIZE.EVENT")]
data.type <- tolower(args[7])

output.dir <- paste0(rec.region.dir, "/", partition, "/", rec.result.dir.name)
dir.create(output.dir, recursive=T, showWarnings=F)

# ------------------------------------------------------------------------------
# DATA READING
# ------------------------------------------------------------------------------
cat(">> Reading", toupper(data.type), "data...\n")
features.data <- read.csv(paste0(rec.region.dir, "/", partition, "/",
                          rec.result.dir.name, "/", model.data.file))

# Select only the desired models
features.data <- features.data[,c("user_id", "event_id", model.names)]

# Remove the rows with 0 in all model scores (there were non-zero in at least one excluded model score)
features.data <- features.data[rowSums(as.data.frame(features.data[,model.names])) != 0,]

user.rsvp.count <- read.csv(paste(data.region.dir, partition, "count_events_per_test-user_train.tsv", sep="/"),
                            sep="\t", header=F)
colnames(user.rsvp.count) <- c("user_id", "HIST.SIZE.USER")

event.rsvp.count <- read.csv(paste(data.region.dir, partition, "count_users_per_test-event_train.tsv", sep="/"),
                             sep="\t", header=F)
colnames(event.rsvp.count) <- c("event_id", "HIST.SIZE.EVENT")

# -----------------------------------------------------------------------------
# Preparing the complete FEATURES DATASET
# -----------------------------------------------------------------------------
cat(">> Preparing the", toupper(data.type), "features...\n")

if (data.type == "train"){
  user.events.ground.truth <- read.table(paste0(data.region.dir, "/", partition, "/user-event-rsvp_test.tsv"),
                                  sep="\t", header=F, stringsAsFactors=F)
  colnames(user.events.ground.truth) <- c("user_id", "event_id")
  user.events.ground.truth$has_rsvp_yes <- T

  features.data <- merge(features.data, user.events.ground.truth, by=c("user_id", "event_id"), all.x=T)
  features.data[is.na(features.data$has_rsvp_yes),"has_rsvp_yes"] <- F

  # Replace the NAs scores with 0
  for (model in model.names){
    features.data[is.na(features.data[,model]), model] <- 0
  }
}else{
  features.data$has_rsvp_yes <- T
}

# Add the user.rsvp.count and event.rsvp.count columns
if ("HIST.SIZE.USER" %in% data.names){
    features.data <- merge(features.data, user.rsvp.count, by="user_id", all.x=T)
}
if ("HIST.SIZE.EVENT" %in% data.names){
    features.data <- merge(features.data, event.rsvp.count, by="event_id", all.x=T)
}

# Order by USER then by EVENT
features.data <- features.data[order(features.data$user_id, features.data$event_id),]

# -----------------------------------------------------------------------------
# Generate the final FEATURES FILE
# -----------------------------------------------------------------------------
cat(">> Parse the data to features file format...\n")
feature.ids <- 1:length(data.names)

feature.file <- apply(features.data, 1, function(row){
  paste(row["has_rsvp_yes"] + 1,
        paste0("qid:", row["user_id"]),
        paste(feature.ids, row[data.names], sep=":", collapse=" "),
        "#eid =", row["event_id"])
})

# -----------------------------------------------------------------------------
# PERSIST it
# -----------------------------------------------------------------------------
if (data.type == "train"){
  cat(">> Persisting Train and Validation features...\n")

  # Sample randomly 20% rows to Validation from the TRUE and FALSE classes
  true.rows <- which(features.data$has_rsvp_yes)
  false.rows <- which(!features.data$has_rsvp_yes)

  validation.rows <- c(sample(1:length(true.rows), size=.2 * length(true.rows)),
                       sample(1:length(false.rows), size=.2 * length(false.rows)))

  validation.file <- feature.file[validation.rows]
  feature.file <- feature.file[-validation.rows]

  write.table(feature.file,
              file=paste0(output.dir, "/", paste0(gsub(".", "-", data.names, fixed=T), collapse="."),
                          "_", data.type, "-features.txt"),
              col.names=F, row.names=F, quote = F)

  write.table(validation.file,
                file=paste0(output.dir, "/", paste0(gsub(".", "-", data.names, fixed=T), collapse="."),
                            "_validation-features.txt"),
                col.names=F, row.names=F, quote = F)

}else{
  cat(">> Persisting Test features...\n")
  write.table(feature.file,
              file=paste0(output.dir, "/", paste0(gsub(".", "-", data.names, fixed=T), collapse="."),
                          "_", data.type, "-features.txt"),
              col.names=F, row.names=F, quote = F)
}


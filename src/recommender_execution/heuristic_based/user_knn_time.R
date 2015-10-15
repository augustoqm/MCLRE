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
source("src/recommender_execution/heuristic_based/time_functions.R")
LoadMe("ff")
LoadMe("foreach")

################################################################################
# FUNCTIONS
################################################################################
bigcor <- function(MAT, nblocks = 10, verbose = TRUE, ...)
{
  NCOL <- ncol(MAT)

  ## test if ncol(MAT) %% nblocks gives remainder 0
  if (NCOL %% nblocks != 0) stop("Choose different 'nblocks' so that ncol(MAT) %% nblocks = 0!")

  ## preallocate square matrix of dimension
  ## ncol(MAT) in 'ff' single format
  corMAT <- ff(vmode = "single", dim = c(NCOL, NCOL))

  ## split column numbers into 'nblocks' groups
  SPLIT <- split(1:NCOL, rep(1:nblocks, each = NCOL/nblocks))

  ## create all unique combinations of blocks
  COMBS <- expand.grid(1:length(SPLIT), 1:length(SPLIT))
  COMBS <- t(apply(COMBS, 1, sort))
  COMBS <- unique(COMBS)

  ## iterate through each block combination, calculate correlation matrix
  ## between blocks and store them in the preallocated matrix on both
  ## symmetric sides of the diagonal
  for (i in 1:nrow(COMBS)) {
    COMB <- COMBS[i, ]
    G1 <- SPLIT[[COMB[1]]]
    G2 <- SPLIT[[COMB[2]]]
    if (verbose) cat("Block", COMB[1], "with Block", COMB[2], "\n")
    flush.console()
    COR <- cor(MAT[, G1], MAT[, G2], ...)
    corMAT[G1, G2] <- COR
    corMAT[G2, G1] <- t(COR)
    COR <- NULL
  }

  gc()
  return(corMAT)
}

PearsonKNN <- function(data.by.row, k){
  # Prepare the data to run with bigcor
  row.num <- nrow(data.by.row)
  extra.rows <- 0
  if (row.num %% 10 != 0){
    extra.rows <- 10 - row.num %% 10
    data.by.row[(row.num + 1):(row.num + extra.rows),] <- 0
  }
  # Calculate the Correlation with BigCor
  similarity.mat <- bigcor(t(data.by.row), nblocks = 10, verbose = F, method="pearson")

  # Set the self correlation as 0
  diag(similarity.mat) <- 0

  # Get the TOP-K Vizinhos
  knn.out <- foreach(i=1:(nrow(similarity.mat)-extra.rows)) %dopar% {
    row <- similarity.mat[i,]
    indexes <- head(order(row, decreasing = T, na.last = T), n = k)
    list(ind=indexes,sim=row[indexes])
  }

  knn.out
}

UserKNNTime <- function(user, user.neighbors, k, user.ids,
                        neighbor.candidate.events){

  all.neighbors <- user.neighbors[[which(user.ids == user)]]
  neighbor.score <- data.frame(user_id = user.ids[head(all.neighbors$ind, n=k)],
                               score = head(all.neighbors$sim, n=k))

  max.event.score <- sum(neighbor.score$score)

  # Remove the Candidate events that were already consumed by the user
  # The neighbor.candidate.events include the users' events that are in the candidate set (only)
  user.consumed.events <- unique(subset(neighbor.candidate.events, user_id == user)$event_id)
  neighbor.candidate.events <- subset(neighbor.candidate.events, !event_id %in% user.consumed.events)

  # INNER JOIN to get the NEIGHBOR CANDIDATE Events
  rec.cand.events <- merge(neighbor.score, neighbor.candidate.events, by="user_id")

  if (nrow(rec.cand.events) > 0){
    # -----------------------------------------------------------------------
    # Users in which its Neighbors have Candidate event receive RECOMMENDATION
    # -----------------------------------------------------------------------

    # Sum the candidate events' scores
    rec.cand.events <- ddply(rec.cand.events, .(event_id),
                             function(data) data.frame(score=sum(data$score)/max.event.score,
                                                       event_time=data$event_time[1]))

    # Sort the Candidate Events by Score then by TIME
    rec.cand.events <- rec.cand.events[order(rec.cand.events$score, -rec.cand.events$event_time,
                                             decreasing=T), c("event_id", "score")]

    # Get the TOP-N events
    rec.cand.events <- head(rec.cand.events, n=max.ranked.list.size)

    result <- data.frame(ranked_events=paste(rec.cand.events$event_id,
                                         round(rec.cand.events$score, 6),
                                         sep=":", collapse=","))
  }else{
    result <- data.frame(ranked_events="")
  }
  result
}

################################################################################
# MAIN
################################################################################
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5){
  stop(paste("Argument Error. Usage: Rscript src/recommender_execution/heuristic_based/user_knn_time.R",
             "<DB_PARTITION_DIR> <REC_RESULT_DIR> <PARTITION_NUMBER> <ALGORITHM> <NEIGHBORHOOD_SIZES>"))
}
db.partition.dir <- args[1]
rec.result.dir <- args[2]
partition.number <- args[3]
algorithm <- args[4]
neighborhood.sizes <- as.integer(strsplit(args[5], ",")[[1]])

# Check if MODELs were already created
result <- c()
for (num.neighbors in neighborhood.sizes){
  model.tsv.file <- paste0(rec.result.dir, "/", algorithm, "_", num.neighbors, ".tsv")

  if (file.exists(model.tsv.file)){
    cat(algorithm, "- k =", num.neighbors, "\n")
    cat("Model already experimented (DONE!)\n")
  }else{
    result <- c(result, num.neighbors)
  }
}

if (length(result) <= 0){
  quit(save = "no", status = 0)
}else{
  neighborhood.sizes <- result
}

# Define the RANK SIZE
max.ranked.list.size <- 100
max.neighborhood.size <- max(neighborhood.sizes)
# -----------------------------------------------------------------------------
# Reading data
# -----------------------------------------------------------------------------
# TRAIN
user.event.train <- read.table(paste0(db.partition.dir, "/user-event_train.tsv"), sep="\t")
colnames(user.event.train) <- c("user_id", "event_id", "mtime")
user.event.train <- user.event.train[,c("user_id", "event_id")]

event.features <- read.table(paste0(db.partition.dir, "/event-features_all.tsv"), sep="\t")
colnames(event.features) <- c("event_id", "event_created", "event_time", "event_hour", "event_day_of_week", "group_id")
event.features <- event.features[,c("event_id", "event_time", "event_hour", "event_day_of_week")]

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

# Merging the candidate.events with the EVENT Features
event.candidates.test <- merge(event.candidates.test, event.features, by="event_id")

# Add the TIME POPULAR score
event.candidates.test$pop_score <- TimePopularEventScore(user.event.train, event.candidates.test)

# Selecting the TEST Users with and without Train
users.with.train <- users.test$user_id[users.test$user_id %in% unique(user.event.train$user_id)]
users.without.train <- users.test$user_id[! users.test$user_id %in% users.with.train]

# -----------------------------------------------------------------------------
# Running recommenders
# -----------------------------------------------------------------------------
switch(algorithm,
       "USER-KNN-TIME-BIN"={
         # Preparing the User Bin Attributes from its EVENT TIME preferences
         user.atts <- ddply(user.event.train, .(user_id), GetEventAtts.Binary, .progress="text")
       },
       "USER-KNN-TIME"={
         # Preparing the User Quant Attributes from its EVENT TIME preferences
         user.atts <- ddply(user.event.train, .(user_id), GetEventAtts.Quant, .progress="text")
       }
)

# Select only the Neighbor Events that are in the Candidate Set
neighbor.candidate.events <- subset(user.event.train, event_id %in% event.candidates.test$event_id)
neighbor.candidate.events <- neighbor.candidate.events[,c("user_id", "event_id", "event_time")]

#user.neighbors <- get.knn(user.atts[,-1], k = num.neighbors, algorithm = "kd_tree")
# user.neighbors <- CosineKNN(t(user.atts[,-1]), k = max.neighborhood.size)
user.neighbors <- PearsonKNN(user.atts[,-1], k = max.neighborhood.size)
gc()

# -----------------------------------------------------------------------------
# Do the Recommendation!
# -----------------------------------------------------------------------------
event.candidates.test <- event.candidates.test[order(-event.candidates.test$pop_score,
                                                     event.candidates.test$event_time),]
top.cold.candidates <- head(event.candidates.test, n=max.ranked.list.size)
user.cold.ranked.list <- data.frame(user_id=users.without.train,
                                    ranked_events=paste(top.cold.candidates$event_id,
                                                        round(top.cold.candidates$pop_score, 6),
                                                        sep=":", collapse=","))

# Iterate over the K values and persist the ranked lists
for (num.neighbors in neighborhood.sizes){
  cat(algorithm, "- k =", num.neighbors, "\n")

  user.ranked.list <- adply(users.with.train, 1, UserKNNTime,
                            user.neighbors, k=num.neighbors, user.ids=user.atts$user_id,
                            neighbor.candidate.events,
                            .progress="text", .parallel=F)
  user.ranked.list$user_id <- users.with.train[user.ranked.list[,1]]
  user.ranked.list <- user.ranked.list[,c("user_id", "ranked_events")]

  # Bind the Cold-Users with its Recs
  user.ranked.list <- rbind(user.ranked.list, user.cold.ranked.list)

  # Order by user_id
  user.ranked.list <- user.ranked.list[order(user.ranked.list$user_id),]

  # -----------------------------------------------------------------------------
  # Persisting result
  # -----------------------------------------------------------------------------
  dir.create(rec.result.dir, recursive=T, showWarnings=F)
  write.table(user.ranked.list, paste0(rec.result.dir, "/", algorithm, "_", num.neighbors, ".tsv"),
              row.names=F, col.names=F, sep="\t", quote=F)
}

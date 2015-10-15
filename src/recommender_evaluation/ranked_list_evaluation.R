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

rm(list = ls())

###############################################################################
# SOURCE and LIBRARIES
################################################################################
source("src/common.R")

################################################################################
# FUNCTIONS
################################################################################

# ------------------------------------------------------------------------------
# Data Functions
# ------------------------------------------------------------------------------
DefinePastRSVPGroups <- function(count.data, new.col.name){
  count.data$past_rsvps <- rep(NA, nrow(count.data))
  freqs <- count.data[,"freq"]

  count.data[freqs <= 0, "past_rsvps"] <- "0"
  count.data[freqs == 1, "past_rsvps"] <- "1"
  count.data[freqs == 2, "past_rsvps"] <- "2"
  count.data[freqs == 3, "past_rsvps"] <- "3"
  count.data[freqs == 4, "past_rsvps"] <- "4"
  count.data[freqs == 5, "past_rsvps"] <- "5"
  count.data[freqs >= 6 & freqs <= 10, "past_rsvps"] <- "6-10"
  count.data[freqs >= 11 & freqs <= 20 , "past_rsvps"] <- "11-20"
  count.data[freqs > 20 , "past_rsvps"] <- ">20"

  count.data$past_rsvps <- factor(count.data$past_rsvps,
                                  levels=c(paste(0:5), "6-10", "11-20", ">20"))
  count.data <- rename(count.data, c(past_rsvps=new.col.name))

  return(count.data)
}

WriteEvaluationPerModel <- function(data, result.eval.dir, file.prefix){
  if (!is.null(data)){
    d_ply(data, .(algorithm), function(data){
      algorithm.name <- data$algorithm[1]
      write.csv(subset(data, algorithm == algorithm.name),
                file=paste0(result.eval.dir, "/", file.prefix, "_", algorithm.name, ".csv"), row.names=F)
    })
  }
}

# ------------------------------------------------------------------------------
# Evaluation Functions
# ------------------------------------------------------------------------------
HitsAtK <- function(user.ranks, k = 10){
  sum(!is.na(user.ranks$rank) & user.ranks$rank <= k, na.rm = T)
}
PrecisionAtK <- function(user.ranks, k){
  precision <- HitsAtK(user.ranks, k)/k
  precision
}
RecallAtK <- function(user.ranks, k){
  recall <- HitsAtK(user.ranks, k)/nrow(user.ranks)
  recall
}
AveragePrecisionAtK <- function(user.ranks, k){
  user.ranks <- user.ranks[order(user.ranks$rank),]
  k.user.ranks <- user.ranks[1:min(nrow(user.ranks), k),]
  k.correct.user.ranks <- subset(k.user.ranks, !is.na(rank) & rank <= k)

  if (nrow(k.correct.user.ranks) > 0){
    score <- 0
    for (row in 1:nrow(k.correct.user.ranks)){
      tmp.user.ranks <- k.correct.user.ranks[1:row,]
      row.k <- k.correct.user.ranks[row, "rank"]
      score <- score + as.numeric(PrecisionAtK(tmp.user.ranks, row.k))
    }
    avgPrec <- score/min(nrow(user.ranks), k)
  }else{
    avgPrec <- 0
  }
  avgPrec
}
NDCGAtK <- function(user.ranks, k){
  user.ranks <- user.ranks[order(user.ranks$rank),]
  k.user.ranks <- user.ranks[1:min(nrow(user.ranks), k),]
  k.ranks <- subset(k.user.ranks, !is.na(rank) & rank <= k)$rank

  dcg <- function(rank) 1/log2(rank+1)

  ranks.idcg <- dcg(1:nrow(k.user.ranks)) # Perfect dcg values for the k initial
  ranks.dcg <- dcg(k.ranks) # DCG values to the k initial ranks

  ndcg <- sum(ranks.dcg, na.rm = T)/sum(ranks.idcg, na.rm = T)
  ndcg
}
TopEventsAtK <- function(user.ranks, k){
  user.ranks <- user.ranks[order(user.ranks$rank),]
  k.user.ranks <- user.ranks[1:min(nrow(user.ranks), k),]
  data.frame(event_id=sort(unique(k.user.ranks$event_id)))
}
# ------------------------------------------------------------------------------
# READ and EVALUATE the RANKED DATA
# ------------------------------------------------------------------------------
EvalMetrics <- function(rank.data){
  RunMetricsPerUser <- function(user.ranks){
    data.frame(precision_at_10=PrecisionAtK(user.ranks, 10),
               recall_at_10=RecallAtK(user.ranks, 10),
               ndcg_at_50=NDCGAtK(user.ranks, 50),
               ndcg_at_20=NDCGAtK(user.ranks, 20),
               ndcg_at_10=NDCGAtK(user.ranks, 10),
               avg_prec_at_20=AveragePrecisionAtK(user.ranks, 20),
               avg_prec_at_10=AveragePrecisionAtK(user.ranks, 10))
  }

  user.metrics <- ddply(rank.data, .(user_id), RunMetricsPerUser)
  top_events_at_10 <- ddply(rank.data, .(user_id), TopEventsAtK, 10)
  top_events_at_20 <- ddply(rank.data, .(user_id), TopEventsAtK, 20)

  # Precision
  precision.10 <- sum(user.metrics$precision_at_10, na.rm=T)/nrow(user.metrics)
  # Recall
  recall.10 <- sum(user.metrics$recall_at_10, na.rm=T)/nrow(user.metrics)
  # F1 Score
  if (precision.10 + recall.10 > 0){
    f1.score.10 <- 2 * ((precision.10 * recall.10)/(precision.10 + recall.10))
  }else {
    f1.score.10 <- 0
  }
  # NDCG@50
  ndcg.50 <- sum(user.metrics$ndcg_at_50, na.rm=T)/nrow(user.metrics)
  # NDCG@20
  ndcg.20 <- sum(user.metrics$ndcg_at_20, na.rm=T)/nrow(user.metrics)
  # NDCG@10
  ndcg.10 <- sum(user.metrics$ndcg_at_10, na.rm=T)/nrow(user.metrics)
  # MAP@20
  map_at_20 <- sum(user.metrics$avg_prec_at_20, na.rm=T)/nrow(user.metrics)
  # MAP@10
  map_at_10 <- sum(user.metrics$avg_prec_at_10, na.rm=T)/nrow(user.metrics)
  # Mean Rank (calculated only over the rank_data without NA's)
  mean.ranks <- mean(rank.data$rank, na.rm=T)
  if(is.na(mean.ranks)){
    mean.ranks <- 0
  }
  # User Coverage (it cannot be calculated here)
  user.coverage <- 0
  # Event Coverage
  event.coverage.10 <- length(unique(top_events_at_10))/length(unique(rank.data$event_id))
  event.coverage.20 <- length(unique(top_events_at_20))/length(unique(rank.data$event_id))

  data.frame(precision_at_10 = precision.10,
             recall_at_10 = recall.10,
             f1_score_at_10 = f1.score.10,
             map_at_20 = map_at_20,
             map_at_10 = map_at_10,
             ndcg_at_50 = ndcg.50,
             ndcg_at_20 = ndcg.20,
             ndcg_at_10 = ndcg.10,
             mean_ranks = mean.ranks,
             user_coverage = user.coverage,
             event_coverage_at_10 = event.coverage.10,
             event_coverage_at_20 = event.coverage.20,
             # This percentage of NA's only affects the mean_ranks metric,
             # the other metrics consider the NA's in the calculation
             perc_user_events_rank_NA = sum(is.na(rank.data$rank))/nrow(rank.data))
}

SelectModelFilesToEval <- function(ranks.dir, group.vars, result.eval.dir){
  # Define the algorithms TO EVALUATE in this group.vars
  model.rank.files <- list.files(ranks.dir)
  model.rank.algorithms <- laply(strsplit(model.rank.files, "_"), function(vec) gsub(".csv", "", vec[1]))
  # Define the set of algorithms ALREADY EVALUATED in this group.vars
  evaluated.alg.group.files <- list.files(result.eval.dir,
                                          pattern=paste0('eval_by_', group.vars, "_"))
  evaluated.algorithms <- unique(laply(strsplit(evaluated.alg.group.files, "_"),
                                       function(vec) gsub('.csv', '', vec[length(vec)])))
  return(model.rank.files[!model.rank.algorithms %in% evaluated.algorithms])
}

ReadEvalRankedData <- function(result.rec.dir, partitioned.data.dir,
                               result.eval.dir, group.vars){
  partitions <- list.files(result.rec.dir)
  all.eval.data <- NULL

  for (partition in partitions){
    cat("\t", partition, "\n")

    db.partition.dir <- paste(partitioned.data.dir, partition, sep="/")

    user.count <- read.csv(paste(db.partition.dir, "count_events_per_test-user_train.csv", sep="/"), header=T)
    event.count <- read.csv(paste(db.partition.dir, "count_users_per_test-event_train.csv", sep="/"), header=T)
    event.count$event_id <- as.character(event.count$event_id) # Guarantee that all event_ids are correctly parsed (and merged)

    user.count <- DefinePastRSVPGroups(user.count, "user_past_rsvps")
    event.count <- DefinePastRSVPGroups(event.count, "event_past_rsvps")

    ranks.dir <- paste(result.rec.dir, partition, "ranks", sep="/")

    model.files <- SelectModelFilesToEval(ranks.dir, group.vars, result.eval.dir)

    if (length(model.files) > 0){
      eval.rank.data <- adply(model.files, 1, function(model.file){
        cat("\t\t", model.file, "\n")

        rank.data <- read.csv(paste(ranks.dir, model.file, sep="/"), header=F)
        colnames(rank.data) <- c("user_id", "event_id", "rank")

        rank.data <- subset(rank.data, !is.na(event_id))
        rank.data$event_id <- as.character(rank.data$event_id)

        rank.data <- merge(rank.data, user.count[,c("user_id", "user_past_rsvps")], by="user_id")
        rank.data <- merge(rank.data, event.count[,c("event_id", "event_past_rsvps")], by="event_id")
        rank.data <- rank.data[order(rank.data$user_past_rsvps,
                                     rank.data$event_past_rsvps),]

        # Evaluate!
        eval.rank.data <- switch(group.vars,
                                 'partition'=EvalMetrics(rank.data),
                                 'partition-user'=ddply(rank.data, .(user_past_rsvps), EvalMetrics),
                                 'partition-event'=ddply(rank.data, .(event_past_rsvps), EvalMetrics),
                                 'partition-user-event'=ddply(rank.data, .(user_past_rsvps, event_past_rsvps), EvalMetrics))

        # Add the partition name
        eval.rank.data$partition <- as.numeric(gsub("partition_", "", partition))

        # Separate the algorithm and the model hyper-parameters
        model.params <- strsplit(gsub(".csv", "", model.file), "_")[[1]]

        eval.rank.data$algorithm <- model.params[1]
        eval.rank.data$model_params <- NULL

        if(length(model.params) > 1){
          eval.rank.data$model_params <- model.params[2]
        }else{
          eval.rank.data$model_params <- NA
        }

        eval.rank.data
      }, .parallel=T)

      eval.rank.data <- eval.rank.data[,-1] # Remove the column added by the adply
      all.eval.data <- rbind(all.eval.data, eval.rank.data)
    }
  }
  all.eval.data
}

################################################################################
# MAIN
################################################################################
args <- commandArgs(trailingOnly = TRUE)
experiment.name <- args[1]
region <- args[2]
# experiment.name <- "hybrids-experiment"
# region <- "phoenix"
cat("======", region, "======\n")

data.dir <- "data"
partitioned.data.dir <- paste0(data.dir, "/partitioned_data/", region)

experiment.region.data.dir <- paste0(data.dir, "/experiments/", experiment.name, "/", region)
result.rec.dir <- paste0(experiment.region.data.dir, "/recommendations")
result.eval.dir <- paste0(experiment.region.data.dir, "/evaluations")
dir.create(result.eval.dir, recursive=T, showWarnings=F)

# ------------------------------------------------------------------------------
cat("Evaluating ranked data...\n")

cat("  By Partition...\n")
system.time(partition.eval.data <- ReadEvalRankedData(result.rec.dir,
                                                      partitioned.data.dir,
                                                      result.eval.dir, "partition"))
WriteEvaluationPerModel(partition.eval.data, result.eval.dir,
                        "eval_by_partition")
cat("\n")

cat("  By Partition and User groups...\n")
system.time(user.group.eval.data <- ReadEvalRankedData(result.rec.dir,
                                                       partitioned.data.dir,
                                                       result.eval.dir, "partition-user"))
WriteEvaluationPerModel(user.group.eval.data, result.eval.dir,
                        "eval_by_partition-user")
cat("\n")

cat("  By Partition and Event groups...\n")
system.time(event.group.eval.data <- ReadEvalRankedData(result.rec.dir,
                                                        partitioned.data.dir,
                                                        result.eval.dir, "partition-event"))
WriteEvaluationPerModel(event.group.eval.data, result.eval.dir,
                        "eval_by_partition-event")
cat("\n")

# cat("  By Partition, User groups and Event groups...\n")
# system.time(user.event.group.eval.data <- ReadEvalRankedData(result.rec.dir,
#                                                              partitioned.data.dir,
#                                                              result.eval.dir, "partition-user-event"))
# WriteEvaluationPerModel(user.event.group.eval.data, result.eval.dir,
#                         "eval_by_partition-user-event")

cat("DONE!\n")

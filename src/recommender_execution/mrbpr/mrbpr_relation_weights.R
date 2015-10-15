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

# =============================================================================
# SOURCE and LIBRARIES
# =============================================================================
source("src/common.R")
LoadMe("qualityTools")

# =============================================================================
# FUNCTIONS
# =============================================================================
LatticeDesigns <- function(components, replications, lattice.degree, lower.constraints,
                           design.name, has.center, has.axial, randomize){
  # Simplex Lattice Degree 1 with center and axial augmentation
  mde <- mixDesign(p = length(components), n = lattice.degree, type = "lattice",
                   # Augmenting with center point and axial runs
                   center = has.center, axial = has.axial,
                   # Randomize or not is not a problem, so we DO IT!
                   randomize = randomize,
                   # General Replicates
                   replicates = replications,
                   # Lower bound constraints
                   lower = lower.constraints)

  names(mde) <- components
  mde@name <- design.name

  return(mde)
}

# =============================================================================
# MAIN
# =============================================================================

# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
experiment.name <- args[1]
algorithm.name <- tolower(args[2])

data.dir <- "data"
partition.dir <- paste0(data.dir, "/partitioned_data")
experiment.dir <- paste0(data.dir, "/experiments/", experiment.name)

# Read the Experiment Attributes
experiment.atts <- read.csv(paste0(experiment.dir, "/experiment_atts.csv"), stringsAsFactors=F)

final_weights_file <- paste0(experiment.dir, "/", algorithm.name, "_relation_weights.txt")

if (file.exists(final_weights_file)){
  cat(final_weights_file, " already created.\n")
  quit()
}

# Set the values
# Relation names
relation.names <- strsplit(subset(experiment.atts, name==paste0(algorithm.name, "_relation_names"))$value, ",")[[1]]
# Number of simultaneous auxiliar relations
lattice.degree <- as.numeric(subset(experiment.atts, name=="lattice_combination_degree")$value)
# Minimum target weight
target.min.weigth <- as.numeric(subset(experiment.atts, name=="target_min_weight")$value)


# The lower bound weights (the user-event-rsvp target relation should be always considered)
lower.bound.weights <- c(target.min.weigth, rep(0, length(relation.names)-1))
# The number of replications (We define as 1 and during the execution we can replicate the same trials)
replications <- 1
# Center and axial points in screen experiment
has.center <- T
has.axial <- T
# Randomize order?
randomize <- F

cat("General Experiment Configurations:\n")
cat("  Relations:", relation.names, "\n", sep = "  ")
cat("  Min Weigths:", lower.bound.weights, "\n", sep = "  ")
cat("  Replications:", replications, "\n\n")

# -----------------------------------------------------------------------------
# Lattice Design
# -----------------------------------------------------------------------------
cat("Creating the Lattice Design...\n")
if (length(relation.names) > 1){
    lattice.design <- LatticeDesigns(components = relation.names,
                                     replications = replications,
                                     lattice.degree = lattice.degree,
                                     lower.constraints = lower.bound.weights,
                                     design.name = "Masters Experiment",
                                     has.center, has.axial, randomize)
    relation.weights <- lattice.design@design
    relation.weights <- round(relation.weights, digits=2)
    char.weights <- NULL
    for (i in 1:nrow(relation.weights)){
      char.weights <- c(char.weights,
                        paste0(relation.weights[i,], collapse=","))
    }
}else{
    char.weights <- "1"
}

write.table(rev(char.weights), final_weights_file, quote=F, row.names = F, col.names=F)

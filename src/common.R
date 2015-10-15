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

# =============================================================================
# SOURCE() and LIBRARY()
# =============================================================================
installed.packages <- installed.packages()[,1]
LoadMe <- function(package){
  if (!package %in% installed.packages){
    install.packages(package, repos="http://cran-r.c3sl.ufpr.br/")
  }
  suppressPackageStartupMessages(library(as.character(package), character.only=T, warn.conflicts=F, quietly=T, verbose=F))
}

# In-Memory Data Management
LoadMe("plyr")
LoadMe("reshape2")
# Plotting
LoadMe("ggplot2")
LoadMe("scales")
# Parallelism
LoadMe("parallel")
LoadMe("doMC")

registerDoMC(detectCores()-1)

theme_set(theme_bw())

# =============================================================================
# FUNCTIONS
# =============================================================================

# -----------------------------------------------------------------------------
# PostgreSQL DATABASE ACCESS
# -----------------------------------------------------------------------------

# To create the USER and grant it the privileges, use the code below:
#
#   CREATE USER augusto WITH ENCRYPTED PASSWORD 'augusto_db';
#   GRANT USAGE ON SCHEMA public to augusto;
#   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO augusto;

#   -- repeat code below for each database:

#   GRANT CONNECT ON DATABASE meetup_db to augusto;
#   \c meetup_db
#   GRANT USAGE ON SCHEMA public to augusto;
#   GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO augusto;
#   GRANT SELECT ON ALL TABLES IN SCHEMA public TO augusto;
#
#   Based on: http://jamie.curle.io/blog/creating-a-read-only-user-in-postgres/

RunQuery <- function(query, params=c()){

  # PostgreSQl DB
  LoadMe("RPostgreSQL")

  ## Loads the PostgreSQL driver
  drv <- dbDriver("PostgreSQL")

  ## Open a connection
  con <- dbConnect(drv, user="augusto", pass="augusto_db", dbname="meetup_db")

  # RUN QUERY
  result.set <- postgresqlExecStatement(con, query, params)
  data <- postgresqlFetch(result.set, n=-1)
  dbClearResult(result.set)
  postgresqlCloseResult(result.set)

  ## Closes all connections
  for( con in dbListConnections(drv)){
    dbDisconnect(con)
  }

  ## Frees all the resources on the driver
  dbUnloadDriver(drv)

  return(data)
}

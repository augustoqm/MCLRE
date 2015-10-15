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

GetTurn <- function(hours) {
  turns <- rep(0, length(hours))
  turns[hours >= 4 & hours <= 11] <- 1  # Morning
  turns[hours >= 12 & hours <= 19] <- 2 # Afternoon
  turns[hours >= 20 | hours <= 3] <- 3  # Night
  return (turns)
}
IsWeekend <- function(days){
  weekend <- rep(F, length(days))
  weekend[days == 0 | days == 6] <- T
  return (weekend)
}

#  Event Attributes (7 days of week, 2 weekend or not, 24 hours and 3 turns)
GetEventAtts.Binary <- function(events.data){
  # -------------------------------------------------------------------------
  # Attribute Vector Names Definition
  days.of.week.names <- c("sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday")
  weekend.or.not.names <- c("not_weekend", "weekend")
  hours.names <- paste0("hour_", (0:23))
  turns.names <- c("morning", "afternoon", "night")
  full.att.vector <- c(days.of.week.names, weekend.or.not.names, hours.names, turns.names)

  # -------------------------------------------------------------------------
  # Selected Attributes Vector Definition
  events.hours <- events.data$event_hour[!is.na(events.data$event_hour)]
  events.days.week <- sort(unique(events.data$event_day_of_week[!is.na(events.data$event_day_of_week)]))

  # The day_of_week is like an index that starts at 0
  days.of.week.names <- days.of.week.names[unique(events.days.week) + 1]
  # We convert the F and T boolean values to integer and increment 1 to act like an index
  weekend.or.not.names <- sort(unique(weekend.or.not.names[IsWeekend(events.days.week) + 1]))
  # We select the hours
  hours.names <- paste0("hour_", as.character(sort(unique(events.hours))))
  # We also the hour act like an index that starts at 0
  turns.names <- sort(unique(turns.names[GetTurn(events.hours)]))

  selected.att.vector <- c(days.of.week.names, weekend.or.not.names, hours.names, turns.names)

  #att.ids <- which(full.att.vector %in% selected.att.vector)
  result <- (full.att.vector %in% selected.att.vector) + 0
  names(result) <- full.att.vector

  return (t(as.data.frame(result)))
}

GetEventAtts.Quant <- function(events.data){
  # -------------------------------------------------------------------------
  # Attribute Vector Names Definition
  days.of.week <- data.frame(name=c("sunday", "monday", "tuesday", "wednesday",
                                    "thursday", "friday", "saturday"),
                             count=rep(0, 7))
  is.weekend <- data.frame(name=c("not_weekend", "weekend"),
                           count=rep(0, 2))
  hours <- data.frame(name=paste0("hour_", (0:23)),
                      count=rep(0, 24))
  turns <- data.frame(name=c("morning", "afternoon", "night"),
                      count=rep(0, 3))

  # -------------------------------------------------------------------------
  # Selected Attributes Vector Definition
  events.hours <- events.data$event_hour[!is.na(events.data$event_hour)]
  events.days.week <- events.data$event_day_of_week[!is.na(events.data$event_day_of_week)]

  # The day_of_week is like an index that starts at 0
  days.of.week.freq <- count(days.of.week$name[events.days.week + 1])
  days.of.week <- merge(days.of.week, days.of.week.freq, by.x="name", by.y="x", all=T)
  days.of.week$count <- rowSums(days.of.week[,c("count", "freq")], na.rm = T)

  # We convert the F and T boolean values to integer and increment 1 to act like an index
  is.weekend.freq <- count(is.weekend$name[IsWeekend(events.days.week) + 1])
  is.weekend <- merge(is.weekend, is.weekend.freq, by.x="name", by.y="x", all=T)
  is.weekend$count <- rowSums(is.weekend[,c("count", "freq")], na.rm = T)

  # We select the hours
  hours.freq <- count(paste0("hour_", as.character(events.hours)))
  hours <- merge(hours, hours.freq, by.x="name", by.y="x", all=T)
  hours$count <- rowSums(hours[,c("count", "freq")], na.rm = T)

  # We also the hour act like an index that starts at 0
  turns.freq <- count(turns$name[GetTurn(events.hours)])
  turns <- merge(turns, turns.freq, by.x="name", by.y="x", all=T)
  turns$count <- rowSums(turns[,c("count", "freq")], na.rm = T)

  result <- c(days.of.week$count, is.weekend$count, hours$count, turns$count)
  result <- result/mean(result)
  names(result) <- c(as.character(days.of.week$name), as.character(is.weekend$name),
                     as.character(hours$name), as.character(turns$name))

  return (t(as.data.frame(result)))
}

TimePopularEventScore <- function(user.event.train, event.cand.test){

  # Parse the event time to binary attributes
  # Event Attributes (7 days of week, 2 weekend or not, 24 hours and 3 turns)
  train.event.atts <- ddply(user.event.train[,c("event_id", "event_hour", "event_day_of_week")],
                            .(event_id), GetEventAtts.Binary, .progress="text")

  # Count the most popular event time
  most.popular.atts <- colSums(train.event.atts[,-1])
  days <- most.popular.atts[1:7]
  hours <- most.popular.atts[10:33]

  # Define the TIME-POPULAR event.att vector
  most.pop.day <- names(days)[which(days == max(days))]
  most.pop.hour <- names(hours)[which(hours == max(hours))]
  weekend.or.not.names <- c("not_weekend", "weekend")
  most.pop.is.weekend <- weekend.or.not.names[most.pop.day %in% c("saturday", "sunday") + 1]
  turns.names <- c("morning", "afternoon", "night")
  most.pop.turn <- turns.names[GetTurn(as.integer(strsplit(most.pop.hour, "_")[[1]][[2]]))]

  pop.event.atts <- rep(0, length(most.popular.atts))
  names(pop.event.atts) <- names(most.popular.atts)
  pop.event.atts[names(pop.event.atts) %in% c(most.pop.day, most.pop.hour, most.pop.is.weekend, most.pop.turn)] <- 1

  # Calculate the Candidate Events Attributes
  cand.event.atts <- ddply(event.cand.test[,c("event_id", "event_hour", "event_day_of_week")],
                           .(event_id), GetEventAtts.Binary, .progress="text")

  # Return the Candidate Events Similarity with the TIME-POPULAR configuration
  pop_score <- cor(pop.event.atts, t(cand.event.atts[,-1]), method="pearson")[1,]

  pop_score
}
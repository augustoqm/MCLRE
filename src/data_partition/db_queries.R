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

# -----------------------------------------------------------------------------
# QUERY LIST
# -----------------------------------------------------------------------------
QUERIES <- list(

  # SELECT THE TIMESTAMP char from an EPOCH integer
  "epoch_to_timestamp" =
    "SELECT TO_CHAR(TO_TIMESTAMP($1), 'YYYY-MM-DD HH24:MI:SS')",

  # SELECT THE EPOCH integer from a TIMESTAMP char
  "timestamp_to_epoch" =
    "SELECT EXTRACT(EPOCH FROM $1 ::TIMESTAMP)",

  # SELECT THE LAST MTIME from the RSVPs table
  "max_rsvp_mtime" =
    "SELECT MAX(mtime) FROM rsvps",

  # SELECT THE DATA FOR EACH PARTITION_TIME
  #   $1              - Initial Time
  #   $2              - Partition Time
  #   $3              - Region
  #   @SQL_QUERY_NAME - name of a temporary table we want (should be replaced before running)
  "partition_data" =
    "WITH
  train_rsvps_between AS (
    SELECT rsvps.user_id, rsvps.event_id, rsvps.response, rsvps.mtime
    FROM rsvps JOIN events ON (rsvps.event_id = events.event_id)
                JOIN groups ON (events.group_id = groups.group_id)
    -- Train RSVPs conditions:
    --  * response YES
    --  * the events were created after the initial time AND before or at the partition time
    --  * they occur in events created by groups at the given region
    WHERE events.created > $1 AND events.created <= $2 AND
          rsvps.mtime <= $2 AND groups.region = $3
    ORDER BY rsvps.mtime
  ),
  test_event_candidates AS(
    SELECT DISTINCT events.event_id
    FROM events JOIN groups ON (events.group_id = groups.group_id)
    -- Events conditions:
    --  * created after the initial time AND before or at the partition time
    --  * that occur after the partition time
    --  * that come from groups at the given region
    WHERE events.created > $1 AND events.created <= $2 AND
    events.time > $2 AND groups.region = $3
  ),
  test_rsvps AS (
    SELECT rsvps.user_id, rsvps.event_id
    FROM rsvps JOIN test_event_candidates ON (rsvps.event_id = test_event_candidates.event_id)
    JOIN users ON (rsvps.user_id = users.user_id)
    -- Test RSVPs conditions
    -- * response YES
    -- * users who joined before the partition time
    -- * they occur after the partition time (between the selected events only)
    WHERE rsvps.response = 'yes' AND users.joined <= $2 AND rsvps.mtime > $2
  ),
  all_users AS (
    SELECT *
    FROM (SELECT DISTINCT train_rsvps_between.user_id
          FROM train_rsvps_between
          UNION
          SELECT DISTINCT test_rsvps.user_id
          FROM test_rsvps) AS train_test_users
  ),
  all_events AS (
    SELECT *
    FROM (SELECT DISTINCT train_rsvps_between.event_id
          FROM train_rsvps_between
          UNION
          SELECT test_event_candidates.event_id
          FROM test_event_candidates) AS train_and_candidates_events
  ),
  all_groups AS (
    SELECT all_groups.group_id
    FROM (SELECT groups.group_id
          FROM all_events JOIN events ON (all_events.event_id = events.event_id)
               JOIN groups ON (events.group_id = groups.group_id)
          UNION
          SELECT group_users.group_id
          FROM all_users JOIN group_users ON (all_users.user_id = group_users.user_id)) AS all_groups
  ),
  all_events_location AS (
    SELECT DISTINCT events.event_id, events.time, locations.longitude, locations.latitude
    FROM all_events JOIN events ON (all_events.event_id = events.event_id)
                    JOIN locations ON (events.location_id = locations.location_id)
    WHERE (locations.longitude IS NOT NULL AND locations.latitude IS NOT NULL)
          AND NOT (locations.longitude = 0 AND locations.latitude = 0)
    ORDER BY events.time
  ),
  all_events_name_description AS (
    SELECT events.event_id, events.name, events.description
    FROM all_events JOIN events ON (all_events.event_id = events.event_id)
  ),
  all_events_features AS (
    SELECT events.event_id,
       TO_CHAR(TO_TIMESTAMP(events.time), 'MM')::INTEGER AS event_month,
       TO_CHAR(TO_TIMESTAMP(events.time), 'DD')::INTEGER AS event_day,
       DATE_PART('hour', TO_TIMESTAMP(events.time)) AS event_hour,
       DATE_PART('dow', TO_TIMESTAMP(events.time)) AS event_day_of_week,
       events.created AS event_created, events.time AS event_time,
       loc.location_id, loc.city, groups.group_id, groups.category_id
    FROM all_events JOIN events ON (all_events.event_id = events.event_id)
                    LEFT JOIN locations AS loc ON (events.location_id = loc.location_id)
                    LEFT JOIN groups ON (events.group_id = groups.group_id)
  ),
  all_group_events AS (
    SELECT events.group_id, all_events.event_id
    FROM all_events JOIN events ON (all_events.event_id = events.event_id)
  ),
  all_users_location AS (
    SELECT DISTINCT users.user_id, users.longitude, users.latitude
    FROM users JOIN all_users ON (users.user_id = all_users.user_id)
    WHERE (users.longitude IS NOT NULL AND users.latitude IS NOT NULL)
          AND NOT (users.longitude = 0 AND users.latitude = 0)
  ),
  all_user_groups AS (
    SELECT all_users.user_id, group_users.group_id
    FROM all_users JOIN group_users ON (all_users.user_id = group_users.user_id)
  )
  SELECT *
  FROM @SQL_QUERY_NAME"
)

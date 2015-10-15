/*
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
*/

-- ============ LOAD TABLES ============
-- REMEMBER: Change the <BASE_PATH> in all the below strings

COPY users FROM '<BASE_PATH>/meetup_collection_april_14/users_1.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY users FROM '<BASE_PATH>/meetup_collection_april_14/users_2.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY users FROM '<BASE_PATH>/meetup_collection_april_14/users_3.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY users FROM '<BASE_PATH>/meetup_collection_april_14/users_4.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY users FROM '<BASE_PATH>/meetup_collection_april_14/users_5.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY users FROM '<BASE_PATH>/meetup_collection_april_14/users_6.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY users FROM '<BASE_PATH>/meetup_collection_april_14/users_7.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');

COPY locations FROM '<BASE_PATH>/meetup_collection_april_14/locations.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');

COPY categories FROM '<BASE_PATH>/meetup_collection_april_14/categories.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');

COPY groups FROM '<BASE_PATH>/meetup_collection_april_14/groups.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');

COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_1.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_2.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_3.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_4.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_5.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_6.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_7.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_8.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_9.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_10.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_11.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_12.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_13.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_14.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_15.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_16.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_17.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_18.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_19.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_20.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_21.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_22.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_23.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY events FROM '<BASE_PATH>/meetup_collection_april_14/events_24.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');

COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_1.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_2.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_3.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_4.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_5.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_6.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_7.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_8.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_9.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_10.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_11.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_12.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_13.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_14.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_15.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_16.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');
COPY rsvps FROM '<BASE_PATH>/meetup_collection_april_14/rsvps_17.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');

COPY tags FROM '<BASE_PATH>/meetup_collection_april_14/tags.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');

COPY group_tags FROM '<BASE_PATH>/meetup_collection_april_14/group_tags.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');

COPY group_users FROM '<BASE_PATH>/meetup_collection_april_14/group_users.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');

COPY user_tags FROM '<BASE_PATH>/meetup_collection_april_14/user_tags.csv' WITH (FORMAT csv, DELIMITER ',', NULL '', HEADER TRUE, QUOTE '"');

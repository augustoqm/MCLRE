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

-- ============ CREATE TABLE ============

DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users (
	user_id		INTEGER PRIMARY KEY,
	name		VARCHAR(255),
	city		VARCHAR(100),
	country		VARCHAR(2),
	latitude	NUMERIC,
	longitude	NUMERIC,
	joined		INTEGER
);


DROP TABLE IF EXISTS locations CASCADE;
CREATE TABLE locations (
	location_id	INTEGER PRIMARY KEY,
	latitude	NUMERIC,
	longitude	NUMERIC,
	name		VARCHAR(255),
	address_1	VARCHAR(255),
	address_2	VARCHAR(255),
	address_3	VARCHAR(255),
	city		VARCHAR(100),
	country		VARCHAR(2)
);

DROP TABLE IF EXISTS categories CASCADE;
CREATE TABLE categories (
	category_id	INTEGER PRIMARY KEY,
	name		VARCHAR(255),
	shortname	VARCHAR(100)
);

DROP TABLE IF EXISTS groups CASCADE;
DROP TYPE IF EXISTS group_join_mode;
DROP TYPE IF EXISTS group_visibility;
CREATE TYPE group_join_mode AS ENUM ('closed', 'invite', 'approval', 'open');
CREATE TYPE group_visibility  AS ENUM ('members', 'public_limited', 'public');
CREATE TABLE groups (
	group_id	INTEGER PRIMARY KEY,
	name		VARCHAR(255),
	url_name	VARCHAR(500),
	created		INTEGER,
	city		VARCHAR(100),
	country		VARCHAR(2),
	join_mode	group_join_mode,
	visibility	group_visibility,
	latitude	NUMERIC,
	longitude	NUMERIC,
	users		INTEGER,
	category_id	INTEGER,
	organizer_id	INTEGER,
	region		VARCHAR(50),
	FOREIGN KEY (category_id) REFERENCES categories (category_id) DEFERRABLE,
	FOREIGN KEY (organizer_id) REFERENCES users (user_id)
);

DROP TABLE IF EXISTS events CASCADE;
DROP TYPE IF EXISTS event_status;
DROP TYPE IF EXISTS event_visibility;
CREATE TYPE event_status AS ENUM ('past', 'upcoming');
CREATE TYPE event_visibility AS ENUM ('public_limited', 'public');
CREATE TABLE events (
	event_id	VARCHAR(20) PRIMARY KEY,
	name		VARCHAR(255),
	event_url	VARCHAR(200),
	fee_price	NUMERIC,
	description	TEXT,
	created		INTEGER,
	time		INTEGER,
	utc_offset	INTEGER,
	status		event_status,
	visibility	event_visibility,
	headcount	INTEGER,
	rsvp_limit	INTEGER,
	location_id	INTEGER,
	group_id	INTEGER,
	FOREIGN KEY (location_id) REFERENCES locations (location_id),
	FOREIGN KEY (group_id) REFERENCES groups (group_id)
);

DROP TABLE IF EXISTS rsvps CASCADE;
DROP TYPE IF EXISTS rsvp_response;
CREATE TYPE rsvp_response AS ENUM ('no', 'waitlist', 'yes');
CREATE TABLE rsvps (
	rsvp_id		INTEGER PRIMARY KEY,
	created		INTEGER,
	mtime		INTEGER,
	response 	rsvp_response,
	user_id		INTEGER,
	event_id	VARCHAR(20),
	FOREIGN KEY (user_id) REFERENCES users (user_id),
	FOREIGN KEY (event_id) REFERENCES events (event_id)
);

DROP TABLE IF EXISTS tags CASCADE;
CREATE TABLE tags (
	tag_id		INTEGER PRIMARY KEY,
	name		VARCHAR(100)
);

-- ======== MANY-TO-MANY RELATIONS ========

DROP TABLE IF EXISTS group_tags CASCADE;
CREATE TABLE group_tags (
	group_id	INTEGER,
	tag_id		INTEGER,
	PRIMARY KEY (group_id, tag_id),
	FOREIGN KEY (group_id) REFERENCES groups (group_id),
	FOREIGN KEY (tag_id) REFERENCES tags (tag_id)
);

DROP TABLE IF EXISTS group_users CASCADE;
CREATE TABLE group_users (
	group_id	INTEGER,
	user_id		INTEGER,
	PRIMARY KEY (group_id, user_id),
	FOREIGN KEY (group_id) REFERENCES groups (group_id),
	FOREIGN KEY (user_id) REFERENCES users (user_id)
);

DROP TABLE IF EXISTS user_tags CASCADE;
CREATE TABLE user_tags (
	user_id		INTEGER,
	tag_id		INTEGER,
	PRIMARY KEY (user_id, tag_id),
	FOREIGN KEY (user_id) REFERENCES users (user_id),
	FOREIGN KEY (tag_id) REFERENCES tags (tag_id)
);
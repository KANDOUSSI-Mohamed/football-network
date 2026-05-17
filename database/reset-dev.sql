-- Development reset script.
-- Use only at the beginning of the project, when there is no important data.
-- Run this before schema.sql if Supabase says a table already exists.

drop table if exists subscriptions cascade;
drop table if exists claims cascade;
drop table if exists messages cascade;
drop table if exists conversation_participants cascade;
drop table if exists conversations cascade;
drop table if exists connections cascade;
drop table if exists applications cascade;
drop table if exists opportunities cascade;
drop table if exists documents cascade;
drop table if exists media_assets cascade;
drop table if exists player_statistics cascade;
drop table if exists player_career_entries cascade;
drop table if exists player_profiles cascade;
drop table if exists teams cascade;
drop table if exists clubs cascade;
drop table if exists stadiums cascade;
drop table if exists seasons cascade;
drop table if exists competitions cascade;
drop table if exists profiles cascade;
drop table if exists federations cascade;
drop table if exists confederations cascade;
drop table if exists countries cascade;


drop table app_users;
drop table app_sequence;

create table app_sequence
(
  seq_number integer
);

insert into app_sequence (seq_number) values (0);

create table app_users
(
  usr_id integer not null primary key,
  usr_login varchar not null,
  usr_password varchar not null,
  usr_change_password boolean default true,
  usr_gecos varchar not null,
  usr_privileges varchar
);

insert into app_users
  (usr_id, usr_login, usr_password, usr_gecos, usr_privileges)
  values (0, 'root', 'plain:root', 'Administrator', 'all');


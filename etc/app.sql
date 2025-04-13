drop table panne_users;
drop table panne_sequence;

create table panne_sequence
(
  seq_number integer
);

insert into panne_sequence (seq_number) values (0);

create table panne_users
(
  usr_id integer not null primary key,
  usr_login varchar not null,
  usr_password varchar not null,
  usr_change_password boolean default true,
  usr_gecos varchar not null,
  usr_privileges varchar
);

insert into panne_users
  (usr_id, usr_login, usr_password, usr_gecos, usr_privileges)
  values (0, 'root', 'plain:root', 'Administrator', 'all');


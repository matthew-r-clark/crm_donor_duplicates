CREATE TABLE IF NOT EXISTS donors (
  id serial PRIMARY KEY,
  first_name text NOT NULL,
  last_name text NOT NULL,
  other_last_name text,
  alt_names text[] DEFAULT '{}'
);

-- create table if not exists donor_aliases (
--   id serial primary key,
--   donor_id int not null,
--   alias text not null,
--   constraint fk_donor_aliases_donors foreign key (donor_id) references donors(id)
-- );

CREATE TABLE IF NOT EXISTS users (
  id serial PRIMARY KEY,
  first_name text NOT NULL,
  last_name text NOT NULL,
  email text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  admin boolean NOT NULL DEFAULT false,
  password text NOT NULL
);

CREATE TABLE IF NOT EXISTS donors_users (
  donor_id int NOT NULL REFERENCES donors(id) ON DELETE CASCADE,
  user_id int NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  donor_type text NOT NULL
);

----
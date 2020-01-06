require "pg"
require_relative "user"
require_relative "donor"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "donor_duplicates")
    end
    @logger = logger
  end

  def setup_schema
    table = @db.exec <<~SQL
      SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'lists'
    SQL

    create_tables if table.field_values("count").first == "0"
  end

  def create_tables
    sql = File.read("schema.sql")
    sql.split(";").each do |statement|
      @db.query(statement)
    end
  end

  def valid_signin?(email, password)
    sql = 'SELECT password FROM users WHERE email = $1;'
    result = query(sql, email)
    if result.ntuples == 1
      stored_password = result.tuple(0)["password"]
      begin
        BCrypt::Password.new(stored_password) == password
      rescue BCrypt::Errors::InvalidHash
        stored_password == password
      end
    else
      false
    end
  end

  def username_taken?(email)
    sql = 'SELECT * FROM users WHERE email = $1;'
    query(sql, email).ntuples > 0
  end

  def get_user_by_email(email)
    sql = <<~SQL
      SELECT id, first_name, last_name, email, active, admin
      FROM users WHERE email = $1;
    SQL

    user = query(sql, email).tuple(0)

    User.new(
      user["id"],
      user["first_name"],
      user["last_name"],
      user["email"],
      user["active"],
      user["admin"]
    )
  end

  def other_connected_users(user_id, donor_id)
    sql = <<~SQL
      SELECT u.first_name, u.last_name
      FROM users u
      INNER JOIN donors_users
      ON user_id = u.id
      WHERE donor_id = $1 AND user_id <> $2;
    SQL

    result = query(sql, donor_id, user_id)

    other_users = []
    result.each { |user| other_users.push "#{user["first_name"]} #{user["last_name"][0]}" }
    other_users
  end

  def all_connected_users(donor_id)
    sql = <<~SQL
      SELECT u.first_name, u.last_name
      FROM users u
      INNER JOIN donors_users
      ON user_id = u.id
      WHERE donor_id = $1;
    SQL

    result = query(sql, donor_id)

    users = []
    result.each { |user| users.push "#{user["first_name"]} #{user["last_name"][0]}" }
    users
  end

  def get_donor_list_for_user(user_id)
    sql = <<~SQL
      SELECT d.id, d.first_name, d.last_name, d.other_last_name,
             d.alt_names, relation
      FROM donors d
      INNER JOIN donors_users
      ON donor_id = d.id
      WHERE user_id = $1
      ORDER BY relation, d.last_name, d.first_name;
    SQL

    result = query(sql, user_id)

    donors = []
    result.each do |donor|
      donors.push Donor.new(
        donor["id"],
        donor["first_name"],
        donor["last_name"],
        donor["other_last_name"],
        parse_pg_array(donor["alt_names"])
      )
    end

    donors
  end

  def get_donor_list
    sql = <<~SQL
      SELECT id, first_name, last_name, other_last_name, alt_names
      FROM donors
      ORDER BY last_name, first_name;
    SQL
    result = query(sql)

    donors = []
    result.each do |donor|
      donors.push Donor.new(
        donor["id"],
        donor["first_name"],
        donor["last_name"],
        donor["other_last_name"],
        parse_pg_array(donor["alt_names"])
      )
    end

    donors
  end

  def get_user_list
    sql = <<~SQL
      SELECT id, first_name, last_name, email, active, admin
      FROM users
      ORDER BY last_name, first_name;
    SQL

    result = query(sql)

    users = []
    result.each do |user|
      users.push User.new(
        user["id"],
        user["first_name"],
        user["last_name"],
        user["email"],
        user["active"],
        user["admin"]
      )
    end

    users
  end

  def add_new_user(first_name, last_name, email, password)
    sql = <<~SQL
      INSERT INTO users (first_name, last_name, email, password)
      VALUES ($1, $2, $3, $4);
    SQL
    query(sql, first_name, last_name, email, password)
  end

  def get_donor_matches(donor_query)
    matches = exact_donor_matches(donor_query)
  end

  def exact_donor_matches(donor_query)
    sql = <<~SQL
      SELECT id, first_name, last_name, other_last_name, alt_names
      FROM donors WHERE last_name = $1;
    SQL

    result = query(sql, donor_query.last_name)

    matches = []
    result.each do |donor|
      matches.push Donor.new(
        donor["id"],
        donor["first_name"],
        donor["last_name"],
        donor["other_last_name"],
        parse_pg_array(donor["alt_names"])
      )
    end

    matches.select do |donor|
      donor.first_name == donor_query.first_name ||
      donor.alt_names.include?(donor_query.first_name) ||
      donor_query.alt_names.include?(donor.first_name) ||
      donor.alt_names.any? {|name| donor_query.alt_names.include?(name)} ||
      donor_query.alt_names.any? {|name| donor.alt_names.include?(name)}
    end
  end

  # def first_name_only_potential_match(donor_query)
  #   first_name = "%" + donor_query.first_name + "%"
  #   last_name = donor_query.last_name
  #   sql = <<~SQL
  #     SELECT id, first_name, last_name, other_last_name, alt_names
  #     FROM donors
  #     WHERE last_name <> $1 first_name LIKE $2 AND alt_names LIKE $2;
  #   SQL
  #   result = query(sql, last_name, first_name)
  # end

  def add_existing_donor_to_user(donor_id, user_id, relation)
    sql = <<~SQL
      INSERT INTO donors_users (donor_id, user_id, relation)
      VALUES ($1, $2, $3);
    SQL

    query(
      sql,
      donor_id,
      user_id,
      relation
    )
  end

  def update_existing_donor_to_user(donor_id, user_id, relation)
    sql = <<~SQL
      UPDATE donors_users
      SET relation = $1
      WHERE donor_id = $2 AND user_id = $3;
    SQL

    query(
      sql,
      relation,
      donor_id,
      user_id
    )
  end

  def create_donor(donor)
    sql = <<~SQL
      INSERT INTO donors (first_name, last_name, alt_names)
      VALUES ($1, $2, $3);
    SQL

    query(
      sql,
      donor.first_name,
      donor.last_name,
      format_pg_array(donor.alt_names)
    )
  end

  def get_newest_donor
    sql = 'SELECT id, first_name, last_name, other_last_name alt_names FROM donors ORDER BY id DESC LIMIT 1;'
    
    donor = query(sql).tuple(0)

    Donor.new(
      donor["id"],
      donor["first_name"],
      donor["last_name"],
      donor["other_last_name"],
      parse_pg_array(donor["alt_names"])
    )
  end

  def get_donor_by_id(id)
    sql = <<~SQL
      SELECT id, first_name, last_name, other_last_name, alt_names
      FROM donors
      WHERE id = $1;
    SQL

    donor = query(sql, id).tuple(0)

    Donor.new(
      donor["id"],
      donor["first_name"],
      donor["last_name"],
      donor["other_last_name"],
      parse_pg_array(donor["alt_names"])
    )
  end

  def get_user_by_id(id)
    sql = <<~SQL
      SELECT id, first_name, last_name, email, active, admin
      FROM users
      WHERE id = $1;
    SQL

    user = query(sql, id).tuple(0)

    User.new(
      user["id"],
      user["first_name"],
      user["last_name"],
      user["email"],
      user["active"],
      user["admin"]
    )
  end

  def update_donor(donor)
    sql = <<~SQL
      UPDATE donors
      SET first_name = $1,
          last_name = $2,
          alt_names = $3
      WHERE id = $4;
    SQL
    query(sql, donor.first_name, donor.last_name, format_pg_array(donor.alt_names), donor.id)
  end

  def remove_donor_from_user(donor_id, user_id)
    sql = <<~SQL
      DELETE FROM donors_users
      WHERE donor_id = $1
      AND user_id = $2;
    SQL
    query(sql, donor_id, user_id)
  end

  def delete_donor(id)
    sql = 'DELETE FROM donors WHERE id = $1;'
    query(sql, id)
  end

  def delete_user(id)
    sql = 'DELETE FROM users WHERE id = $1;'
    query(sql, id)
  end

  def update_user(user)
    sql = <<~SQL
      UPDATE users
      SET first_name = $1,
          last_name = $2,
          email = $3,
          active = $4,
          admin = $5
      WHERE id = $6;
    SQL

    query(sql,
          user.first_name,
          user.last_name,
          user.username,
          user.active,
          user.admin,
          user.id)
  end

  def reset_password(password, id)
    sql = <<~SQL
      UPDATE users
      SET password = $1
      WHERE id = $2;
    SQL
    query(sql, password, id)
  end

  def disconnect
    @db.close
  end

  private

  def query(statement, *params)
    @logger.info "#{statement} (Params: #{params.empty? ? "n/a" : params.join(", ")})"
    @db.exec_params(statement, params)
  end

  def format_pg_array(array)
    array.to_s.gsub('[', '{').gsub(']', '}')
  end

  def parse_pg_array(array)
    array.delete('{}').split(',')
  end
end
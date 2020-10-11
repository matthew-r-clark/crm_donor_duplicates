require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"
require "bcrypt"
require "securerandom"

require_relative "database_persistence"
require_relative "donor"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(64)
  set :erb, :escape_html => true
  set :protection, :except => :frame_options  # only added for use in iframe on resume
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb", "user.rb", "donor.rb", "donor_relation.rb"
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
  @storage.disconnect
end

helpers do
  def signed_in?
    session[:user].class == User
  end

  def current_user
    session[:user]
  end

  def other_connected_users(user_id, donor_id)
    @storage.other_connected_users(user_id, donor_id)
  end

  def all_connected_users(donor_id)
    @storage.all_connected_users(donor_id)
  end
end

def valid_signin?(email, password)
  @storage.valid_signin?(email, password)
end

def username_taken?(email)
  @storage.username_taken?(email)
end

def sign_user_in(email)
  session[:user] = get_user_by_email(email)
end

def add_new_user(first_name, last_name, email, password)
  @storage.add_new_user(first_name, last_name, email, password)
end

def get_user_by_email(email)
  @storage.get_user_by_email(email)
end

def get_donor_list_for_user(user_id)
  @storage.get_donor_list_for_user(user_id)
end

def get_donor_list
  @storage.get_donor_list
end

def get_user_list
  @storage.get_user_list
end

def get_donor_matches(donor_query)
  @storage.get_donor_matches(donor_query)
end

def add_existing_donor_to_user(donor_id, user_id, relation)
  @storage.add_existing_donor_to_user(donor_id, user_id, relation)
end

def update_existing_donor_to_user(donor_id, user_id, relation)
  @storage.update_existing_donor_to_user(donor_id, user_id, relation)
end

def create_donor(donor_data)
  @storage.create_donor(donor_data)
end

def get_newest_donor
  @storage.get_newest_donor
end

def get_donor_by_id(id)
  @storage.get_donor_by_id(id)
end

def update_donor(donor)
  @storage.update_donor(donor)
end

def update_donor_alt_names(donor, donor_query)
  donor.alt_names.concat(donor_query['alt_names'])
  donor.alt_names.push(donor_query['first_name'])
  donor.alt_names.uniq!
  donor.alt_names.delete(donor.first_name) if donor.alt_names.include?(donor.first_name)
  update_donor(donor)
end

def remove_donor_from_user(donor_id, user_id)
  @storage.remove_donor_from_user(donor_id, user_id)
end

def update_user(user)
  @storage.update_user(user)
  session[:success] = 'User has been updated.'
end

def reset_password(password, id)
  @storage.reset_password(password, id)
end

def delete_donor(id)
  @storage.delete_donor(id)
end

def delete_user(id)
  @storage.delete_user(id)
  session[:success] = 'User has been deleted.'
end

def get_user_by_id(id)
  @storage.get_user_by_id(id)
end

def generate_password
  upper = ('A'..'Z').to_a
  lower = ('a'..'z').to_a
  nums = ('0'..'9').to_a
  syms = %w(! @ # $ % ^ &)
  chars = upper + lower + nums + syms
  password = ''
  10.times do
    password += chars.sample
  end
  password
end

def process_name(name)
  name.strip!
  name[0].upcase + name[1..-1] unless name.size < 1
end

def process_alt_names(names)
  if names == nil
    names = ""
  end

  if names.class == String
    return names.split(",").map(&:strip).map(&:capitalize)
  end

  if names.class == Array
    return names
  end
end

def name_is_empty(name)
  name.class != String || name.strip.length <= 0
end

def donor_entry_invalid(donor_query)
  first_name = donor_query["first_name"]
  last_name = donor_query["last_name"]
  name_is_empty(first_name) || name_is_empty(last_name)
end

get "/" do
  redirect "/signin" unless signed_in?
  redirect "/user"
end

get "/signin" do
  erb :signin, layout: :layout
end

post "/signin" do
  redirect "/user" if signed_in?
  email = params[:username]
  password = params[:password]
  if valid_signin?(email, password)
    sign_user_in(email)
    redirect "user"
  else
    session[:error] = 'Invalid signin. Please try again.'
    redirect "/signin"
  end
end

get "/signout" do
  session[:user] = nil
  redirect "/signin"
end

get "/signup" do
  erb :signup, layout: :layout
end

post "/signup" do
  @first_name = params["first_name"]
  @last_name = params["last_name"]
  @email = params["email"]
  password = BCrypt::Password.create(params["password"])
  if username_taken?(@email)
    session[:error] = "Email is already used for another user profile."
    erb :signup, layout: :layout
  else
    add_new_user(@first_name, @last_name, @email, password)
    sign_user_in(@email)
    redirect "/user"
  end
end

get "/user" do
  @donors = get_donor_list_for_user(current_user.id)
  erb :user, layout: :layout
end

get "/add" do
  @donors = get_donor_list_for_user(current_user.id)
  erb :add, layout: :layout
end

post "/add" do
  donor_query = {
    'first_name' => process_name(params["first_name"]),
    'last_name' => process_name(params["last_name"]),
    'alt_names' => process_alt_names(params["alt_names"]),
    'relation' => params["relation"]
  }

  # handle invalid donor entry
  if donor_entry_invalid(donor_query)
    session[:error] = 'Invalid donor name, first and last name cannot be blank.'
    redirect "/add"
  end

  # find matches
  matches = get_donor_matches(donor_query)
  if matches.length == 0
    create_donor(donor_query)
    donor = get_newest_donor
    add_existing_donor_to_user(donor.id, current_user.id, donor_query['relation'])
  elsif matches.length > 1
    @donor_name = donor_query['first_name'] + ' ' + donor_query['last_name']
    @matches = matches
    erb :matches, layout: :layout
  else
    donor = matches.first
    update_donor_alt_names(donor, donor_query)
    add_existing_donor_to_user(donor.id, current_user.id, donor_query['relation'])
  end
  redirect "/user"
end

get "/remove/:donor_id/confirm" do |donor_id|
  @donor = get_donor_by_id(donor_id.to_i)
  erb :remove, layout: :layout
end

post "/remove/:donor_id" do |donor_id|
  donor_id = donor_id.to_i
  remove_donor_from_user(donor_id, current_user.id)
  redirect "/user"
end

get "/edit/:donor_id" do |donor_id|
  @donor = get_donor_by_id(donor_id.to_i)
  @donors = get_donor_list_for_user(current_user.id)
  erb :edit, layout: :layout
end

post "/edit/:donor_id" do |donor_id|
  first_name = params["first_name"]
  last_name = params["last_name"]
  alt_names = params["alt_names"]
              .split(",")
              .map(&:strip)
              .map {|name| name[0].upcase + name[1..-1]}
  relation = params["relation"]

  donor = Donor.new(donor_id, first_name, last_name, alt_names)

  update_donor(donor)
  update_existing_donor_to_user(donor_id, current_user.id, relation)
  redirect "/user"
end

get "/profile" do
  erb :profile, layout: :layout
end

get "/profile/edit" do
  erb :profile_edit, layout: :layout
end

post "/profile/edit" do
  current_user.first_name = params["first_name"]
  current_user.last_name = params["last_name"]
  current_user.username = params["username"]
  update_user(current_user)
  redirect "/profile"
end

get "/profile/reset-pass" do
  erb :reset_pass, layout: :layout
end

post "/profile/reset-pass" do
  current_password = params["current_password"]
  new_password = params["new_password"]
  confirm_password = params["confirm_password"]
  if valid_signin?(current_user.username, current_password)
    if new_password == confirm_password
      reset_password(BCrypt::Password.create(new_password), current_user.id)
      session[:success] = 'Password has been reset.'
      redirect "/profile"
    end
    session[:error] = 'New passwords do not match.'
  else
    session[:error] = 'Current password is incorrect.'
  end
  redirect "/profile/reset-pass"
end

get "/users" do
  @users = get_user_list
  erb :users, layout: :layout
end

get "/users/edit/:user_id" do |user_id|
  user_id = user_id.to_i
  @user = get_user_by_id(user_id)
  erb :admin_edit_user, layout: :layout
end

post "/users/edit/:user_id" do |user_id|
  id = user_id.to_i
  first_name = params["first_name"]
  last_name = params["last_name"]
  username = params["username"]
  active = params["active"] == "on"
  admin = params["admin"] == "on"
  user = User.new(id, first_name, last_name, username, active, admin)
  update_user(user)
  redirect "/users"
end

get "/users/reset-pass/:user_id" do |user_id|
  id = user_id.to_i
  password = generate_password
  reset_password(BCrypt::Password.create(password), id)
  session[:success] = "User's password has been reset to #{password}."
  redirect "/users"
end

get "/users/remove/:user_id/confirm" do |user_id|
  id = user_id.to_i
  @user = get_user_by_id(id)
  erb :admin_remove_user, layout: :layout
end

post "/users/remove/:user_id" do |user_id|
  id = user_id.to_i
  delete_user(id)
  redirect "/users"
end

get "/donors" do
  @donors = get_donor_list
  erb :donors, layout: :layout
end

get "/donors/remove/:donor_id/confirm" do |donor_id|
  @donor = get_donor_by_id(donor_id.to_i)
  erb :admin_remove, layout: :layout
end

post "/donors/remove/:donor_id" do |donor_id|
  delete_donor(donor_id.to_i)
  redirect "/donors"
end

get "/donors/edit/:donor_id" do |donor_id|
  @donor = get_donor_by_id(donor_id.to_i)
  @donors = get_donor_list
  erb :admin_edit, layout: :layout
end

post "/donors/edit/:donor_id" do |donor_id|
  first_name = params["first_name"]
  last_name = params["last_name"]
  alt_names = params["alt_names"]
              .split(",")
              .map(&:strip)
              .map {|name| name[0].upcase + name[1..-1]}
  donor = Donor.new(donor_id, first_name, last_name, alt_names)
  update_donor(donor)
  redirect "/donors"
end

not_found do
  session[:error] = "The page you requested does not exist."
  redirect "/"
end
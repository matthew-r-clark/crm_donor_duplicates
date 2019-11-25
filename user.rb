class User
  attr_reader :id, :first_name, :last_name, :admin, :active

  def initialize(id, first_name, last_name, email, active=true, admin=false)
    @id = id.to_i
    @first_name = process_name(first_name)
    @last_name = process_name(last_name)
    @email = email
    @active = process_boolean(active)
    @admin = process_boolean(admin)
  end

  def first_name=(name)
    @first_name = process_name(name)
  end

  def last_name=(name)
    @last_name = process_name(name)
  end

  def username
    @email
  end

  def username=(email)
    @email = email
  end

  def active=(bool)
    process_boolean(bool)
  end

  def admin=(bool)
    process_boolean(bool)
  end

  def fullname
    "#{first_name} #{last_name}"
  end

  private

  def process_name(name)
    name.strip!
    name[0].upcase + name[1..-1]
  end

  def process_boolean(bool)
    if bool.class == TrueClass
      bool
    else
      bool == 't'
    end
  end
end
class DonorRelation
  attr_accessor :first_name, :last_name, :alt_names, :relation, :user_id

  def initialize(first_name, last_name, alt_names="", relation, user_id)
    @first_name = process_name(first_name)
    @last_name = process_name(last_name)
    @alt_names = process_alt_names(alt_names)
    @relation = relation
    @user_id = user_id
  end

  def alt_names=(names)
    @alt_names = process_alt_names(names)
  end

  def alt_names_string
    alt_names.join(", ")
  end

  def fullname
    first_name + " " + last_name
  end

  private

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
end

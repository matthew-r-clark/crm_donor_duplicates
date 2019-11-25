class Donor
  attr_accessor :id, :first_name, :last_name, :other_last_name, :alt_names, :relation

  def initialize(id, first_name, last_name, other_last_name, alt_names, relation=nil)
    @id = id
    @first_name = process_name(first_name)
    @last_name = process_name(last_name)
    @other_last_name = process_name(other_last_name) if other_last_name
    @alt_names = alt_names
    @relation = relation
  end

  def alt_names=(names)
    @alt_names = process_alt_names(names)
  end

  def alt_names_string
    alt_names.join(", ")
  end

  private

  def process_name(name)
    name.strip!
    name[0].upcase + name[1..-1]
  end
end

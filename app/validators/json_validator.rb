class JsonValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    JSON.parse(value)
  rescue
    record.errors.add(attribute, "is not valid JSON")
  end
end
class JsonValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    value && JSON.parse(value)
  rescue JSON::ParserError
    record.errors.add(attribute, "is not valid JSON")
  end
end
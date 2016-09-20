class JsonValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value.blank?
      value && JSON.parse(value)
    end
  rescue JSON::ParserError
    record.errors.add(attribute, "is not valid JSON")
  end
end
class DeployUniquenessValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    (record.project.deploys - [record]).each do |deploy|
      if deploy.name == value
        record.errors.add(attribute, 'name is already in use')
        break
      end
    end
  end
end
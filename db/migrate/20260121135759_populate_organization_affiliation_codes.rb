require 'securerandom'

class PopulateOrganizationAffiliationCodes < ActiveRecord::Migration[8.1]
  def up
    Organization.where(affiliation_code: nil).find_each do |org|
      org.update_column(:affiliation_code, SecureRandom.urlsafe_base64(24))
    end

    change_column_null :organizations, :affiliation_code, false
  end

  def down
    change_column_null :organizations, :affiliation_code, true
  end
end

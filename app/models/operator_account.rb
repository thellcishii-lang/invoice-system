# The SaaS operator (Everyone's合同会社) — separate from tenant users.
# Used only for the /operator sales dashboard that lists 販売先 (tenants).
class OperatorAccount < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true

  # Creates the first operator account from ENV on first use, because
  # FirstBootSeeder only runs while the tenants table is empty.
  def self.bootstrap!
    return if exists?

    create!(
      email: ENV["OPERATOR_EMAIL"].presence || "admin@agent-partners.space",
      password: ENV["OPERATOR_PASSWORD"].presence || "password"
    )
  end
end

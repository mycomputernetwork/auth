class AllowedEmail < ApplicationRecord
  include UuidPrimaryKey

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true

  def self.allows?(email) = exists?(email: email.to_s.strip.downcase)
end

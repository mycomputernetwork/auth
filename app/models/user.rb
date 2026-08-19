class User < ApplicationRecord
  has_many :sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  def self.from_google(auth)
    email = auth.info.email.to_s.strip.downcase
    return nil unless AllowedEmail.allows?(email)

    user = find_by(google_sub: auth.uid) || find_or_initialize_by(email: email)
    user.assign_attributes(google_sub: auth.uid, email: email, name: auth.info.name)
    user.save!
    user
  end

  def revoked? = revoked_at.present?

  def revoke!
    update!(revoked_at: Time.current)
    sessions.each { |session| BackchannelLogout.call(session) }
    sessions.destroy_all
  end
end

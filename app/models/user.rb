class User < ApplicationRecord
  include UuidPrimaryKey

  has_secure_password validations: false

  has_many :sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 12 }, confirmation: true, allow_nil: true

  scope :active, -> { where(revoked_at: nil) }

  def self.from_google(auth)
    email = auth.info.email.to_s.strip.downcase
    return nil unless AllowedEmail.allows?(email)

    user = find_by(google_sub: auth.uid) || find_or_initialize_by(email: email)
    return user if user.revoked?

    user.assign_attributes(google_sub: auth.uid, email: email, name: auth.info.name)
    user.save!
    user
  end

  def self.from_password(email, password)
    email = email.to_s.strip.downcase
    return nil unless AllowedEmail.allows?(email)

    authenticate_by(email: email, password: password.to_s)
  end

  def revoked? = revoked_at.present?

  def password? = password_digest.present?

  # An administrator handed this one over; it is theirs only once they pick their own.
  def must_change_password? = password? && password_changed_at.nil?

  def change_password(password, confirmation)
    assign_attributes(password: password, password_confirmation: confirmation, password_changed_at: Time.current)
    save
  end

  def revoke!
    update!(revoked_at: Time.current)
    sessions.each { |session| BackchannelLogout.call(session) }
    sessions.destroy_all
  end
end

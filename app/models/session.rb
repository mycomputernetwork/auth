class Session < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user

  has_secure_token :sid, length: 32

  scope :active, -> { joins(:user).where(users: { revoked_at: nil }) }

  def touch_seen!(request)
    update_columns(
      last_seen_at: Time.current,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
  end
end

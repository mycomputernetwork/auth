class LogoutDelivery < ApplicationRecord
  belongs_to :application, class_name: "Doorkeeper::Application"

  scope :failed, -> { where.not(status: "delivered") }

  def delivered? = status == "delivered"
end

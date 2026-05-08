class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :pairing_sessions, dependent: :destroy
  has_many :candidate_potholes, dependent: :destroy
  has_many :reviewed_candidate_potholes, class_name: "CandidatePothole", foreign_key: :reviewed_by_id, dependent: :nullify

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def latest_paired_android_device
    pairing_sessions.claimed.recently_claimed.first
  end
end

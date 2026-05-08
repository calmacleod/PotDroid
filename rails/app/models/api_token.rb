class ApiToken < ApplicationRecord
  TOKEN_PREFIX_LENGTH = 16

  has_secure_password :token, validations: false

  belongs_to :user

  validates :name, presence: true
  validates :token_digest, presence: true
  validates :token_prefix, presence: true, uniqueness: true

  def self.issue!(user:, name:)
    raw_token = "pd_#{SecureRandom.hex(32)}"
    api_token = user.api_tokens.create!(
      name: name,
      token: raw_token,
      token_prefix: raw_token.first(TOKEN_PREFIX_LENGTH)
    )

    [ api_token, raw_token ]
  end

  def self.authenticate(raw_token)
    return if raw_token.blank?

    api_token = find_by(token_prefix: raw_token.first(TOKEN_PREFIX_LENGTH))
    return unless api_token&.authenticate_token(raw_token)

    api_token.touch(:last_used_at)
    api_token
  end
end

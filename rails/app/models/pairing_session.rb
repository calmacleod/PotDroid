class PairingSession < ApplicationRecord
  CODE_LENGTH = 12
  EXPIRES_IN = 15.minutes

  has_secure_password :code, validations: false

  belongs_to :user
  belongs_to :api_token, optional: true

  validates :code_digest, presence: true
  validates :expires_at, presence: true

  scope :claimable, -> { where(claimed_at: nil).where("expires_at > ?", Time.current) }

  def self.issue_for!(user)
    raw_code = generate_code
    pairing_session = user.pairing_sessions.create!(
      code: normalize_code(raw_code),
      expires_at: EXPIRES_IN.from_now
    )

    [pairing_session, raw_code]
  end

  def self.claim!(raw_code:, device_name:)
    pairing_session = claimable.detect { |session| session.authenticate_code(normalize_code(raw_code)) }
    return unless pairing_session

    transaction do
      api_token, raw_token = ApiToken.issue!(
        user: pairing_session.user,
        name: device_name.presence || "Paired Android device"
      )
      pairing_session.update!(
        api_token: api_token,
        device_name: device_name.presence || "Paired Android device",
        claimed_at: Time.current
      )

      [pairing_session, raw_token]
    end
  end

  def expired?
    expires_at <= Time.current
  end

  def claimed?
    claimed_at.present?
  end

  def active?
    !expired? && !claimed?
  end

  def pairing_payload(raw_code:, api_base_url:)
    URI::Generic.build(
      scheme: "potdroid",
      host: "pair",
      query: URI.encode_www_form(api_base_url: api_base_url, code: raw_code)
    ).to_s
  end

  def qr_svg(raw_code:, api_base_url:)
    RQRCode::QRCode.new(pairing_payload(raw_code: raw_code, api_base_url: api_base_url)).as_svg(
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 6,
      standalone: true,
      use_path: true
    )
  end

  def self.normalize_code(raw_code)
    raw_code.to_s.upcase.gsub(/[^A-Z0-9]/, "")
  end

  def self.format_code(raw_code)
    normalize_code(raw_code).scan(/.{1,4}/).join("-")
  end

  def self.generate_code
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    code = Array.new(CODE_LENGTH) { alphabet[SecureRandom.random_number(alphabet.length)] }.join
    format_code(code)
  end
end

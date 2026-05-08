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

    [ pairing_session, raw_code ]
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

      [ pairing_session, raw_token ]
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
      query: URI.encode_www_form(u: api_base_url, c: raw_code)
    ).to_s
  end

  def qr_svg(raw_code:, api_base_url:)
    qr_code = RQRCode::QRCode.new(pairing_payload(raw_code: raw_code, api_base_url: api_base_url))
    module_size = 8
    quiet_modules = 8
    size = (qr_code.modules.size + (quiet_modules * 2)) * module_size
    path = qr_code.modules.each_with_index.flat_map do |row, row_index|
      row.each_with_index.filter_map do |dark, column_index|
        next unless dark

        x = (column_index + quiet_modules) * module_size
        y = (row_index + quiet_modules) * module_size
        "M#{x} #{y}h#{module_size}v#{module_size}h-#{module_size}z"
      end
    end.join

    <<~SVG.squish
      <svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}" viewBox="0 0 #{size} #{size}" shape-rendering="crispEdges" role="img" aria-label="PotDroid pairing QR code">
        <rect width="100%" height="100%" fill="#fff"/>
        <path d="#{path}" fill="#000"/>
      </svg>
    SVG
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

FactoryBot.define do
  factory :api_token do
    user
    name { "Android device" }
    transient do
      raw_token { "pd_#{SecureRandom.hex(32)}" }
    end
    token { raw_token }
    token_prefix { raw_token.first(ApiToken::TOKEN_PREFIX_LENGTH) }
  end
end

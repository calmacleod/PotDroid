# frozen_string_literal: true

Scalar.setup do |config|
  config.page_title = "PotDroid API Documentation"
  config.library_url = "/scalar-api-reference.js"
  config.configuration = {
    url: "/openapi.yml",
    theme: "default",
    layout: "modern",
    withDefaultFonts: false,
    agent: {
      disabled: true
    },
    authentication: {
      preferredSecurityScheme: "bearerAuth"
    }
  }
end

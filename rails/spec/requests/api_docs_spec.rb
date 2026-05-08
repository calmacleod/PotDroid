require "rails_helper"

RSpec.describe "API documentation", type: :request do
  it "serves self-hosted Scalar documentation" do
    get "/api-docs"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/scalar-api-reference.js")
    expect(response.body).to include("/openapi.yml")
    expect(response.body).not_to include("cdn.jsdelivr.net")
  end

  it "serves the OpenAPI specification" do
    get "/openapi.yml"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("openapi: 3.1.0")
    expect(response.body).to include("/api/v1/candidate_potholes")
  end
end

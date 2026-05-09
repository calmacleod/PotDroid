require "test_helper"

class ApiDocsTest < ActionDispatch::IntegrationTest
  test "serves self-hosted Scalar documentation" do
    get "/api-docs"

    assert_response :ok
    assert_includes response.body, "/scalar-api-reference.js"
    assert_includes response.body, "/openapi.yml"
    assert_not_includes response.body, "cdn.jsdelivr.net"
  end

  test "serves the OpenAPI specification" do
    get "/openapi.yml"

    assert_response :ok
    assert_includes response.body, "openapi: 3.1.0"
    assert_includes response.body, "/api/v1/candidate_potholes"
  end
end

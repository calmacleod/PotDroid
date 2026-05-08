module CitySubmissions
  Result = Data.define(
    :status,
    :external_request_id,
    :external_status,
    :payload,
    :message
  )
end

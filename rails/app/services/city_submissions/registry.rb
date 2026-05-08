module CitySubmissions
  class Registry
    CONNECTORS = {
      "ottawa_open311" => "CitySubmissions::Ottawa::Open311Connector"
    }.freeze

    def self.fetch(name = ENV.fetch("CITY_CONNECTOR", "ottawa_open311"))
      CONNECTORS.fetch(name).constantize.new
    end
  end
end

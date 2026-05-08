module CitySubmissions
  class Connector
    def submit(_candidate_pothole)
      raise NotImplementedError, "#{self.class.name} must implement #submit"
    end

    def status(_city_submission)
      raise NotImplementedError, "#{self.class.name} must implement #status"
    end
  end
end

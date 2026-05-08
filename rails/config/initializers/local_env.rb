if Rails.env.local?
  Rails.root.join(".env.local").then do |path|
    next unless path.exist?

    path.each_line do |line|
      line = line.strip
      next if line.blank? || line.start_with?("#")

      key, value = line.split("=", 2)
      next if key.blank? || value.nil?

      ENV[key] ||= value
    end
  end
end

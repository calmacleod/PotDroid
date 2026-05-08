module PotholeDetector
  class Error < StandardError; end
  class Unavailable < Error; end
  class InferenceError < Error; end
end

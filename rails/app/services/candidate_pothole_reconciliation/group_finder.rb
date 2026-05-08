require "set"

module CandidatePotholeReconciliation
  class GroupFinder
    Group = Struct.new(:candidates, :representative, keyword_init: true) do
      def started_at
        candidates.min_by(&:captured_at).captured_at
      end

      def ended_at
        candidates.max_by(&:captured_at).captured_at
      end
    end

    TIME_WINDOW = 90.seconds
    DISTANCE_METERS = 15.0
    EARTH_RADIUS_METERS = 6_371_000.0

    def initialize(scope, time_window: TIME_WINDOW, distance_meters: DISTANCE_METERS)
      @scope = scope
      @time_window = time_window
      @distance_meters = distance_meters
    end

    def call
      candidates = scope.pending_review.with_attached_image.order(:captured_at, :id).to_a
      grouped_ids = Set.new

      candidates.each_with_object([]) do |candidate, groups|
        next if grouped_ids.include?(candidate.id)

        group_candidates = connected_candidates(candidate, candidates, grouped_ids)
        next if group_candidates.size < 2

        group_candidates.each { |group_candidate| grouped_ids.add(group_candidate.id) }
        groups << Group.new(
          candidates: group_candidates.sort_by(&:captured_at),
          representative: group_candidates.max_by(&:detector_confidence)
        )
      end
    end

    private

    attr_reader :scope, :time_window, :distance_meters

    def connected_candidates(seed, candidates, grouped_ids)
      group = [ seed ]
      changed = true

      while changed
        changed = false
        candidates.each do |candidate|
          next if grouped_ids.include?(candidate.id) || group.include?(candidate)
          next unless group.any? { |group_candidate| likely_duplicate?(group_candidate, candidate) }

          group << candidate
          changed = true
        end
      end

      group
    end

    def likely_duplicate?(first, second)
      (first.captured_at - second.captured_at).abs <= time_window &&
        distance_between(first, second) <= distance_meters
    end

    def distance_between(first, second)
      first_latitude = radians(first.latitude.to_f)
      second_latitude = radians(second.latitude.to_f)
      latitude_delta = radians(second.latitude.to_f - first.latitude.to_f)
      longitude_delta = radians(second.longitude.to_f - first.longitude.to_f)

      haversine = Math.sin(latitude_delta / 2)**2 +
        Math.cos(first_latitude) * Math.cos(second_latitude) * Math.sin(longitude_delta / 2)**2

      2 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine))
    end

    def radians(degrees)
      degrees * Math::PI / 180.0
    end
  end
end

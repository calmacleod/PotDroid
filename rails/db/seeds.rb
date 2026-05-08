require Rails.root.join("lib/dev_seed_credentials")

unless Rails.env.development?
  puts "No seed data is configured for #{Rails.env}."
  return
end

require "faker"
require "stringio"

Faker::Config.locale = "en-CA"
Faker::Config.random = Random.new(31_337)

class DevelopmentSeeds
  POTHOLE_IMAGE_PATH = Rails.root.join("spec/fixtures/files/pothole.png")

  CANDIDATE_ROWS = [
    {
      captured_at: "2026-05-08 12:00:00 UTC",
      latitude: 45.4215,
      longitude: -75.6972,
      confidence: 0.91,
      status: :pending_review,
      heading: 180.0,
      speed: 12.5
    },
    {
      captured_at: "2026-05-08 12:08:00 UTC",
      latitude: 45.4241,
      longitude: -75.7008,
      confidence: 0.84,
      status: :confirmed,
      heading: 194.0,
      speed: 10.9
    },
    {
      captured_at: "2026-05-08 12:17:00 UTC",
      latitude: 45.4276,
      longitude: -75.6891,
      confidence: 0.63,
      status: :rejected,
      heading: 133.0,
      speed: 8.2
    },
    {
      captured_at: "2026-05-08 12:26:00 UTC",
      latitude: 45.4189,
      longitude: -75.7065,
      confidence: 0.96,
      status: :submitted,
      heading: 205.0,
      speed: 15.1
    },
    {
      captured_at: "2026-05-08 12:39:00 UTC",
      latitude: 45.4312,
      longitude: -75.6814,
      confidence: 0.79,
      status: :closed,
      heading: 91.0,
      speed: 6.7
    }
  ].freeze

  def run
    driver = seed_driver
    seed_api_token(driver)
    seed_candidates(driver)

    puts "\nSeeded development data"
    puts "  Email:    #{DevSeedCredentials::EMAIL}"
    puts "  Password: #{DevSeedCredentials::PASSWORD}"
    puts "  API token: #{DevSeedCredentials::API_TOKEN}"
  end

  private

  def seed_driver
    User.find_or_initialize_by(email_address: DevSeedCredentials::EMAIL).tap do |user|
      user.password = DevSeedCredentials::PASSWORD
      user.save!
    end
  end

  def seed_api_token(user)
    token_prefix = DevSeedCredentials::API_TOKEN.first(ApiToken::TOKEN_PREFIX_LENGTH)
    user.api_tokens.where(name: "Seed Android token").where.not(token_prefix: token_prefix).destroy_all

    user.api_tokens.find_or_initialize_by(token_prefix: token_prefix).tap do |token|
      token.name = "Seed Android token"
      token.token = DevSeedCredentials::API_TOKEN
      token.save!
    end
  end

  def seed_candidates(user)
    CANDIDATE_ROWS.each_with_index do |row, index|
      captured_at = Time.zone.parse(row.fetch(:captured_at))
      candidate = user.candidate_potholes.find_or_initialize_by(captured_at: captured_at)
      candidate.assign_attributes(candidate_attributes(row, index, user))
      attach_pothole_image(candidate)
      candidate.save!
      seed_city_submission(candidate) if candidate.submitted? || candidate.closed?
    end
  end

  def candidate_attributes(row, index, reviewer)
    status = row.fetch(:status)

    {
      latitude: row.fetch(:latitude),
      longitude: row.fetch(:longitude),
      heading: row.fetch(:heading),
      speed: row.fetch(:speed),
      detector_confidence: row.fetch(:confidence),
      detector_model_version: "dev-detector-#{index + 1}",
      bounding_box: seeded_bounding_box(index),
      status: status,
      reviewed_by: status == :pending_review ? nil : reviewer,
      reviewed_at: status == :pending_review ? nil : Time.zone.parse(row.fetch(:captured_at)) + 10.minutes,
      submitted_at: %i[ submitted closed ].include?(status) ? Time.zone.parse(row.fetch(:captured_at)) + 30.minutes : nil
    }
  end

  def seeded_bounding_box(index)
    Faker::Config.random = Random.new(9000 + index)

    left = Faker::Number.between(from: 0.08, to: 0.22).round(2)
    top = Faker::Number.between(from: 0.42, to: 0.58).round(2)
    width = Faker::Number.between(from: 0.16, to: 0.28).round(2)
    height = Faker::Number.between(from: 0.10, to: 0.18).round(2)

    {
      left: left,
      top: top,
      right: (left + width).round(2),
      bottom: (top + height).round(2)
    }
  end

  def attach_pothole_image(candidate)
    return if candidate.image.attached? &&
      candidate.image.blob.filename.to_s == "seed-pothole.png" &&
      candidate.image.blob.byte_size == POTHOLE_IMAGE_PATH.size

    candidate.image.purge if candidate.image.attached?
    candidate.image.attach(
      io: StringIO.new(POTHOLE_IMAGE_PATH.binread),
      filename: "seed-pothole.png",
      content_type: "image/png"
    )
  end

  def seed_city_submission(candidate)
    Faker::Config.random = Random.new(12_000 + candidate.id)

    submission = candidate.city_submission || candidate.build_city_submission
    submission.assign_attributes(
      connector: "ottawa_open311",
      status: candidate.closed? ? :closed : :submitted,
      submitted_at: candidate.submitted_at,
      external_request_id: "OTT-#{candidate.id.to_s.rjust(6, "0")}",
      external_status: candidate.closed? ? "closed" : "open",
      last_checked_at: candidate.submitted_at + 45.minutes,
      response_payload: {
        service_name: "Roadway pothole",
        address: Faker::Address.street_address,
        ward: Faker::Address.community
      }
    )
    submission.save!
    event = submission.city_submission_events.find_or_initialize_by(event_type: "status_polled")
    event.message = "Seeded status #{submission.external_status}."
    event.payload = { external_status: submission.external_status }
    event.save!
    submission.city_submission_events.where(event_type: "status_polled").where.not(id: event.id).destroy_all
  end
end

DevelopmentSeeds.new.run

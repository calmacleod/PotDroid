class CandidatePothole < ApplicationRecord
  belongs_to :user
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_one :city_submission, dependent: :destroy
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 320, 240 ]
  end

  enum :status, {
    pending_review: 0,
    confirmed: 1,
    rejected: 2,
    submitted: 3,
    closed: 4
  }

  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :detector_confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :captured_at, presence: true
  validate :image_is_attached

  scope :recent_first, -> { order(captured_at: :desc, created_at: :desc) }
  scope :with_status, ->(status) { status.present? && statuses.key?(status) ? where(status: status) : all }

  def confirm!(reviewer:)
    update!(status: :confirmed, reviewed_by: reviewer, reviewed_at: Time.current)
  end

  def reject!(reviewer:)
    update!(status: :rejected, reviewed_by: reviewer, reviewed_at: Time.current)
  end

  def mark_submitted!(external_status: nil)
    update!(status: :submitted, submitted_at: Time.current)
    city_submission&.update!(external_status: external_status) if external_status.present?
  end

  private

  def image_is_attached
    errors.add(:image, "must be attached") unless image.attached?
  end
end

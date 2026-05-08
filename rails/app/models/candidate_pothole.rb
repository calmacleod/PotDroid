class CandidatePothole < ApplicationRecord
  belongs_to :user
  belongs_to :reviewed_by, class_name: "User", optional: true
  belongs_to :duplicate_of, class_name: "CandidatePothole", optional: true
  has_many :duplicates, class_name: "CandidatePothole", foreign_key: :duplicate_of_id, dependent: :nullify
  has_one :city_submission, dependent: :destroy
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 320, 240 ]
  end

  enum :status, {
    pending_review: 0,
    confirmed: 1,
    rejected: 2,
    submitted: 3,
    closed: 4,
    duplicate: 5
  }

  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :detector_confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :captured_at, presence: true
  validate :image_is_attached
  validate :duplicate_points_to_same_user
  validate :duplicate_does_not_point_to_self

  scope :recent_first, -> { order(captured_at: :desc, created_at: :desc) }
  scope :with_status, ->(status) { status.present? && statuses.key?(status) ? where(status: status) : all }

  def confirm!(reviewer:)
    update!(status: :confirmed, reviewed_by: reviewer, reviewed_at: Time.current)
  end

  def reject!(reviewer:)
    update!(status: :rejected, reviewed_by: reviewer, reviewed_at: Time.current)
  end

  def mark_duplicate_of!(representative:, reviewer:)
    update!(status: :duplicate, duplicate_of: representative, reviewed_by: reviewer, reviewed_at: Time.current)
  end

  def mark_submitted!(external_status: nil)
    update!(status: :submitted, submitted_at: Time.current)
    city_submission&.update!(external_status: external_status) if external_status.present?
  end

  private

  def image_is_attached
    errors.add(:image, "must be attached") unless image.attached?
  end

  def duplicate_points_to_same_user
    return if duplicate_of.blank? || duplicate_of.user_id == user_id

    errors.add(:duplicate_of, "must belong to the same user")
  end

  def duplicate_does_not_point_to_self
    return if duplicate_of.blank?
    return unless duplicate_of == self || duplicate_of_id == id

    errors.add(:duplicate_of, "cannot be itself")
  end
end

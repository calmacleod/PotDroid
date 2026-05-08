module ApplicationHelper
  def candidate_bounding_box(candidate)
    box = normalized_bounding_box(candidate.bounding_box)
    return if box.blank?

    tag.span(
      class: "detection-box",
      style: [
        "--box-left: #{box[:left]}%;",
        "--box-top: #{box[:top]}%;",
        "--box-width: #{box[:right] - box[:left]}%;",
        "--box-height: #{box[:bottom] - box[:top]}%;"
      ].join(" "),
      aria: { label: "Pothole bounding box" }
    )
  end

  private

  def normalized_bounding_box(raw_box)
    return if raw_box.blank?

    left = bounding_box_value(raw_box, "left")
    top = bounding_box_value(raw_box, "top")
    right = bounding_box_value(raw_box, "right")
    bottom = bounding_box_value(raw_box, "bottom")
    return if [ left, top, right, bottom ].any?(&:nil?)
    return unless right > left && bottom > top

    {
      left: (left.clamp(0.0, 1.0) * 100).round(4),
      top: (top.clamp(0.0, 1.0) * 100).round(4),
      right: (right.clamp(0.0, 1.0) * 100).round(4),
      bottom: (bottom.clamp(0.0, 1.0) * 100).round(4)
    }
  end

  def bounding_box_value(raw_box, key)
    Float(raw_box[key] || raw_box[key.to_sym], exception: false)
  end
end

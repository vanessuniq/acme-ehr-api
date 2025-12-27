class Record < ApplicationRecord
  belongs_to :import_run, optional: true

  # Validations
  validates :resource_id, presence: true, uniqueness: { scope: :resource_type }
  validates :resource_type, presence: true
  validates :extracted_data, presence: true
  validates :raw_data, presence: true

  # Scopes
  scope :by_resource_type, ->(type) { where(resource_type: type).order(created_at: :desc) }
  scope :by_subject, ->(subject) { where(subject_reference: subject).order(created_at: :desc) if subject.present? }
  scope :by_resource_type_and_subject, ->(type, subject) {
    where(resource_type: type, subject_reference: subject).order(created_at: :desc)
  }

  def self.filter(resource_type: nil, subject: nil)
    rt = normalize_resource_type(resource_type)

    if rt.present? && subject.present?
      by_resource_type_and_subject(rt, subject)
    elsif resource_type.present?
      by_resource_type(rt)
    elsif subject.present?
      by_subject(subject)
    else
      all.order(created_at: :desc)
    end
  end

  def self.unique_subjects_count
    where.not(subject_reference: nil).distinct.count(:subject_reference)
  end

  def self.normalize_resource_type(resource_type)
    case resource_type
    when Array
      resource_type.map(&:to_s).map(&:strip).reject(&:blank?)
    when String
      resource_type.strip
    else
      resource_type
    end
  end

  private_class_method :normalize_resource_type
end

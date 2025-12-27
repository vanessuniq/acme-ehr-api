class ImportRun < ApplicationRecord
  has_many :records, dependent: :nullify

  # Validations
  validates :status, inclusion: { in: %w[pending processing completed failed] }
  validates :total_lines, numericality: { greater_than_or_equal_to: 0 }
  validates :successful_records, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :with_errors, -> { where.not(validation_errors: []) }
end

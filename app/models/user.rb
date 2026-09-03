class User < ApplicationRecord
  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  AVATAR_MAX_BYTES = 5.megabytes

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one_attached :avatar

  enum :role, { no_admin: 0, admin: 1 }

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :full_name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :avatar_must_be_a_supported_image, if: -> { avatar.attached? }

  private
    def avatar_must_be_a_supported_image
      errors.add(:avatar, "must be a PNG, JPEG or WEBP image") unless avatar.content_type.in?(AVATAR_CONTENT_TYPES)
      errors.add(:avatar, "is too large (max #{AVATAR_MAX_BYTES / 1.megabyte}MB)") if avatar.byte_size > AVATAR_MAX_BYTES
    end
end

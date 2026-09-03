class User < ApplicationRecord
  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  AVATAR_MAX_BYTES = 5.megabytes

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one_attached :avatar

  enum :role, { no_admin: 0, admin: 1 }

  attr_accessor :avatar_url

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :full_name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_blank: true
  validate :avatar_must_be_a_supported_image, if: -> { avatar.attached? }
  validate :avatar_url_must_be_http, if: -> { avatar_url.present? }

  after_commit :enqueue_avatar_download, if: -> { avatar_url.present? }
  after_commit :broadcast_dashboard_counts, if: -> { destroyed? || previously_new_record? || saved_change_to_role? }

  private
    def avatar_must_be_a_supported_image
      errors.add(:avatar, "must be a PNG, JPEG or WEBP image") unless avatar.content_type.in?(AVATAR_CONTENT_TYPES)
      errors.add(:avatar, "is too large (max #{AVATAR_MAX_BYTES / 1.megabyte}MB)") if avatar.byte_size > AVATAR_MAX_BYTES
    end

    def avatar_url_must_be_http
      uri = URI.parse(avatar_url)
      errors.add(:avatar_url, "must be a valid http(s) URL") unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(:avatar_url, "must be a valid http(s) URL")
    end

    def enqueue_avatar_download
      AvatarDownloadJob.perform_later(id, avatar_url)
    end

    def broadcast_dashboard_counts
      Turbo::StreamsChannel.broadcast_replace_to(
        "admin_dashboard",
        target: "dashboard_counts",
        partial: "admin/dashboards/counts",
        locals: { total_users: User.count, users_by_role: User.group(:role).count }
      )
    end
end

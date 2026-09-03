class AvatarDownloadJob < ApplicationJob
  queue_as :default

  def perform(user_id, url)
    user = User.find_by(id: user_id)
    return unless user

    result = AvatarFetcher.new(url).fetch
    user.avatar.attach(io: result.io, filename: result.filename, content_type: result.content_type)
  rescue AvatarFetcher::FetchError => e
    Rails.logger.warn("AvatarDownloadJob: failed to fetch avatar for user #{user_id} from #{url}: #{e.message}")
  end
end

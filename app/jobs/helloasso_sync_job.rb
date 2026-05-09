class HelloassoSyncJob < ApplicationJob
  queue_as :default

  def perform(edition_id)
    edition = Edition.find(edition_id)
    Helloasso::SyncService.new(edition).call
  rescue => e
    Rails.logger.error("[HelloassoSyncJob] Failed for edition #{edition_id}: #{e.message}")
    raise
  end
end

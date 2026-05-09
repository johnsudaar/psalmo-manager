Sidekiq::Cron::Job.create(
  name:  "HelloAsso sync — édition courante",
  cron:  "*/30 * * * *",
  class: "HelloassoSyncJob",
  args:  [ -> { Edition.order(year: :desc).first&.id } ]
)

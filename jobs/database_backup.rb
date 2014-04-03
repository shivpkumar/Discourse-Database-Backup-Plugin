module Jobs
  class DatabaseBackupJob < ::Jobs::Scheduled
    daily at: 4.hours
    sidekiq_options retry: false

    def execute(args)
      DatabaseBackup::DatabaseBackuper.new.run
    end
  end
end

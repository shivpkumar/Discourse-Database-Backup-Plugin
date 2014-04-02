module DatabaseBackup

  class FilenameMissingError < RuntimeError; end

  class DatabaseBackuper

    def initialize
      initialize_state
    end

    def run
      log "[STARTED]"
      ensure_directory_exists(@tmp_directory)
      copy_archive_to_tmp_directory
      unzip_archive
      extract_dump
      restore_dump
    rescue SystemExit
      log "Database backup was cancelled!"
    rescue Exception => ex
      log "EXCEPTION: " + ex.message
      log ex.backtrace.join("\n")
    else
      @success = true
    ensure
      clean_up
      @success ? log("[SUCCESS]") : log("[FAILED]")
    end

    protected

    def initialize_state
      @success = false
      @current_db = RailsMultisite::ConnectionManagement.current_db
      @timestamp = Time.now.strftime("%Y-%m-%d-%H%M%S")
      @tmp_directory = File.join(Rails.root, "tmp", "restores", @current_db, @timestamp)
      @filename = Backup.all.first.filename
      @archive_filename = File.join(@tmp_directory, @filename)
      @tar_filename = @archive_filename[0...-3]
      @dump_filename = File.join(@tmp_directory, BackupRestore::DUMP_FILE)
      @logger = Logger.new(File.join(Rails.root, "plugins", "background_jobs", "logs", "database_backup.log"))
    end

    def ensure_directory_exists(directory)
      log "Making sure #{directory} exists..."
      FileUtils.mkdir_p(directory)
    end

    def copy_archive_to_tmp_directory
      log "Copying archive to tmp directory..."
      source = File.join(Backup.base_directory, @filename)
      `cp #{source} #{@archive_filename}`
    end

    def unzip_archive
      log "Unzipping archive..."
      FileUtils.cd(@tmp_directory) { `gzip --decompress #{@archive_filename}` }
    end

    def extract_dump
      log "Extracting dump file..."
      FileUtils.cd(@tmp_directory) { `tar --extract --file #{@tar_filename} #{BackupRestore::DUMP_FILE}` }
    end

    def restore_dump
      log "Backing up database... (can be quite long)"

      logs = Queue.new
      psql_running = true
      has_error = false

      Thread.new do
        while psql_running
          message = logs.pop.strip
          has_error ||= (message =~ /ERROR:/)
          log(message) unless message.blank?
        end
      end

      IO.popen("#{psql_command} 2>&1") do |pipe|
        begin
          while line = pipe.readline
            logs << line
          end
        rescue EOFError
          # finished reading...
        ensure
          psql_running = false
          logs << ""
        end
      end

      # psql does not return a valid exit code when an error happens
      raise "psql failed" if has_error
    end

    def psql_command
      [ "PGPASSWORD='#{ENV['DB_BACKUP_PASSWORD']}'",      # pass the password to psql
        "psql",                                           # the psql command
        "--dbname='#{ENV['DB_BACKUP_DATABASE_NAME']}'",   # connect to database *dbname*
        "--file='#{@dump_filename}'",                     # read the dump
        "--single-transaction",                           # all or nothing (also runs COPY commands faster)
        "--host='#{ENV['DB_BACKUP_HOST']}'",              # the hostname to connect to
        "--username='#{ENV['DB_BACKUP_USERNAME']}'"       # the username to connect as
      ].join(" ")
    end

    def clean_up
      log "Cleaning stuff up..."
      remove_tmp_directory
      log "Finished!"
    end

    def remove_tmp_directory
      log "Removing tmp '#{@tmp_directory}' directory..."
      FileUtils.rm_rf(@tmp_directory) if Dir[@tmp_directory].present?
    rescue
      log "Something went wrong while removing the following tmp directory: #{@tmp_directory}"
    end

    def log(message)
      puts(message) rescue nil
      publish_log(message) rescue nil
    end

    def publish_log(message)
      return unless @logger
      @logger.info(message)
    end
  end
end

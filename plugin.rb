# name: background_jobs
# about: run background jobs from plugin
# authors: shiv kumar

after_initialize do
  #lib
  load File.expand_path("../lib/database_backup.rb", __FILE__)  
  
  # background job
  load File.expand_path("../jobs/database_backup.rb", __FILE__)
end
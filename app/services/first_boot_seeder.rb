# Loads the seed data on the very first boot, while the database is still
# empty. The entrypoint only runs `db:prepare`, which migrates an existing
# database but never runs the seeds — and the first deploy's db:prepare
# failed on the database connection, so the seeds never ran at all (that is
# why the seeded admin login was rejected on the live app on 2026-11-23).
# bin/docker-entrypoint calls this (via `bin/rails runner`) when
# RUN_SEED_IF_EMPTY=true, right after db:prepare. The guard makes it a
# no-op on every later boot, so leaving the environment variable in place
# is harmless once data exists. Same pattern as agency-system's
# FirstBootSeeder (commit a84e097).
class FirstBootSeeder
  def self.call
    new.call
  end

  # Returns true when seed data was loaded, false when data already existed.
  def call
    return false if Tenant.exists?

    Rails.application.load_seed
    true
  end
end

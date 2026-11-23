class ScheduledDeliveriesJob < ApplicationJob
  queue_as :default

  def perform
    ScheduledDelivery.due.find_each(&:execute!)
  end
end

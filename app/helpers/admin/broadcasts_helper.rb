module Admin::BroadcastsHelper
  def status_badge_class(model)
    color = case model.status.to_sym
    when :created, :preparing
      :warning
    when :ready
      :primary
    when :pending
      :warning
    when :sending
      :warning
    when :sent, :accepted, :delivered
      :info
    when :failed, :rejected
      :danger
    when :opened, :clicked
      :success
    else
      :dark
    end

    "badge badge-#{color}"
  end
end

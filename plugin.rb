# name: hive-community-webhooks
# version: 1.0
# authors: Hiveologie (nikola@hiveologie.com)

PLUGIN_NAME = 'site_visited_webhooks'.freeze

enabled_site_setting :site_visited_webhooks_enabled

after_initialize do
  register_seedfu_fixtures(Rails.root.join("plugins", "site-visited-webhooks", "db", "fixtures").to_s)

  add_model_callback(:notification, :after_commit, on: :create) do
    # you can enqueue web hooks anywhere outside the AR transaction
    # provided that web hook event type exists
    WebHook.enqueue_hooks(:notification, # event type name
                          notification_id: self.id, # pass the relevant record id
                          # event name appears in the header of webhook payload
                          event_name: "notification_#{Notification.types[self.notification_type]}_created")
  end

  add_model_callback(DiscoursePageVisits::PageVisit, :after_commit, on: :create) do
    # you can enqueue web hooks anywhere outside the AR transaction
    # provided that web hook event type exists
    Rails.logger.warn "FromAddModelCallback: #{self}"
    WebHook.enqueue_hooks(:page_visit, # event type name
                          page_visit_id: self.id, # pass the relevant record id
                          # event name appears in the header of webhook payload
                          event_name: "page_visit_#{self.id}_created")
  end

  %i(user_logged_in user_logged_out).each do |event|
    DiscourseEvent.on(event) do |user|
      WebHook.enqueue_hooks(:session, user_id: user.id, event_name: event.to_s)
    end
  end

  Jobs::EmitWebHookEvent.class_eval do
    # the method name should always be setup_<event type name>(args)
    def setup_notification(args)
      notification = Notification.find_by(id: args[:notification_id])
      return if notification.blank? # or raise an exception if you like

      # here you can define the serializer, you can also create a new serializer to prune the payload
      # See also: `WebHookPostSerializer`, `WebHookTopicViewSerializer`
      args[:payload] = NotificationSerializer.new(notification, scope: guardian, root: false).as_json
    end

    def setup_page_visit(args)
      Rails.logger.warn "FromSetup: args: #{args}"
      page_visit = DiscoursePageVisits::PageVisit.find_by(id: args[:page_visit_id])
      return if page_visit.blank?
      args[:payload] = DiscoursePageVisits::PageVisitSerializer.new(page_visit, scope: guardian, root: false).as_json
    end

    def setup_session(args)
      user = User.find_by(id: args[:user_id])
      return if user.blank?
      args[:payload] = UserSerializer.new(user, scope: guardian, root: false).as_json
    end
  end

  # `instance` is a live `Jobs::EmitWebHookEvent`
  # `body` is the object about to be sent (JSON serialized).
  # In this filter, you have the power to modify it as your wish
  Plugin::Filter.register(:after_build_web_hook_body) do |instance, body|
    if body[:session]
      body[:user_session] = body.delete :session
    end

    body # remember to return the object, otherwise the payload would be empty
  end

end

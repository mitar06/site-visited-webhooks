WebHookEventType.seed do |b|
  b.id = 100 # start with a relative large number so it doesn't conflict with the core type
  b.name = "notification"
end

WebHookEventType.seed do |b|
  b.id = 101
  b.name = "session"
end


WebHookEventType.seed do |b|
  b.id = 110
  b.name = "page_visits"
end
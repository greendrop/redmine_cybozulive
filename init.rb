require_dependency 'cybozulive_listener'

Redmine::Plugin.register :redmine_cybozulive do
  name 'Redmine Cybozulive plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  settings \
    :default => {},
    :partial => 'settings/cybozulive_settings'
end

require 'redmine' 

ActionDispatch::Callbacks.to_prepare do
  Issue.send(:include, IssueNumberPatch) unless Issue.included_modules.include?(IssueNumberPatch)
end

Redmine::Plugin.register :issue_number_per_project do
  name 'Issue Number Per Project plugin'
  author 'Invent.to'
  description 'Creates an entity to do the relationship with issues Git'
  version '0.0.1'
#  url 'http://example.com/path/to/plugin'
#  author_url 'http://example.com/about'
end

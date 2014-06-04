# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'iconv'
require 'open-uri'

class Changeset < ActiveRecord::Base
  belongs_to :repository
  belongs_to :user
  has_many :filechanges, :class_name => 'Change', :dependent => :delete_all
  has_and_belongs_to_many :issues
  has_and_belongs_to_many :parents,
                          :class_name => "Changeset",
                          :join_table => "#{table_name_prefix}changeset_parents#{table_name_suffix}",
                          :association_foreign_key => 'parent_id', :foreign_key => 'changeset_id'
  has_and_belongs_to_many :children,
                          :class_name => "Changeset",
                          :join_table => "#{table_name_prefix}changeset_parents#{table_name_suffix}",
                          :association_foreign_key => 'changeset_id', :foreign_key => 'parent_id'

  acts_as_event :title => Proc.new {|o| o.title},
                :description => :long_comments,
                :datetime => :committed_on,
                :url => Proc.new {|o| {:controller => 'repositories', :action => 'revision', :id => o.repository.project, :repository_id => o.repository.identifier_param, :rev => o.identifier}}

  acts_as_searchable :columns => 'comments',
                     :include => {:repository => :project},
                     :project_key => "#{Repository.table_name}.project_id",
                     :date_column => 'committed_on'

  acts_as_activity_provider :timestamp => "#{table_name}.committed_on",
                            :author_key => :user_id,
                            :find_options => {:include => [:user, {:repository => :project}]}

  validates_presence_of :repository_id, :revision, :committed_on, :commit_date
  validates_uniqueness_of :revision, :scope => :repository_id
  validates_uniqueness_of :scmid, :scope => :repository_id, :allow_nil => true

  scope :visible,
     lambda {|*args| { :include => {:repository => :project},
                                          :conditions => Project.allowed_to_condition(args.shift || User.current, :view_changesets, *args) } }

  after_create :scan_for_issues
  before_create :before_create_cs

  cattr_accessor :access_token

  def revision=(r)
    write_attribute :revision, (r.nil? ? nil : r.to_s)
  end

  # Returns the identifier of this changeset; depending on repository backends
  def identifier
    if repository.class.respond_to? :changeset_identifier
      repository.class.changeset_identifier self
    else
      revision.to_s
    end
  end

  def committed_on=(date)
    self.commit_date = date
    super
  end

  # Returns the readable identifier
  def format_identifier
    if repository.class.respond_to? :format_changeset_identifier
      repository.class.format_changeset_identifier self
    else
      identifier
    end
  end

  def project
    repository.project
  end

  def author
    user || committer.to_s.split('<').first
  end

  def before_create_cs
    self.committer = self.class.to_utf8(self.committer, repository.repo_log_encoding)
    self.comments  = self.class.normalize_comments(
                       self.comments, repository.repo_log_encoding)
    self.user = repository.find_committer_user(self.committer)
  end

  def scan_for_issues
    scan_comment_for_issue_ids
  end

  TIMELOG_RE = /
    (
    ((\d+)(h|hours?))((\d+)(m|min)?)?
    |
    ((\d+)(h|hours?|m|min))
    |
    (\d+):(\d+)
    |
    (\d+([\.,]\d+)?)h
    )
    /x

  def scan_comment_for_issue_ids
    return if comments.blank?
    # keywords used to reference issues

    ref_keywords = Setting.commit_ref_keywords.downcase.split(",").collect(&:strip)
    ref_keywords_any = ref_keywords.delete('*')
    # keywords used to fix issues
    fix_keywords = Setting.commit_fix_keywords.downcase.split(",").collect(&:strip)

    kw_regexp = (ref_keywords + fix_keywords).collect{|kw| Regexp.escape(kw)}.join("|")

    referenced_issues = []
    action = ""
    add_time_entry = false
    comments.scan(/([\s\(\[,-]|^)((#{kw_regexp})[\s:]+)?(#\d+\s+(#{TIMELOG_RE})?([\s,;&]+#\d+\s+(#{TIMELOG_RE})?)*)(?=[[:punct:]]|\s|<|$)/i) do |match|
      action, refs = match[2], match[3]
      logger.info ["---->ACTION, REFS:", comments, kw_regexp.inspect, action, refs].join("\n")
      next unless action.present? || ref_keywords_any
      info = {}
      if not self.user
        logger.info "Changeset sem usuario? #{self.inspect}"
        return
      end
      info[:user] = self.user.login
      comments.scan(/pai?r (com)?[^@]*@(\w+)(.{0,2}@(\w+))?(.{0,2}@(\w+))?/) do |pair|
        if (par = pair[1]) and par != info[:user] 
          info[:pair1] = par
        end
        if (par = pair[3]) and par != info[:user] and par != pair[1]
          info[:pair2] = par
        end
        if (par = pair[5]) and par != info[:user] and par != pair[1] and par != pair[3]
          info[:pair3] = par         
        end
      end 

      import_issue
      info.values.each do |user|
	usuario = User.find_by_login(user.gsub(/^jonatasdp$/,"jonatas").gsub(/^marlon$/,"marlonscalabrin"))
        has_hour = false
   	refs.scan(/#(\d+)(\s+(#{TIMELOG_RE}))?/).each do |m|
          has_hour = true
          issue, hours = find_referenced_issue_by_issue_number(m[1].to_i), m[3]
          if issue
            referenced_issues << issue
            forward_status_issue(issue, action.to_s.downcase, fix_keywords)
	    fix_issue(issue, usuario) if fix_keywords.include?(action.to_s.downcase)
          end
          logger.info "Adicionando Time forX: #{comments}"
          add_time_entry = true
	  log_time(issue, hours, usuario, comments) if hours && Setting.commit_logtime_enabled?
	end
        if not has_hour
          info.values.each do |user|
            refs.scan(/\s+(#{TIMELOG_RE})/).each do |m|
              hours = m[1]
              logger.info "Adicionando Time for0: #{comments}"
              add_time_entry = true
              log_time(nil, hours, usuario, comments) if hours and hours.length > 0 && Setting.commit_logtime_enabled?
            end
          end
        end
        if not add_time_entry
          info.values.each do |user|
            comments.scan(/\s+(#{TIMELOG_RE})/).each do |m|
              hours = m[1]
              logger.info "Adicionando Time forK: #{comments}"
              add_time_entry = true
              log_time(nil, hours, usuario, comments) if hours and hours.length > 0 && Setting.commit_logtime_enabled?
            end
          end
        end
      end
    end
    if not add_time_entry
      info = {}
      if not self.user
        logger.info "Changeset sem usuario? #{self.inspect}"
        return
      end
      info[:user] = self.user.login

      comments.scan(/pair (com)?[^@]*@(\w+)(.{0,2}@(\w+))?(.{0,2}@(\w+))?/) do |pair|
        if (par = pair[1]) and par != info[:user] 
          info[:pair1] = par
        end
        if (par = pair[3]) and par != info[:user] and par != pair[1]
          info[:pair2] = par
        end
        if (par = pair[5]) and par != info[:user] and par != pair[1] and par != pair[3]
          info[:pair3] = par         
        end
      end 

      issue = nil
      if comments =~ /(#{kw_regexp})+.#(\d+)/
        action = $1
        issue = find_referenced_issue_by_issue_number($2)
        forward_status_issue(issue, action.to_s.downcase, fix_keywords)
        referenced_issues << issue
      end
      info.values.each do |user|
	usuario = User.find_by_login(user.gsub(/^jonatasdp$/,"jonatas").gsub(/^marlon$/,"marlonscalabrin"))
   	comments.scan(/[\.\s,](#{TIMELOG_RE})/).each do |m|
	  fix_issue(issue, usuario) if not issue.nil? and fix_keywords.include?(action.to_s.downcase)
          hours = m[1]
          if usuario and hours and hours.length > 0 && Setting.commit_logtime_enabled?
            logger.info "Adicionando Time for: #{comments}"
	    log_time(issue, hours, usuario, comments)
            add_time_entry = true
          else
            logger.info "Nao adicionou #{user}, #{hours}"
          end
	end
      end
    end
    if not add_time_entry
      logger.warn "Sem TimeEntry para: '#{comments}'"
    end
    referenced_issues = referenced_issues.compact
    self.issues = referenced_issues.uniq if not referenced_issues.empty? 
    self.save
  end

  def forward_status_issue issue, action, fix_keywords
    statuses_closed = IssueStatus.where(:is_closed => true).map(&:id)
    # se não está fechada ou não está fechando a issue
    if issue and not statuses_closed.include?(issue.status_id) and not fix_keywords.include?(action)
      if issue.status_id == 7 # 7 == Aguardando 
        wf = WorkflowTransition.where(:old_status_id => 7).first
        issue.status_id = wf.new_status_id
        issue.save
      end
    end
  end

  def import_issue 
    identifier = project.identifier
    project_id = project.id

    if identifier and identifier.to_s != ""
      closed_issues = []
      closed_issues = ActiveSupport::JSON.decode(open("https://api.github.com/repos/#{repository.github_repo}/issues?state=closed&per_page=1000&access_token=#{access_token}").read)
      puts "JSON >>>>>>>>>>>>>>>>>>>>>>> #{closed_issues}"
      closed_issues.each do |closed_issue|
        if IssueNumber.joins(:issue).where("number = #{closed_issues["number"]} and project_id = #{project_id} and repository_id=#{repository.id}").empty?
         begin
          issue = Issue.new(
              'subject' => closed_issue["title"],
              'description' => closed_issue["body"],
              'created_on' => closed_issue["created_at"],
              'updated_on' => closed_issue["updated_at"],
              'start_date' => closed_issue["created_at"],
              'is_private' => 'f',
              'tracker_id' => 2, # Tipo = Funcionalidade
              'project_id' => project_id, # Project Identifier
              'status_id' => 5, # Status ID, 5 = fechda, 2 = em andamento
              'done_ratio' => 100,
              'priority_id' => 2, #2 = normal
              'author_id' => User.find_by_login(closed_issue["user"]["login"].downcase).id
          );
          issue.number = closed_issue["number"].to_i
          issue.origin = "github"
          issue.repository = repository
  
          if !issue.save
            p "=====>ERRORS TO SAVING ISSUE:", issue.errors.full_messages
          end
         rescue
         end
        end
      end

      opened_issues = ActiveSupport::JSON.decode(open("https://api.github.com/repos/#{repository.github_repo}/issues?state=opened&per_page=1000&access_token=#{access_token}").read)
  
      opened_issues.each do |opened_issue|
        if IssueNumber.joins(:issue).where("number = #{opened_issues["number"]} and project_id = #{project_id} and repository_id=#{repository.id}").empty?
         begin
          issue = Issue.new(
              'subject' => opened_issue["title"],
              'description' => opened_issue["body"],
              'created_on' => opened_issue["created_at"],
              'updated_on' => opened_issue["updated_at"],
              'start_date' => opened_issue["created_at"],
              'is_private' => 'f',
              'tracker_id' => 2, # Tipo = Funcionalidade
              'project_id' => project_id, # Project Identifier
              'status_id' => 2,
              'priority_id' => 2, #2 = normal
              'author_id' => User.find_by_login(opened_issue["user"]["login"].downcase).id
          );
          issue.number = opened_issue["number"].to_i
          issue.origin = "github"
          issue.repository = repository
  
          if !issue.save
            p "=====>ERRORS TO SAVING ISSUE:", issue.errors.full_messages
          end
         rescue
         end
        end
      end
    end
	rescue
  end
=begin

def extrair_horas string
  info = {}
  if string =~ /(pair|pair com) @(\w+)(, ?@(\w+))?/
    info[:pair] = $2
    if $4
      info[:pair] = [$2,$4]
    end
  end
  if string =~ / #(\d+)[.\s,]/
    info[:issue_id ] = $1.to_i
  end
  if string =~ / (\d+([.,]\d+)?) H/
    tempo = $1.tr(',','.').to_f
    info[:tempo] = tempo
  end
  info
end


["pair com @marlonscalabrin. desenvolvido tarefa #13. 2,5 H",
"pair com @jonatasdp. fechado #13. 0,5 H",
"pair com @jonatasdp, @marlonscalabrin. fechado #13. 0,5 H"
].each do |x|
  p extrair_horas(x)
end
=end

  def short_comments
    @short_comments || split_comments.first
  end

  def long_comments
    @long_comments || split_comments.last
  end

  def text_tag(ref_project=nil)
    tag = if scmid?
      "commit:#{scmid}"
    else
      "r#{revision}"
    end
    if repository && repository.identifier.present?
      tag = "#{repository.identifier}|#{tag}"
    end
    if ref_project && project && ref_project != project
      tag = "#{project.identifier}:#{tag}"
    end
    tag
  end

  # Returns the title used for the changeset in the activity/search results
  def title
    repo = (repository && repository.identifier.present?) ? " (#{repository.identifier})" : ''
    comm = short_comments.blank? ? '' : (': ' + short_comments)
    "#{l(:label_revision)} #{format_identifier}#{repo}#{comm}"
  end

  # Returns the previous changeset
  def previous
    @previous ||= Changeset.where(["id < ? AND repository_id = ?", id, repository_id]).order('id DESC').first
  end

  # Returns the next changeset
  def next
    @next ||= Changeset.where(["id > ? AND repository_id = ?", id, repository_id]).order('id ASC').first
  end

  # Creates a new Change from it's common parameters
  def create_change(change)
    Change.create(:changeset     => self,
                  :action        => change[:action],
                  :path          => change[:path],
                  :from_path     => change[:from_path],
                  :from_revision => change[:from_revision])
  end

  # Finds an issue that can be referenced by the commit message
  def find_referenced_issue_by_issue_number(id)
    return nil if id.blank?
    issue = Issue.find(:first, :conditions => ["issue_numbers.number = ? and projects.id = ? and issue_numbers.repository_id = ?", id.to_i, repository.project_id, repository.id], :include => [:project, :issue_number])
    if Setting.commit_cross_project_ref?
      # all issues can be referenced/fixed
    elsif issue
      # issue that belong to the repository project, a subproject or a parent project only
      unless issue.project &&
                (project == issue.project || project.is_ancestor_of?(issue.project) ||
                 project.is_descendant_of?(issue.project))
        issue = nil
      end
    end
    issue
  end

  # Finds an issue that can be referenced by the commit message
  def find_referenced_issue_by_id(id)
    return nil if id.blank?
    issue = Issue.find_by_id(id.to_i, :include => :project)
    if Setting.commit_cross_project_ref?
      # all issues can be referenced/fixed
    elsif issue
      # issue that belong to the repository project, a subproject or a parent project only
      unless issue.project &&
                (project == issue.project || project.is_ancestor_of?(issue.project) ||
                 project.is_descendant_of?(issue.project))
        issue = nil
      end
    end
    issue
  end

  private

  def fix_issue(issue, user)
    status = IssueStatus.find_by_id(Setting.commit_fix_status_id.to_i)
    if status.nil?
      logger.warn("No status matches commit_fix_status_id setting (#{Setting.commit_fix_status_id})") if logger
      return issue
    end

    # the issue may have been updated by the closure of another one (eg. duplicate)
    issue.reload
    # don't change the status is the issue is closed
    return if issue.status && issue.status.is_closed?

    journal = issue.init_journal(user || User.anonymous, ll(Setting.default_language, :text_status_changed_by_changeset, text_tag(issue.project)))
    issue.status = status
    unless Setting.commit_fix_done_ratio.blank?
      issue.done_ratio = Setting.commit_fix_done_ratio.to_i
    end
    Redmine::Hook.call_hook(:model_changeset_scan_commit_for_issue_ids_pre_issue_update,
                            { :changeset => self, :issue => issue })
    unless issue.save
      logger.warn("Issue ##{issue.id} could not be saved by changeset #{id}: #{issue.errors.full_messages}") if logger
    end
    issue
  end

  def log_time(issue, hours, user, comments = nil)
    time_entry = TimeEntry.new(
      :user => user,
      :hours => hours.gsub(",","."),
      :issue => issue,
      :project => project,
      :spent_on => commit_date,
      :comments => "#{comments} - #{l(:text_time_logged_by_changeset, :value => text_tag((issue.nil? ? nil : issue.project)),
                     :locale => Setting.default_language)}"
      )
    time_entry.activity = log_time_activity unless log_time_activity.nil?

    unless time_entry.save
      logger.info "Erro ao adicionar time_entry"
      logger.info time_entry.errors.inspect
      logger.info "#{hours}, #{user.inspect}"
      logger.warn("TimeEntry could not be created by changeset #{id}: #{time_entry.errors.inspect}") if logger
    else
      puts "Salvou o timeentry id #{time_entry.id}"
    end
    time_entry
  end

  def log_time_activity
    if Setting.commit_logtime_activity_id.to_i > 0
      TimeEntryActivity.find_by_id(Setting.commit_logtime_activity_id.to_i)
    end
  end

  def split_comments
    comments =~ /\A(.+?)\r?\n(.*)$/m
    @short_comments = $1 || comments
    @long_comments = $2.to_s.strip
    return @short_comments, @long_comments
  end

  public

  # Strips and reencodes a commit log before insertion into the database
  def self.normalize_comments(str, encoding)
    Changeset.to_utf8(str.to_s.strip, encoding)
  end

  def self.to_utf8(str, encoding)
    Redmine::CodesetUtil.to_utf8(str, encoding)
  end
end

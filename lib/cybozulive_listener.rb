require 'oauth'
require 'nokogiri'
require 'cgi'

class CybozuliveListener < Redmine::Hook::Listener
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::SanitizeHelper
  include ApplicationHelper

  def controller_issues_new_after_save(context={})
    issue = context[:issue]
    project = issue.project

    message = <<-EOF
[#{CGI.escapeHTML(issue.project.name)}] #{CGI.escapeHTML(issue.author.name)} created
#{CGI.escapeHTML(issue.subject)}
#{get_object_url(issue)}

#{I18n.t("field_status")} : #{CGI.escapeHTML(issue.status.try(:name))}
#{I18n.t("field_priority")} : #{CGI.escapeHTML(issue.priority.try(:name))}
#{I18n.t("field_assigned_to")} : #{CGI.escapeHTML(issue.assigned_to.try(:name))}

#{strip_tags(textilizable(issue, :description)).gsub(/(\r\n|\r|\n)+/, "\n")}
    EOF

    post_chat(project, message)
  end

  def controller_issues_edit_after_save(context={})
    issue = context[:issue]
    journal = context[:journal]
    project = issue.project

    journal_detail_messages = journal.details.map { |detail| get_journal_detail_message(detail) }
    message = <<-EOF
[#{CGI.escapeHTML(issue.project.name)}] #{CGI.escapeHTML(journal.user.name)} updated
#{CGI.escapeHTML(issue.subject)}
#{get_object_url(issue)}

#{journal_detail_messages.join("\n")}

#{strip_tags(textilizable(journal, :notes)).gsub(/(\r\n|\r|\n)+/, "\n")}
    EOF

    post_chat(project, message)
  end

  private

  def post_chat(project, message)

    consumer_key = Setting.plugin_redmine_cybozulive[:consumer_key]
    consumer_secret = Setting.plugin_redmine_cybozulive[:consumer_secret]
    consumer = OAuth::Consumer.new(
      consumer_key,
      consumer_secret,
      :site => "https://api.cybozulive.com",
      :request_token_url => "https://api.cybozulive.com/oauth/initiate",
      :access_token_url => "https://api.cybozulive.com/oauth/token"
    )

    x_auth_username = get_cybozulive_mail_address(project)
    x_auth_password = get_cybozulive_password(project)
    access_token = consumer.get_access_token(
      nil,
      {},
      {
        :x_auth_mode => "client_auth",
        :x_auth_username => x_auth_username,
        :x_auth_password => x_auth_password,
      }
    )

    id = get_cybozulive_chat_id(project, access_token)
    body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><feed xmlns=\"http://www.w3.org/2005/Atom\" xmlns:cbl=\"http://schemas.cybozulive.com/common/2010\"><cbl:operation type=\"insert\"/><id>#{id}</id><entry><summary type=\"text\">#{truncate(message, :length => 3000)}</summary></entry></feed>"

    response = access_token.post(
      "https://api.cybozulive.com/api/comet/mpChatPush/V2",
      body,
      {
        'Accept' => 'application/atom+xml',
        'Content-Type' => 'application/atom+xml'
      }
    )
    Rails.logger.error "post chat error: #{response.body}" unless response.kind_of?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error "post chat error: #{e.message}"
  end

  def get_cybozulive_chat_id(project, access_token)
    chat_id = get_project_custome_field_value(project, "Cybozulive Chat Id")

    if chat_id.blank?
      chat_room_id = get_project_custome_field_value(project, "Cybozulive Chat Room Id")
      urls = [
        "https://api.cybozulive.com/api/mpChat/V2?chat-type=DIRECT",
        "https://api.cybozulive.com/api/mpChat/V2?chat-type=THEME",
      ]

      urls.each do |url|
        response = access_token.get(url)
        if response.kind_of?(Net::HTTPSuccess)
          xml_doc  = Nokogiri::XML(response.body)
          chat_id = xml_doc.xpath("//xmlns:link[@href='https://cybozulive.com/mpChat/view?chatRoomId=#{chat_room_id}']/parent::node()/xmlns:id").try(:text)
          if chat_id.present?
            save_cybozulive_chat_id(project, chat_id)
            break
          end
        else
          chat_id = nil
        end
      end
    end

    chat_id
  end

  def save_cybozulive_chat_id(project, chat_id)
    project_custom_field = ProjectCustomField.find_by_name("Cybozulive Chat Id")
    custom_value = project.custom_value_for(project_custom_field)
    custom_value.value = chat_id
    custom_value.save!
  rescue => e
    Rails.logger.error "save cybozulive_chat_id error: #{e.message}"
  end

  def get_cybozulive_chat_room_id(project)
    get_project_custome_field_value(project, "Cybozulive Chat Room Id")
  end

  def get_cybozulive_mail_address(project)
    get_project_custome_field_value(project, "Cybozulive Mail Address")
  end

  def get_cybozulive_password(project)
    get_project_custome_field_value(project, "Cybozulive Password")
  end

  def get_project_custome_field_value(project, name)
    return nil if project.blank?

    project_custom_field = ProjectCustomField.find_by_name(name)

    value = [
      (project.custom_value_for(project_custom_field).value rescue nil),
      (get_project_custome_field_value(project.parent, name)),
    ].find { |v| v.present? }

    value
  end

  def get_object_url(object)
    Rails.application.routes.url_for(
      object.event_url({:host => Setting.host_name, :protocol => Setting.protocol})
    )
  end

  def get_journal_detail_message(detail)
    if detail.property == "cf"
      key = CustomField.find(detail.prop_key).name rescue nil
      title = key
    elsif detail.property == "attachment"
      key = "attachment"
      title = I18n.t(:label_attachment)
    else
      key = detail.prop_key.to_s.sub("_id", "")
      title = I18n.t("field_#{key}")
    end

    value = CGI.escapeHTML(detail.value.to_s)

    case key
    when "title", "subject", "description"
    when "tracker"
      tracker = Tracker.find(detail.value) rescue nil
      value = CGI.escapeHTML(tracker.to_s)
    when "project"
      project = Project.find(detail.value) rescue nil
      value = CGI.escapeHTML(project.to_s)
    when "status"
      status = IssueStatus.find(detail.value) rescue nil
      value = CGI.escapeHTML(status.to_s)
    when "priority"
      priority = IssuePriority.find(detail.value) rescue nil
      value = CGI.escapeHTML(priority.to_s)
    when "category"
      category = IssueCategory.find(detail.value) rescue nil
      value = CGI.escapeHTML(category.to_s)
    when "assigned_to"
      user = User.find(detail.value) rescue nil
      value = CGI.escapeHTML(user.to_s)
    when "fixed_version"
      version = Version.find(detail.value) rescue nil
      value = CGI.escapeHTML(version.to_s)
    when "attachment"
      attachment = Attachment.find(detail.prop_key) rescue nil
      value = CGI.escapeHTML(attachment.filename) if attachment
    when "parent"
      issue = Issue.find(detail.value) rescue nil
      value = CGI.escapeHTML(issue.to_s) if issue
    end

    value = "-" if value.blank?

    "#{title} : #{value}"
  end

end


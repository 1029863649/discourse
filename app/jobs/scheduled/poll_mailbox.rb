#
# Connects to a mailbox and checks for replies
#
require 'net/pop'
require_dependency 'email/receiver'
require_dependency 'email/message_builder'

module Jobs
  class PollMailbox < Jobs::Scheduled
    recurrence { hourly.minute_of_hour(0,5,10,15,20,25,30,35,40,45,50,55) }
    sidekiq_options retry: false

    def execute(args)
      if SiteSetting.pop3s_polling_enabled?
        poll_pop3s
      end
    end

    def poll_pop3s
      Net::POP3.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
      Net::POP3.start(SiteSetting.pop3s_polling_host,
                      SiteSetting.pop3s_polling_port,
                      SiteSetting.pop3s_polling_username,
                      SiteSetting.pop3s_polling_password) do |pop|
        unless pop.mails.empty?
          pop.each do |mail|
            if Email::Receiver.new(mail.pop).process == Email::Receiver.results[:processed]
              mail.delete
            else
                @message = Mail::Message.new(@raw)
                # One for you (mod), and one for me (sender)
                GroupMessage.create(Group[:moderators].name, :email_reject_notification, {limit_once_per: false})
                 build_email(@message.from.first, template: 'email_reject_notification', email: @message)
            end
          end
        end
      end
    end

  end
end

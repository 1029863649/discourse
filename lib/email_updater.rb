# frozen_string_literal: true

class EmailUpdater
  include HasErrors

  attr_reader :user

  def initialize(guardian: nil, user: nil)
    @guardian = guardian
    @user = user
  end

  def change_to(email, add: false)
    @guardian.ensure_can_edit_email!(@user)

    email = Email.downcase(email.strip)
    EmailValidator.new(attributes: :email).validate_each(self, :email, email)

    if existing_user = User.find_by_email(email)
      if SiteSetting.hide_email_address_taken
        Jobs.enqueue(:critical_user_email, type: :account_exists, user_id: existing_user.id)
      else
        error_message = +'change_email.error'
        error_message << '_staged' if existing_user.staged?
        errors.add(:base, I18n.t(error_message))
      end
    end

    return if errors.present? || existing_user.present?

    old_email = @user.email if !add

    if @guardian.is_admin? && !@user.staff? && @guardian.user != @user
      send_email_notification(@user.email, email)
      update_user_email(old_email, email)
      send_email(:forgot_password, @user.email_tokens.create!(email: @user.email))
      return
    end

    change_req = EmailChangeRequest.find_or_initialize_by(user_id: @user.id, new_email: email)
    if change_req.new_record?
      change_req.old_email = old_email
      change_req.new_email = email
    end

    if change_req.change_state.blank?
      change_req.change_state = if @user.staff?
        # Staff users must confirm their old email address first.
        EmailChangeRequest.states[:authorizing_old]
      else
        EmailChangeRequest.states[:authorizing_new]
      end
    end

    if change_req.change_state == EmailChangeRequest.states[:authorizing_old]
      change_req.old_email_token = @user.email_tokens.create!(email: @user.email)
      send_email(add ? :confirm_old_email_add : :confirm_old_email, change_req.old_email_token)
    elsif change_req.change_state == EmailChangeRequest.states[:authorizing_new]
      change_req.new_email_token = @user.email_tokens.create!(email: email)
      send_email(:confirm_new_email, change_req.new_email_token)
    end

    change_req.save!
  end

  def confirm(token)
    confirm_result = nil

    User.transaction do
      result = EmailToken.atomic_confirm(token)
      if result[:success]
        token = result[:email_token]
        @user = token.user

        change_req = @user.email_change_requests
          .where('old_email_token_id = :token_id OR new_email_token_id = :token_id', token_id: token.id)
          .first

        case change_req.try(:change_state)
        when EmailChangeRequest.states[:authorizing_old]
          change_req.update!(
            change_state: EmailChangeRequest.states[:authorizing_new],
            new_email_token: @user.email_tokens.create(email: change_req.new_email)
          )
          send_email(:confirm_new_email, change_req.new_email_token)
          confirm_result = :authorizing_new
        when EmailChangeRequest.states[:authorizing_new]
          change_req.update!(change_state: EmailChangeRequest.states[:complete])
          if !@user.staff?
            # Send an email notification only to users who did not confirm old
            # email.
            send_email_notification(change_req.old_email, change_req.new_email)
          end
          update_user_email(change_req.old_email, change_req.new_email)
          confirm_result = :complete
        end

        if confirm_result == :complete
          if @initiating_user&.staff? && @initiating_user != @user
            StaffActionLogger.new(@initiating_user).log_add_email(@user, previous_value: change_req.old_email, new_value: change_req.new_email)
          else
            UserHistory.create!(action: UserHistory.actions[:add_email], target_user_id: @user.id, previous_value: change_req.old_email, new_value: change_req.new_email)
          end
        end
      else
        errors.add(:base, I18n.t('change_email.already_done'))
        confirm_result = :error
      end
    end

    confirm_result || :error
  end

  def update_user_email(old_email, new_email)
    if old_email.present?
      @user.user_emails.find_by(email: old_email).update!(email: new_email)
    else
      @user.user_emails.create!(email: new_email)
    end

    @user.set_automatic_groups
  end

  protected

  def send_email(type, email_token)
    Jobs.enqueue :critical_user_email,
                 to_address: email_token.email,
                 type: type,
                 user_id: @user.id,
                 email_token: email_token.token
  end

  def send_email_notification(old_email, new_email)
    Jobs.enqueue :critical_user_email,
                 to_address: @user.email,
                 type: old_email ? :notify_old_email : :notify_old_email_add,
                 user_id: @user.id,
                 new_email: new_email
  end
end

# frozen_string_literal: true

require_dependency 'account_controller'

module AccountController2faTrustPatch
  def twofa_confirm
    # ✅ If already trusted today in this browser, skip OTP screen
    if twofa_trust_enabled_for_current_user?
      destroy_twofa_session_if_possible
      return handle_active_user(@user)
    end

    super
  end

  def twofa_resend
    # ✅ If already trusted today in this browser, don't resend OTP
    if twofa_trust_enabled_for_current_user?
      destroy_twofa_session_if_possible
      return handle_active_user(@user)
    end

    super
  end

  def twofa
    # Inject cookie only on OTP success
    if @twofa.verify!(params[:twofa_code].to_s)
      mark_trusted_2fa_for_today!(@user)

      destroy_twofa_session_if_possible
      handle_active_user(@user)

    # allow at most 3 otp entry tries per successfull password entry
    elsif session[:twofa_tries_counter].to_i > 3
      destroy_twofa_session_if_possible
      flash[:error] = l('twofa_too_many_tries')
      redirect_to home_url
    else
      flash[:error] = l('twofa_invalid_code')
      redirect_to account_twofa_confirm_path
    end
  end

  private

  def twofa_trust_cookie_name
    :trusted_2fa_until_eod
  end

  def end_of_day_expiry
    Time.zone.now.end_of_day
  end

  def mark_trusted_2fa_for_today!(user)
    value = "#{user.id}:#{Time.zone.now.to_date.iso8601}"

    cookies.signed[twofa_trust_cookie_name] = {
      value: value,
      expires: end_of_day_expiry,   # ✅ expires at 23:59:59
      httponly: true,
      secure: request.ssl?
    }
  end

  def trusted_2fa_for_today?(user)
    return false unless user

    raw = cookies.signed[twofa_trust_cookie_name].to_s
    expected = "#{user.id}:#{Time.zone.now.to_date.iso8601}"

    ActiveSupport::SecurityUtils.secure_compare(raw, expected)
  rescue StandardError
    false
  end

  def twofa_trust_enabled_for_current_user?
    return false unless defined?(@user) && @user
    trusted_2fa_for_today?(@user)
  end

  def destroy_twofa_session_if_possible
    destroy_twofa_session if respond_to?(:destroy_twofa_session, true)
  end
end
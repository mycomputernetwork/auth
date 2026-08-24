module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_session, :current_user, :signed_in?

    before_action :require_own_password
  end

  def current_session
    return @current_session if defined?(@current_session)

    @current_session = Session.active.find_by(sid: cookies.signed[:auth_sid])
  end

  def current_user = current_session&.user

  def signed_in? = current_session.present?

  def sign_in(user)
    return_to = session[:return_to]
    reset_session
    session[:return_to] = return_to if return_to

    record = user.sessions.create!
    record.touch_seen!(request)
    cookies.signed[:auth_sid] = { value: record.sid, httponly: true, same_site: :lax, secure: request.ssl? }
    @current_session = record
  end

  def sign_out
    BackchannelLogout.call(current_session) if current_session
    current_session&.destroy
    cookies.delete(:auth_sid)
    @current_session = nil
  end

  def require_own_password
    return unless current_user&.must_change_password?

    store_return_to(request.fullpath) if request.get?
    redirect_to edit_password_path
  end

  def store_return_to(path) = session[:return_to] = path

  def pop_return_to = session.delete(:return_to)
end

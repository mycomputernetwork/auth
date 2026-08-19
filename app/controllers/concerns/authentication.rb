module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_session, :current_user, :signed_in?
  end

  def current_session
    return @current_session if defined?(@current_session)

    @current_session = Session.active.find_by(sid: cookies.signed[:auth_sid])
  end

  def current_user = current_session&.user

  def signed_in? = current_session.present?

  def sign_in(user)
    session = user.sessions.create!
    session.touch_seen!(request)
    cookies.signed[:auth_sid] = { value: session.sid, httponly: true, same_site: :lax, secure: request.ssl? }
    @current_session = session
  end

  def sign_out
    current_session&.destroy
    cookies.delete(:auth_sid)
    @current_session = nil
  end

  def store_return_to(path) = session[:return_to] = path

  def pop_return_to = session.delete(:return_to)
end

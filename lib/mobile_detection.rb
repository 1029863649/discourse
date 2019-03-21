module MobileDetection
  def self.mobile_device?(user_agent)
    user_agent =~ /Mobile/ && !(user_agent =~ /iPad/)
  end

  # we need this as a reusable chunk that is called from the cache
  def self.resolve_mobile_view!(user_agent, params, session)
    return false unless SiteSetting.enable_mobile_theme

    if params && params.has_key?(:mobile_view)
      session[:mobile_view] = params[:mobile_view]
    end
    if params && params.has_key?(:mobile_view) && params[:mobile_view] == 'auto'
      session[:mobile_view] = nil
    end

    if session && session[:mobile_view]
      session[:mobile_view] == '1'
    else
      mobile_device?(user_agent)
    end
  end
end

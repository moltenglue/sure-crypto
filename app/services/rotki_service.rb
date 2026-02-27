class RotkiService
  BASE_URL = ENV.fetch("ROTKI_API_URL", "http://localhost:5042")

  class AuthenticationError < StandardError; end
  class ConnectionError < StandardError; end

  def initialize(username: nil, password: nil)
    @username = username
    @password = password
    @http = nil
    @logged_in = false
    @session_cookie = nil
  end

  def create_user(username, password)
    post("/api/1/users", { name: username, password: password })
  end

  def login(username, password)
    Rails.logger.info "RotkiService: Attempting login for user: #{username}"
    
    # First try to logout any existing session to avoid 409 conflict
    begin
      logout(username) if @logged_in
    rescue => e
      Rails.logger.info "RotkiService: Could not logout existing session: #{e.message}"
    end
    
    response = request(:post, "/api/1/users/#{CGI.escape(username)}", { 
      password: password, 
      sync_approval: "unknown", 
      resume_from_backup: false 
    })
    
    Rails.logger.info "RotkiService: Login successful for user: #{username}"
    @logged_in = true
    
    { "success" => true }
  rescue => e
    Rails.logger.error "Rotki login error: #{e.message}"
    if e.message.include?("409")
      Rails.logger.info "RotkiService: 409 Conflict - user already logged in, trying logout and retry"
      begin
        force_logout(username)
        retry
      rescue => retry_error
        Rails.logger.error "RotkiService: Retry failed: #{retry_error.message}"
      end
      { "success" => true, "message" => "User already exists" }
    else
      raise
    end
  end

  def ensure_logged_in
    return if @logged_in

    raise AuthenticationError, "Rotki username not provided" unless @username
    raise AuthenticationError, "Rotki password not provided" unless @password

    login(@username, @password)
  end

  def logout(username)
    Rails.logger.info "RotkiService: Attempting logout for user: #{username}"
    response = patch("/api/1/users/#{username}", { action: "logout" })
    Rails.logger.info "RotkiService: Logout response: #{response.inspect}"
    @logged_in = false
    close_connection
    response
  rescue => e
    Rails.logger.warn "RotkiService: Logout failed (this is usually OK): #{e.message}"
    @logged_in = false
    close_connection
    { "result" => true }
  end

  def force_logout(username)
    Rails.logger.info "RotkiService: Force logout for user: #{username}"
    patch("/api/1/users/#{username}", { action: "logout" })
    @logged_in = false
    close_connection
  rescue => e
    Rails.logger.warn "RotkiService: Force logout failed: #{e.message}"
    @logged_in = false
    close_connection
  end

  def all_balances
    ensure_logged_in

    Rails.logger.info "RotkiService: Fetching balances..."

    # Try to fetch balances with the current session
    begin
      blockchain = blockchain_balances
      exchanges = exchange_balances
      manual = manual_balances

      Rails.logger.info "RotkiService: Successfully fetched all balances"

      {
        blockchain: blockchain,
        exchanges: exchanges,
        manual: manual
      }
    rescue AuthenticationError, ConnectionError => e
      Rails.logger.error "RotkiService: Authentication/Connection error fetching balances: #{e.message}"
      raise
    rescue => e
      # Check if this is a session error
      if e.message.include?("500") || e.message.include?("400") || e.message.include?("401") || e.message.include?("403")
        Rails.logger.error "RotkiService: Session error fetching balances. This usually means nginx is stripping cookies."
        Rails.logger.error "RotkiService: To fix this, set ROTKI_API_URL to connect directly to Rotki (e.g., http://rotki:5042) instead of through nginx."
        raise AuthenticationError, "Rotki session failed. If using nginx proxy, connect directly to Rotki container instead. Error: #{e.message}"
      else
        raise
      end
    end
  end

  def balances
    get("/api/1/balances")
  end

  def blockchain_balances
    result = get("/api/1/balances/blockchain")
    Rails.logger.info "Rotki blockchain_balances response: #{result.inspect}"
    result
  end

  def exchange_balances
    result = get("/api/1/balances/exchanges")
    Rails.logger.info "Rotki exchange_balances response: #{result.inspect}"
    result
  end

  def manual_balances
    result = get("/api/1/balances/manual")
    Rails.logger.info "Rotki manual_balances response: #{result.inspect}"
    result
  end

  def periodic_data
    get("/api/1/periodic")
  end

  private

  def http_connection
    return @http if @http && @http.started?

    close_connection if @http

    uri = URI.parse(BASE_URL)
    Rails.logger.info "RotkiService: Creating HTTP connection to #{uri.host}:#{uri.port}"
    
    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = uri.scheme == "https"
    @http.open_timeout = 10
    @http.read_timeout = 30
    
    # Don't use keep_alive since nginx doesn't support it properly
    # @http.keep_alive_timeout = 30
    
    @http.start
    @http
  rescue => e
    Rails.logger.error "RotkiService: Failed to create HTTP connection: #{e.message}"
    raise ConnectionError, "Failed to connect to Rotki at #{BASE_URL}: #{e.message}"
  end

  def close_connection
    if @http
      begin
        @http.finish if @http.started?
      rescue => e
        Rails.logger.warn "RotkiService: Error closing connection: #{e.message}"
      end
      @http = nil
    end
    @logged_in = false
    @session_cookie = nil
  end

  def get(path)
    response = request(:get, path)
    if response.is_a?(Hash)
      if response.key?("result")
        return response["result"]
      elsif response.key?("error")
        raise "Rotki API error: #{response["error"]}"
      end
    end
    response
  end

  def post(path, body)
    response = request(:post, path, body)
    if response.is_a?(Hash) && response.key?("result")
      response["result"]
    else
      response
    end
  end

  def patch(path, body)
    request(:patch, path, body)
  end

  def request(method, path, body = nil)
    uri = URI.join(BASE_URL, path)
    
    req = case method
          when :get then Net::HTTP::Get.new(uri)
          when :post then Net::HTTP::Post.new(uri)
          when :patch then Net::HTTP::Patch.new(uri)
          end

    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    
    # Send session cookie if we have one
    if @session_cookie
      req["Cookie"] = @session_cookie
      Rails.logger.info "RotkiService: Sending request #{method.upcase} #{path} with session cookie"
    else
      Rails.logger.info "RotkiService: Sending request #{method.upcase} #{path} WITHOUT session cookie"
    end
    
    req.body = body.to_json if body

    http = http_connection
    response = http.request(req)

    # Log ALL response headers for debugging
    Rails.logger.info "RotkiService: Response headers: #{response.to_hash.inspect}"
    
    # Capture session cookie from response - check all possible cookie names
    if response["Set-Cookie"]
      set_cookie = response["Set-Cookie"]
      Rails.logger.info "RotkiService: Raw Set-Cookie header: #{set_cookie.inspect}"
      
      # Try to find any session cookie - Rotki might use different names
      # Common names: rotki_session, session, _rotki_session
      cookie_match = set_cookie.to_s.match(/(?:rotki_session|session)=([^;]+)/i)
      if cookie_match
        # Get the actual cookie name from the match
        cookie_name = set_cookie.to_s.match(/([^=]+)=/)[1]
        @session_cookie = "#{cookie_name}=#{cookie_match[1]}"
        Rails.logger.info "RotkiService: Captured session cookie: #{@session_cookie}"
      else
        # If we can't parse it, store the whole thing and try using it
        @session_cookie = set_cookie.to_s.split(';').first.strip
        Rails.logger.info "RotkiService: Storing full cookie string (unparsed): #{@session_cookie}"
      end
    else
      Rails.logger.info "RotkiService: No Set-Cookie header in response"
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Rotki API error response: #{response.code} - #{response.message} - #{response.body}"
      
      # Check for authentication errors
      if response.code == "401" || response.code == "403"
        close_connection
        raise AuthenticationError, "Rotki authentication failed: #{response.code} - #{response.message}"
      elsif response.code == "500" && response.body.include?("400 Bad Request")
        close_connection
        raise ConnectionError, "Rotki session lost. Error: #{response.body}"
      end
      
      raise "Rotki API error: #{response.code} - #{response.message}"
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.error "RotkiService: Failed to parse JSON response: #{e.message}"
    raise ConnectionError, "Invalid response from Rotki: #{e.message}"
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "Rotki connection error: #{e.message}"
    close_connection
    raise ConnectionError, "Cannot connect to Rotki at #{BASE_URL}: #{e.message}"
  rescue Errno::EPIPE, Errno::ECONNRESET => e
    Rails.logger.error "Rotki connection closed: #{e.message}"
    close_connection
    raise ConnectionError, "Connection to Rotki was closed."
  end
end

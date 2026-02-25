class RotkiService
  BASE_URL = ENV.fetch("ROTKI_API_URL", "http://localhost:5042")

  def initialize(username: nil, password: nil)
    @username = username
    @password = password
    @cookies = {}
  end

  def create_user(username, password)
    post("/api/1/users", { name: username, password: password })
  end

  def login(username, password)
    Rails.logger.info "RotkiService: Attempting login for user: #{username}"
    
    # First try to logout any existing session to avoid 409 conflict
    begin
      logout(username) if @username
    rescue => e
      Rails.logger.info "RotkiService: Could not logout existing session: #{e.message}"
    end
    
    response = request(:post, "/api/1/users/#{CGI.escape(username)}", { password: password, sync_approval: "unknown", resume_from_backup: false })
    Rails.logger.info "RotkiService: Login raw response: #{response.inspect}"
    
    if response.is_a?(Hash)
      if response["success"] && response["result"].is_a?(Hash)
        @cookies["rotki_session"] = response["result"]["session_token"]
      elsif response["success"]
        Rails.logger.info "RotkiService: Login returned success but no session token"
      end
    end
    
    Rails.logger.info "RotkiService: Session cookie set: #{@cookies["rotki_session"]}"
    { "success" => true }
  rescue => e
    Rails.logger.error "Rotki login error: #{e.message}"
    if e.message.include?("409")
      Rails.logger.info "RotkiService: 409 Conflict - trying logout and retry login"
      # Try one more time after logout
      begin
        logout(username)
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
    return if @cookies["rotki_session"]

    raise "Rotki username not provided" unless @username
    raise "Rotki password not provided" unless @password

    login(@username, @password)
  end

  def logout(username)
    Rails.logger.info "RotkiService: Attempting logout for user: #{username}"
    response = patch("/api/1/users/#{username}", { action: "logout" })
    Rails.logger.info "RotkiService: Logout response: #{response.inspect}"
    @cookies["rotki_session"] = nil
    response
  end

  def all_balances
    ensure_logged_in

    Rails.logger.info "RotkiService: Attempting to fetch balances..."

    blockchain = blockchain_balances
    exchanges = exchange_balances
    manual = manual_balances

    Rails.logger.info "RotkiService: blockchain=#{blockchain.inspect}"
    Rails.logger.info "RotkiService: exchanges=#{exchanges.inspect}"
    Rails.logger.info "RotkiService: manual=#{manual.inspect}"

    {
      blockchain: blockchain,
      exchanges: exchanges,
      manual: manual
    }
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
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 30

    req = case method
          when :get then Net::HTTP::Get.new(uri)
          when :post then Net::HTTP::Post.new(uri)
          when :patch then Net::HTTP::Patch.new(uri)
          end

    req["Content-Type"] = "application/json"

    if @cookies["rotki_session"]
      req["Cookie"] = "rotki_session=#{@cookies["rotki_session"]}"
    end

    req.body = body.to_json if body

    response = http.request(req)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Rotki API error response: #{response.code} - #{response.message} - #{response.body}"
      raise "Rotki API error: #{response.code} - #{response.message}"
    end

    JSON.parse(response.body)
  end
end

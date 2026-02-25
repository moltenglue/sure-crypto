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
    result = post("/api/1/users/#{CGI.escape(username)}", { password: password, sync_approval: "unknown", resume_from_backup: false })
    @cookies["rotki_session"] = result["session_token"] if result["success"]
    result
  rescue => e
    Rails.logger.error "Rotki login error: #{e.message}"
    if e.message.include?("409")
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
    patch("/api/1/users/#{username}", { action: "logout" })
  end

  def all_balances
    ensure_logged_in

    blockchain = blockchain_balances
    exchanges = exchange_balances
    manual = manual_balances

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

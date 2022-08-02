require 'uri'
require 'socket'
require 'openssl'
require 'forwardable'
require 'net-http2'

module Houston
  class Connection
    extend Forwardable
    def_delegators :@ssl, :read, :write
    def_delegators :@uri, :scheme, :host, :port

    attr_reader :ssl, :socket, :certificate, :passphrase

    class << self
      def open(uri, certificate, passphrase)
        return unless block_given?

        connection = new(uri, certificate, passphrase)
        connection.open
        yield connection

        connection.close
      end
    end

    def initialize(uri, certificate, passphrase)
      @uri = URI(uri)
      @certificate = certificate.to_s
      @passphrase = passphrase.to_s unless passphrase.nil?
      @device_token = ""
      @message = ""
      @badge = ""
      @priority = 0
      @custom_data = ""
    end

    def open
      return false if open?

      context = OpenSSL::SSL::SSLContext.new
      context.key = OpenSSL::PKey::RSA.new(@certificate, @passphrase)
      context.cert = OpenSSL::X509::Certificate.new(@certificate)

      client = NetHttp2::Client.new(@uri.to_s, ssl_context: context)

      request = client.prepare_request(:post, "/3/device/#{@device_token}", headers: { 'Apns-Topic' => 'com.lifelinea.mysaic.mobile', 'Apns-Expiration' => '1', 'Apns-Priority' => '10' }, body: JSON.dump({
                                                                                                                                                                                                             "aps" => {
                                                                                                                                                                                                               "alert" => @message,
                                                                                                                                                                                                               "sound" => @sound,
                                                                                                                                                                                                               "badge" => @badge,
                                                                                                                                                                                                               "priority" => @priority,
                                                                                                                                                                                                             },
                                                                                                                                                                                                             "data" => @custom_data['data']

                                                                                                                                                                                                           }))
      #request.on(:body_chunk) { |chunk| p chunk }
      request.on(:close) { puts "request completed!" }
      # read the response

      client.on(:error) { |exception| puts "Exception has been raised: #{exception}" }
      client.join(timeout: 5)
      client.call_async(request)
      client
    end

    def open?
      !(@conn).nil?
    end

    def set_token (device_token)
      @device_token = device_token
    end

    def set_sound (sound)
      @sound = sound
    end

    def set_custom_data (custom_data)
      @custom_data = custom_data
    end

    def set_priority (priority)
      @priority = priority
    end

    def set_message (message)
      @message = message
    end

    def set_badge (badge)
      @badge = badge
    end

    def close
      return false if closed?

      @conn.close
      @conn = nil
    end

    def closed?
      !open?
    end
  end
end

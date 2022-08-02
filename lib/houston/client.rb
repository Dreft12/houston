module Houston
  APPLE_PRODUCTION_GATEWAY_URI = 'apn://gateway.push.apple.com:2195'
  APPLE_PRODUCTION_FEEDBACK_URI = 'apn://feedback.push.apple.com:2196'

  APPLE_DEVELOPMENT_GATEWAY_URI = 'https://api.development.push.apple.com/'
  APPLE_DEVELOPMENT_FEEDBACK_URI = 'apn://feedback.sandbox.push.apple.com:2196'

  class Client
    attr_accessor :gateway_uri, :feedback_uri, :device_token, :certificate, :passphrase, :timeout

    class << self
      def development
        client = new
        client.gateway_uri = APPLE_DEVELOPMENT_GATEWAY_URI
        client.feedback_uri = APPLE_DEVELOPMENT_FEEDBACK_URI
        client
      end

      def production
        client = new
        client.gateway_uri = APPLE_PRODUCTION_GATEWAY_URI
        client.feedback_uri = APPLE_PRODUCTION_FEEDBACK_URI
        client
      end
    end

    def initialize
      @gateway_uri = ENV['APN_GATEWAY_URI']
      @feedback_uri = ENV['APN_FEEDBACK_URI']
      @certificate = certificate_data
      @passphrase = ENV['APN_CERTIFICATE_PASSPHRASE']
      @timeout = Float(ENV['APN_TIMEOUT'] || 0.5)
    end

    def push(*notifications)
      return if notifications.empty?

      notifications.flatten!
      Connection.open(@gateway_uri, @certificate, @passphrase) do |connection|
        notifications.each_with_index do |notification, index|

          next unless notification.is_a?(Notification)
          next if notification.sent?
          notification.id = index
          connection.set_token notification.token
          connection.open
=begin
          ssl = connection.ssl
          next unless notification.is_a?(Notification)
          next if notification.sent?
          next unless notification.valid?
          notification.id = index

          connection.write(notification.message)
          notification.mark_as_sent!

          read_socket, _write_socket = IO.select([ssl], [ssl], [ssl], nil)
          next unless read_socket && read_socket[0]

          next unless error = connection.read(6)

          _command, status, index = error.unpack('ccN')
          notification.apns_error_code = status
          notification.mark_as_unsent!
=end
        end
      end
    end

    def unregistered_devices
      devices = []

      Connection.open(@feedback_uri, @certificate, @passphrase) do |connection|
        while line = connection.read(38)
          feedback = line.unpack('N1n1H140')
          timestamp = feedback[0]
          token = feedback[2].scan(/.{0,8}/).join(' ').strip
          devices << { token: token, timestamp: timestamp } if token && timestamp
        end
      end

      devices
    end

    def devices
      unregistered_devices.collect { |device| device[:token] }
    end

    def certificate_data
      if ENV['APN_CERTIFICATE']
        File.read(ENV['APN_CERTIFICATE'])
      elsif ENV['APN_CERTIFICATE_DATA']
        ENV['APN_CERTIFICATE_DATA']
      end
    end
  end
end

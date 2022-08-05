module Houston
  APPLE_PRODUCTION_GATEWAY_URI = 'https://api.push.apple.com'
  APPLE_DEVELOPMENT_GATEWAY_URI = 'https://api.development.push.apple.com'

  class Client
    attr_accessor :gateway_uri, :feedback_uri, :device_token, :certificate, :passphrase, :timeout

    class << self
      def development
        client = new
        client.gateway_uri = APPLE_DEVELOPMENT_GATEWAY_URI
        client
      end

      def production
        client = new
        client.gateway_uri = APPLE_PRODUCTION_GATEWAY_URI
        client
      end
    end

    def initialize
      @gateway_uri = ENV['APN_GATEWAY_URI']
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
          connection.set_message notification.alert
          connection.set_badge notification.badge
          connection.set_sound notification.sound
          connection.set_priority notification.priority
          connection.set_custom_data notification.custom_data
          response = connection.open
          notification.mark_as_sent!
        end
      end
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

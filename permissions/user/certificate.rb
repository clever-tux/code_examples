module Core
  module Permissions
    class User::Certificate

      include Mongoid::Document
      include Mongoid::Timestamps

      store_in session: 'users'

      WRONG_PKSC_SERIAL = "**wrong_pksc_serial**"

      belongs_to :user, class_name: "Core::Permissions::User"

      field :container_id
      field :owner_name
      field :valid_from, type: Date
      field :valid_to, type: Date
      field :serial_number

      field :default, type: Boolean, default: false

      before_save :prepare_serial_number

      validates_uniqueness_of :serial_number, scope: :user_id      

      def self.from_params(prms)
        certificates = []
        (prms || {}).values.each do |h|
          certificate = new(h.except(:valid_from, :valid_to))
          certificate.valid_from = DateTime.from_s(h[:valid_from])
          certificate.valid_to = DateTime.from_s(h[:valid_to])
          certificates << certificate
        end
        certificates
      end

      def self.from_params!(prms, user_id)
        (prms || {}).values.each do |h|
          next unless h[:enabled]
          next unless by_serial_number(h[:serial_number]).blank?
          attrs = h.except(:enabled)
          certificate = new(attrs)
          certificate.user_id = user_id
          certificate.save
        end
      end

      def self.by_serial_number(serial_number)
        where(serial_number: serial_number).first
      end

      def set_default!
        Core::Permissions::User::Certificate.where(user_id: user_id).update_all(default: false)
        set(:default, true)
      end

      def self.by_serial_numbers(serial_numbers)
        where(:serial_number.in => (serial_numbers || []).map { |serial_number| serial_number.gsub(":", "") }, default: true).first
      end

      def prepare_serial_number
        self.serial_number = serial_number.gsub(":", "")
      end

      def is_me?(sign)
        return false if Core::Permissions::UsedSign.has?(sign)
        Core::Permissions::User::Certificate.pksc_serial(sign) == serial_number
      end

      def self.by_sign(sign)
        where(serial_number: pksc_serial(sign)).first
      end

      def self.valid_sign?(sign)
        !by_sign(sign).blank?
      end

      def self.pksc_serial(sign)
        pkcs(sign).certificates.first.serial.to_s(16)
      rescue
        WRONG_PKSC_SERIAL
      end

      def self.signer(sign)
        by_sign(sign).try(:owner_name)
      end

      def self.pkcs(sign)
        OpenSSL::PKCS7.new(Base64.urlsafe_decode64(sign))
      end

    end
  end
end

module Core
  module Permissions
    class User

      include Mongoid::Document
      include Mongoid::Timestamps

      store_in session: 'users'

      attr_protected :super_user

      # Include default devise modules. Others available are:
      # :token_authenticatable, :confirmable,
      # :lockable, :timeoutable and :omniauthable
      devise :database_authenticatable, :registerable,
             :recoverable, :rememberable, :trackable, :timeoutable

      ## Database authenticatable
      field :encrypted_password, :type => String, :default => ""

      ## Recoverable
      field :reset_password_token,   :type => String
      field :reset_password_sent_at, :type => Time

      ## Rememberable
      field :remember_created_at, :type => Time


      ## Trackable
      field :sign_in_count,      :type => Integer, :default => 0
      field :current_sign_in_at, :type => Time
      field :last_sign_in_at,    :type => Time
      field :current_sign_in_ip, :type => String
      field :last_sign_in_ip,    :type => String

      field :super_user, type: Boolean, default: false

      field :roles_ids, type: Array, default: []
      field :rights_ids, type: Array, default: []

      belongs_to :user_group, class_name: "Core::Permissions::UserGroup", inverse_of: :users

      field :login, type: String
      field :password, type: String

      field :authentication_token

      belongs_to :official, class_name: "Core::OshsMvd::Official"
      field :official_name

      belongs_to :organization, class_name: "Core::OshsMvd::Organization"
      belongs_to :provider, class_name: "Core::Settings::Provider"
      has_one :settings, dependent: :destroy, class_name: "Core::Permissions::Settings", autobuild: true, autosave: true

      has_many :certificates, class_name: "Core::Permissions::User::Certificate"

      # validations
      validates :login, presence: true, uniqueness: true
      validates :password, length: { in: 6..128 }, on: :create
      validates :password, length: { in: 6..128 }, on: :update, allow_blank: true
      validates_each :login do |record, attr, value|
        record.errors.add attr, :invalid unless value.to_s.gsub(/[\w\-]/, "") == ""
      end
      validates :official_id, uniqueness: { scope: :provider_id }
      validates :official_name, presence: true

      # callbacks
      before_save :set_organization
      before_create :set_official_name

      before_save :update_rights_ids!, if: :roles_ids_changed?
      before_save :ensure_authentication_token

      def ensure_authentication_token
        if authentication_token.blank?
          reset_authentication_token
        end
      end

      def reset_authentication_token!
        reset_authentication_token
        save(:validate => false)
      end

      def reset_authentication_token
        self.authentication_token = generate_authentication_token
      end

      def update_account!
        save(validate: false)
      end

      def roles
        @roles ||= Core::Permissions::Role.in(id: roles_ids)
      end

      #get from db if it's possibly
      def _settings
        Core::Permissions::Settings.find_by(user_id: id) || settings
      end

      def reset_password
        set(:password, DEFAULT_PASSWORD)
      end

      def self.with_roles
        @with_roles ||= ne(roles_ids: [])
      end

      def self.without_roles
        @without_roles ||= where(roles_ids: [])
      end

      def rights
        rights_ids
      end

      def organisation
        official.try(:organization)
      end

      def organization_name
        organization.try(:to_s, short_title: true)
      end

      def self.find_for_database_authentication(warden_conditions)
        conditions = warden_conditions.dup
        if login = conditions.delete(:login).downcase
          where(conditions).where(login: /^#{Regexp.escape(login)}$/i).first
        else
          where(conditions).first
        end
      end

      def self.find_by_term(term)
        where(login: /#{term}/i)
      end

      def to_s
        login
      end

      def self.all(args = {})
        args[:login] = /#{args[:login]}/i if args[:login].present?
        where(args)
      end

      def set_official_name
        self.official_name = official.to_s unless official.blank?
      end

      def set_organization
        return if official.blank?
        self.organization_id = official.organization_id
      end

      def update_rights_ids!
        set(:rights_ids, Core::Permissions::Role.in(id: roles_ids).distinct(:rights_ids))
      end

      def update_settings_item(field_name, value)
        if settings.present? && settings.respond_to?("#{field_name}=")
          settings.send("#{field_name}=", value)
          settings.save
        else
          false
        end
      end

      def expire_auth_token_on_timeout
        self.class.expire_auth_token_on_timeout
      end

      def certificate
        certificates.where(default: true).first
      end


      Devise::Models.config(self.class, :token_authentication_key, :expire_auth_token_on_timeout)

      private

      def generate_authentication_token
        loop do
          token = Devise.friendly_token
          break token unless User.where(authentication_token: token).first
        end
      end

    end
  end
end


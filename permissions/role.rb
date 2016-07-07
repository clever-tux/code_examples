module Core
  module Permissions
    class Role

      include Mongoid::Document
      include Mongoid::Timestamps

      store_in session: 'users'

      field :name, type: String
      field :description, type: String

      field :rights_ids, type: Array, default: []

      field :default_page

      belongs_to :provider, class_name: "Core::Settings::Provider"

      validates :name, presence: true, uniqueness: {scope: :provider_id}

      after_save :update_users!, if: :rights_ids_changed?

      def self.find_by_term(term)
        where(name: /#{term}/i)
      end

      def to_s
        name
      end

      def users
        @users ||= Core::Permissions::User.where(roles_ids: id.to_s)
      end

      def self.all(args = {})
        args[:name] = /#{args[:name]}/i if args[:name].present?
        where(args)
      end

      def update_users!
        Core::Permissions::User.where(roles_ids: id.to_s).each { |user| user.update_rights_ids! }
      end

    end
  end
end

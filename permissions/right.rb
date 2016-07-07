module Core
  module Permissions
    class Right

      include Mongoid::Document
      include Mongoid::Timestamps

      store_in session: 'users'

      field :_id, type: String

      field :name, type: String

      validates :name, presence: true

      default_scope order_by(name: 1)

      def self.find_by_term(term = '')
        where(name: /#{Regexp.escape(term)}/i)
      end

      def to_s
        name
      end

      def self.all(args = {})
        args[:name] = /#{args[:name]}/i if args[:name].present?
        where(args)
      end

      # [['Group1', [['Item1', '123'], ['Item2', '123'], ['Item3', '123']]]]
      #    gname       name    value
      def self.grouped(options = {})
        rights = all.order_by(name: 1)
        rights = rights.find_by_term(options[:term]) unless options[:term].blank?
        rights = rights.page(options[:page]).per(options[:per] || 50) unless options[:page].blank?
        rights = rights.to_a
        groups = rights.map { |right| right.name.split('.').first }.uniq
        groups.map { |group| [group, rights.select { |right| right.name =~ /^#{group}\./i }.map { |right| [right.name.split('.')[1..-1].join('. '), right.id] }] }
      end
    end
  end
end

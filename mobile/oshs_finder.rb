#encoding: utf-8
module Core
  module Mobile
    class OshsFinder

      attr_accessor :term, :current_user

      def initialize(term, current_user)
        self.term = term
        self.current_user = current_user
      end
      
      def find
        return if current_user.blank?
        return find_in_mobilre_client_group if term.blank?
        find_in_oshs
      end

      def find_in_mobilre_client_group
        Core::Groups::Group.mobile_client.members(current_user.provider_id).map {|record| ::Classifiers::Oshs::Record.find(record.oshs_type, record.oshs_id) }
      end

      def find_in_oshs
        ::Classifiers::Oshs::Record.find_by_term([::Classifiers::Oshs::MVD_PERSON, ::Classifiers::Oshs::MVD_ORGANISATION, ::Classifiers::Oshs::GROUP], term, current_user.provider_id, 10)
      end

    end
  end
end
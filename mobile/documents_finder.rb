#encoding: utf-8
module Core
  module Mobile
    class DocumentsFinder

      attr_accessor :journal_type, :addressed_to_id, :provider_id, :from_id, :primary_consideration, :official_id

      def initialize(journal_type, current_user, from_id = nil, primary_consideration = false, official_id = nil)
        self.journal_type = journal_type || Core::Cards::Types::INCOMING_DOCUMENTS
        self.addressed_to_id = official_id || current_user.official_id
        self.provider_id = current_user.provider_id
        self.from_id = from_id
        self.primary_consideration = primary_consideration
      end

      def find
        if Core::Mobile::DocumentsFinder.incoming_journal_types.include?(journal_type)
          documents = find_by_exemplars
          unless from_id.blank?
            documents = documents.where(from_id: from_id) unless journal_type == Core::Cards::Types::CITIZEN_REQUESTS
            documents = documents.where('state_structures.organisation_id' => from_id) if journal_type == Core::Cards::Types::CITIZEN_REQUESTS
          end
          documents = documents.order_by(reg_number: -1)
        elsif Core::Mobile::DocumentsFinder.outgoing_journal_types.include?(journal_type)
          find_in_workstation
        else
          []
        end
      end

      def filter
        return (find_by_exemplars.map { |document| ::Classifiers::Oshs::Record.find(document.from_type, document.from_id) }).uniq if journal_type == Core::Cards::Types::INCOMING_DOCUMENTS
        return (find_by_exemplars.map { |document| document.is_from_state_structure ? document.state_structures.map(&:organisation) : [] }).flatten.uniq if journal_type == Core::Cards::Types::CITIZEN_REQUESTS
        return []
      end

      def self.incoming_journal_types
        [Core::Cards::Types::INCOMING_DOCUMENTS, Core::Cards::Types::SECRET_INCOMING_DOCUMENTS, Core::Cards::Types::CITIZEN_REQUESTS, Core::Cards::Types::INCOMING_ORDERS, Core::Cards::Types::SECRET_INCOMING_ORDERS]
      end

      def self.outgoing_journal_types
        [Core::Cards::Types::OUTGOING_DOCUMENTS, Core::Cards::Types::ORDERS]
      end

      def self.is_incoming_document?(uid)
        return if uid.blank?
        uid.to_s.start_with?(_uid_codes::INCOMING_DOCUMENTS, _uid_codes::SECRET_INCOMING_DOCUMENTS, _uid_codes::INCOMING_ORDERS, _uid_codes::CITIZEN_REQUESTS, _uid_codes::SECRET_INCOMING_ORDERS)
      end

      def self.find_by_uid(uid, provider_id)
        uid ||= ''
        if is_incoming_document? uid
          ::Common::Card.find(uid, provider_id)
        else
          Core::Workstation::CommonCard.klass(uid).by_uid(uid, provider_id) unless Core::Workstation::CommonCard.klass(uid).blank?
        end
      end

      private

      def find_in_workstation
        Core::Workstation::CommonCards::Finder.cards_for_journal(journal_type).where(
          status_id: ::Classifiers::Simples::NonRegisteredDocumentStatus.on_signing_id,
          provider_id: provider_id,
          'agreement_route.signer.official_id' => addressed_to_id.to_s,
          'agreement_route.signer.status' => Core::Workstation::Card::Inspector::UNDER_CONSIDERATION
        ).order_by(_id: -1)
      end

      def find_by_exemplars
        exemplars = Core::Bpe::Exemplar.where(
          addressed_to_id: addressed_to_id
        )
        unless primary_consideration
          exemplars = exemplars.where(journal_type: journal_type, status_code: Core::Classifiers::ExemplarStatus::SENT_TO_THE_REPORT)
        else
          exemplars = exemplars.where(status_code: Core::Classifiers::ExemplarStatus::PRIMARY_CONSIDERATION)
        end
        Core::Cards::Types.klass(journal_type).where(:uid.in => exemplars.distinct(:document_uid), provider_id: provider_id, :mobile_status.ne => "approved")
      end

    def self._uid_codes
      Core::Cards::Parents::CommonCard::UidCodes
    end

    end
  end
end
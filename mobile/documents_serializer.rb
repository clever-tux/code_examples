#encoding: utf-8
module Core
  module Mobile
    class DocumentsSerializer

      attr_accessor :obj, :filters, :current_user

      def initialize(obj, filters = [], current_user = nil)
        self.obj = obj
        self.filters = filters
        self.current_user = current_user
      end

      def serialize
        return serialize_scope if obj.is_a?(Mongoid::Criteria) || obj.is_a?(Array)
        return serialize_incoming_document if Core::Mobile::DocumentsFinder.incoming_journal_types.include?(obj.card_type)
        serialize_outgoing_document
      end

      def serialize_link
        {
          uid: obj.uid,
          images: images,
          info: info
        }
      end

      def serialize_scope
        {
          pagination: pagination,
          filter: filter,
          documents: obj.map { |document|
            {
              uid: document.uid,
              reg_number: document.respond_to?(:reg_number) ? document.reg_number : "",
              head: head(document),
              rows: rows(document)
            }
          }
        }
      end

      def serialize_incoming_document
        view_card
        {
          uid: obj.uid,
          head: head(obj),
          rows: rows(obj),
          filter: filter(generate_filter),
          registration_number: document_reg_number,
          registration_date: obj.registration_date.to_s,
          decision: decision_serialize,
          images: images,
          info: info
        }
      end

      def serialize_outgoing_document
        view_card
        {
          uid: obj.uid,
          head: head(obj),
          rows: rows(obj),
          links: links_serialize,
          agreement_lists: agreement_route_serialize,
          images: images
        }
      end


      def pagination
        {
          total_count: obj.total_count,
          current_page: obj.current_page,
          num_pages: obj.num_pages
        }
      end

      def rows(document)
        rows = []

        if [::Core::Cards::Types::INCOMING_DOCUMENTS, Core::Cards::Types::SECRET_INCOMING_DOCUMENTS, ::Core::Cards::Types::INCOMING_ORDERS, Core::Cards::Types::SECRET_INCOMING_ORDERS].include?(document.card_type)
          signer = document.signer
          rows << signer.to_s(with_organization: true) unless signer.blank?
          rows << "#{document.registration_number} от #{document.registration_date}"
        elsif document.card_type == ::Core::Cards::Types::CITIZEN_REQUESTS
          rows << "#{document_reg_number(document)} от #{document.registration_date}"
        elsif document.card_type.in? ::Core::Workstation::CardTypes.all
          performer = document.performer
          rows << performer.to_s(with_organization: true) unless performer.blank?
        end

      end

      def head(document)
        if document.card_type.in? [::Core::Cards::Types::INCOMING_DOCUMENTS,
                                   ::Core::Cards::Types::SECRET_INCOMING_DOCUMENTS,
                                   ::Core::Cards::Types::INCOMING_ORDERS,
                                   ::Core::Cards::Types::SECRET_INCOMING_ORDERS,
                                   ::Core::Workstation::CardTypes::OUTGOING_DOCUMENTS,
                                   ::Core::Workstation::CardTypes::ORDERS]
          document.short_description.blank? ? NO_DESCRIPTION : document.short_description
        elsif document.card_type == ::Core::Cards::Types::CITIZEN_REQUESTS
          document.request_content.blank? ? NO_DESCRIPTION : document.request_content
        end
      end

      def filter(f = filters)
        f.map do |f|
          { from_id: f.id, title: f.short_title } unless f.blank?
        end.compact
      end

      def generate_filter
        return [ ::Classifiers::Oshs::Record.find(obj.from_type, obj.from_id) ] if obj.card_type == Core::Cards::Types::INCOMING_DOCUMENTS
        return (obj.is_from_state_structure? ? obj.state_structures.map(&:organisation) : []).flatten.uniq if obj.card_type == Core::Cards::Types::CITIZEN_REQUESTS
        []
      end

      def decision_serialize
        return {} if current_user.blank?
        query = Core::Decisions::Decision.where(document_uid: obj.uid, provider_id: current_user.provider_id)
        
        if obj.on_primary_consideration?
          decision = query.first
        else
          query = query.where(signer_id: current_user.official_id)
          decision = query.last
        end
        
        return {} if decision.blank?
        {
          id: decision.id,
          letterhead: decision.letterhead.try(:full_title),
          blocks: blocks(decision),
          signer_id: decision.signer_id,
          signer_name: decision.signer.to_s
        }
      end

      def blocks(decision)
        decision.blocks.map do |block|
          {
            id: block.id,
            number: block.number,
            text: block.text,
            performers: block.performers.map { |performer|
              { id: performer.id, performer_id: performer.performer_id, to_s: performer.to_s(provider: decision.provider), is_group: performer.is_group?, is_organization: performer.is_organisation?  } }
          }
        end
      end

      def images
        Core::DocumentImages::Image.where(document_uid: obj.uid).map { |image| "/documents/#{obj.uid}/document_images/#{image.id}" }
      end

      def info
        "/common/api_cards/#{obj.uid}/info_card.json"
      end

      #serialize only registered documents
      def links_serialize
        return [] if current_user.blank?
        linked_uids = ::Common::CardsLink.ws_links_by_uid(obj.uid, current_user.provider_id).map{|link| link.link_to(obj.uid)}
        documents = linked_uids.compact.uniq.map{|uid| ::Common::Card.find(uid, current_user.provider_id)}.compact
        return if documents.blank?
        documents.map do |document|
          {
            uid: document.uid,
            head: head_for_link(document),
            rows: rows_for_link(document),
            actuality: actuality(document)
          }
        end
      end

      def agreement_route_serialize
        return [] if obj.agreement_route.blank?
        lists = obj.agreement_route.agreement_lists
        return [] if lists.blank?
        lists.map do |list|
          {
            title: list.name_and_type,
            index: list.index,
            inspectors: list.inspectors.map { |inspector|
              {
                id: inspector.official_id,
                image: Core::Mobile::OshsSerializer.image(inspector.official),
                name: inspector.name_and_position,
                organization: inspector.organization,
                date: inspector.agreement_date.to_s
              }
            }
          }
        end
      end

      def head_for_link(document)
        "#{document_reg_number(document)} от #{document.registration_date}"
      end

      def rows_for_link(document)
        rows = []
        if document.card_type == ::Core::Cards::Types::CITIZEN_REQUESTS
          rows << ( document.request_content.blank? ? NO_DESCRIPTION : document.request_content )
        elsif document.card_type == ::Core::Cards::Types::INCOMING_DOCUMENTS
          signer = document.signer
          rows << signer.to_s(with_organization: true) unless signer.blank?
          rows << ( document.short_description.blank? ? NO_DESCRIPTION : document.short_description )
        else
          rows << ( document.short_description.blank? ? NO_DESCRIPTION : document.short_description )
        end
        rows
      end

      def actuality(document)
        return '' unless document.card_type == ::Core::Cards::Types::ORDERS
        document.actuality
      end

      def document_reg_number(document = obj)
        return '' if document.blank? && document.respond_to?(:registration_number)
        (document.card_type == ::Core::Cards::Types::CITIZEN_REQUESTS && document.is_reception_card?) ?
          document.reception_registration_number :
          document.registration_number
      end

      NO_DESCRIPTION = "Нет описания"

      def view_card
       Core::Workstation:: UserSettings.find(current_user.id).try(:view_card, obj)
      end

    end
  end
end
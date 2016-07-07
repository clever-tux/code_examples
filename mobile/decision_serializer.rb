#encoding: utf-8
module Core
  module Mobile
    class DecisionSerializer

      attr_accessor :decision, :saved

      def initialize(decision, saved)
        self.decision = decision
        self.saved = saved
      end

      def serialize
        {
          id: decision.id,
          document_uid: decision.document_uid,
          letterhead: decision.letterhead.try(:full_title),
          blocks: blocks,
          signer_id: decision.signer_id,
          signer_name: decision.signer.to_s,
          saved: saved,
          errors: decision.errors.messages
        }
      end

      def blocks
        (decision.blocks || []).map do |block|
          {
            id: block.id,
            number: block.number,
            text: block.text,
            performers: (block.performers || []).map { |performer|
              { id: performer.id, performer_id: performer.performer_id, to_s: performer.to_s(provider: decision.provider), is_group: performer.is_group?, is_organization: performer.is_organisation?, errors: performer.errors.messages }
            },
            errors: block.errors.messages
          }
        end
      end

    end
  end
end
#encoding: utf-8
module Core
  module Mobile
    class DocumentsUpdater

      APPROVED = "approved"
      CANCELED = "canceled"
      ERROR = "error"

      attr_accessor :document, :what_to_do, :user, :comment, :prms

      def initialize(document, prms, user = nil)
        self.document = document
        self.what_to_do = prms[:what_to_do]
        self.user = user
        self.comment = prms[:comment]
        self.prms = prms
      end

      def update
        return if document.blank? || what_to_do.blank?
        approve and return if what_to_do == "approve"
        to_the_primary_consideration and return if what_to_do == "to_the_primary_consideration"
        cancel and return if what_to_do == "cancel"
      end

      def to_the_primary_consideration
        Core::Bpe::Tasks::ToThePrimaryConsideration.new(user.provider_id, document.uid, prms[:official_id]).go
      end

      def approve
        if Core::Mobile::DocumentsFinder.incoming_journal_types.include?(document.card_type)
          approve_incoming_types
        else
          approve_outgoing_types
        end
      end

      def cancel
        if Core::Mobile::DocumentsFinder.incoming_journal_types.include?(document.card_type)
          cancel_incoming_types
        else
          cancel_outgoing_types
        end
      end

      def approve_incoming_types
        document.set(:mobile_status, APPROVED)
        return APPROVED
      end

      def cancel_incoming_types
        document.set(:mobile_status, CANCELED)
        return CANCELED
      end

      def approve_outgoing_types
        card = _updater.new(document, {status_id:  ::Classifiers::Simples::NonRegisteredDocumentStatus.on_registration_id, action: 'sign'}, user).update_status
        return card.is_on_registration? ? APPROVED : ERROR
      end

      def cancel_outgoing_types
        card = _updater.new(document, {status_id:  ::Classifiers::Simples::NonRegisteredDocumentStatus.on_correction_id, action: 'reject', reject_comment: comment}, user).update_status
        return card.is_on_correction? ? CANCELED : ERROR
      end

      private

      def _updater
        Core::Workstation::CommonCard.updater_klass(document.uid)
      end

    end
  end
end
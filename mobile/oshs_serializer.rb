#encoding: utf-8
require 'RMagick'
module Core
  module Mobile
    class OshsSerializer

      attr_accessor :records, :provider_id

      def initialize(records, provider_id)
        self.records = records
        self.provider_id = provider_id
      end

      def serialize
        {
          records: serialize_records
        }
      end

      def self.assistants_for(current_user)
        h = {
              me:
                {
                  id: current_user.official_id, 
                  name: current_user.official_name
                },
              heads: []
            }
        Core::Classifiers::Assistant.heads_for(current_user.provider_id, current_user.official_id.to_s).each do |head|
          h[:heads] << {
            official_id: head.id,
            official_name: head.to_s
          }
        end
        h
      end

      def serialize_records
        records.map do |record|
        {
          id: record.id,
          is_organization: record.type == ::Classifiers::Oshs::MVD_ORGANISATION,
          is_group: record.type == ::Classifiers::Oshs::GROUP,
          name: record.to_s(short_title: true),
          description: description(record),
          image: image(record)
        }
        end
      end

      def description(record)
        if record.type == ::Classifiers::Oshs::MVD_PERSON
          s = "#{record.position} "
          unless record.organization.blank?
            s += record.organization.short_title
          end
          return [s]
        end
        if record.type == ::Classifiers::Oshs::GROUP
          return record.members(provider_id).map { |member| member.member_name }
        end
      end

      def image(record)
        self.class.image(record)
      end

      def self.image(record)
        return "" if record.blank?
        return "" unless record.type == ::Classifiers::Oshs::MVD_PERSON
        return "" if record.photo.blank?
        return "" if record.photo.file.blank?
        content = record.photo.file.read
        return "" if content.blank?
        image = Magick::Image.from_blob(content).first
        Base64.encode64(image.resize_to_fill(70, nil, Magick::NorthGravity).to_blob)
      end

    end
  end
end
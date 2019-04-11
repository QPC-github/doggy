# encoding: utf-8
# frozen_string_literal: true

module Doggy
  module Models
    class Monitor < Doggy::Model
      class Options
        include Virtus.model

        attribute :escalation_message,  String
        attribute :evaluation_delay,    Integer
        attribute :include_tags,        Boolean
        attribute :locked,              Boolean
        attribute :new_host_delay,      Integer
        attribute :no_data_timeframe,   Integer
        attribute :notify_audit,        Boolean
        attribute :notify_no_data,      Boolean
        attribute :renotify_interval,   Integer
        attribute :require_full_window, Boolean
        attribute :silenced,            Hash
        attribute :thresholds,          Hash
        attribute :timeout_h,           Integer
      end

      attribute :id,     Integer
      attribute :org_id, Integer
      attribute :name,   String

      attribute :message, String
      attribute :query,   String
      attribute :options, Options
      attribute :tags,    Array[String]
      attribute :type,    String
      attribute :multi,   Boolean

      def prefix
        'monitor'
      end

      def ensure_read_only!
        if options
          options.locked = true
        else
          self.options = Options.new(locked: true)
        end
      end

      def refute_read_only!
        if options
          options.locked = false
        else
          self.options = Options.new(locked: false)
        end
      end

      def self.resource_url(id = nil)
        ["https://app.datadoghq.com/api/v1/monitor", id].compact.join("/")
      end

      def managed?
        !(name =~ Doggy::DOG_SKIP_REGEX)
      end

      def ensure_managed_emoji!
        return unless managed?
        return if name =~ /\xF0\x9F\x90\xB6/
        self.name += " \xF0\x9F\x90\xB6"
      end

      def validate
        ensure_renotify_interval_valid
      end

      def toggle_mute!(action, body = nil)
        return unless %w[mute unmute].include?(action) && id
        attributes = request(:post, "#{resource_url(id)}/#{action}", body)
        if message = attributes['errors']
          Doggy.ui.error(message)
        else
          self.attributes = attributes
          if local_version = Doggy::Model.find_local(id)
            self.path = local_version.path
          end
          save_local
        end
      end

      def human_url
        "https://#{Doggy.base_human_url}/monitors##{id}"
      end

      def human_edit_url
        "https://#{Doggy.base_human_url}/monitors##{id}/edit"
      end

      def to_h
        Doggy::Model.sort_by_key(super.merge(options: options.to_h))
      end

      private

      def ensure_renotify_interval_valid
        return unless options&.renotify_interval && options.renotify_interval.to_i > 0

        allowed_renotify_intervals = [10, 20, 30, 40, 50, 60, 90, 120, 180, 240, 300, 360, 720, 1440] # minutes
        best_matching_interval = allowed_renotify_intervals.min_by { |x| (x.to_f - options.renotify_interval).abs }
        puts "WARN: Monitor #{id} uses invalid escalation interval (renotify_interval) #{options.renotify_interval}, using #{best_matching_interval} instead"
        options.renotify_interval = best_matching_interval
      end
    end # Monitor
  end # Models
end # Doggy

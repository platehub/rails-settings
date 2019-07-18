module RailsSettings
  module Base
    def self.included(base)
      base.class_eval do
        has_many :setting_objects,
                 :as         => :target,
                #  :autosave   => true,
                 :dependent  => :destroy,
                 :class_name => self.setting_object_class_name do
          #
          def detect_with_class(&block)
            result = to_a.detect(&block)
            if result
              owner_class = proxy_association.owner.class
              setting_klass = owner_class.setting_object_class_names[result.var.to_sym]
              result = result.becomes(setting_klass.safe_constantize) if setting_klass != owner_class.setting_object_class_name
            end
            result
          end

          def with_own_class
            owner_class = proxy_association.owner.class
            to_a.map do |x|
              setting_klass = owner_class.setting_object_class_names[x.var.to_sym]
              setting_klass != owner_class.setting_object_class_name ? x.becomes(setting_klass.safe_constantize) : x
            end
          end
        end

        self.setting_object_class_names.each do |key_name, klass|
          has_many  "#{key_name}_setting_objects".to_sym,
                    -> {where(var: key_name)},
                    :as         => :target,
                    :autosave   => true,
                    # :dependent  => :delete_all,
                    :class_name => klass
        end

        validate :validate_settings
        after_save :autosave_settings

        def settings(var)
          raise ArgumentError unless var.is_a?(Symbol)
          raise ArgumentError.new("Unknown key: #{var}") unless self.class.default_settings[var]

          if RailsSettings.can_protect_attributes?
            setting_objects.detect_with_class { |s| s.var == var.to_s } || scoped_setting_objects(var).build({ :var => var.to_s }, :without_protection => true)
          else
            setting_objects.detect_with_class { |s| s.var == var.to_s } || scoped_setting_objects(var).build(:var => var.to_s)
          end
        end

        def settings=(value)
          if value.nil?
            self.class.setting_object_class_names.keys.each do |key_name|
              scoped_setting_objects(key_name).each(&:mark_for_destruction)
            end
          else
            raise ArgumentError
          end
        end

        def settings?(var=nil)
          if var.nil?
            setting_objects.any? { |setting_object| !setting_object.marked_for_destruction? && setting_object.value.present? }
          else
            settings(var).value.present?
          end
        end

        def to_settings_hash
          settings_hash = self.class.default_settings.dup
          settings_hash.each do |var, vals|
            settings_hash[var] = settings_hash[var].merge(settings(var.to_sym).value)
          end
          settings_hash
        end

        private

        def autosave_settings
          for setting in self.setting_objects.with_own_class
            setting.save if setting.changed?
          end
        end

        def validate_settings
          for setting in self.setting_objects.with_own_class.delete_if(&:valid?)
            setting.errors.messages.each{|key,msgs| msgs.each{|msg| self.errors.add("setting_objects.#{key.to_sym}".to_sym, msg) } }
          end
        end

        def scoped_setting_objects(var)
          send("#{var}_setting_objects")
        end
      end
    end
  end
end

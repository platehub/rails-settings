module RailsSettings
  module Base
    def self.included(base)
      base.class_eval do
        has_many :setting_objects,
                 :as         => :target,
                #  :autosave   => true,
                 :dependent  => :delete_all,
                 :class_name => self.setting_object_class_name do
          #
          def detect(&block)
            result = super
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

        self.setting_object_class_names.each_pair do |key_name, klass|
          has_many  "#{key_name}_setting_objects".to_sym,
                    -> {where(var: key_name)},
                    :as         => :target,
                    # :autosave   => true,
                    :dependent  => :delete_all,
                    :class_name => klass
        end

        after_save :autosave_settings

        def settings(var)
          raise ArgumentError unless var.is_a?(Symbol)
          raise ArgumentError.new("Unknown key: #{var}") unless self.class.default_settings[var]

          # setting_object = setting_objects.detect{ |s| s.var == var.to_s }
          # if setting_object
          #   setting_klass = self.class.setting_object_class_names[var]
          #   setting_object = setting_object.becomes(setting_klass.safe_constantize) if setting_klass != self.class.setting_object_class_name
          #   setting_object
          # else
          #   if RailsSettings.can_protect_attributes?
          #     scoped_setting_objects(var).build({ :var => var.to_s }, :without_protection => true)
          #   else
          #     scoped_setting_objects(var).build(:var => var.to_s, :target => self)
          #   end
          # end
          if RailsSettings.can_protect_attributes?
            setting_objects.detect { |s| s.var == var.to_s } || scoped_setting_objects(var).build({ :var => var.to_s }, :without_protection => true)
          else
            setting_objects.detect { |s| s.var == var.to_s } || scoped_setting_objects(var).build(:var => var.to_s, :target => self)
          end
        end

        def settings=(value)
          if value.nil?
            scoped_setting_objects(var).each(&:mark_for_destruction)
          else
            raise ArgumentError
          end
        end

        def settings?(var=nil)
          if var.nil?
            scoped_setting_objects(var).any? { |setting_object| !setting_object.marked_for_destruction? && setting_object.value.present? }
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
          for setting in setting_objects.with_own_class
            setting.save if setting.changed?
          end
        end

        def scoped_setting_objects(var)
          send("#{var}_setting_objects")
        end
      end
    end
  end
end

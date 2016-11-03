module RailsSettings
  class Configuration
    def initialize(*args, &block)
      options = args.extract_options!
      klass = args.shift
      keys = args

      raise ArgumentError unless klass

      @klass = klass
      @klass.class_attribute :default_settings, :setting_object_class_name, :setting_object_class_names
      @klass.default_settings = {}
      @klass.setting_object_class_name = options[:class_name] || 'RailsSettings::SettingObject'
      @klass.setting_object_class_names = {}

      if block_given?
        yield(self)
      else
        keys.each do |k|
          key(k)
        end
      end

      raise ArgumentError.new('has_settings: No keys defined') if @klass.default_settings.blank?
    end

    def key(name, options={})
      raise ArgumentError.new("has_settings: Symbol expected, but got a #{name.class}") unless name.is_a?(Symbol)
      raise ArgumentError.new("has_settings: Option :defaults or :class_name expected, but got #{options.keys.join(', ')}") unless options.blank? || options.keys.include?(:defaults) || options.keys.include?(:class_name)
      @klass.default_settings[name] = (options[:defaults] || {}).stringify_keys.freeze
      @klass.setting_object_class_names[name] = (options[:class_name] || @klass.setting_object_class_name).to_s
    end
  end
end

module ProtocolBuffers
  module Enum
    def self.included(clazz)
      clazz.extend(EnumClassMethods)
    end
  end

  module EnumClassMethods
    def set_fully_qualified_name(fully_qualified_name)
      @fully_qualified_name = fully_qualified_name.dup.freeze
    end

    def fully_qualified_name
      @fully_qualified_name
    end

    def value_to_names_map
      @value_to_names_map ||= self.constants.inject(Hash.new) do |hash, constant|
        # values do not have to be unique
        value = self.const_get(constant)
        hash[value] ||= Array.new
        hash[value] << constant.to_sym
        hash
      end
      @value_to_names_map
    end

    def name_to_value_map
      @name_to_value_map ||= self.constants.inject(Hash.new) do |hash, constant|
        hash[constant.to_sym] = self.const_get(constant)
        hash
      end
      @name_to_value_map
    end
  end
end

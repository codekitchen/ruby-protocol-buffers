require 'protocol_buffers/runtime/rpc'

module ProtocolBuffers
  class Service

    private_class_method :new

    def self.set_fully_qualified_name(name)
      @fully_qualified_name = name.dup.freeze
    end

    def self.fully_qualified_name
      @fully_qualified_name
    end

    def self.rpcs
      @rpcs
    end

    def self.rpc(name, proto_name, request_type, response_type)
      @rpcs ||= Array.new
      @rpcs = @rpcs.dup
      @rpcs << Rpc.new(name.to_sym, proto_name, request_type, response_type, self).freeze
      @rpcs.freeze
    end
  end
end

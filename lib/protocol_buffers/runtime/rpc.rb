module ProtocolBuffers
  class Rpc
    attr_reader :name, :proto_name, :request_class, :response_class, :service_class

    def initialize(name, proto_name, request_class, response_class, service_class)
      @name = name
      @proto_name = proto_name.dup.freeze
      @request_class = request_class
      @response_class = response_class
      @service_class = service_class
    end

    def to_s
      {
        :name => name,
        :proto_name => proto_name,
        :request_class_name => request_class.name,
        :response_class_name => response_class.name,
        :service_class_name => service_class.name
      }.to_s
    end
  end
end

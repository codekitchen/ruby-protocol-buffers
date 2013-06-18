module ProtocolBuffers

  class EncodeError < StandardError
    attr_reader :invalid_field

    def initialize(invalid_field)
      @invalid_field = invalid_field
    end
  end

  module Encoder # :nodoc: all
    def self.encode(io, message)
      message.validate!

      message.fields.each do |tag, field|
        next unless message.value_for_tag?(tag)

        value = message.value_for_tag(tag)
        wire_type = field.wire_type
        tag = (field.tag << 3) | wire_type

        if field.repeated?
          next if value.size == 0

          if field.packed?
            # encode packed field in a LENGTH_DELIMITED wire
            wire_type = 2
            tag = (field.tag << 3) | wire_type
            buf = StringIO.new
            value.each { |i| serialize_field_value(buf, field.wire_type, field.serialize(i)) }
            Varint.encode(io, tag)
            Varint.encode(io, buf.size)
            io.write(buf.string)
          else
            value.each { |i| serialize_field(io, tag, wire_type, field.serialize(i)) }
          end
        else
          serialize_field(io, tag, wire_type, field.serialize(value))
        end
      end

      message.each_unknown_field do |tag_int, value|
        wire_type = tag_int & 0b111
        serialize_field(io, tag_int, wire_type, value)
      end
    end

    def self.serialize_field(io, tag, wire_type, serialized)
      # write the tag
      Varint.encode(io, tag)
      self.serialize_field_value(io, wire_type, serialized)
      Varint.encode(io, tag & ~3 | 4) if wire_type == 3
    end

    def self.serialize_field_value(io, wire_type, serialized)
      # see comment in decoder.rb about magic numbers
      case wire_type
      when 0 # VARINT
        Varint.encode(io, serialized)
      when 1, 5 # FIXED64, FIXED32
        io.write(serialized)
      when 2 # LENGTH_DELIMITED
        Varint.encode(io, serialized.bytesize)
        io.write(serialized)
      when 3 # START_GROUP
        io.write(serialized)
      when 4 # END_GROUP: never appear
        raise(EncodeError, "Unexpected wire type END_GROUP")
      else
        raise(EncodeError, "unknown wire type: #{wire_type}")
      end
    end
  end

end

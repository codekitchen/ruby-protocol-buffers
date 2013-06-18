require 'protocol_buffers/limited_io'

module ProtocolBuffers

  class DecodeError < StandardError; end

  module Decoder # :nodoc: all
    def self.decode(io, message)
      fields = message.fields

      until io.eof?
        tag_int = Varint.decode(io)
        tag = tag_int >> 3
        wire_type = tag_int & 0b111
        break if wire_type == 4
        field = fields[tag]

        if field && ( !( field.packed? || wire_type == field.wire_type ) || ( field.packed? && wire_type != 2 ) )
          raise(DecodeError, "incorrect wire type for tag: #{field.tag}, expected #{field.wire_type} but got #{wire_type}\n#{field.inspect}")
        end

        # replacing const lookups with hard-coded ints removed an entire 10%
        # from an earlier decoding benchmark. these values can't change without
        # breaking the protocol anyway, so we decided it was worth it.
        case wire_type
        when 0 # VARINT
          value = Varint.decode(io)
        when 1 # FIXED64
          value = io.read(8)
        when 2 # LENGTH_DELIMITED
          length = Varint.decode(io)
          value = LimitedIO.new(io, length)
        when 5 # FIXED32
          value = io.read(4)
        when 3 # START_GROUP
          value = io
        when 4 # END_GROUP
          break
        else
          raise(DecodeError, "unknown wire type: #{wire_type}")
        end

        if field
          begin
            if field.packed?
              deserialized = []
              until value.eof?

                decoded = case field.wire_type
                  when 0 # VARINT
                    Varint.decode(value)
                  when 1 # FIXED64
                    value.read(8)
                  when 5 # FIXED32
                    value.read(4)
                  end
                deserialized << field.deserialize(decoded)
              end
            else
              deserialized = field.deserialize(value)
            end
            # merge_field handles repeated field logic
            message.merge_field(tag, deserialized, field)
          rescue ArgumentError
            # for enum fields, treat bad values as unknown fields
            if field.is_a?(Field::EnumField)
              field = nil
            else
              raise
            end
          end
        end

        unless field
          # ignore unknown fields, pass them on when re-serializing this message

          # special handling -- if it's a LENGTH_DELIMITED field, we need to
          # actually read the IO so that extra bytes aren't left on the wire
          value = value.read if wire_type == 2 # LENGTH_DELIMITED

          message.remember_unknown_field(tag_int, value)
        end
      end

      unless message.valid?
        raise(DecodeError, "invalid message")
      end

      return message
    rescue TypeError, ArgumentError
      raise(DecodeError, "error parsing message")
    end
  end

end

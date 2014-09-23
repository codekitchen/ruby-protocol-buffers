require 'rubygems'
require 'rspec'

require 'simplecov'
SimpleCov.start

require 'protocol_buffers'

# These are a couple of classes used by tests
class SignedIntTest
  include ProtocolBuffers::Message

  required :int32, :test_member, 1
  gen_methods! # new fields ignored after this point
end

class StringTest
  include ProtocolBuffers::Message

  optional :string, :test_member, 1
  gen_methods! # new fields ignored after this point
end

class NilTest
  include ProtocolBuffers::Message

  optional :string, :test_field_1, 1
  optional :string, :test_field_2, 2
  gen_methods! # new fields ignored after this point
end

# klass should be derived from ::ProtocolBuffers::Message
# and have a member named test_member
# value is assigned to test member, then an encoding/parse cycle occurs
# rescues are reported

# suppress_output is meant for use in RSpec tests where output is not desired

# This function returns true if value == decoded proto value
def validate_pbr(klass, value, suppress_output = false)
  unless suppress_output
    puts
    puts "Validate Pbr: class=#{klass.name}, value=#{value}"
    puts "  creating and encoding"
  end

  encode_pbr = klass.new
  encode_pbr.test_member = value
  encoded_string = encode_pbr.to_s

  unless suppress_output
    puts "  encoded_string: #{to_hex_string encoded_string}"
    puts "  encoded length: #{encoded_string.length}"
    puts "  parsing encoded_string"
  end

  decode_pbr = nil;
  begin
    decode_pbr = klass.parse encoded_string
  rescue Exception => e
    # Exceptions always return false
    unless suppress_output
      puts e.message
      puts "  FAIL: RESCUE occured in #{klass.name}.parse"
    end
    return false
  end

  if decode_pbr
    unless suppress_output
      puts "  decoded value: #{decode_pbr.test_member}"
      puts "   passed value: #{value}"
      puts "  decoded value <=> passed value = #{decode_pbr.test_member <=> value}"
    end

    if value.respond_to?("bytesize")
      unless suppress_output
        puts "  decoded value bytesize: #{decode_pbr.test_member.bytesize}"
        puts "  passed value bytesize : #{value.bytesize}"
        puts "  decoded value inspect : #{decode_pbr.test_member.inspect}"
        puts "  passed value inspect  : #{value.inspect}"
      end

      # Ruby 1.8 Strings don't have encodings
      if decode_pbr.test_member.respond_to?("encoding")
        unless suppress_output
          puts "  decoded value encoding: #{decode_pbr.test_member.encoding.name}"
          puts "  passed value encoding : #{value.encoding.name}"
        end
      end
    end

    unless suppress_output
      puts "  GOOD COMPARE" if decode_pbr.test_member == value
    end

    decode_pbr.test_member == value
  end
end

def to_hex_string ss
  yy = []
  ss.each_byte { |b| yy << b.to_s(16) }
  yy.join(' ')
end

def has_compiler?
  ProtocolBuffers::Compiler.available?
end

RSpec.configure do |config|
  config.backtrace_exclusion_patterns = []
  config.after(:each) do
    # clear our namespaces
    Object.send(:remove_const, :Simple) if defined?(Simple)
    Object.send(:remove_const, :Featureful) if defined?(Featureful)
    Object.send(:remove_const, :Foo) if defined?(Foo)
    Object.send(:remove_const, :TehUnknown) if defined?(TehUnknown)
    Object.send(:remove_const, :TehUnknown2) if defined?(TehUnknown2)
    Object.send(:remove_const, :TehUnknown3) if defined?(TehUnknown3)
  end
end

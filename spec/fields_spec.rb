# encoding: binary

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'stringio'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers/runtime/field'

describe ProtocolBuffers, "fields" do

  def mkfield(ftype)
    ProtocolBuffers::Field.const_get(ftype).new(:optional, "test", 1)
  end

  it "checks bounds on varint field types" do
    u32 = mkfield(:Uint32Field)
    proc { u32.check_valid(0xFFFFFFFF) }.should_not raise_error()
    proc { u32.check_valid(0x100000000) }.should raise_error(ArgumentError)
    proc { u32.check_valid(-1) }.should raise_error(ArgumentError)

    u64 = mkfield(:Uint64Field)
    proc { u64.check_valid(0xFFFFFFFF_FFFFFFFF) }.should_not raise_error()
    proc { u64.check_valid(0x100000000_00000000) }.should raise_error(ArgumentError)
    proc { u64.check_valid(-1) }.should raise_error(ArgumentError)
  end

  it "properly encodes and decodes negative varints" do
    val = -2082844800000000
    str = "\200\300\313\274\236\265\246\374\377\001"
    sio = ProtocolBuffers.bin_sio
    ProtocolBuffers::Varint.encode(sio, val)
    sio.string.should == str
    sio.rewind
    val2 = ProtocolBuffers::Varint.decode(sio)
    int64 = mkfield(:Int64Field)
    int64.deserialize(val2).should == val
    proc { int64.check_value(int64.deserialize(val2)) }.should_not raise_error
  end

  context "UTF-8 encoding of length-delimited fields" do
    if RUBY_VERSION < "1.9"
      pending "UTF-8 validation only happens in ruby 1.9+"
    else

      before :each do
        @good_utf   = "\xc2\xa1hola\x21"
        @bad_utf    = "\xc2"
        @good_ascii = "!hola!".force_encoding("us-ascii")

        @good_utf_io   = proc { StringIO.new(@good_utf) }
        @bad_utf_io    = proc { StringIO.new(@bad_utf) }
        @good_ascii_io = proc { StringIO.new(@good_ascii) }

        @s = mkfield(:StringField)
        @b = mkfield(:BytesField)
      end

      context "string fields" do

        it "forces UTF-8 on serializing" do
          @s.serialize(@good_utf).encoding.should == Encoding::UTF_8
          proc { @s.check_valid(@s.serialize(@good_utf)) }.should_not raise_error()

          @s.serialize(@good_ascii).encoding.should == Encoding::UTF_8
          proc { @s.check_valid(@s.serialize(@good_ascii)) }.should_not raise_error()

          proc { @s.serialize(@bad_utf) }.should raise_error(ArgumentError)
        end

        it "forces UTF-8 on deserializing" do
          @s.deserialize(@good_utf_io[]).encoding.should == Encoding::UTF_8
          proc { @s.check_valid(@s.deserialize(@good_utf_io[])) }.should_not raise_error()

          @s.deserialize(@good_ascii_io[]).encoding.should == Encoding::UTF_8
          proc { @s.check_valid(@s.deserialize(@good_ascii_io[])) }.should_not raise_error()

          @s.deserialize(@bad_utf_io[]).encoding.should == Encoding::UTF_8
          proc { @s.check_valid(@s.deserialize(@bad_utf_io[])) }.should raise_error(ArgumentError)
        end
      end

      context "byte fields" do

        it "does not force UTF-8 on deserializing" do
          @b.deserialize(@good_utf_io[]).encoding.should == Encoding::BINARY
          proc { @b.check_valid(@b.deserialize(@good_utf_io[])) }.should_not raise_error()

          @b.deserialize(@good_ascii_io[]).encoding.should == Encoding.find("us-ascii")
          proc { @b.check_valid(@b.deserialize(@good_ascii_io[])) }.should_not raise_error()

          @b.deserialize(@bad_utf_io[]).encoding.should == Encoding::BINARY
          proc { @b.check_valid(@b.deserialize(@bad_utf_io[])) }.should_not raise_error()
        end
      end
    end
  end

  it "provides a reader for proxy_class on message fields" do
    ProtocolBuffers::Field::MessageField.new(nil, :optional, :fake_name, 1).should respond_to(:proxy_class)
    ProtocolBuffers::Field::MessageField.new(Class, :optional, :fake_name, 1).proxy_class.should == Class
  end
end

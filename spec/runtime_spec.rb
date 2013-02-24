require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'stringio'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'
require 'protocol_buffers/compiler'

describe ProtocolBuffers, "runtime" do
  before(:each) do
    # clear our namespaces
    %w( Simple Featureful Foo Packed TehUnknown TehUnknown2 TehUnknown3 ).each do |klass|
      Object.send(:remove_const, klass.to_sym) if Object.const_defined?(klass.to_sym)
    end

    # load test protos
    %w( simple featureful packed ).each do |proto|
      load File.join(File.dirname(__FILE__), "proto_files", "#{proto}.pb.rb")
    end
  end

  context "packed field handling" do

    before :each do
      @packed = Packed::Test.new
    end

    it "does not encode empty field" do
      @packed.a = [ ]
      @packed.to_s.should == ""

      ser = ProtocolBuffers.bin_sio(@packed.to_s)
      unpacked = Packed::Test.parse(ser)
      unpacked.a.should == [ ]
    end

    it "correctly encodes repeated field" do
      # Example values from https://developers.google.com/protocol-buffers/docs/encoding.
      @packed.a  = [ 3, 270 ]
      @packed.a << 86942
      @packed.to_s.should == "\x22\x06\x03\x8e\x02\x9e\xa7\x05"

      ser = ProtocolBuffers.bin_sio(@packed.to_s)
      unpacked = Packed::Test.parse(ser)
      unpacked.a.should == [ 3, 270, 86942 ]
    end

    it "handles primitive numeric data types" do
      types_to_be_packed = {
        :int32    => { :field => :a, :value => [ 0, 1, 1 ] },
        :int64    => { :field => :b, :value => [ 2, 3, 5 ] },

        :uint32   => { :field => :c, :value => [ 8, 13, 21 ] },
        :uint64   => { :field => :d, :value => [ 34, 55, 89 ] },

        :sint32   => { :field => :e, :value => [ -114, 233, -377 ] },
        :sint64   => { :field => :f, :value => [ 610, -987, 1597 ] },

        :fixed64  => { :field => :g, :value => [ 2584, 4181, 6765 ] },
        :sfixed64 => { :field => :h, :value => [ -10946, 17711, -28657 ] },
        :double   => { :field => :i, :value => [ 46.368, -75025, 121.393 ] },

        :fixed32  => { :field => :j, :value => [ 196418, 317811, 514229 ] },
        :sfixed32 => { :field => :k, :value => [ -832040, 1346269, -2178309 ] },
        :float    => { :field => :l, :value => [ 3524.578, -5702887, 92274.65 ] },

        :bool     => { :field => :m, :value => [ false, false, true, false ] },
        :enum     => { :field => :n, :value => [ Packed::Test::N::A, Packed::Test::N::B, Packed::Test::N::A, Packed::Test::N::C ] }
      }

      types_to_be_packed.values.each do |v|
        @packed.send("#{v[:field]}=", v[:value])
      end

      ser = ProtocolBuffers.bin_sio(@packed.to_s)
      unpacked = Packed::Test.parse(ser)

      types_to_be_packed.each_pair do |k, v|
        if [ :float, :double ].include? k
          act = unpacked.send(v[:field]).map{|i| (i * 100).round}
          exp = v[:value].map{|i| (i * 100).round}

          act.should == exp
        else
          unpacked.send(v[:field]).should == v[:value]
        end
      end

    end

  end

  it "can handle basic operations" do

    msg1 = Simple::Test1.new
    msg1.test_field.should == ""

    msg1.test_field = "zomgkittenz"

    ser = ProtocolBuffers.bin_sio(msg1.to_s)
    msg2 = Simple::Test1.parse(ser)
    msg2.test_field.should == "zomgkittenz"
    msg2.should == msg1
  end

  it "doesn't serialize unset fields" do
    msg1 = Simple::Test1.new
    msg1.test_field.should == ""
    msg1.to_s.should == ""

    msg1.test_field = "zomgkittenz"
    msg1.to_s.should_not == ""
  end

  it "flags values that have been set" do
    a1 = Featureful::A.new
    a1.has_i2?.should == false
    a1.i2 = 5
    a1.has_i2?.should == true
  end

  it "flags sub-messages that have been set" do
    a1 = Featureful::A.new
    a1.value_for_tag?(a1.class.field_for_name(:sub1).tag).should == true
    a1.value_for_tag?(a1.class.field_for_name(:sub2).tag).should == false
    a1.value_for_tag?(a1.class.field_for_name(:sub3).tag).should == false

    a1.has_sub1?.should == true
    a1.has_sub2?.should == false
    a1.has_sub3?.should == false

    a1.sub2 = Featureful::A::Sub.new(:payload => "ohai")
    a1.has_sub2?.should == true
  end

  describe "#inspect" do
    it "should leave out un-set fields" do
      b1 = Simple::Bar.new
      b1.inspect.should == "#<Simple::Bar foo=<unset>>"
      b1.foo = Simple::Foo.new
      b1.inspect.should == "#<Simple::Bar foo=#<Simple::Foo>>"
    end
  end

  it "detects changes to a sub-message and flags it as set if it wasn't" do
    a1 = Featureful::A.new
    a1.has_sub2?.should == false
    a1.sub2.payload = "ohai"
    a1.has_sub2?.should == true
  end

  it "detects changes to a sub-sub-message and flags up the chain" do
    a1 = Featureful::A.new
    a1.sub2.has_subsub1?.should == false
    a1.has_sub2?.should == false
    a1.sub2.subsub1.subsub_payload = "ohai"
    a1.has_sub2?.should == true
    a1.sub2.has_subsub1?.should == true
  end

  it "allows directly recursive sub-messages" do
    module Foo
      class Foo < ProtocolBuffers::Message
        optional :int32, :payload, 1
        optional Foo, :foo, 2
      end
    end

    foo = Foo::Foo.new
    foo.has_foo?.should == false
    foo.foo.payload = 17
    foo.has_foo?.should == true
    foo.foo.has_foo?.should == false
  end

  it "allows indirectly recursive sub-messages" do
    module Foo
      class Bar < ProtocolBuffers::Message; end

      class Foo < ProtocolBuffers::Message
        optional :int32, :payload, 1
        optional Bar, :bar, 2
      end

      class Bar
        optional Foo, :foo, 1
        optional :int32, :payload, 2
      end
    end

    foo = Foo::Foo.new
    foo.has_bar?.should == false
    foo.bar.payload = 17
    foo.has_bar?.should == true
    foo.bar.has_foo?.should == false
    foo.bar.foo.payload = 23
    foo.bar.has_foo?.should == true
  end

  it "pretends that repeated fields are arrays" do
    # make sure our RepeatedField class acts like a normal Array
    module Foo
      class Foo < ProtocolBuffers::Message
        repeated :int32, :nums, 1
      end
    end

    foo = Foo::Foo.new
    foo2 = Foo::Foo.new(:nums => [1,2,3])
    proc do
      foo.nums << 1
      foo.nums.class.should == ProtocolBuffers::RepeatedField
      foo.nums.to_a.class.should == Array
      (foo.nums & foo2.nums).should == [1]
      (foo.nums + foo2.nums).should == [1,1,2,3]
      foo2.nums.map! { |i| i + 1 }
      foo2.nums.to_a.should == [2,3,4]
      foo2.nums.class.should == ProtocolBuffers::RepeatedField
    end.should_not raise_error
  end

  it "does type checking of repeated fields" do
    a1 = Featureful::A.new
    proc do
      a1.sub1 << Featureful::A::Sub.new
    end.should_not raise_error(TypeError)

    a1 = Featureful::A.new
    proc do
      a1.sub1 << Featureful::A::Sub.new << "dummy string"
    end.should raise_error(TypeError)
    a1.sub1.should == [Featureful::A::Sub.new]

    a1 = Featureful::A.new
    proc do
      a1.sub1 = [Featureful::A::Sub.new, Featureful::A::Sub.new, 5, Featureful::A::Sub.new]
    end.should raise_error(TypeError)
  end

  it "does value checking of repeated fields" do
    module Foo
      class Foo < ProtocolBuffers::Message
        repeated :int32, :nums, 1
      end
    end

    foo = Foo::Foo.new
    proc do
      foo.nums << 5 << 3 << (1 << 32) # value too large for int32
    end.should raise_error(ArgumentError)
  end

  # sort of redundant test, but let's check the example in the docs for
  # correctness
  it "handles singular message fields exactly as in the documentation" do
    module Foo
      class Bar < ProtocolBuffers::Message
        optional :int32, :i, 1
      end
      class Foo < ProtocolBuffers::Message
        optional Bar, :bar, 1
      end
    end

    foo = Foo::Foo.new
    foo.has_bar?.should == false
    foo.bar = Foo::Bar.new
    foo.has_bar?.should == true

    foo = Foo::Foo.new
    foo.has_bar?.should == false
    foo.bar.i = 1
    foo.has_bar?.should == true

    foo = Foo::Foo.new
    foo.has_bar?.should == false
    local_i = foo.bar.i
    foo.has_bar?.should == false
  end

  # another example from the docs
  it "handles repeated field logic" do
    module Foo
      class Foo < ProtocolBuffers::Message
        repeated :int32, :nums, 1
      end
    end

    foo = Foo::Foo.new
    foo.has_nums?.should == true
    foo.nums << 15
    foo.has_nums?.should == true
    foo.nums.push(32)
    foo.nums.length.should == 2
    foo.nums[0].should == 15
    foo.nums[1].should == 32
    foo.nums[1] = 56
    foo.nums[1].should == 56

    foo = Foo::Foo.new
    foo.nums << 15
    foo.nums.push(32)
    foo.nums.length.should == 2
    foo.nums.clear
    foo.nums.length.should == 0
    foo.nums << 15
    foo.nums.length.should == 1
    foo.nums = nil
    foo.nums.length.should == 0

    foo = Foo::Foo.new
    foo.nums << 15
    foo.nums = [1, 3, 5]
    foo.nums.length.should == 3
    foo.nums.to_a.should == [1,3,5]

    foo.merge_from_string(foo.to_s)
    foo.nums.length.should == 6
    foo.nums.to_a.should == [1,3,5,1,3,5]
  end

  it "can assign any object with an each method to a repeated field" do
    module Foo
      class Bar < ProtocolBuffers::Message
        optional :int32, :i, 1
      end

      class Foo < ProtocolBuffers::Message
        repeated Bar, :nums, 1
      end
    end

    class Blah
      def each
        yield Foo::Bar.new(:i => 1)
        yield Foo::Bar.new(:i => 3)
      end
    end

    foo = Foo::Foo.new
    foo.nums = Blah.new
    foo.nums.to_a.should == [Foo::Bar.new(:i => 1), Foo::Bar.new(:i => 3)]
  end

  it "shouldn't modify the default Message instance like this" do
    a1 = Featureful::A.new
    a1.sub2.payload = "ohai"
    a2 = Featureful::A.new
    a2.sub2.payload.should == ""
    sub = Featureful::A::Sub.new
    sub.payload.should == ""
  end

  it "responds to gen_methods! for backwards compat" do
    Featureful::A.gen_methods!
  end

  def filled_in_bit
    bit = Featureful::ABitOfEverything.new
    bit.int64_field.should == 15
    bit.bool_field.should == false
    bit.string_field.should == "zomgkittenz"
    bit.double_field = 1.0
    bit.float_field = 2.0
    bit.int32_field = 3
    bit.int64_field = 4
    bit.uint32_field = 5
    bit.uint64_field = 6
    bit.sint32_field = 7
    bit.sint64_field = 8
    bit.fixed32_field = 9
    bit.fixed64_field = 10
    bit.sfixed32_field = 11
    bit.sfixed64_field = 12
    bit.bool_field = true
    bit.string_field = "14"
    bit.bytes_field = "15"
    bit
  end

  it "can serialize and de-serialize all basic field types" do
    bit = filled_in_bit

    bit2 = Featureful::ABitOfEverything.parse(bit.to_s)
    bit.should == bit2
    bit.fields.each do |tag, field|
      bit.value_for_tag(tag).should == bit2.value_for_tag(tag)
    end
  end

  it "does type checking" do
    bit = filled_in_bit

    proc do
      bit.fixed32_field = 1.0
    end.should raise_error(TypeError)

    proc do
      bit.double_field = 15
    end.should_not raise_error()
    bit2 = Featureful::ABitOfEverything.parse(bit.to_s)
    bit2.double_field.should == 15
    bit2.double_field.should == 15.0
    bit2.double_field.is_a?(Float).should == true

    proc do
      bit.bool_field = 1.0
    end.should raise_error(TypeError)

    proc do
      bit.string_field = 1.0
    end.should raise_error(TypeError)

    a1 = Featureful::A.new
    proc do
      a1.sub2 = "zomgkittenz"
    end.should raise_error(TypeError)
  end

  it "doesn't allow invalid enum values" do
    sub = Featureful::A::Sub.new

    proc do
      sub.payload_type.should == 0
      sub.payload_type = Featureful::A::Sub::Payloads::P2
      sub.payload_type.should == 1
    end.should_not raise_error()

    proc do
      sub.payload_type = 2
    end.should raise_error(ArgumentError)
  end

  it "enforces required fields on serialization" do
    module TehUnknown
      class MyResult < ProtocolBuffers::Message
        required :string, :field_1, 1
        optional :string, :field_2, 2
      end
    end

    res1 = TehUnknown::MyResult.new(:field_2 => 'b')

    proc { res1.to_s }.should raise_error(ProtocolBuffers::EncodeError)

    begin
      res1.to_s
    rescue Exception => e
      e.invalid_field.name.should == :field_1
      e.invalid_field.tag.should == 1
      e.invalid_field.otype.should == :required
      e.invalid_field.default_value.should == ''
    end

  end

  it "enforces required fields on deserialization" do
    module TehUnknown
      class MyResult < ProtocolBuffers::Message
        optional :string, :field_1, 1
        optional :string, :field_2, 2
      end
    end

    res1 = TehUnknown::MyResult.new(:field_2 => 'b')
    buf = res1.to_s

    # now make field_1 required
    module TehUnknown2
      class MyResult < ProtocolBuffers::Message
        required :string, :field_1, 1
        optional :string, :field_2, 2
      end
    end

    proc { TehUnknown2::MyResult.parse(buf) }.should raise_error(ProtocolBuffers::DecodeError)
  end

  it "enforces valid values on deserialization" do
    module TehUnknown
      class MyResult < ProtocolBuffers::Message
        optional :int64, :field_1, 1
      end
    end

    res1 = TehUnknown::MyResult.new(:field_1 => (2**33))
    buf = res1.to_s

    module TehUnknown2
      class MyResult < ProtocolBuffers::Message
        optional :int32, :field_1, 1
      end
    end

    proc { TehUnknown2::MyResult.parse(buf) }.should raise_error(ProtocolBuffers::DecodeError)
  end

  it "ignores and passes on unknown fields" do
    module TehUnknown
      class MyResult < ProtocolBuffers::Message
        optional :int32, :field_1, 1
        optional :int32, :field_2, 2
        optional :int32, :field_3, 3
        optional :int32, :field_4, 4
      end
    end

    res1 = TehUnknown::MyResult.new(:field_1 => 0xffff, :field_2 => 0xfffe,
                                   :field_3 => 0xfffd, :field_4 => 0xfffc)
    serialized = res1.to_s

    # remove field_2 to pretend we never knew about it
    module TehUnknown2
      class MyResult < ProtocolBuffers::Message
        optional :int32, :field_1, 1
        optional :int32, :field_3, 3
      end
    end

    res2 = nil
    proc do
      res2 = TehUnknown2::MyResult.parse(serialized)
    end.should_not raise_error()

    res2.field_1.should == 0xffff
    res2.field_3.should == 0xfffd

    proc do
      res2.field_2.should == 0xfffe
    end.should raise_error(NoMethodError)

    serialized2 = res2.to_s

    # now we know about field_2 again
    module TehUnknown3
      class MyResult < ProtocolBuffers::Message
        optional :int32, :field_1, 1
        optional :int32, :field_2, 2
        optional :int32, :field_4, 4
      end
    end

    res3 = TehUnknown3::MyResult.parse(serialized2)
    res3.field_1.should == 0xffff

    res3.field_2.should == 0xfffe
    res3.field_4.should == 0xfffc
  end

  it "ignores and passes on unknown enum values" do
    module TehUnknown
      class MyResult < ProtocolBuffers::Message
        module E
          include ProtocolBuffers::Enum
          V1 = 1
          V2 = 2
        end
        optional E, :field_1, 1
      end
    end

    res1 = TehUnknown::MyResult.new(:field_1 => TehUnknown::MyResult::E::V2)
    serialized = res1.to_s

    # remove field_2 to pretend we never knew about it
    module TehUnknown2
      class MyResult < ProtocolBuffers::Message
        module E
          include ProtocolBuffers::Enum
          V1 = 1
        end
        optional E, :field_1, 1
      end
    end

    res2 = nil
    proc do
      res2 = TehUnknown2::MyResult.parse(serialized)
    end.should_not raise_error()

    res2.value_for_tag?(1).should be_false
    res2.unknown_field_count.should == 1

    serialized2 = res2.to_s

    # now we know about field_2 again
    module TehUnknown3
      class MyResult < ProtocolBuffers::Message
        module E
          include ProtocolBuffers::Enum
          V1 = 1
          V2 = 2
        end
        optional E, :field_1, 1
      end
    end

    res3 = TehUnknown3::MyResult.parse(serialized2)
    res3.field_1.should == 2
  end

  describe "Message#valid?" do
    it "should validate sub-messages" do
      f = Featureful::A.new
      f.i3 = 1
      f.sub3 = Featureful::A::Sub.new
      f.valid?.should == false
      f.sub3.valid?.should == false
      f.sub3.payload_type = Featureful::A::Sub::Payloads::P1
      f.valid?.should == true
      f.sub3.valid?.should == true
    end
  end

end

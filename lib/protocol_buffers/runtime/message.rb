require 'stringio'
require 'protocol_buffers/runtime/field'
require 'protocol_buffers/runtime/encoder'
require 'protocol_buffers/runtime/decoder'

module ProtocolBuffers

  # = Generated Code
  #
  # This text describes exactly what Ruby code the protocol buffer compiler
  # generates for any given protocol definition. You should read the language
  # guide before reading this document:
  #
  # http://code.google.com/apis/protocolbuffers/docs/proto.html
  #
  # == Packages
  #
  # If a package name is given in the <tt>.proto</tt> file, all top-level
  # messages and enums in the file will be defined underneath a module with the
  # same name as the package. The first letter of the package is capitalized if
  # necessary.  This applies to message and enum names as well, since Ruby
  # classes and modules must be capitalized.
  #
  # For example, the following <tt>.proto</tt> file:
  #
  #   package wootcakes;
  #   message uberWoot { }
  #
  # Will define a module +Wootcakes+ and a class <tt>Wootcakes::UberWoot</tt>
  #
  # == Messages
  #
  # Given a simple message definition:
  #
  #   message Foo {}
  #
  # The compiler will generate a class called +Foo+, which subclasses
  # ProtocolBuffers::Message.
  #
  # These generated classes are not designed for subclassing.
  #
  # Ruby message classes have no particular public methods or accessors other
  # than those defined by ProtocolBuffers::Message and those generated for
  # nested fields, messages, and enum types (see below).
  #
  # A message can be declared inside another message. For example:
  # <tt>message Foo { message Bar { } }</tt>
  #
  # In this case, the +Bar+ class is declared inside the +Foo+ class, so you can
  # access it as <tt>Foo::Bar</tt> (or if in package +Baz+,
  # <tt>Baz::Foo::Bar</tt>)
  #
  # == Fields
  #
  # For each field in the message type, the corresponding class has a member
  # with the same name as the field. How you can manipulate the member depends
  # on its type.
  #
  # === Singular Fields
  #
  # If you have a singular (optional or required) field +foo+ of any non-message
  # type, you can manipulate the field +foo+ as if it were a regular object
  # attribute.  For example, if +foo+'s type is <tt>int32</tt>, you can say:
  #
  #   message.foo = 123
  #   puts message.foo
  #
  # Note that setting +foo+ to a value of the wrong type will raise a
  # TypeError. Setting +foo+ to a value of the right type, but one that doesn't
  # fit (such as assigning an out-of-bounds enum value) will raise an
  # ArgumentError.
  #
  # If +foo+ is read when it is not set, its value is the default value for that
  # field. To check if +foo+ is set, call <tt>has_foo?</tt> To clear +foo+, call
  # <tt>message.foo = nil</tt>. For example:
  #
  #   assert(!message.has_foo?)
  #   message.foo = 123
  #   assert(message.has_foo?)
  #   message.foo = nil
  #   assert(!message.has_foo?)
  #
  # === Singular String Fields
  #
  # String fields are treated like other singular fields, but note that the
  # default value for string fields is frozen, so it is effectively an immutable
  # string. Attempting to modify this default string will raise a TypeError,
  # so assign a new string to the field instead.
  #
  # === Singular Message Fields
  #
  # Message types are a bit special, since they are mutable. Accessing an unset
  # message field will return a default instance of the message type. Say you
  # have the following <tt>.proto</tt> definition:
  #
  #   message Foo {
  #     optional Bar bar = 1;
  #   }
  #   message Bar {
  #     optional int32 i = 1;
  #   }
  #
  # To set the message field, you can do either of the following:
  #
  #   foo = Foo.new
  #   assert(!foo.has_bar?)
  #   foo.bar = Bar.new
  #   assert(foo.has_bar?)
  #
  # Or, to set bar, you can simply assign a value directly to a field within
  # bar, and - presto! - foo has a bar field:
  #
  #   foo = Foo.new
  #   assert(!foo.has_bar?)
  #   foo.bar.i = 1
  #   assert(foo.has_bar?)
  #
  # Note that simply reading a field inside bar does not set the field:
  #
  #   foo = Foo.new
  #   assert(!foo.has_bar?)
  #   puts foo.bar.i
  #   assert(!foo.has_bar?)
  #
  # === Repeated Fields
  #
  # Repeated fields are represented as an object that acts like an Array.
  # For example, given this message definition:
  #
  #   message Foo {
  #     repeated int32 nums = 1;
  #   }
  #
  # You can do the following:
  #
  #   foo = Foo.new
  #   foo.nums << 15
  #   foo.nums.push(32)
  #   assert(foo.nums.length == 2)
  #   assert(foo.nums[0] == 15)
  #   assert(foo.nums[1] == 32)
  #   foo.nums.each { |i| puts i }
  #   foo.nums[1] = 56
  #   assert(foo.nums[1] == 56)
  #
  # To clear a repeated field, call the <tt>clear</tt> method, or assign nil to
  # it like a singular field.
  #
  #   foo = Foo.new
  #   foo.nums << 15
  #   foo.nums.push(32)
  #   assert(foo.nums.length == 2)
  #   foo.nums.clear
  #   assert(foo.nums.length == 0)
  #   foo.nums = nil # equivalent to foo.nums.clear
  #   assert(foo.nums.length == 0)
  #
  # You can assign to a repeated field using an array, or any other object that
  # responds to +each+. This will replace the current contents of the repeated
  # field.
  #
  #   foo = Foo.new
  #   foo.nums << 15
  #   foo.nums = [1, 3, 5]
  #   assert(foo.nums.length == 3)
  #   assert(foo.nums.to_a == [1,3,5])
  #
  # Repeated fields are always set, so <tt>foo.has_nums?</tt> will always be
  # true. Repeated fields don't take up any space in a serialized message if
  # they are empty.
  #
  # === Repeated Message Fields
  #
  # Repeated message fields work like other repeated fields. For example, given
  # this message definition:
  #
  #   message Foo {
  #     repeated Bar bars = 1;
  #   }
  #   message Bar {
  #     optional int32 i = 1;
  #   }
  #
  # You can do the following:
  #
  #   foo = Foo.new
  #   foo.bars << Bar.new(:i => 15)
  #   foo.bars << Bar.new(:i => 32)
  #   assert(foo.bars.length == 2)
  #   assert(foo.bars[0].i == 15)
  #   assert(foo.bars[1].i == 32)
  #   foo.bars.each { |bar| puts bar.i }
  #   foo.bars[1].i = 56
  #   assert(foo.bars[1].i == 56)
  #
  # == Enumerations
  #
  # Enumerations are defined as a module with an integer constant for each
  # valid value. For example, given:
  #
  #   enum Foo {
  #     VALUE_A = 1;
  #     VALUE_B = 5;
  #     VALUE_C = 1234;
  #   }
  #
  # The following Ruby code will be generated:
  #
  #   module Foo
  #     VALUE_A = 1
  #     VALUE_B = 5
  #     VALUE_C = 1234
  #   end
  #
  # An exception will be thrown if an enum field is assigned a value not in the
  # enum. If an unknown enum value is found while parsing a message, this is
  # treated like an unknown tag id. This matches the C++ library behavior.
  #
  # == Extensions
  #
  # Protocol Buffer extensions are not currently supported in this library.
  #
  # == Services
  #
  # Protocol Buffer service (RPC) definitions are ignored.

  class Message
    # Create a new Message of this class.
    #
    #   message = MyMessageClass.new(attributes)
    #   # is equivalent to
    #   message = MyMessageClass.new
    #   message.attributes = attributes
    def initialize(attributes = {})
      @set_fields = self.class.initial_set_fields.dup
      self.attributes = attributes
    end

    # Serialize this Message to the given IO stream using the Protocol Buffer
    # wire format.
    #
    # Equivalent to, but more efficient than
    #
    #   io << message
    #
    # Returns +io+
    def serialize(io)
      Encoder.encode(io, self)
      io
    end

    # Serialize this Message to a String and return it.
    def serialize_to_string
      sio = ProtocolBuffers.bin_sio
      serialize(sio)
      return sio.string
    end
    alias_method :to_s, :serialize_to_string

    # Parse a Message of this class from the given IO/String. Since Protocol
    # Buffers are not length delimited, this will read until the end of the
    # stream.
    #
    # This does not call clear! beforehand, so this is logically equivalent to
    #
    #   new_message = self.class.new
    #   new_message.parse(io)
    #   merge_from(new_message)
    def parse(io_or_string)
      io = io_or_string
      if io.is_a?(String)
        io = ProtocolBuffers.bin_sio(io)
      end
      Decoder.decode(io, self)
      return self
    end

    # Shortcut, simply calls self.new.parse(io)
    def self.parse(io)
      self.new.parse(io)
    end

    # Merge the attribute values from +obj+ into this Message, which must be of
    # the same class.
    #
    # Singular fields will be overwritten, except for embedded messages which
    # will be merged. Repeated fields will be concatenated.
    def merge_from(obj)
      raise(ArgumentError, "Incompatible merge types: #{self.class} and #{obj.class}") unless obj.is_a?(self.class)
      for tag, field in self.class.fields
        next unless obj.value_for_tag?(tag)
        value = obj.value_for_tag(tag)
        merge_field(tag, value, field)
      end
    end

    # Parse the string into a new Message of this class, and merge it into the
    # current message like +merge_from+.
    def merge_from_string(string)
      merge_from(self.class.new.parse(string))
    end

    # Assign values to attributes in bulk.
    #
    #   message.attributes = { :field1 => value1, :field2 => value2 } -> message
    def attributes=(hash = {})
      hash.each do |name, value|
        self.send("#{name}=", value)
      end
      self
    end

    # Comparison by class and field values.
    def ==(obj)
      return false unless obj.is_a?(self.class)
      fields.each do |tag, field|
        return false unless self.__send__(field.name) == obj.__send__(field.name)
      end
      return true
    end

    # Reset all fields to the default value.
    def clear!
      fields.each { |tag, field| self.__send__("#{field.name}=", nil) }
    end

    # This is a shallow copy.
    def dup
      ret = self.class.new
      fields.each do |tag, field|
        val = self.__send__(field.name)
        ret.__send__("#{field.name}=", val)
      end
      return ret
    end

    # Returns a hash of { tag => ProtocolBuffers::Field }
    def self.fields
      @fields || @fields = {}
    end

    def self.initial_set_fields
      @set_fields ||= []
    end

    # Returns a hash of { tag => ProtocolBuffers::Field }
    def fields
      self.class.fields
    end

    # Find the field for the given attribute name. Returns a
    # ProtocolBuffers::field
    def self.field_for_name(name)
      name = name.to_sym
      field = fields.find { |tag,field| field.name == name }
      field && field.last
    end

    # Equivalent to fields[tag]
    def self.field_for_tag(tag)
      fields[tag]
    end

    # Reflection: get the attribute value for the given tag id.
    #
    #   message.value_for_tag(message.class.field_for_name(:f1).tag)
    #   # is equivalent to
    #   message.f1
    def value_for_tag(tag)
      self.__send__(fields[tag].name)
    end

    def set_value_for_tag(tag, value)
      self.__send__("#{fields[tag].name}=", value)
    end

    # Reflection: does this Message have the field set?
    #
    #   message.value_for_tag?(message.class.field_for_name(:f1).tag)
    #   # is equivalent to
    #   message.has_f1?
    def value_for_tag?(tag)
      @set_fields[tag] || false
    end

    def inspect
      ret = ProtocolBuffers.bin_sio
      ret << "#<#{self.class.name}"
      fields.each do |tag, field|
        if value_for_tag?(tag)
          value = field.inspect_value(self.__send__(field.name))
        else
          value = "<unset>"
        end
        ret << " #{field.name}=#{value}"
      end
      ret << ">"
      return ret.string
    end

    def merge_field(tag, value, field = fields[tag]) # :nodoc:
      if field.repeated?
        if value.is_a?(Array)
          self.__send__("#{field.name}=", self.__send__(field.name) + value)
        else
          self.__send__(field.name) << value
        end
      else
        self.__send__("#{field.name}=", value)
        @set_fields[tag] = true
      end
    end

    def self.define_field(otype, type, name, tag, opts = {}) # :NODOC:
      type = type.is_a?(Module) ? type : type.to_sym
      name = name.to_sym
      tag  = tag.to_i
      raise("Field already exists for tag: #{tag}") if fields[tag]
      field = Field.create(self, otype, type, name, tag, opts)
      fields[tag] = field
      field.add_methods_to(self)
    end

    def self.required(type, name, tag, opts = {}) # :NODOC:
      define_field(:required, type, name, tag, opts)
      @has_required_field = true
    end

    def self.optional(type, name, tag, opts = {}) # :NODOC:
      define_field(:optional, type, name, tag, opts)
    end

    def self.repeated(type, name, tag, opts = {}) # :NODOC:
      define_field(:repeated, type, name, tag, opts)
    end

    def notify_on_change(parent, tag)
      @parent_for_notify = parent
      @tag_for_notify = tag
    end

    def default_changed(tag)
      @set_fields[tag] = true
      if @parent_for_notify
        @parent_for_notify.default_changed(@tag_for_notify)
        @parent_for_notify = @tag_for_notify = nil
      end
    end

    def valid?
      self.class.valid?(self)
    end

    def self.valid?(message, raise_exception=false)
      return true unless @has_required_field

      fields.each do |tag, field|
        next if field.otype != :required
        next if message.value_for_tag?(tag) && (field.class != Field::MessageField || message.value_for_tag(tag).valid?)
        return false unless raise_exception
        raise(ProtocolBuffers::EncodeError.new(field), "Required field '#{field.name}' is invalid")
      end

      true
    end

    def validate!
      self.class.validate!(self)
    end

    def self.validate!(message)
      valid?(message, true)
    end

    def remember_unknown_field(tag_int, value)
      @unknown_fields || @unknown_fields = []
      @unknown_fields << [tag_int, value]
    end

    # yields |tag_int, value| pairs
    def each_unknown_field # :nodoc:
      return unless @unknown_fields
      @unknown_fields.each { |tag_int, value| yield tag_int, value }
    end

    def unknown_field_count
      (@unknown_fields || []).size
    end

    # left in for compatibility with previously created .pb.rb files -- no longer used
    def self.gen_methods! # :NODOC:
      @methods_generated = true
    end

    protected

    def initialize_field(tag)
      field = fields[tag]
      new_value = field.default_value
      self.instance_variable_set("@#{field.name}", new_value)
      if field.kind_of? Field::AggregateField
        new_value.notify_on_change(self, tag)
      end
      @set_fields[tag] = false
    end

  end
end

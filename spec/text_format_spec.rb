# -*- coding: UTF-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ProtocolBuffers::TextScanner do
  def scanned_list(text)
    s = ProtocolBuffers::TextScanner.new(text)
    s.enum_for(:scan).to_a
  end

  it "returns [false, nil] on the end" do
    expect(scanned_list("")).to eq [[false, nil]]
  end

  it "returns [:bool, true] for 'true'" do
    expect(scanned_list("true")).to eq [[:bool, true], [false, nil]]
  end

  it "returns [:bool, false] for 'false'" do
    expect(scanned_list("false")).to eq [[:bool, false], [false, nil]]
  end

  %w( . : [ ] < > { } ).each do |c|
    it "returns a single character token for #{c}" do
      expect(scanned_list(c)).to eq [[c, c], [false, nil]]
    end
  end

  it 'returns [:string, str] for a simple single quoted text' do
    expect(scanned_list(%q['str'])).to eq [[:string, 'str'], [false, nil]]
  end

  it 'returns [:string, str] for a simple doubl quoted text' do
    expect(scanned_list(%q["str"])).to eq [[:string, 'str'], [false, nil]]
  end

  it 'raises Racc::ParseError on unterminated quotation' do
    expect {
      scanned_list(%q['str])
    }.to raise_error(Racc::ParseError, /unterminated string from line 1/)

    expect {
      scanned_list(%Q['str '\n'str])
    }.to raise_error(Racc::ParseError, /unterminated string from line 2/)

    expect {
      scanned_list(%Q['str" 'str'])
    }.to raise_error(Racc::ParseError, /unterminated string from line 1/)
  end

  it 'raises Racc::ParseError on multiline string' do
    expect {
      scanned_list(%Q['str\n'])
    }.to raise_error(Racc::ParseError, /unterminated string from line 1/)
  end

  it 'understands hex escaped string' do
    expect(scanned_list(%q["\\x12"])).to eq [[:string, "\x12"], [false, nil]]
    expect(scanned_list(%q["\\X12"])).to eq [[:string, "\x12"], [false, nil]]

    expect(scanned_list(%q['\\x12'])).to eq [[:string, "\x12"], [false, nil]]

    expect(scanned_list(%q['\\xfghijk'])).to eq [[:string, "\x0f" + "ghijk"], [false, nil]]
  end

  it 'understands octal escaped string' do
    expect(scanned_list(%q["\\012"])).to eq [[:string, "\012"], [false, nil]]
    expect(scanned_list(%q['\\12'])).to eq [[:string, "\012"], [false, nil]]

    expect(scanned_list(%q['\\0'])).to eq [[:string, "\0"], [false, nil]]

    expect(scanned_list(%q['\\0012'])).to eq [[:string, "\001" + "2"], [false, nil]]
    expect(scanned_list(%q['\\6789'])).to eq [[:string, "\067" + "89"], [false, nil]]
  end

  it 'understands named escaped string' do
    input = %q[
      "
      \\a
      \\b
      \\f
      \\n
      \\r
      \\t
      \\v
      \\\\
      \\"
      \\'
      "
    ].gsub(/\s/, '')
    expect(scanned_list(input)).to eq [
      [:string, "\a\b\f\n\r\t\v\\\"'"],
      [false, nil]
    ]
  end

  it 'accepts quoted punctuations' do
    expect(scanned_list(%q[".:[]<>{}"])).to eq [[:string, ".:[]<>{}"], [false, nil]]
    expect(scanned_list(%q["'"])).to eq [[:string, "'"], [false, nil]]
    expect(scanned_list(%q['"'])).to eq [[:string, '"'], [false, nil]]
  end

  it 'leaves uninterpretable escape as is' do
    expect(scanned_list(%q["\\c"])).to eq [[:string, "\\c"], [false, nil]]
    expect(scanned_list(%q["\\u0030"])).to eq [[:string, "\\u0030"], [false, nil]]
  end

  it 'returns [:integer, value] for binary integer literal' do
    expect(scanned_list('0b0101')).to eq [[:integer, 0b0101], [false, nil]]
    expect(scanned_list('0B0101')).to eq [[:integer, 0b0101], [false, nil]]
    expect(scanned_list('+0B0101')).to eq [[:integer, +0b0101], [false, nil]]
    expect(scanned_list('-0B0101')).to eq [[:integer, -0b0101], [false, nil]]
  end

  it 'returns [:integer, value] for octal integer literal' do
    expect(scanned_list('0123')).to eq [[:integer, 0123], [false, nil]]
    expect(scanned_list('0o123')).to eq [[:integer, 0123], [false, nil]]
    expect(scanned_list('0O123')).to eq [[:integer, 0123], [false, nil]]
    expect(scanned_list('+0123')).to eq [[:integer, 0123], [false, nil]]
    expect(scanned_list('+0o123')).to eq [[:integer, 0123], [false, nil]]
    expect(scanned_list('-0123')).to eq [[:integer, -0123], [false, nil]]
    expect(scanned_list('-0o123')).to eq [[:integer, -0123], [false, nil]]
  end

  it 'returns [:integer, value] for decimal integer literal' do
    expect(scanned_list('12345')).to eq [[:integer, 12345], [false, nil]]
    expect(scanned_list('0d12345')).to eq [[:integer, 12345], [false, nil]]
    expect(scanned_list('0D12345')).to eq [[:integer, 12345], [false, nil]]
    expect(scanned_list('+12345')).to eq [[:integer, 12345], [false, nil]]
    expect(scanned_list('+0d12345')).to eq [[:integer, 12345], [false, nil]]
    expect(scanned_list('-12345')).to eq [[:integer, -12345], [false, nil]]
    expect(scanned_list('-0d12345')).to eq [[:integer, -12345], [false, nil]]
  end

  it 'returns [:integer, value] for hex integer literal' do
    expect(scanned_list('0xABC12')).to eq [[:integer, 0xABC12], [false, nil]]
    expect(scanned_list('0XABC12')).to eq [[:integer, 0xABC12], [false, nil]]
    expect(scanned_list('+0xABC12')).to eq [[:integer, 0xABC12], [false, nil]]
    expect(scanned_list('-0xABC12')).to eq [[:integer, -0xABC12], [false, nil]]
  end

  it 'returns [:integer, 0] for "0"' do
    expect(scanned_list('0')).to eq [[:integer, 0], [false, nil]]
    expect(scanned_list('+0')).to eq [[:integer, 0], [false, nil]]
    expect(scanned_list('-0')).to eq [[:integer, 0], [false, nil]]
  end

  it 'returns [:float, value] for decimal float literal' do
    expect(scanned_list('0.123')).to eq [[:float, 0.123], [false, nil]]
    expect(scanned_list('12.34')).to eq [[:float, 12.34], [false, nil]]
    expect(scanned_list('+0.123')).to eq [[:float, 0.123], [false, nil]]
    expect(scanned_list('+12.34')).to eq [[:float, 12.34], [false, nil]]
    expect(scanned_list('-0.123')).to eq [[:float, -0.123], [false, nil]]
    expect(scanned_list('-12.34')).to eq [[:float, -12.34], [false, nil]]
    expect(scanned_list('0.0')).to eq [[:float, 0.0], [false, nil]]
    expect(scanned_list('+0.0')).to eq [[:float, 0.0], [false, nil]]
    expect(scanned_list('-0.0')).to eq [[:float, -0.0], [false, nil]]
  end

  it 'returns [:float, value] for scientific float literal' do
    expect(scanned_list('1.1e5')).to eq [[:float, 1.1e5], [false, nil]]
    expect(scanned_list('1.1E5')).to eq [[:float, 1.1e5], [false, nil]]
    expect(scanned_list('1.1e+5')).to eq [[:float, 1.1e5], [false, nil]]
    expect(scanned_list('1.1e-5')).to eq [[:float, 1.1e-5], [false, nil]]
    expect(scanned_list('1.1e0')).to eq [[:float, 1.1], [false, nil]]
    expect(scanned_list('1.1e+0')).to eq [[:float, 1.1], [false, nil]]
    expect(scanned_list('1.1e-0')).to eq [[:float, 1.1], [false, nil]]
  end

  it 'returns [:identifier, str] for identifiers' do
    %w! abc ab_c _abc abc_ ABC AB_C _ABC ABC_ Abc AbC aBc !.each do |name|
      expect(scanned_list(name)).to eq [[:identifier, name], [false, nil]]
    end
  end

  it 'ignores spaces between tokens' do
    expect(scanned_list("abc\n: def . ghi jk :\t'l : m' n\r: 012")).to eq [
      [:identifier, 'abc'],
      [':', ':'],
      [:identifier, 'def'],
      ['.', '.'],
      [:identifier, 'ghi'],
      [:identifier, 'jk'],
      [':', ':'],
      [:string, 'l : m'],
      [:identifier, 'n'],
      [':', ':'],
      [:integer, 012],
      [false, nil]
    ]
  end

  it 'splits tokens without spaces' do
    expect(scanned_list("abc:def.ghi jk:'l : m'n:012")).to eq [
      [:identifier, 'abc'],
      [':', ':'],
      [:identifier, 'def'],
      ['.', '.'],
      [:identifier, 'ghi'],
      [:identifier, 'jk'],
      [':', ':'],
      [:string, 'l : m'],
      [:identifier, 'n'],
      [':', ':'],
      [:integer, 012],
      [false, nil]
    ]
  end

  it 'ignores comments' do
    expect(scanned_list("#")).to eq [[false, nil]]
    expect(scanned_list("#\n")).to eq [[false, nil]]
    expect(scanned_list("# abc\n")).to eq [[false, nil]]
    expect(scanned_list("abc #\n")).to eq [[:identifier, 'abc'], [false, nil]]
  end
end

describe ProtocolBuffers::TextParser do
  before(:each) do
    @parser = ProtocolBuffers::TextParser.new
    load File.join(File.dirname(__FILE__), "proto_files", "simple.pb.rb")
    load File.join(File.dirname(__FILE__), "proto_files", "featureful.pb.rb")
  end

  it 'returns parsed message' do
    m = ::Simple::Foo.new
    tokens = [[false, nil]]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
  end

  it 'accepts simple field' do
    m = ::Simple::Test1.new
    tokens = [
      [:identifier, 'test_field'],
      [':', ':'],
      [:string, 'str'],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
    expect(m.test_field).to eq 'str'
  end

  it 'rejects unknown field name' do
    m = ::Simple::Test1.new
    tokens = [
      [:identifier, 'no_such_field'],
      [':', ':'],
      [:string, 'str'],
      [false, nil]
    ]
    expect {
      @parser.parse_from_scanner(tokens, m)
    }.to raise_error(Racc::ParseError, /no such field/)
  end

  it 'accepts nested field' do
    m = ::Simple::Bar.new
    tokens = [
      [:identifier, 'foo'],
      ['<', '<'],
      ['>', '>'],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
    expect(m).to have_foo
  end

  it 'accepts nested field with colon' do
    m = ::Simple::Bar.new
    tokens = [
      [:identifier, 'foo'],
      [':', ':'],
      ['<', '<'],
      ['>', '>'],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
    expect(m).to have_foo
  end


  it 'accepts deeply nested field' do
    m = ::Featureful::C.new
    tokens = [
      [:identifier, 'e'],
      ['<', '<'],
      [:identifier, 'd'],
      ['<', '<'],
      [:identifier, 'f'],
      ['<', '<'],
      [:identifier, 's'],
      [':', ':'],
      [:string, 'str'],
      ['>', '>'],
      ['>', '>'],
      ['>', '>'],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)

    expect(m).not_to have_d
    expect(m).to have(1).e

    expect(m.e[0]).to have_d
    expect(m.e[0].d).to have(1).f

    expect(m.e[0].d.f[0]).to have_s
    expect(m.e[0].d.f[0].s).to eq 'str'
  end

  it 'accepts group field' do
    m = ::Featureful::A::Group1.new
    tokens = [
      [:identifier, 'i1'],
      [':', ':'],
      [:integer, 1],
      [:identifier, 'Subgroup'],
      ['{', '{'],
      [:identifier, 'i1'],
      [':', ':'],
      [:integer, 1],
      ['}', '}'],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)

    expect(m.i1).to eq(1)
    expect(m).to have(1).subgroup
    expect(m.subgroup[0].i1).to eq(1)
  end

  it 'accepts multiple values for repeated field' do
    m = ::Featureful::D.new
    tokens = [
      [:identifier, 'f'],
      ['<', '<'],
      [:identifier, 's'],
      [':', ':'],
      [:string, 'str'],
      ['>', '>'],
      [:identifier, 'f'],
      ['{', '{'],
      [:identifier, 's'],
      [':', ':'],
      [:string, 'str2'],
      ['}', '}'],
      [:identifier, 'f'],
      ['<', '<'],
      ['>', '>'],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)

    expect(m).to have(3).f
    expect(m.f[0]).to have_s
    expect(m.f[0].s).to eq 'str'
    expect(m.f[1]).to have_s
    expect(m.f[1].s).to eq 'str2'
    expect(m.f[2]).not_to have_s
  end

  it 'rejects unterminated field' do
    m = ::Simple::Test1.new
    tokens = [
      [:identifier, 'test_field'],
      [':', ':'],
      [false, nil]
    ]
    expect {
      @parser.parse_from_scanner(tokens, m)
    }.to raise_error(Racc::ParseError)

    m = ::Simple::Test1.new
    tokens = [
      [:identifier, 'test_field'],
      [false, nil]
    ]
    expect {
      @parser.parse_from_scanner(tokens, m)
    }.to raise_error(Racc::ParseError)
  end

  it 'accepts string field' do
    m = ::Featureful::ABitOfEverything.new
    tokens = [
      [:identifier, 'string_field'],
      [':', ':'],
      [:string, 'str'],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
    expect(m.string_field).to eq 'str'
    expect(m.string_field.encoding).to eq Encoding::UTF_8
  end

  it 'accepts bytes field' do
    m = ::Featureful::ABitOfEverything.new
    tokens = [
      [:identifier, 'bytes_field'],
      [':', ':'],
      [:string, "bytes\x00\x01\x02\x03"],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
    expect(m.bytes_field).to eq "bytes\x00\x01\x02\x03"
  end

  it 'accepts float field' do
    m = ::Featureful::ABitOfEverything.new
    tokens = [
      [:identifier, 'float_field'],
      [':', ':'],
      [:float, 1.1],
      [:identifier, 'double_field'],
      [':', ':'],
      [:float, 1.1],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
    expect(m.float_field).to eq 1.1
    expect(m.double_field).to eq 1.1
  end

  it 'accepts int field' do
    m = ::Featureful::ABitOfEverything.new
    tokens = [
      [:identifier, 'int32_field'],
      [':', ':'],
      [:integer, 1],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
    expect(m.int32_field).to eq 1
  end

  it 'accepts bool field' do
    m = ::Featureful::ABitOfEverything.new
    tokens = [
      [:identifier, 'bool_field'],
      [':', ':'],
      [:bool, true],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
    expect(m.bool_field).to be_true
  end

  it 'accepts integer as a enum field' do
    m = ::Featureful::A::Sub.new
    tokens = [
      [:identifier, 'payload_type'],
      [':', ':'],
      [:integer, 1],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
    expect(m).to have_payload_type
    expect(m.payload_type).to eq ::Featureful::A::Sub::Payloads::P2
  end

  it 'accepts enum name as a enum field' do
    m = ::Featureful::A::Sub.new
    tokens = [
      [:identifier, 'payload_type'],
      [':', ':'],
      [:identifier, 'P2'],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
    expect(m).to have_payload_type
    expect(m.payload_type).to eq ::Featureful::A::Sub::Payloads::P2
  end

  it 'concatenates strings' do
    m = ::Simple::Test1.new
    tokens = [
      [:identifier, 'test_field'],
      [':', ':'],
      [:string, 'str'],
      [:string, 'another str'],
      [false, nil]
    ]
    expect(@parser.parse_from_scanner(tokens, m)).to be_equal(m)
    expect(m.test_field).to eq 'stranother str'
  end

  it 'rejects unknown field' do
    # The text format for unknown field is designed only for displaying a
    # message to human.
    # Since wire_types in it are ambigous, we cannot parse the notation.
    m = ::Simple::Test1.new
    tokens = [
      [:integer, 1],
      [':', ':'],
      [:string, 'str'],
      [false, nil]
    ]
    expect {
      @parser.parse_from_scanner(tokens, m)
    }.to raise_error(Racc::ParseError)
  end
end

describe ProtocolBuffers::TextFormatter do
  def formatter(options = nil)
    ProtocolBuffers::TextFormatter.new(options)
  end

  # Returns a dummy instance of Featureful::A
  def dummy_a
    m = Featureful::A.new
    m.i1 = [1, 2, 3]
    m.i3 = 4

    subsub = Featureful::A::Sub::SubSub.new(:subsub_payload => "foo")
    m.sub1 = [
      Featureful::A::Sub.new(:payload => "bar",
                             :payload_type => Featureful::A::Sub::Payloads::P1,
                             :subsub1 => subsub),
                             Featureful::A::Sub.new(:payload => "baz",
                                                    :payload_type => Featureful::A::Sub::Payloads::P2),
    ]
    m.sub3.payload = "qux"
    m.sub3.payload_type = Featureful::A::Sub::Payloads::P1
    m.sub3.subsub1.subsub_payload = "quux"

    sg = Featureful::A::Group1::Subgroup.new(:i1 => 1)
    m.group1 = [
      Featureful::A::Group1.new(:i1 => 1, :subgroup => [sg]),
      Featureful::A::Group1.new(:i1 => 2),
    ]
    m.group3.i1 = 5
    m.group3.subgroup << Featureful::A::Group3::Subgroup.new(:i1 => 1)

    m
  end

  before(:each) do
    @parser = ProtocolBuffers::TextParser.new
    load File.join(File.dirname(__FILE__), "proto_files", "simple.pb.rb")
    load File.join(File.dirname(__FILE__), "proto_files", "featureful.pb.rb")
  end

  it "formats integer field in decimal" do
    m = Featureful::ABitOfEverything.new
    m.int32_field = 123
    expect(m.text_format_to_string).to eq "int32_field: 123\n"
  end

  it "formats float field in decimal" do
    m = Featureful::ABitOfEverything.new
    m.float_field = 0.123
    expect(m.text_format_to_string).to eq "float_field: 0.123\n"
  end

  it "formats string field with quotation" do
    m = Featureful::ABitOfEverything.new
    m.string_field = "str"
    expect(m.text_format_to_string).to eq "string_field: \"str\"\n"
  end

  it "escapes non ascii printable characters in string field" do
    str = "\xe3\x81\x82\0\n"
    str.force_encoding(Encoding::UTF_8) if str.respond_to?(:force_encoding)
    m = Featureful::ABitOfEverything.new
    m.string_field = str

    formatted = m.text_format_to_string
    expect(formatted).to match(/\Astring_field: "(.*?)"\n/)

    escaped = formatted[/string_field: (".*?")/, 1]
    expect(escaped).to match(/\A[[:ascii:]&&[:print:]]+\z/)
    expect(eval(escaped)).to eq str
  end

  it "escapes bytes in bytes field" do
    m = Featureful::ABitOfEverything.new
    m.bytes_field = "bytes"
    expect(m.text_format_to_string).to eq "bytes_field: \"\\x62\\x79\\x74\\x65\\x73\"\n"
  end

  it "formats message field with indent" do
    m = Featureful::E.new
    m.d.f2.s = "str"
    expect(m.text_format_to_string).to eq <<-EOS
d {
  f2 {
    s: "str"
  }
}
    EOS
  end

  it "formats group field with indent" do
    m = Featureful::A::Group1.new
    m.i1 = 1
    m.subgroup << Featureful::A::Group1::Subgroup.new(:i1 => 1)
    expect(m.text_format_to_string).to eq <<-EOS
i1: 1
Subgroup {
  i1: 1
}
    EOS
  end

  it "rejects invalid message" do
    m = Featureful::A.new
    expect {
      m.text_format_to_string
    }.to raise_error(ProtocolBuffers::EncodeError)
  end

  it "formats unknown field with tag number" do
    m = ::Simple::Foo.new
    m.remember_unknown_field(100 << 3 | ProtocolBuffers::WireTypes::VARINT, 1)
    m.remember_unknown_field(101 << 3 | ProtocolBuffers::WireTypes::FIXED32, "\x01\x02\x03\x04")
    m.remember_unknown_field(102 << 3 | ProtocolBuffers::WireTypes::FIXED64, "\x01\x02\x03\x04\x05\x06\x07\x08")
    m.remember_unknown_field(103 << 3 | ProtocolBuffers::WireTypes::LENGTH_DELIMITED, "str")

    klass = Class.new
    klass.send :include, ProtocolBuffers::Message

    group = klass.new
    group.remember_unknown_field(1 << 3 | ProtocolBuffers::WireTypes::VARINT, 1)
    subgroup = klass.new
    subgroup.remember_unknown_field(1 << 3 | ProtocolBuffers::WireTypes::VARINT, 1)
    group.remember_unknown_field(2 << 3 | ProtocolBuffers::WireTypes::START_GROUP, subgroup)
    m.remember_unknown_field(104 << 3 | ProtocolBuffers::WireTypes::START_GROUP, group)

    expect(m.text_format_to_string).to eq <<-EOS
100: 1
101: 0x04030201
102: 0x0807060504030201
103: "\\x73\\x74\\x72"
104 {
  1: 1
  2 {
    1: 1
  }
}
    EOS
  end

  it "roundtrips with TextParser" do
    m = dummy_a
    parser = ProtocolBuffers::TextParser.new
    parsed = Featureful::A.new
    parser.parse_text(m.text_format_to_string, parsed)

    expect(parsed).to eq(m)
  end

  context "if option[:short] is specified" do
    it "doesn't emit newline" do
      m = Featureful::ABitOfEverything.new
      m.int32_field = 123
      expect(m.text_format_to_string(:short => true)).to eq "int32_field: 123"
    end

    it "separates fields with space" do
      m = Featureful::ABitOfEverything.new
      m.int32_field = 123
      m.string_field = "str"
      expect(m.text_format_to_string(:short => true)).to eq "int32_field: 123 string_field: \"str\""
    end

    it "formats message field with spaces" do
      m = Featureful::E.new
      m.d.f2.s = "str"
      expect(m.text_format_to_string(:short => true)).to eq "d { f2 { s: \"str\" } }"
    end

    it "roundtrips with TextParser" do
      m = dummy_a

      parser = ProtocolBuffers::TextParser.new
      parsed = Featureful::A.new
      parser.parse_text(m.text_format_to_string(:short => true), parsed)

      expect(parsed).to eq(m)
    end
  end
end

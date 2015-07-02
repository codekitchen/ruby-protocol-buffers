require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'
require 'protocol_buffers/compiler'

require 'protocol_buffers/compiler/file_descriptor_to_ruby'

require 'tmpdir'
require 'tempfile'
describe ProtocolBuffers, "compiler" do

  test_files = Dir[File.join(File.dirname(__FILE__), "proto_files", "*.proto")]

  before do
    pending "need protoc installed" unless has_compiler?
  end

  test_files.each do |file|
    next if File.basename(file) == 'depends.proto'

    it "can compile #{File.basename(file)}" do
      proc do
        ProtocolBuffers::Compiler.compile_and_load(file)
      end.should_not raise_error()
    end
  end

  it 'can compile and instantiate a proto with nested dependencies' do
    protocfile = Tempfile.new('ruby-protoc')
    protocfile.binmode

    ProtocolBuffers::Compiler.compile(protocfile.path, %w(
      spec/proto_files/simple.proto
      spec/proto_files/nested/child.proto
      spec/proto_files/depends.proto
    ), :include_dirs => %w(spec/proto_files))


    descriptor_set = Google::Protobuf::FileDescriptorSet.parse(protocfile)
    protocfile.close(true)

    Dir.mktmpdir do |dir|
      descriptor_set.file.each do |file|
        name = file.name
        path = File.join(dir, File.dirname(name), File.basename(name, '.proto') + '.pb.rb')
        FileUtils.mkdir_p File.dirname(path)
        File.open(path, "w") {|f|
          FileDescriptorToRuby.new(file).write(f)
        }
      end

      $LOAD_PATH << dir
      load File.join(dir, 'depends.pb.rb')
    end
  end

  it "can compile and instantiate a message in a package with under_scores" do
    Object.send(:remove_const, :UnderScore) if defined?(UnderScore)

    ProtocolBuffers::Compiler.compile_and_load(
      File.join(File.dirname(__FILE__), "proto_files", "under_score_package.proto"))

    proc do
      under_test = UnderScore::UnderTest.new
    end.should_not raise_error()
  end

  it "should compile and correctly translate" do
    ProtocolBuffers::Compiler.compile_and_load(
      File.join(File.dirname(__FILE__), "proto_files", "simple.proto"))
    ProtocolBuffers::Compiler.compile_and_load(
      File.join(File.dirname(__FILE__), "proto_files", "featureful.proto"))
  end

  it "correctly throws an error when protoc cannot be found" do
    protoc_cmd = "garbageadsvasdv"
    ProtocolBuffers::Compiler.set_protoc_cmd(protoc_cmd)

    protocfile = Tempfile.new("protocol_buffers_spec_cmd_test")
    protocfile.binmode
    expect do
      ProtocolBuffers::Compiler.compile(protocfile.path, %w(spec/proto_files/simple.proto))
    end.to raise_error(ProtocolBuffers::CompileError, /Could not find protoc executable: #{protoc_cmd}/)

    ProtocolBuffers::Compiler.reset_protoc_cmd
  end

  it "correctly throws an error that is not when protoc cannot be found" do
    protocfile = Tempfile.new("protocol_buffers_spec_cmd_test2")
    protocfile.binmode

    expect do
      # simple2.proto does not exist
      ProtocolBuffers::Compiler.compile(protocfile.path, %w(spec/proto_files/simple2.proto))
    end.to raise_error(ProtocolBuffers::CompileError, /^[0-9]+/)
  end
end

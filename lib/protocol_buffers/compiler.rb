require 'protocol_buffers/compiler/descriptor.pb'

module ProtocolBuffers
  class CompileError < StandardError; end

  module Compiler
    def self.compile(output_filename, input_files, opts = {})
      input_files = Array(input_files) unless input_files.is_a?(Array)
      raise(ArgumentError, "Need at least one input file") if input_files.empty?
      other_opts = ""
      (opts[:include_dirs] || []).each { |d| other_opts += " -I#{d}" }

      cmd = "protoc #{other_opts} -o#{output_filename} #{input_files.join(' ')}"
      rc = system(cmd)
      raise(CompileError, $?.exitstatus.to_s) unless rc
      true
    end

    def self.compile_and_load(input_files, opts = {})
      require 'tempfile'
      require 'protocol_buffers/compiler/file_descriptor_to_ruby'

      input_files = Array(input_files) unless input_files.is_a?(Array)

      tempfile = Tempfile.new("protocol_buffers_spec")
      tempfile.binmode

      include_dirs = (opts[:include_dirs] ||= [])
      include_dirs.concat(input_files.map { |i| File.dirname(i) }.uniq)

      compile(tempfile.path, input_files, opts)
      descriptor_set = Google::Protobuf::FileDescriptorSet.parse(tempfile)
      tempfile.close(true)
      descriptor_set.file.each do |file|
        parsed = FileDescriptorToRuby.new(file)
        output = Tempfile.new("protocol_buffers_spec_parsed")
        output.binmode
        parsed.write(output)
        output.flush
        load output.path
        output.close(true)
      end
      true
    end

    def self.compile_and_load_string(input, opts = {})
      require 'tempfile'
      tempfile = Tempfile.new("protocol_buffers_load_string")
      tempfile.binmode
      tempfile.write(input)
      tempfile.flush
      (opts[:include_dirs] ||= []) << File.dirname(tempfile.path)
      compile_and_load(tempfile.path, opts)
    end

    def self.available?
      version = `protoc --version`.match(/[\d\.]+/)
      version && version[0] >= "2.2"
    rescue Errno::ENOENT
      false
    end
  end
end

require "mini_mime"
require "magic"

class Marcel::MimeType
  BINARY = "application/octet-stream"

  OverrideInfo = Struct.new(:content_type)

  @magic = Magic.new
  @magic.flags = Magic::MIME_TYPE

  @ext_overrides = {}

  @parents = {}

  class << self
    attr_reader :magic, :ext_overrides, :parents

    def extend(type, extensions: [], parents: [], magic: nil)
      info = MiniMime.lookup_by_content_type(type)

      extensions = Array(extensions)
      extensions << info.extension unless info.nil?

      info ||= OverrideInfo.new(type)

      extensions.each do |ext|
        @ext_overrides[ext] = info
      end

      parents = Array(parents)

      if parents.any?
        @parents[type] ||= []
        @parents[type] |= parents
      end
    end

    def for(pathname_or_io = nil, name: nil, extension: nil, declared_type: nil)
      type_from_data = for_data(pathname_or_io)
      fallback_type = for_declared_type(declared_type) || for_name(name) || for_extension(extension) || BINARY

      if type_from_data
        most_specific_type type_from_data, fallback_type
      else
        fallback_type
      end
    end

    private
      def for_data(pathname_or_io)
        mime_type =
          case
          when defined?(Pathname) && pathname_or_io.is_a?(Pathname)
            pathname_or_io.open { |io| for_data(io) }

          when pathname_or_io.is_a?(String)
            magic.buffer(pathname_or_io)

          when io = IO.try_convert(pathname_or_io)
            magic.file(io)
          end

        mime_type unless mime_type == "application/x-empty"
      end

      def for_name(name)
        if name
          extension = File.extname(name)
          return if extension.empty?
          for_extension(extension)
        end
      end

      def for_extension(extension)
        if extension
          extension = extension.gsub(/\A\./, "").downcase

          if info = (Marcel::MimeType.ext_overrides[extension] || MiniMime.lookup_by_extension(extension))
            info.content_type.downcase
          end
        end
      end

      def for_declared_type(declared_type)
        type = parse_media_type(declared_type)

        if type != BINARY && !type.nil?
          type.downcase
        end
      end

      def parse_media_type(content_type)
        if content_type
          result = content_type.downcase.split(/[;,\s]/, 2).first
          result if result && result.index("/")
        end
      end

      def most_specific_type(from_magic_type, fallback_type)
        if (root_types(from_magic_type) & root_types(fallback_type)).any?
          fallback_type
        else
          from_magic_type
        end
      end

      def root_types(type)
        if parents.include?(type) && parents[type].any?
          parents[type].flat_map { |parent| root_types parent }.uniq
        else
          [ type ]
        end
      end
  end
end

require 'marcel/mime_type/definitions'

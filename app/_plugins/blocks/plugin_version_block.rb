module Jekyll
  class PluginVersionIs < Liquid::Block
    def initialize(tag_name, markup, tokens)
      @tag = markup

      @params = {}
      markup.scan(Liquid::TagAttributes) do |key, value| 
        @params[key.to_sym] = value
      end
      super
    end

    def render(context)
      @context = context
      contents = super
      page = context.environments.first["page"]

      # Ideally we'd raise here and require a version for all files, but to reduce
      # breaking changes we'll just return the contents if there is no version set
      ::Jekyll.logger.error "Missing version for #{page['path']}" unless page['version']
      return contents unless page['version']

      page_version = page['version'].to_s.gsub(/\.x/, ".0")
      begin
        current_version = to_version(page_version) # Handle 3.0.x etc
      rescue => e
        # Again, return content early if we can't parse a version
        ::Jekyll.logger.error "Unable to parse version in #{page['path']} [#{page_version}]: #{e.to_s}".red
        return contents
      end

      # If there's an exact match, check only that
      if @params.key?(:eq)
        version = to_version(@params[:eq])
        return "" unless current_version == version
      end

      # If there's a greater than or equal to check, fail if it's lower
      if @params.key?(:gte)
        version = to_version(@params[:gte])
        return "" unless current_version >= version
      end

      # If there's a less than or equal to heck, fail if it's higher
      if @params.key?(:lte)
        version = to_version(@params[:lte])
        return "" unless current_version <= version
      end

      # Remove the leading and trailing whitespace and return
      # We can't use .strip as that removes all leading whitespace,
      # including indentation
      contents.gsub(/^\n/,"").gsub(/\n$/,"") + "<hr />" + version.version + "/" + current_version.version
    end

    def to_version(input)
      # If we were provided with a variable, pull that out of the current scope
      path = input.split('.')
      ref = @context.scopes[0].dig(*path)
      input = ref if ref

      # Handle minimum_version check when there is not a minimum version set
      if input.include?("minimum_version")
        input = "0.0.0"
      end
      # Then convert to a Gem::Version for later comparison
      Gem::Version.new(input.gsub(/\.x$/, ".0"))
    end
  end
end

Liquid::Template.register_tag("if_plugin_version", Jekyll::PluginVersionIs)


Jekyll::Hooks.register :pages, :pre_render do |page|
  # Replace double line breaks when using if_version when
  # combined with <pre> blocks. This is usually in code samples
  page.content = page.content.gsub(/\n(\s*{% if_plugin_version)/, '\1')

  # Also allow for a newline after endif_version when in a table
  page.content = page.content.gsub("{% endif_plugin_version %}\n\n|", "{% endif_plugin_version %}\n|")
end
module Jekyll
  # Add a way to change the page URL
  class Page
    def url=(name)
      @url = name
    end
  end
end

module LatestVersion
  class Generator < Jekyll::Generator
    priority :medium
    def generate(site)

      products_with_latest = ["gateway", "mesh", "KIC", "deck"]
      site.pages.each do |page|

        parts = Pathname(page.path).each_filename.to_a
        products_with_latest.each do |product|
          # Reset values for every new page
          generate_latest = false
          releasePath = nil

          productName = product.downcase
          # Special case KIC
          productName = "kubernetes-ingress-controller" if productName == "kic"

          # Latest version
          if parts[0] == productName && parts[1] == site.data["kong_latest_" + product]['release']
            generate_latest = true
            releasePath = parts[1]
          end

          if generate_latest && !page.data['is_latest']
            # If it has a permalink it's _probably_ an index page e.g. /gateway/
            # so we should not generate a /latest/ URL as it's already evergreen
            next if page.data['permalink']

            # Otherwise, let's generate a /latest/ URL too
            page = DuplicatePage.new(
              site,
              site.source,
              page.url.gsub(releasePath, "latest"),
              page.content,
              page.data
            )
            site.pages << page
          end

        end
      end
    end
  end

  class DuplicatePage < ::Jekyll::Page
    def initialize(site, base_dir, path, content, data)
      @site = site
      @base = base_dir
      @content = content

      @dir = path
      @name = "index.md"

      process(@name)
      @data = data.clone
    end
  end
end
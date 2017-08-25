module CiteProc
  module Ruby

    class Renderer

      # @param item [CiteProc::CitationItem]
      # @param node [CSL::Style::Group]
      # @return [String]
      def render_group(item, node)
        return '' unless node.has_children?

	if item.kind_of?(CiteProc::CitationItem)
          observer = ItemObserver.new(item.data)
	else
          observer = ItemObserver.new(item[0].data)      
        end
        observer.start

        begin
	  if item.kind_of?(CiteProc::CitationItem)
            rendition = join node.each_child.map { |child|
              render item, child
	    }.reject(&:empty?), node.delimiter || ''
	  else
            rendition = join item.map { |sub_item|
              result_2 = join node.each_child.map { |child|
	        result = render sub_item, child
	        result
	      }.reject(&:empty?) || ''
              result_2
	    }.reject(&:empty?), node.delimiter || ''
	  end

	  if node.respond_to?('prefix')
            prefix = node.prefix
          else
	    prefix = ''    
	  end
	  if node.respond_to?('suffix')
            suffix = node.suffix
	  else
            suffix = ''
	  end
	  #rendition = join(rendition,node.delimiter)
	  rendition = prefix + rendition + suffix
	  rendition

	ensure
          observer.stop
        end

        return '' if observer.skip?

        rendition
      end

    end

  end
end

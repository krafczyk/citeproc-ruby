module CiteProc
  module Ruby

    class Renderer

      private

      # @param item [CiteProc::CitationItem]
      # @param node [CSL::Style::Layout]
      # @return [String]
      def render_layout(item, node)
        result = join node.each_child.map { |child|
          render item, child
        }.reject(&:empty?), node.delimiter
        result
      end

      # @param item [CiteProc::CitationData]
      # @param node [CSL::Style::Layout]
      # @return [String]
      def render_layout_data(item, node)
        result = join node.each_child.map { |child|
          render item, child
        }.reject(&:empty?), node.delimiter
	result
      end
      
    end

  end
end

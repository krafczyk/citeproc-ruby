module CiteProc
  module Ruby

    class Renderer

      attr_reader :state

      attr_accessor :engine

      def initialize(options_or_engine = nil)
        @state = State.new

        case options_or_engine
        when Engine
          @engine = options_or_engine
        when Hash
          locale, format = options_or_engine.values_at(:locale, :format)
          @locale, @format = CSL::Locale.load(locale), Format.load(format)
        end
      end

      def abbreviate(*arguments)
        return unless engine
        engine.abbreviate(*arguments)
      end
      alias abbrev abbreviate

      def allow_locale_overrides?
        return false unless engine
        engine.options[:allow_locale_overrides]
      end

      # @param item [CiteProc::CitationItem]
      # @param node [CSL::Node]
      # @return [String] the rendered and formatted string
      def render(item, node)
        raise ArgumentError, "no CSL node: #{node.inspect}" unless
          node.respond_to?(:nodename)

        specialize = "render_#{node.nodename.tr('-', '_')}"

        raise ArgumentError, "#{specialize} not implemented" unless
          respond_to?(specialize, true)

        format! send(specialize, item, node), node
      end

      # @param data [CiteProc::CitationData]
      # @param node [CSL::Style::Citation]
      # @return [String] the rendered and formatted string
      def render_citation(data, node)
	# Sort passed nodes in order if the sort key is citation-number.
	if node.sort_keys.length > 0 and node.sort_keys[0][:variable] == 'citation-number'
          all_data_have_citation_number = true
          for data_instance in data
	    if data_instance.data[:'citation-number'].nil?
              all_data_have_citation_number = false
              break
            end
          end
          if all_data_have_citation_number
		  data.sort!{|x,y| x.data[:'citation-number'].to_i <=> y.data[:'citation-number'].to_i}
	  end
        end

        state.store! data, node

	result = render_layout data, node.layout

	if not node[:collapse].nil? and node[:collapse] == "citation-number"
	  first_num_idx = result.index(/\d/)
	  last_num_idx = result.length - result.reverse.index(/\d/) -1
	  prefix = result[0...first_num_idx]
	  suffix = result[last_num_idx+1..-1]
	  sub_result = result[first_num_idx..last_num_idx]
	  num_array = sub_result.split(node.layout.delimiter)
	  first_idx = -1
	  last_idx = -1
	  idx = 0
	  while idx < num_array.length
	    if num_array[idx].to_i > num_array[last_idx].to_i + 1
              if last_idx <= first_idx + 1
                first_idx = idx
                last_idx = idx
                idx += 1
	      else
                first_num = num_array[first_idx]
                last_num = num_array[last_idx]
                separator = '–'
                num_array[first_idx] = first_num + separator + last_num
                tot_del = last_idx - first_idx
		num_del = 0
                idx = first_idx + 1
		first_idx = idx-1
		last_idx = idx-1
		while num_del < tot_del
                  num_array.delete_at(idx)
                  num_del += 1
                end
	      end
	    else
	       last_idx = idx
               idx += 1
	    end
          end
	  new_result = num_array.join(node.layout.delimiter)
	  new_result = prefix + new_result + suffix
	  result = new_result
	end

	result
      ensure
        state.clear! result
      end

      # @param group [[CiteProc::CitationItem]]
      # @param node [CSL::Style::Layout]
      # @return [String] the rendered and string
      def render_citation_group(group, node)
         citations = join group.map { |item|
           render_single_citation item, node
	 } || ''
      end

      # @param data [CiteProc::CitationItem]
      # @param node [CSL::Style::Layout]
      # @return [String] the rendered and string
      def render_single_citation(item, node)
        # TODO author_only
        item.suppress! 'author' if item.suppress_author?

        join [item.prefix, render_layout(item, node), item.suffix].compact
      end

      # @param item [CiteProc::CitationItem]
      # @param node [CSL::Style::Bibliography]
      # @return [String] the rendered and formatted string
      def render_bibliography(item, node)
        state.store! item, node

        if allow_locale_overrides? && item.language != locale.language
          begin
            new_locale = CSL::Locale.load(item.language)

            unless new_locale.nil?
              original_locale, @locale = @locale, new_locale
            end
          rescue ParseError
            # locale not found
          end
        end

        result = render item, node.layout

      ensure
        unless original_locale.nil?
          @locale = original_locale
        end

        state.clear! result
      end

      #def render_sort(a, b, node, key)
      def render_sort(item, node)
	if item.kind_of?(CiteProc::CitationItem)
	  return ''
	end
	key = node.children[0][:variable]
        #state.store! nil, key

        if key == "citation-number"
	  item.sort!{|x,y| x.data[:'citation-number'].to_i <=> y.data[:'citation-number'].to_i}
	end        
	result = ''
        #p "Renderer.render_sort 2"
        #original_format = @format
        #@format = Formats::Sort.new
#
#        p "Renderer.render_sort 3"
#        if a.is_a?(CiteProc::Names)
#          p "Renderer.render_sort 4"
#          [render_name(a, node), render_name(b, node)]
#
#        else
#          p "Renderer.render_sort 5"
#          # We need to clear any items that are suppressed
#          # because they were used as substitutes during
#          # rendering for sorting purposes!
#          a_rendered = render a.cite, node
#          a.suppressed.clear
#
#          b_rendered = render b.cite, node
#          b.suppressed.clear
#
#          [a_rendered, b_rendered]
#        end
#
#        p "Renderer.render_sort 6"
      ensure
	#p "Renderer.render_sort 7"
        #@format = original_format
	#p "Renderer.render_sort 8"
        #state.clear!
	#p "Renderer.render_sort 9"
      end

    end

  end
end

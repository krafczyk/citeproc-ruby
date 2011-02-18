#--
# CiteProc-Ruby
# Copyright (C) 2009-2011 Sylvester Keil <sylvester.keil.or.at>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.	If not, see <http://www.gnu.org/licenses/>.
#++

module CSL
    
  class Variable
    include Attributes
    include Comparable

    @date_fields = %w{ accessed container event-date issued original-date }

    @name_fields = %w{
      author editor translator recipient interviewer publisher composer
      original-publisher original-author container-author collection-editor }

    @text_fields = %w{
      id abstract annote archive archive-location archive-place authority
      call-number chapter-number citation-label citation-number collection-title
      container-title DOI edition event event-place first-reference-note-number
      genre ISBN issue jurisdiction keyword locator medium note number
      number-of-pages number-of-volumes original-publisher original-publisher-place
      original-title page page-first publisher publisher-place references
      section status title URL version volume year-suffix }

    @filters = Hash.new
    
    @parser = Hash.new('Variable')
    @date_fields.each { |field| @parser[field] = 'Date' }
    @name_fields.each { |field| @parser[field] = 'Name' }

    attr_fields :literal
    
    class << self
      attr_reader :date_fields, :name_fields, :text_fields, :filters, :parser

      def fields
        date_fields + name_fields + text_fields
      end
      
      def filter(id, key)
        Variable.filters[id][key]
      end

      def parse(variables, type=nil)
        parser = lambda { |variable| CSL.const_get(Variable.parser[type]).new(variable) }
        variables.is_a?(Array) ? variables.map { |v| parser.call(v) } : parser.call(variables)
      end
      
    end

    def initialize(attributes={})
      set(attributes)
    end
    
    def set(argument)
      argument.is_a?(Hash) || argument.is_a?(Array) ?  self.merge!(argument) : self.literal = argument.to_s
    end

    def to_s
      self.literal.to_s
    end
        
    def <=>(other)
      self.attributes <=> other.attributes
    end
  end
  

  # == Name Variables
  #
  # When present in the item data, CSL name variables must be delivered as a
  # list of JavaScript arrays, with one array for each name represented by the
  # variable. Simple personal names are composed of family and given elements,
  # containing respectively the family and given name of the individual.
  #
  # { "author" : [
  #     { "family" : "Doe", "given" : "Jonathan" },
  #     { "family" : "Roe", "given" : "Jane" }
  #   ],
  #   "editor" : [
  #     { "family" : "Saunders",
  #       "given" : "John Bertrand de Cusance Morant" }
  #   ]
  # }
  #
  # Institutional and other names that should always be presented literally
  # (such as "The Artist Formerly Known as Prince", "Banksy", or "Ramses IV")
  # should be delivered as a single literal element in the name array:
  # 
  # { "author" : [
  #     { "literal" : "Society for Putting Things on Top of Other Things" }
  #   ]
  # }
  #
  # If the name is spelled using a 'byzantine' alphabet (i.e., latin or
  # cyrillic) its sort and display order is computed according to the given
  # arguments.
  #
  class Name < Variable
  
    attr_fields %w{ given family literal suffix dropping-particle
      non-dropping-particle comma-suffix static-ordering parse-names }

    [[:last, :family], [:first, :given]].each do |m|
      alias_method m[0], m[1]
    end
    
    def defaults
      Hash[*%w{ form long name-as-sort-order false demote-non-dropping-particle never }]
    end
    
    def is_oriental?
      false # TODO
    end
    
    
    # @returns a list of strings, representing a given order of the individual
    # tokens when displaying the name.
    def display_order(options={})
      options = defaults.merge(options)
      case
      when literal?
        return %w{ literal }
        
      when options['form'] == 'long' && options['name-as-sort-order'] == 'false'
        return %w{ given dropping-particle non-dropping-particle family suffix }

      when options['form'] == 'long' && options['name-as-sort-order'] == 'true' && ['never', 'sort-only'].include?(options['demote-non-dropping-particle'])
        return %w{ non-dropping-particle family given dropping-particle suffix }
    
      when options['form'] == 'long' && options['name-as-sort-order'] == 'true' && options['demote-non-dropping-particle'] == 'display-and-sort'
        return %w{ family given dropping-particle non-dropping-particle suffix }
    
      else # options['form'] == 'short'
        return %w{ non-dropping-particle family}
      end
    end
    
    # @returns a list of strings, representing the order of precedence of the
    # individual tokens when sorting the name.
    def sort_order(options={})
      options = defaults.merge(options)
      case
      when literal?
        return %w{ literal }
        
      when options['demote-non-dropping-particle'] == 'never'
        return %w{ non-dropping-particle+family dropping-particle given suffix }
      else
        return %w{ family non-dropping-particle+dropping-particle given suffix }
      end
    end
    
    # @returns a string representing the name according to the given set of
    # display order options.
    def display(options={})
      self.display_order(options).map { |part| attributes[part] }.reject(&:nil?).join(' ')
    end
    
    def to_s
      self.display
    end
    
    def to_json
      self.attributes.to_json
    end
    
    def literal_as_sort_order
      literal.gsub(/^(the|an?|der|die|das|eine?|l[ae])\s+/i, '')
    end
    
    def <=>(other)
      tests = self.sort_order.zip(other.sort_order).map do |pair|
        this, that = pair.map { |token| token.gsub(/[\s-]+/,'_').gsub(/literal/, 'literal_sort_order') }          

        this = this.split(/\+/).map { |token| self.send(token) }.join.downcase
        that = that.split(/\+/).map { |token| other.send(token) }.join.downcase

        # TODO should we ignore '' here?
        this <=> that
      end
      
      tests = tests.reject(&:nil?)
      tests[tests.take_while(&:zero?).length]
    end
  end


  # == Date Variables
  #
  # Date objects wrap an underlying JavaScript object, within which the
  # "date-parts" element is a nested JavaScript array containing a start date
  # and optional end date, each of which consists of a year, an optional month
  # and an optional day, in that order if present. Additionally, the string
  # fields "season", "literal", as well as the boolean field "circa" are
  # supported. 
  #
  class Date < Variable

    attr_fields %w{ date-parts season circa literal }

    [:year, :month, :day].each_with_index do |method_id, index|
      define_method method_id do; date_parts[0][index].to_i end
      
      define_method [method_id, '='].join do |value|
        date_parts[0][index] = value.to_i
      end      
    end
        
    def date_parts
      attributes['date-parts'] ||= [[]]
    end
    
    def is_range?
      date_parts.length > 1
    end
    
    def from
      date_parts.first
    end
    
    def to
      date_parts[1] ||= []
    end
    
    def to_s
      literal || attributes.inspect
    end
  
    def to_json
      self.attributes.to_json
    end
    
    def <=>(other)
      self.from <=> other.from
    end
  end
end
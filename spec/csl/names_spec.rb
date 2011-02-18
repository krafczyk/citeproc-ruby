describe CSL::Variables::Name do
  CSL::Test::Fixtures::Names.keys.each do |feature|
    describe feature do

      CSL::Test::Fixtures::Names[feature].each do |test|

        it test['it'] do
          names = CSL::Variables::Name.parse(test['names'])
          expected = test['expected']
          options = test['options']
        
          result = case feature
            when 'sort'
              names.sort.map(&:to_s)
            else
              names.map { |name| name.send(feature, options) }
            end
        
          result.should == expected 
        end
        
      end
      
    end
  end
end
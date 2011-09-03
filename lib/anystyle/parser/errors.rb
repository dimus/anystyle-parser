module Anystyle
	module Parser
		
		class Error < StandardError
			
			attr_accessor :original
			
			def initialize(message = nil, original = $!)
				super(message)
				@original = original				
			end
			
		end
		
		class DatabaseError < Error; end
		class TrainingError < Error; end
		
	end
end
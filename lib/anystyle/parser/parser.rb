module Anystyle
	module Parser

		class Parser

			@formats = [:bibtex, :hash, :citeproc, :tags].freeze
			
			@defaults = {
				:model => File.expand_path('../support/anystyle.mod', __FILE__),
				:pattern => File.expand_path('../support/anystyle.pat', __FILE__),
				:separator => /\s+/,
				:tagged_separator => /\s+|(<\/?[^>]+>)/,
				:strip => /[^[:alnum:]]/,
				:format => :hash,
				:training_data => File.expand_path('../../../../resources/train.txt', __FILE__)
			}.freeze
			
			@features = Feature.instances
			@feature = Hash.new { |h,k| h[k.to_sym] = features.detect { |f| f.name == k.to_sym } }
			
			class << self

				attr_reader :defaults, :features, :feature, :formats
								
				def load(path)
					p = new                                    
					p.model = Wapiti.load(path)
					p
				end

				# Returns a default parser instance
				def instance
					@instance ||= new
				end
				
			end
			
			attr_reader :options
			
			attr_accessor :model, :normalizer
			
			def initialize(options = {})
				@options = Parser.defaults.merge(options)
				@model = Wapiti.load(@options[:model])
				@normalizer = Normalizer.instance
			end
			
			def parse(input, format = options[:format])
				formatter = "format_#{format}".to_sym
				send(formatter, label(input))
			rescue NoMethodError
				raise ArgumentError, "format not supported: #{formatter}"
			end
			
			# Returns an array of label/segment pairs for each line in the passed-in string.
			def label(input, labelled = false)
				string = input_to_s(input)
				
				model.label(prepare(string, labelled)).map! do |sequence|
					sequence.inject([]) do |ts, (token, label)|
						token, label = token[/^\S+/], label.to_sym
						if (prev = ts[-1]) && prev[0] == label
							prev[1] << ' ' << token
							ts
						else
							ts << [label, token]
						end
					end
				end
				
			end
			
			# Returns an array of tokens for each line of input.
			#
			# If the passed-in string is marked as being tagged, extracts labels
			# from the string and returns an array of token/label pairs for each
			# line of input.
			def tokenize(string, tagged = false)
				if tagged
					string.split(/[\n\r]+/).each_with_index.map do |s,i|
						tt, tokens, tags = s.split(options[:tagged_separator]), [], []

						tt.each do |token|
							case token
							when /^$/
								# skip
							when /^<([^\/>][^>]*)>$/
								tags << $1
							when /^<\/([^>]+)>$/
								unless (tag = tags.pop) == $1
									raise ArgumentError, "mismatched tags on line #{i}: #{$1.inspect} (current tag was #{tag.inspect})"
								end
							else
								tokens << [token, (tags[-1] || :unknown).to_sym]
							end
						end

						tokens
					end
				else
					string.split(/[\n\r]+/).map { |s| s.split(options[:separator]) }
				end
			end

			# Prepares the passed-in string for processing by a CRF tagger. The
			# string is split into separate lines; each line is tokenized and
			# expanded. Returns an array of sequence arrays that can be labelled
			# by the CRF model.
			#
			# If the string is marked as being tagged by passing +true+ as the
			# second argument, training labels will be extracted from the string
			# and appended after feature expansion. The returned sequence arrays
			# can be used for training or testing the CRF model.
			def prepare(input, tagged = false)
				string = input_to_s(input)
				tokenize(string, tagged).map { |tk| tk.each_with_index.map { |(t,l),i| expand(t,tk,i,l) } }
			end


			# Expands the passed-in token string by appending a space separated list
			# of all features for the token.
			def expand(token, sequence = [], offset = 0, label = nil)
				f = features_for(token, strip(token), sequence, offset)
				f.unshift(token)
				f.push(label) unless label.nil?
				f.join(' ')
			end
			
			def train(input = options[:training_data], truncate = true)
				string = input_to_s(input)
				@model = Wapiti::Model.new(:pattern => options[:pattern]) if truncate
				@model.train(prepare(string, true))
				@model.compact
				@model.path = options[:model]
				@model
			end
			
			def test(input)
				string = input_to_s(input)
				model.options.check!
				model.label(prepare(string, true))
			end
			
			def normalize(hash)
				hash.keys.each do |label|
					normalizer.send("normalize_#{label}", hash)
				end
				classify hash
			end
			
			def classify(hash)
				return hash if hash.has_key?(:type)
				
				keys = hash.keys
				text = hash.values.flatten.join
				
				case
				when keys.include?(:journal)
					hash[:type] = :article
				when text =~ /proceedings/i
					hash[:type] = :inproceedings
				when keys.include?(:booktitle), keys.include?(:container)
					hash[:type] = :incollection
				when keys.include?(:publisher)
					hash[:type] = :book
				when keys.include?(:institution)
					hash[:type] = :techreport
				when keys.include?(:school) || text =~ /master('s)?\s+thesis/i
					hash[:type] = :mastersthesis
				when text =~ /interview/i
					hash[:type] = :interview
				when text =~ /videotape/i
					hash[:type] = :videotape
				when text =~ /unpublished/i
					hash[:type] = :unpublished
				else
					hash[:type] = :misc
				end
				
				hash
			end
						
			private
			
			def input_to_s(input)
				case input
				when String
					if input.length < 128 && File.exists?(input)
						f = File.open(input, 'r:UTF-8')
						f.read
					else
						input
					end
				when Array
					input.join("\n")
				else
					raise ArgumentError, "invalid input: #{input.class}"
				end
			ensure
				f.close if f
			end
			
			def features_for(*arguments)
				Parser.features.map { |f| f.match(*arguments) }
			end
			
			def strip(token)
				token.gsub(options[:strip], '')
			end
			
			def format_bibtex(labels)
				b = BibTeX::Bibliography.new
				format_hash(labels).each do |hash|
					b << BibTeX::Entry.new(hash)
				end
				b
			end
			
			def format_hash(labels)
				labels.map do |line|
					hash = line.inject({}) do |h, (label, token)|
						if h.has_key?(label)
							h[label] = [h[label]].flatten << token
						else
							h[label] = token
						end
						h
					end
					normalize hash
				end
			end
			
			def format_citeproc(labels)
				format_bibtex(labels).to_citeproc
			end
			
			def format_tags(labels)
				labels.map do |line|
					line.map { |label, token| "<#{label}>#{token}</#{label}>" }.join(' ')
				end
			end
			
		end

	end
end

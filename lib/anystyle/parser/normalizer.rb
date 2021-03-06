# -*- encoding: utf-8 -*-

module Anystyle
	module Parser

		class Normalizer

			include Singleton

			MONTH = Hash.new do |h,k|
				case k
				when /jan/i
					h[k] = 1
				when /feb/i
					h[k] = 2
				when /mar/i
					h[k] = 3
				when /apr/i
					h[k] = 4
				when /ma[yi]/i
					h[k] = 5
				when /jun/i
					h[k] = 6
				when /jul/i
					h[k] = 7
				when /aug/i
					h[k] = 8
				when /sep/i
					h[k] = 9
				when /o[ck]t/i
					h[k] = 10
				when /nov/i
					h[k] = 11
				when /dec/i
					h[k] = 12
				else
					h[k] = nil
				end
			end
			
			def method_missing(name, *arguments, &block)
				case name.to_s
				when /^normalize_(.+)$/
					normalize($1.to_sym, *arguments, &block)
				else
					super
				end
			end

			# Default normalizer. Strips punctuation.
			def normalize(key, hash)
				token, *dangling =  hash[key]
				unmatched(key, hash, dangling) unless dangling.empty?

				token.gsub!(/^[^[:alnum:]]+|[^[:alnum:]]+$/, '')
				hash[key] = token
				hash
			rescue => e
				warn e.message
				hash
			end

			def normalize_author(hash)
				authors, *dangling = hash[:author]
				unmatched(:author, hash, dangling) unless dangling.empty?
				
				if authors =~ /[^[:alnum:]]*[Ee]d(s|itors)?[^[:alnum:]]*$/ && !hash.has_key?(:editor)
					hash[:editor] = hash.delete(:author)
					hash = normalize_editor(hash)
				else
		      hash['more-authors'] = true if !!authors.sub!(/\bet\.?\s*al.*$/i, '')
					authors.gsub!(/^[^[:alnum:]]+|[^[:alnum:]]+$/, '')
					hash[:author] = normalize_names(authors)
				end
				
				hash
			rescue => e
				warn e.message
				hash
			end
			
	    def normalize_editor(hash)
				editors, *dangling = hash[:editor]
	
				unless dangling.empty?
					case
					when !hash.has_key?(:author)
						hash[:author] = editors
						hash[:editor] = dangling
						hash = normalize_author(hash)
						return normalize_editor(hash)
					when dangling[0] =~ /(\d+)/
						hash[:edition] = $1.to_i
					else
						unmatched(:editor, hash, dangling)
					end
				end
	
	      hash['more-editors'] = true if !!editors.sub!(/\bet\.?\s*al.*$/i, '')
	
				editors.gsub!(/^[^[:alnum:]]+|[^[:alnum:]]+$/, '')
				editors.gsub!(/^in\s+/i, '')
				editors.gsub!(/[^[:alpha:]]*[Ee]d(s|itors?|ited)?[^[:alpha:]]*/, '')
				editors.gsub!(/[^[:alpha:]]*([Hh]rsg|Herausgeber)[^[:alpha:]]*/, '')
				editors.gsub!(/\bby\b/i, '')

				is_trans = !!editors.gsub!(/[^[:alpha:]]*trans(lated)?[^[:alpha:]]*/i, '')

      	hash[:editor] = normalize_names(editors)
				hash[:translator] = hash[:editor] if is_trans
				
	      hash
			rescue => e
				warn e.message
				hash
	    end

			def normalize_translator(hash)
				translators = hash[:translator]
				
				translators.gsub!(/^[^[:alnum:]]+|[^[:alnum:]]+$/, '')
				translators.gsub!(/[^[:alpha:]]*trans(lated)?[^[:alpha:]]*/i, '')
				translators.gsub!(/\bby\b/i, '')
				
				hash[:translator] = normalize_names(translators)
				hash
			rescue => e
				warn e.message
				hash
			end
			
			Namae::Parser.instance.options[:prefer_comma_as_separator] = true

			def normalize_names(names)
				Namae.parse!(names).map(&:sort_order).join(' and ')
			rescue => e
				warn e.message
				hash
			end
						
			def normalize_title(hash)
				title, container = hash[:title]
				
				unless container.nil?
					hash[:container] = container
					normalize(:container, hash)
				end

				extract_edition(title, hash)
				
				title.gsub!(/^[\s]+|[\.,:;\s]+$/, '')
				title.gsub!(/^["'”’´‘“`]|["'”’´‘“`]$/, '')
					
				hash[:title] = title
				
				hash
			rescue => e
				warn e.message
				hash
			end
			
			def extract_edition(token, hash)
				edition = [hash[:edition]].flatten.compact
				
				if token.gsub!(/[^[:alnum:]]*(\d+)(?:st|nd|rd|th)?\s*(?:Aufl(?:age|\.)|ed(?:ition|\.)?)[^[:alnum:]]*/i, '')
					edition << $1
				end				

				if token.gsub!(/(?:\band)?[^[:alnum:]]*([Ee]xpanded)[^[:alnum:]]*$/, '')
					edition << $1
				end					

				if token.gsub!(/(?:\band)?[^[:alnum:]]*([Ii]llustrated)[^[:alnum:]]*$/, '')
					edition << $1
				end					

				if token.gsub!(/(?:\band)?[^[:alnum:]]*([Rr]evised)[^[:alnum:]]*$/, '')
					edition << $1
				end					

				if token.gsub!(/(?:\band)?[^[:alnum:]]*([Rr]eprint)[^[:alnum:]]*$/, '')
					edition << $1
				end
				
				hash[:edition] = edition.join(', ') unless edition.empty?
			end
			
			def normalize_booktitle(hash)
				booktitle, *dangling = hash[:booktitle]
				unmatched(:booktitle, hash, dangling) unless dangling.empty?
				
				booktitle.gsub!(/^in\s*/i, '')

				extract_edition(booktitle, hash)

				booktitle.gsub!(/^[\s]+|[\.,:;\s]+$/, '')
				hash[:booktitle] = booktitle
				
				hash
			rescue => e
				warn e.message
				hash
			end

			def normalize_journal(hash)
				journal, *dangling = hash[:journal]
				unmatched(:journal, hash, dangling) unless dangling.empty?

				journal.gsub!(/^[\s]+|[\.,:;\s]+$/, '')
				hash[:journal] = journal
				
				hash
			rescue => e
				warn e.message
				hash
			end
			
			def normalize_container(hash)
				container, *dangling = hash[:container]
				unmatched(:container, hash, dangling) unless dangling.empty?
				
				case container
				when /dissertation abstracts/i
					container.gsub!(/\s*section \w: ([[:alnum:]\s]+).*$/i, '')
					hash[:category] = $1 unless $1.nil?
					hash[:type] = :phdthesis
				end
				
				hash[:container] = container
				hash
			rescue => e
				warn e.message
				hash
			end
			
			def normalize_date(hash)
				date, *dangling = hash[:date]
				unmatched(:date, hash, dangling) unless dangling.empty?
				
				unless (month = MONTH[date]).nil?
					hash[:month] = month
				end
				
				if date =~ /(\d{4})/
					hash[:year] = $1.to_i
					hash.delete(:date)
				end

				hash
			rescue => e
				warn e.message
				hash
			end

			def normalize_volume(hash)
				volume, *dangling = hash[:volume]
				unmatched(:volume, hash, dangling) unless dangling.empty?
				
				if !hash.has_key?(:pages) && volume =~ /\D*(\d+):(\d+(?:[–-]+)\d+)/
					hash[:volume], hash[:pages] = $1.to_i, $2
					hash = normalize_pages(hash)				
				else
					case volume
					when /\D*(\d+)\D+(\d+[\s&-]+\d+)/
						hash[:volume], hash[:number] = $1.to_i, $2
					when /(\d+)?\D+no\.\s*(\d+\D+\d+)/
						hash[:volume] = $1.to_i unless $1.nil?
						hash[:number] = $2
					when /(\d+)?\D+no\.\s*(\d+)/
						hash[:volume] = $1.to_i unless $1.nil?
						hash[:number] = $2.to_i
					when /\D*(\d+)\D+(\d+)/
						hash[:volume], hash[:number] = $1.to_i, $2.to_i
					when /(\d+)/
						hash[:volume] = $1.to_i
					end
				end
				
				hash
			rescue => e
				warn e.message
				hash
			end

			def normalize_pages(hash)
				pages, *dangling = hash[:pages]
				unmatched(:pages, hash, dangling) unless dangling.empty?
				
				# "volume.issue(year):pp"
				case pages
				when /(\d+) (?: \.(\d+))? (?: \( (\d{4}) \))? : (\d.*)/x
					hash[:volume] = $1.to_i
					hash[:number] = $2.to_i unless $2.nil?
					hash[:year] = $3.to_i unless $3.nil?
					hash[:pages] = $4
				end

				case hash[:pages]
				when /(\d+)\D+(\d+)/
					hash[:pages] = [$1,$2].join('--')
				when  /(\d+)/
					hash[:pages] = $1
				end
				
				hash
			rescue => e
				warn e.message
				hash
			end
			
			def normalize_location(hash)
				location, *dangling = hash[:location]
				unmatched(:pages, hash, dangling) unless dangling.empty?

				location.gsub!(/^[^[:alnum:]]+|[^[:alnum:]]+$/, '')

				if !hash.has_key?(:publisher) && location =~ /:/
					location, publisher = location.split(/\s*:\s*/)
					hash[:publisher] = publisher
				end
				
				hash[:location] = location
				hash
			rescue => e
				warn e.message
				hash
			end

			def normalize_isbn(hash)
				isbn, *dangling = hash[:isbn]
				unmatched(:isbn, hash, dangling) unless dangling.empty?

				isbn = isbn[/[\d-]+/]
				hash[:isbn] = isbn

				hash
			rescue => e
				warn e.message
				hash
			end
			
			def normalize_url(hash)
				url, *dangling = hash[:url]
				unmatched(:url, hash, dangling) unless dangling.empty?

				url.gsub!(/^\s+|[,\s]+$/, '')
				hash[:isbn] = isbn
				hash
			rescue => e
				warn e.message
				hash
			end
			
			private
			
			def unmatched(label, hash, tokens)
				hash["unmatched-#{label}"] = tokens.join(' ')
			end
			
		end

	end
end

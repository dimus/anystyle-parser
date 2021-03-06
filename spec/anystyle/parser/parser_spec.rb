module Anystyle::Parser
  describe Parser do
    
    it { should_not be nil }
    
		describe "#tokenize" do
			it "returns [] when given an empty string" do
				subject.tokenize('').should == []
			end
			
		  it "takes a single line and returns an array of token sequences" do
				subject.tokenize('hello, world!').should == [%w{ hello, world! }]
			end
			
		  it "takes two lines and returns an array of token sequences" do
				subject.tokenize("hello, world!\ngoodbye!").should == [%w{ hello, world! }, %w{ goodbye! }]
			end
			
			context "when passing a string marked as tagged" do
				it "returns [] when given an empty string" do
					subject.tokenize('', true).should == []
				end
			
				it "returns an array of :unknown token sequences when given an untagged single line" do
					subject.tokenize('hello, world!', true).should == [[['hello,', :unknown], ['world!', :unknown]]]
				end

				it "returns an array of :unknown token sequences when given two untagged lines" do
					subject.tokenize("hello,\nworld!", true).should == [[['hello,', :unknown]], [['world!', :unknown]]]
				end

				it "returns an array of token/tag pair for each line when given a single tagged string" do
					subject.tokenize('<a>hello</a>', true).should == [[['hello', :a]]]
				end
			
				it "returns an array of token/tag pair for each line when given a string with multiple tags" do
					subject.tokenize('<a>hello world</a> <b> !</b>', true).should == [[['hello',:a], ['world', :a], ['!', :b]]]
				end
			
				it "raises an argument error if the string contains mismatched tags" do
					expect { subject.tokenize('<a> hello </b>', true) }.to raise_error(ArgumentError)
					expect { subject.tokenize('<a> hello <b> world </a>', true) }.to raise_error(ArgumentError)
				end
			end
			
		end
		
		describe "#prepare" do
			it 'returns an array of expanded token sequences' do
				subject.prepare('hello, world!').should == [['hello, , h he hel hell , o, lo, llo, hello other none 0 no-male no-female no-surname no-month no-place no-publisher no-journal no-editors 0 internal other none', 'world! ! w wo wor worl ! d! ld! rld! world other none 36 no-male no-female surname no-month no-place publisher no-journal no-editors 5 terminal other none']]
			end
			
			context 'when marking the input as being tagged' do
				let(:input) { %{<author> A. Cau, R. Kuiper, and W.-P. de Roever. </author> <title> Formalising Dijkstra's development strategy within Stark's formalism. </title> <editor> In C. B. Jones, R. C. Shaw, and T. Denvir, editors, </editor> <booktitle> Proc. 5th. BCS-FACS Refinement Workshop, </booktitle> <date> 1992. </date>} }

				it 'returns an array of expaned and labelled token sequences for a tagged string' do
					subject.prepare(input, true)[0].map { |t| t[/\S+$/] }.should == %w{ author author author author author author author author title title title title title title title editor editor editor editor editor editor editor editor editor editor editor booktitle booktitle booktitle booktitle booktitle date }
				end

				it 'returns an array of expanded and labelled :unknown token sequences for an untagged input' do
					subject.prepare('hello, world!', true)[0].map { |t| t[/\S+$/] }.should == %w{ unknown unknown }
				end
				
			end
		end

		describe "#label" do
			let(:citation) { 'Perec, Georges. A Void. London: The Harvill Press, 1995. p.108.' }
			
			it 'returns an array of labelled segments' do
				subject.label(citation)[0].map(&:first).should == [:author, :title, :location, :publisher, :date, :pages]
			end
			
			describe 'when passed more than one line' do
				it 'returns two arrays' do
					subject.label("foo\nbar").should have(2).elements
				end
			end

			describe 'when passed invalid input' do
				it 'returns an empty array for an empty string' do
					subject.label('').should == []
				end
				
				it 'returns an empty array for an empty line' do
					subject.label("\n").should == []
					subject.label("\n ").should == [[],[]]
					subject.label(" \n ").should == [[],[]]
					subject.label(" \n").should == [[]]
				end

				it 'does not fail for unrecognizable input' do
					lambda { subject.label("@misc{70213094902020,\n") }.should_not raise_error
					lambda { subject.label("doi = {DOI:10.1503/jpn.100140}\n}\n") }.should_not raise_error
					
					pending
					lambda { subject.label("\n doi ") }.should_not raise_error
				end
			end

			
		end

		describe "#parse" do
			let(:citation) { 'Perec, Georges. A Void. London: The Harvill Press, 1995. p.108.' }
			
			it 'returns a hash of label/segment pairs by default' do
				subject.parse(citation)[0].should == { :author => 'Perec, Georges', :title => 'A Void', :location => 'London', :publisher => 'The Harvill Press', :year => 1995, :pages => '108', :type => :book }
			end
			
			describe 'using output format "tags"' do
				it 'returns a tagged string' do
					subject.parse(citation, :tags)[0].should == '<author>Perec, Georges.</author> <title>A Void.</title> <location>London:</location> <publisher>The Harvill Press,</publisher> <date>1995.</date> <pages>p.108.</pages>'
				end
			end
		end

		
  end
end

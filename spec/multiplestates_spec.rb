require 'statemachine'
require 'scxml2.rb'

describe 'state' do
  before (:each) do

    parser = StatemachineParser.new
    @sm = parser.build_from_scxml "testmachines/multiplestates.xml"
  end

  it "should start with the correct state >state1<" do
    @sm.state.should==:state1
  end

  it "should support transitions" do
    @sm.event1
    @sm.state.should==:state2
    @sm.event2
    @sm.state.should==:state3
    @sm.event3
    @sm.state.should==:state1
  end
end

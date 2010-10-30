# -*- coding: raw-text -*-
require 'rubygems'
require 'statemachine'
require 'rexml/document'
require 'rexml/streamlistener'

include REXML

module Statemachine
  class SuperstateBuilder < Builder
    include StateBuilding
    include SuperstateBuilding

    def initialize(id, superstate, statemachine)
      super statemachine
      #p "id: #{id}"
      # p "superstate: #{superstate}"
      @subject = Superstate.new(id, superstate, statemachine)
      #   p "subject: #{@subject}"
      superstate.startstate_id = id if superstate.startstate_id == nil

      # small patch to support redefinition of already existing states without 
      # loosing the already existing transformations. Used to overwrite states
      # with superstates.

      s = statemachine.get_state(id)
      if (s)
        s.transitions.each {|k,v|
          @subject.add(v)
        }
      end

      statemachine.add_state(@subject)
    end
  end

  class StateBuilder < Builder
    include StateBuilding

    def initialize(id, superstate, statemachine)
      super statemachine
#      p "id: #{id}"
#      p "superstate: #{superstate}"
      @subject = acquire_state_in(id, superstate)
 #     p "subject: #{@subject}"
    end
  end
end

class State
  attr_accessor :id, :initial
end

class Transition
  attr_accessor :event, :target, :action
end

class StatemachineParser < Statemachine:: StatemachineBuilder
  include StreamListener
 
  def initialize(logger = nil)
    super()
    # derived by super class Statemachinebuilder - you need to understand how both variables @statemachine and @subject are used in the builders
    #@statemachine = nil
    @current_transition = nil
    @current_state = nil
    @current_element = nil
    @transitions = Array.new
    @actions = Array.new
    @state = Array.new
    @@logger = logger
  end

  def build_from_scxml(filename)
    source = File.new filename
    Document.parse_stream(source, self)
    @statemachine.reset
	return @statemachine
  end

  # parses scxml directly from string parameter stringbuffer
  def build_from_scxml_string(stringbuffer)
    Document.parse_stream(stringbuffer, self)
    @statemachine.reset
    return @statemachine
  end

  def tag_start(name, attributes)
    case name
      when 'state'
        state = nil
        @current_state = State.new
        @current_state.id = attributes['id']
        @current_state.initial = attributes['initial']        # d�vida se realmente precisa
        if (@current_state.initial != nil)                    # we already know it is a superstate
            state = Statemachine::SuperstateBuilder.new(attributes['id'].to_sym, @subject, @statemachine)
            state.startstate(@current_state.initial.to_sym)
        else
          if (@state.empty?)      # It isn't a sub state
            state = Statemachine::StateBuilder.new(attributes['id'].to_sym, @subject, @statemachine)
          else                    # this state is a sub state => last state in @state it's its superstate
            if (@state.last.is_a? Statemachine::StateBuilder)       # if @state.last isn't a superstate, change it to one
              state = Statemachine::SuperstateBuilder.new(@state.last.subject.id, @state.last.subject.superstate, @state.last.subject.statemachine)
              @state.pop            # pops the old one
              @state.push(state)    # pushes the new one
            end
            #   @state.last is a superstate => just create the new state using it
            state = Statemachine::StateBuilder.new(attributes['id'].to_sym, @state.last.subject, @statemachine)
          end
        end
        @state.push(state)
      when 'transition'
        @current_transition = Transition.new
        @current_transition.event = attributes['event']
        @current_transition.target = attributes['target']
        @transitions.push(@current_transition)
      when 'log'
        @actions.push(attributes['expr'])
      else
        @current_element = name
      end
  end

  def tag_end(name) # think we really need this, since only when reaching the end tag we are sure about that we have added all events, actions and so on.
    case name
      when 'state'
         @state.pop
      when 'transition'       # I still have to add the parent state's transitions to the child state
        action = @actions.last
        if (@transitions.last.target != nil)     # if it has a target state
          @state.last.event(@transitions.last.event.to_sym, @transitions.last.target.to_sym, proc { @@logger.puts action if (action and @@logger)  })
        else                                     # it is its own target state
          @state.last.event(@transitions.last.event.to_sym, @state.last.id.to_sym, proc {  @@logger.puts action if ( action and @@logger)  })
        end
        @transitions.pop
        @actions.pop
    end
  end

  def xmldecl(version, encoding, standalone)
  end
end

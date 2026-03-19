# frozen_string_literal: true

require "spec_helper"

# Minimal concrete agent for testing base class behavior
class TestAgent < Gemlings::Agent
  def system_prompt
    prompt = "You are a test agent. Tools: {{tool_descriptions}}"
    prompt = prompt.gsub("{{tool_descriptions}}", tools.map { |t| t.class.to_prompt }.join("\n"))
    prompt = "#{prompt}\n\n#{@instructions}" if @instructions
    prompt
  end

  def parse_response(response)
    [response.content, nil]
  end

  def run_action(thought, action, response, llm_duration)
    nil
  end
end

RSpec.describe Gemlings::Agent do
  let(:model) { instance_double(Gemlings::Model) }

  let(:simple_response) do
    Gemlings::ChatMessage.new(
      role: "assistant",
      content: "Just thinking",
      token_usage: Gemlings::TokenUsage.new(input_tokens: 10, output_tokens: 20)
    )
  end

  describe "#build_tools" do
    it "always includes FinalAnswerTool" do
      agent = TestAgent.new(model: model)
      expect(agent.tools.map { |t| t.class.tool_name }).to include("final_answer")
    end

    it "instantiates tool classes" do
      tool_class = Class.new(Gemlings::Tool) do
        tool_name "my_tool"
        description "test"
        output_type :string
        def call = "ok"
      end

      agent = TestAgent.new(model: model, tools: [tool_class])
      expect(agent.tools.map { |t| t.class.tool_name }).to include("my_tool")
    end

    it "passes through tool instances" do
      tool_class = Class.new(Gemlings::Tool) do
        tool_name "instance_tool"
        description "test"
        output_type :string
        def call = "ok"
      end
      instance = tool_class.new

      agent = TestAgent.new(model: model, tools: [instance])
      expect(agent.tools).to include(instance)
    end

    it "wraps agents as ManagedAgentTool" do
      sub_agent = TestAgent.new(model: model, name: "helper", description: "Helps")
      agent = TestAgent.new(model: model, agents: [sub_agent])
      tool_names = agent.tools.map { |t| t.class.tool_name }
      expect(tool_names).to include("helper")
    end
  end

  describe "#validate_final_answer" do
    it "passes with no checks" do
      agent = TestAgent.new(model: model)
      result = agent.send(:validate_final_answer, "answer")
      expect(result).to be_nil
    end

    it "passes when all checks return true" do
      checks = [
        ->(answer, _memory) { answer.length > 3 },
        ->(answer, _memory) { answer.include?("ok") }
      ]
      agent = TestAgent.new(model: model, final_answer_checks: checks)
      allow(model).to receive(:generate).and_return(simple_response)
      agent.run("test") # initialize memory
      result = agent.send(:validate_final_answer, "this is ok")
      expect(result).to be_nil
    end

    it "rejects when a check returns false" do
      checks = [->(answer, _memory) { answer.length > 100 }]
      agent = TestAgent.new(model: model, final_answer_checks: checks)
      allow(model).to receive(:generate).and_return(simple_response)
      agent.run("test")
      result = agent.send(:validate_final_answer, "short")
      expect(result).to include("rejected by check #1")
    end
  end

  describe "#validate_output_type" do
    it "passes with no output_type" do
      agent = TestAgent.new(model: model)
      expect(agent.send(:validate_output_type, "anything")).to be_nil
    end

    it "validates with a Proc" do
      agent = TestAgent.new(model: model, output_type: ->(answer) { answer.is_a?(String) })
      expect(agent.send(:validate_output_type, "ok")).to be_nil
      expect(agent.send(:validate_output_type, 42)).to include("validation failed")
    end

    it "validates with a JSON Schema" do
      schema = {
        "type" => "object",
        "required" => ["name"],
        "properties" => { "name" => { "type" => "string" } }
      }
      agent = TestAgent.new(model: model, output_type: schema)
      expect(agent.send(:validate_output_type, { "name" => "Alice" })).to be_nil
      expect(agent.send(:validate_output_type, { "age" => 30 })).to include("validation failed")
    end
  end

  describe "#maybe_plan" do
    it "does nothing when planning_interval is nil" do
      agent = TestAgent.new(model: model, planning_interval: nil)
      expect(agent).not_to receive(:run_planning_step)
      agent.send(:maybe_plan, 1)
    end

    it "does nothing when planning_interval is 0" do
      agent = TestAgent.new(model: model, planning_interval: 0)
      expect(agent).not_to receive(:run_planning_step)
      agent.send(:maybe_plan, 1)
    end

    it "plans on step 1 as initial" do
      agent = TestAgent.new(model: model, planning_interval: 3)
      expect(agent).to receive(:run_planning_step).with(initial: true)
      agent.send(:maybe_plan, 1)
    end

    it "plans on step interval+1" do
      agent = TestAgent.new(model: model, planning_interval: 3)
      expect(agent).to receive(:run_planning_step).with(initial: false)
      agent.send(:maybe_plan, 4)
    end

    it "does not plan on non-interval steps" do
      agent = TestAgent.new(model: model, planning_interval: 3)
      expect(agent).not_to receive(:run_planning_step)
      agent.send(:maybe_plan, 2)
      agent.send(:maybe_plan, 3)
      agent.send(:maybe_plan, 5)
    end
  end

  describe "callbacks" do
    it "notifies callbacks that respond to the event" do
      callback = double("callback")
      allow(callback).to receive(:respond_to?).with(:on_run_start).and_return(true)
      allow(callback).to receive(:on_run_start)
      allow(callback).to receive(:respond_to?).with(:on_step_start).and_return(false)
      allow(callback).to receive(:respond_to?).with(:on_step_end).and_return(false)
      allow(callback).to receive(:respond_to?).with(:on_run_end).and_return(false)
      allow(callback).to receive(:respond_to?).with(:on_error).and_return(false)

      allow(model).to receive(:generate).and_return(simple_response)

      agent = TestAgent.new(model: model, callbacks: [callback], max_steps: 1)
      agent.run("test")

      expect(callback).to have_received(:on_run_start).with(task: "test", agent: agent)
    end

    it "skips callbacks that do not respond to the event" do
      callback = double("callback")
      allow(callback).to receive(:respond_to?).and_return(false)

      allow(model).to receive(:generate).and_return(simple_response)

      agent = TestAgent.new(model: model, callbacks: [callback], max_steps: 1)
      expect { agent.run("test") }.not_to raise_error
    end
  end

  describe "#reset!" do
    it "clears agent state" do
      allow(model).to receive(:generate).and_return(simple_response)

      agent = TestAgent.new(model: model, max_steps: 1)
      agent.run("test")
      expect(agent.memory).not_to be_nil

      agent.reset!
      expect(agent.memory).to be_nil
      expect(agent.done?).to be false
      expect(agent.final_answer_value).to be_nil
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubyagent::Callback do
  it "has no-op methods for all events" do
    cb = described_class.new
    agent = double("agent")

    expect(cb.on_run_start(task: "hello", agent: agent)).to be_nil
    expect(cb.on_step_start(step_number: 1, agent: agent)).to be_nil
    expect(cb.on_step_end(step: double, agent: agent)).to be_nil
    expect(cb.on_tool_call(tool_name: "echo", arguments: {}, agent: agent)).to be_nil
    expect(cb.on_error(error: RuntimeError.new, agent: agent)).to be_nil
    expect(cb.on_run_end(result: "done", agent: agent)).to be_nil
  end

  describe "Agent callback integration" do
    let(:model) do
      instance_double(Rubyagent::Model).tap do |m|
        allow(m).to receive(:generate).and_return(
          Rubyagent::ChatMessage.new(
            role: "assistant",
            content: "Thought: done\nCode:\n```ruby\nfinal_answer(\"42\")\n```",
            token_usage: Rubyagent::TokenUsage.new(input_tokens: 10, output_tokens: 5)
          )
        )
      end
    end

    it "fires on_run_start and on_run_end during a run" do
      events = []
      cb = Rubyagent::Callback.new
      allow(cb).to receive(:on_run_start) { |**kw| events << [:run_start, kw[:task]] }
      allow(cb).to receive(:on_run_end) { |**kw| events << [:run_end] }
      allow(cb).to receive(:on_step_start) { |**kw| events << [:step_start, kw[:step_number]] }
      allow(cb).to receive(:on_step_end) { |**kw| events << [:step_end] }

      agent = Rubyagent::CodeAgent.new(model: model, callbacks: [cb])
      agent.run("test task")

      expect(events).to include([:run_start, "test task"])
      expect(events).to include([:run_end])
      expect(events).to include([:step_start, 1])
      expect(events).to include([:step_end])
    end

    it "fires on_tool_call in ToolCallingAgent" do
      tool_calls_seen = []
      cb = Rubyagent::Callback.new
      allow(cb).to receive(:on_tool_call) do |**kw|
        tool_calls_seen << kw[:tool_name]
      end
      # Allow other callbacks without tracking
      allow(cb).to receive(:on_run_start)
      allow(cb).to receive(:on_run_end)
      allow(cb).to receive(:on_step_start)
      allow(cb).to receive(:on_step_end)

      tc_model = instance_double(Rubyagent::Model)
      allow(tc_model).to receive(:generate).and_return(
        Rubyagent::ChatMessage.new(
          role: "assistant",
          content: "Let me answer",
          tool_calls: [
            Rubyagent::ToolCall.new(
              id: "call_1",
              function: Rubyagent::ToolCallFunction.new(name: "final_answer", arguments: { "answer" => "42" })
            )
          ],
          token_usage: Rubyagent::TokenUsage.new(input_tokens: 10, output_tokens: 5)
        )
      )

      agent = Rubyagent::ToolCallingAgent.new(model: tc_model, callbacks: [cb])
      agent.run("test")

      expect(tool_calls_seen).to eq(["final_answer"])
    end
  end
end

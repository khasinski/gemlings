# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gemlings::Model do
  describe ".for" do
    it "resolves provider-prefixed model names via RubyLLM" do
      model = described_class.for("anthropic/claude-sonnet-4-5")
      expect(model).to be_a(Gemlings::Models::RubyLLMAdapter)
      expect(model.model_name).to eq("claude-sonnet-4-5")
      expect(model.provider).to eq(:anthropic)
    end

    it "resolves bare model names via RubyLLM" do
      model = described_class.for("gpt-4o")
      expect(model).to be_a(Gemlings::Models::RubyLLMAdapter)
      expect(model.model_name).to eq("gpt-4o")
      expect(model.provider).to be_nil
    end

    it "prefers registered custom adapters over RubyLLM" do
      klass = Class.new(described_class)
      described_class.register("custom", klass)
      model = described_class.for("custom/my-model")
      expect(model).to be_a(klass)
      expect(model.model_name).to eq("my-model")
    ensure
      described_class.registry.delete("custom")
    end
  end

  describe ".register" do
    it "registers a new provider" do
      klass = Class.new(described_class)
      described_class.register("test_provider", klass)
      expect(described_class.registry["test_provider"]).to eq(klass)
    ensure
      described_class.registry.delete("test_provider")
    end
  end
end

RSpec.describe Gemlings::TokenUsage do
  describe "arithmetic" do
    it "adds two usages" do
      a = described_class.new(input_tokens: 100, output_tokens: 50)
      b = described_class.new(input_tokens: 200, output_tokens: 100)
      sum = a + b
      expect(sum.input_tokens).to eq(300)
      expect(sum.output_tokens).to eq(150)
      expect(sum.total_tokens).to eq(450)
    end

    it "formats as string" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)
      expect(usage.to_s).to eq("150 tokens (100 in / 50 out)")
    end
  end
end

RSpec.describe Gemlings::ChatMessage do
  it "creates with defaults" do
    msg = described_class.new(role: "assistant", content: "hello")
    expect(msg.token_usage).to be_nil
    expect(msg.tool_calls).to be_nil
  end

  it "stores tool_calls" do
    tc = [Gemlings::ToolCall.new(id: "1", function: Gemlings::ToolCallFunction.new(name: "f", arguments: {}))]
    msg = described_class.new(role: "assistant", content: "hi", tool_calls: tc)
    expect(msg.tool_calls.size).to eq(1)
    expect(msg.tool_calls.first.function.name).to eq("f")
  end
end

RSpec.describe Gemlings::RunResult do
  it "creates with defaults" do
    result = described_class.new(output: "done", state: "success")
    expect(result.success?).to be true
    expect(result.steps).to eq([])
    expect(result.token_usage).to be_nil
    expect(result.timing).to be_nil
  end

  it "reports non-success states" do
    result = described_class.new(output: nil, state: "max_steps")
    expect(result.success?).to be false
  end
end

RSpec.describe Gemlings::ToolCall do
  it "stores function details" do
    tc = described_class.new(
      id: "call_123",
      function: Gemlings::ToolCallFunction.new(name: "search", arguments: { query: "test" })
    )
    expect(tc.id).to eq("call_123")
    expect(tc.function.name).to eq("search")
    expect(tc.function.arguments).to eq({ query: "test" })
  end
end

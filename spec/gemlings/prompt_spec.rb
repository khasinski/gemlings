# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gemlings::Prompt do
  let(:tool) do
    Class.new(Gemlings::Tool) do
      tool_name "test_tool"
      description "A test tool"
      input :name, type: :string, description: "A name"
      output_type :string

      def call(name:) = name
    end.new
  end

  describe ".code_agent_system" do
    it "substitutes tool descriptions into the template" do
      result = described_class.code_agent_system(tools: [tool])
      expect(result).to include("test_tool")
      expect(result).to include("A test tool")
      expect(result).to include("expert Ruby programmer")
    end

    it "includes all tools" do
      tool2 = Class.new(Gemlings::Tool) do
        tool_name "other_tool"
        description "Another tool"
        output_type :string
        def call = "ok"
      end.new

      result = described_class.code_agent_system(tools: [tool, tool2])
      expect(result).to include("test_tool")
      expect(result).to include("other_tool")
    end
  end

  describe ".tool_calling_agent_system" do
    it "substitutes tool descriptions into the template" do
      result = described_class.tool_calling_agent_system(tools: [tool])
      expect(result).to include("test_tool")
      expect(result).to include("expert problem solver")
    end
  end

  describe ".initial_plan" do
    it "returns the planning prompt" do
      expect(described_class.initial_plan).to include("step-by-step plan")
    end
  end

  describe ".update_plan" do
    it "substitutes progress summary" do
      result = described_class.update_plan(progress_summary: "Step 1 done")
      expect(result).to include("Step 1 done")
      expect(result).to include("remaining work")
    end
  end
end

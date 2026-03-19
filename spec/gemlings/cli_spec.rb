# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gemlings::CLI do
  describe "option parsing" do
    it "uses default options with no args" do
      cli = described_class.new([])
      options = cli.instance_variable_get(:@options)
      expect(options[:model]).to eq("openai/gpt-5.2")
      expect(options[:tools]).to eq([])
      expect(options[:agent_type]).to eq("code")
      expect(options[:max_steps]).to eq(10)
      expect(options[:interactive]).to be false
    end

    it "parses --model" do
      cli = described_class.new(["-m", "ollama/qwen3:4b", "test"])
      expect(cli.instance_variable_get(:@options)[:model]).to eq("ollama/qwen3:4b")
    end

    it "parses --tools" do
      cli = described_class.new(["-t", "web_search,file_read", "test"])
      expect(cli.instance_variable_get(:@options)[:tools]).to eq(["web_search", "file_read"])
    end

    it "parses --agent-type" do
      cli = described_class.new(["-a", "tool_calling", "test"])
      expect(cli.instance_variable_get(:@options)[:agent_type]).to eq("tool_calling")
    end

    it "parses --plan" do
      cli = described_class.new(["-p", "3", "test"])
      expect(cli.instance_variable_get(:@options)[:planning_interval]).to eq(3)
    end

    it "parses --max-steps" do
      cli = described_class.new(["-s", "5", "test"])
      expect(cli.instance_variable_get(:@options)[:max_steps]).to eq(5)
    end

    it "parses --interactive" do
      cli = described_class.new(["-i"])
      expect(cli.instance_variable_get(:@options)[:interactive]).to be true
    end

    it "accumulates --mcp options" do
      cli = described_class.new(["--mcp", "cmd1", "--mcp", "cmd2", "test"])
      expect(cli.instance_variable_get(:@options)[:mcp]).to eq(["cmd1", "cmd2"])
    end

    it "captures the query from remaining args" do
      cli = described_class.new(["What", "is", "2+2?"])
      expect(cli.instance_variable_get(:@query)).to eq("What is 2+2?")
    end
  end

  describe "#run" do
    it "prints help with no query and no interactive flag" do
      cli = described_class.new([])
      expect { cli.run }.to output(/Usage:/).to_stdout
    end

    it "prints version with -v" do
      expect { described_class.new(["-v"]) }.to raise_error(SystemExit)
    end
  end

  describe "TOOL_MAP" do
    it "contains expected tools" do
      expect(described_class::TOOL_MAP.keys).to include("web_search", "visit_webpage", "file_read", "file_write", "user_input")
    end
  end
end

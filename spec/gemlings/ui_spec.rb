# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gemlings::UI do
  # Bypass global UI stubs for these tests
  before do
    allow(Gemlings::UI).to receive(:thought).and_call_original
    allow(Gemlings::UI).to receive(:code).and_call_original
    allow(Gemlings::UI).to receive(:observation).and_call_original
    allow(Gemlings::UI).to receive(:error).and_call_original
    allow(Gemlings::UI).to receive(:plan).and_call_original
    allow(Gemlings::UI).to receive(:step_metrics).and_call_original
    allow(Gemlings::UI).to receive(:run_summary).and_call_original
    allow(Gemlings::UI).to receive(:final_answer).and_call_original
    allow(Gemlings::UI).to receive(:welcome).and_call_original
    allow(Gemlings::UI).to receive(:spinner).and_call_original
  end

  describe ".thought" do
    it "outputs thought text" do
      expect { described_class.thought("I need to think") }.to output(/I need to think/).to_stdout
    end
  end

  describe ".code" do
    it "outputs syntax-highlighted code" do
      expect { described_class.code("puts 'hello'") }.to output(/puts/).to_stdout
    end
  end

  describe ".observation" do
    it "outputs result text" do
      expect { described_class.observation("42") }.to output(/42/).to_stdout
    end

    it "truncates long text" do
      long = "x" * 300
      expect { described_class.observation(long) }.to output(/truncated/).to_stdout
    end
  end

  describe ".error" do
    it "outputs error text" do
      expect { described_class.error("something broke") }.to output(/something broke/).to_stdout
    end
  end

  describe ".plan" do
    it "outputs plan text" do
      expect { described_class.plan("1. Do stuff") }.to output(/Do stuff/).to_stdout
    end
  end

  describe ".step_metrics" do
    it "outputs duration and token usage" do
      usage = Gemlings::TokenUsage.new(input_tokens: 10, output_tokens: 20)
      expect { described_class.step_metrics(duration: 1.5, token_usage: usage) }.to output(/1\.5s/).to_stdout
    end

    it "outputs token info even when zero" do
      usage = Gemlings::TokenUsage.new(input_tokens: 0, output_tokens: 0)
      expect { described_class.step_metrics(duration: 0, token_usage: usage) }.to output(/0 tokens/).to_stdout
    end
  end

  describe ".run_summary" do
    it "outputs step count and duration" do
      usage = Gemlings::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect { described_class.run_summary(total_steps: 3, total_duration: 5.2, total_tokens: usage) }
        .to output(/3 steps.*5\.2s/).to_stdout
    end

    it "uses singular 'step' for 1 step" do
      usage = Gemlings::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      expect { described_class.run_summary(total_steps: 1, total_duration: 1.0, total_tokens: usage) }
        .to output(/1 step[^s]/).to_stdout
    end
  end

  describe ".final_answer" do
    it "outputs the answer" do
      expect { described_class.final_answer("hello world") }.to output(/hello world/).to_stdout
    end
  end

  describe ".welcome" do
    it "outputs version" do
      expect { described_class.welcome }.to output(/gemlings.*v#{Gemlings::VERSION}/).to_stdout
    end
  end

  describe ".spinner" do
    it "returns a Spinner instance" do
      spinner = described_class.spinner("Loading...")
      expect(spinner).to be_a(Gemlings::UI::Spinner)
    end
  end

  describe ".status" do
    it "returns a StatusLine instance" do
      status = described_class.status("Working...")
      expect(status).to be_a(Gemlings::UI::StatusLine)
    end
  end

  describe Gemlings::UI::NullStyle do
    it "returns text unchanged" do
      style = described_class.new
      expect(style.render("hello")).to eq("hello")
    end
  end

  describe Gemlings::UI::Spinner do
    it "starts and stops a thread" do
      spinner = described_class.new("Testing...")
      spinner.start
      sleep 0.1
      expect(spinner.instance_variable_get(:@running)).to be true
      spinner.stop
      expect(spinner.instance_variable_get(:@thread)).not_to be_alive
    end
  end

  describe Gemlings::UI::StatusLine do
    it "resolves with success" do
      status = described_class.new("Running...")
      status.start
      expect { status.success!("done") }.to output(/Result:.*done/).to_stdout
    end

    it "resolves with error" do
      status = described_class.new("Running...")
      status.start
      expect { status.error!("boom") }.to output(/Error:.*boom/).to_stdout
    end

    it "truncates long success text" do
      status = described_class.new("Running...")
      status.start
      expect { status.success!("x" * 300) }.to output(/truncated/).to_stdout
    end
  end
end

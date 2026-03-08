# frozen_string_literal: true

require "bundler/setup"
require "rubyagent"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # Suppress UI output during tests
  config.before do
    allow(Rubyagent::UI).to receive(:welcome)
    allow(Rubyagent::UI).to receive(:thought)
    allow(Rubyagent::UI).to receive(:code)
    allow(Rubyagent::UI).to receive(:observation)
    allow(Rubyagent::UI).to receive(:error)
    allow(Rubyagent::UI).to receive(:plan)
    allow(Rubyagent::UI).to receive(:step_metrics)
    allow(Rubyagent::UI).to receive(:run_summary)
    allow(Rubyagent::UI).to receive(:final_answer)
    allow(Rubyagent::UI).to receive(:spinner).and_return(
      instance_double(Rubyagent::UI::Spinner, start: nil, stop: nil)
    )
  end
end

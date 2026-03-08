#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/rubyagent"
require_relative "../lib/rubyagent/tools/web_search"

agent = Rubyagent::CodeAgent.new(
  model: "anthropic/claude-sonnet-4-20250514",
  tools: [Rubyagent::WebSearch]
)

agent.run("What year was Ruby created and who created it?")

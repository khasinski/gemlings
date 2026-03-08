#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/gemlings"
require_relative "../lib/gemlings/tools/web_search"

agent = Gemlings::CodeAgent.new(
  model: "anthropic/claude-sonnet-4-20250514",
  tools: [Gemlings::WebSearch]
)

agent.run("What year was Ruby created and who created it?")

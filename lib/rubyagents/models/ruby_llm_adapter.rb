# frozen_string_literal: true

module Rubyagents
  module Models
    class RubyLLMAdapter < Model
      attr_reader :provider

      def initialize(model_name, provider: nil)
        super(model_name)
        @provider = provider&.to_sym
      end

      def generate(messages, tools: nil, &on_stream)
        require "ruby_llm"

        chat = build_chat
        load_messages(chat, messages)
        load_tools(chat, tools) if tools&.any?

        response = if on_stream
          chat.complete { |chunk| on_stream.call(chunk.content) if chunk.content }
        else
          chat.complete
        end

        extract_response(chat, response)
      end

      private

      def build_chat
        RubyLLM::Chat.new(model: model_name, provider: @provider)
      end

      def load_messages(chat, messages)
        messages.each do |msg|
          role = msg[:role]
          content = msg[:content]

          case role
          when "system"
            chat.with_instructions(content)
          when "assistant"
            attrs = { role: :assistant, content: content }
            if msg[:tool_calls]
              attrs[:tool_calls] = convert_tool_calls_to_ruby_llm(msg[:tool_calls])
            end
            chat.add_message(attrs)
          else
            chat.add_message(role: role.to_sym, content: content || "")
          end
        end
      end

      def load_tools(chat, tool_schemas)
        tool_schemas.each { |schema| chat.with_tool(build_stub_tool(schema)) }
      end

      def build_stub_tool(schema)
        tool_name = schema[:name]
        tool_desc = schema[:description]
        params = schema[:parameters] || {}
        properties = params[:properties] || params["properties"] || {}
        required_list = (params[:required] || params["required"] || []).map(&:to_s)

        klass = Class.new(RubyLLM::Tool) do
          description tool_desc

          properties.each do |pname, pschema|
            ptype = (pschema[:type] || pschema["type"] || "string").to_s
            pdesc = pschema[:description] || pschema["description"]
            is_req = required_list.include?(pname.to_s)
            param pname.to_sym, type: ptype, desc: pdesc, required: is_req
          end

          define_method(:execute) { |**_kwargs| halt("tool_called") }
        end

        instance = klass.new
        instance.define_singleton_method(:name) { tool_name }
        instance
      end

      def extract_response(chat, response)
        if defined?(RubyLLM::Tool::Halt) && response.is_a?(RubyLLM::Tool::Halt)
          # Tool calls halted the loop; find the assistant message with tool_calls
          message = chat.messages.reverse.find { |m| m.role == :assistant && m.tool_call? }
          build_chat_message(message)
        else
          build_chat_message(response)
        end
      end

      def build_chat_message(message)
        ChatMessage.new(
          role: "assistant",
          content: message.content,
          token_usage: extract_token_usage(message),
          tool_calls: extract_tool_calls(message)
        )
      end

      def extract_token_usage(message)
        input = message.input_tokens
        output = message.output_tokens
        return nil unless input || output
        TokenUsage.new(input_tokens: input || 0, output_tokens: output || 0)
      end

      def extract_tool_calls(message)
        return nil unless message.tool_call?

        message.tool_calls.map do |_id, tc|
          ToolCall.new(
            id: tc.id,
            function: ToolCallFunction.new(name: tc.name, arguments: tc.arguments || {})
          )
        end
      end

      def convert_tool_calls_to_ruby_llm(tool_calls)
        return nil unless tool_calls&.any?

        tool_calls.each_with_object({}) do |tc, hash|
          hash[tc.id] = RubyLLM::ToolCall.new(
            id: tc.id,
            name: tc.function.name,
            arguments: tc.function.arguments || {}
          )
        end
      end
    end
  end
end

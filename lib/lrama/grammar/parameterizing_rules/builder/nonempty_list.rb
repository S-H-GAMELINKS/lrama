module Lrama
  class Grammar
    class ParameterizingRules
      class Builder
        class NonemptyList
          EXPECTED_ARGUMENT_NUM = 1

          def initialize(token, rule_counter, lhs, user_code, precedence_sym, line)
            @args = token.args
            @token = @args.first
            @rule_counter = rule_counter
            @lhs = lhs
            @user_code = user_code
            @precedence_sym = precedence_sym
            @line = line
          end

          def build
            validate_argument_number!

            rules = []
            nonempty_list_token = Lrama::Lexer::Token::Ident.new(s_value: "nonempty_list_#{@token.s_value}")
            rules << Rule.new(id: @rule_counter.increment, lhs: @lhs, rhs: [nonempty_list_token], token_code: @user_code, precedence_sym: @precedence_sym, lineno: @line)
            rules << Rule.new(id: @rule_counter.increment, lhs: nonempty_list_token, rhs: [@token], token_code: @user_code, precedence_sym: @precedence_sym, lineno: @line)
            rules << Rule.new(id: @rule_counter.increment, lhs: nonempty_list_token, rhs: [nonempty_list_token, @token], token_code: @user_code, precedence_sym: @precedence_sym, lineno: @line)
            rules
          end

          private

          def validate_argument_number!
            unless @args.count == EXPECTED_ARGUMENT_NUM
              raise "Invalid number of arguments. expect: #{EXPECTED_ARGUMENT_NUM} actual: #{@args.count}"
            end
          end
        end
      end
    end
  end
end

module Lrama
  class StatesReporter
    def initialize(states)
      @states = states
    end

    def report(io, grammar: false, states: false, itemsets: false, lookaheads: false, solved: false, verbose: false)
      # TODO: Unused terms
      # TODO: Unused rules

      # Report Conflict
      has_conflict = false

      @states.states.each do |state|
        messages = []
        cs = state.conflicts.group_by(&:type)
        if cs[:shift_reduce]
          messages << "#{cs[:shift_reduce].count} shift/reduce"
        end

        if cs[:reduce_reduce]
          messages << "#{cs[:reduce_reduce].count} reduce/reduce"
        end

        if !messages.empty?
          has_conflict = true
          io << "State #{state.id} conflicts: #{messages.join(', ')}\n"
        end
      end

      if has_conflict
        io << "\n\n"
      end

      # Report Grammar
      if grammar
        io << "Grammar\n"
        last_lhs = nil

        @states.rules.each do |rule|
          if rule.rhs.empty?
            r = "ε"
          else
            r = rule.rhs.map(&:display_name).join(" ")
          end

          if rule.lhs == last_lhs
            io << sprintf("%5d %s| %s\n", rule.id, " " * rule.lhs.display_name.length, r)
          else
            io << "\n"
            io << sprintf("%5d %s: %s\n", rule.id, rule.lhs.display_name, r)
          end

          last_lhs = rule.lhs
        end
        io << "\n\n"
      end

      @states.states.each do |state|
        # Report State
        io << "State #{state.id}\n\n"

        # Report item
        last_lhs = nil
        list = itemsets ? state.items : state.kernels
        list.sort_by {|i| [i.rule_id, i.position] }.each do |item|
          rule = item.rule
          position = item.position
          if rule.rhs.empty?
            r = "ε •"
          else
            r = rule.rhs.map(&:display_name).insert(position, "•").join(" ")
          end
          if rule.lhs == last_lhs
            l = " " * rule.lhs.id.s_value.length + "|"
          else
            l = rule.lhs.id.s_value + ":"
          end
          la = ""
          if lookaheads && item.end_of_rule?
            reduce = state.find_reduce_by_item!(item)
            look_ahead = reduce.selected_look_ahead
            if !look_ahead.empty?
              la = "  [#{look_ahead.map(&:display_name).join(", ")}]"
            end
          end
          last_lhs = rule.lhs

          io << sprintf("%5i %s %s%s\n", rule.id, l, r, la)
        end
        io << "\n"


        # Report shifts
        tmp = state.term_transitions.select do |shift, _|
          !shift.not_selected
        end.map do |shift, next_state|
          [shift.next_sym, next_state.id]
        end
        max_len = tmp.map(&:first).map(&:display_name).map(&:length).max
        tmp.each do |term, state_id|
          io << "    #{term.display_name.ljust(max_len)}  shift, and go to state #{state_id}\n"
        end
        io << "\n" if !tmp.empty?


        # Report error caused by %nonassoc
        nl = false
        tmp = state.resolved_conflicts.select do |resolved|
          resolved.which == :error
        end.map do |error|
          error.symbol.display_name
        end
        max_len = tmp.map(&:length).max
        tmp.each do |name|
          nl = true
          io << "    #{name.ljust(max_len)}  error (nonassociative)\n"
        end
        io << "\n" if !tmp.empty?


        # Report reduces
        nl = false
        max_len = state.non_default_reduces.flat_map(&:look_ahead).compact.map(&:display_name).map(&:length).max || 0
        max_len = [max_len, "$default".length].max if state.default_reduction_rule
        @states.terms.each do |term|
          reduce = state.non_default_reduces.find do |r|
            r.look_ahead.include?(term)
          end

          next unless reduce

          rule = reduce.item.rule
          io << "    #{term.display_name.ljust(max_len)}  reduce using rule #{rule.id} (#{rule.lhs.display_name})\n"
          nl = true
        end
        if r = state.default_reduction_rule
          nl = true
          s = "$default".ljust(max_len)

          if r.initial_rule?
            io << "    #{s}  accept\n"
          else
            io << "    #{s}  reduce using rule #{r.id} (#{r.lhs.display_name})\n"
          end
        end
        io << "\n" if nl


        # Report nonterminal transitions
        tmp = []
        max_len = 0
        state.nterm_transitions.each do |shift, next_state|
          nterm = shift.next_sym
          tmp << [nterm, next_state.id]
          max_len = [max_len, nterm.id.s_value.length].max
        end
        tmp.uniq!
        tmp.sort_by! do |nterm, state_id|
          nterm.number
        end
        tmp.each do |nterm, state_id|
          io << "    #{nterm.id.s_value.ljust(max_len)}  go to state #{state_id}\n"
        end
        io << "\n" if !tmp.empty?


        if solved
          # Report conflict resolutions
          state.resolved_conflicts.each do |resolved|
            io << "    #{resolved.report_message}\n"
          end
          io << "\n" if !state.resolved_conflicts.empty?
        end


        if verbose
          # Report direct_read_sets
          io << "  [Direct Read sets]\n"
          direct_read_sets = @states.direct_read_sets
          @states.nterms.each do |nterm|
            terms = direct_read_sets[[state.id, nterm.token_id]]
            next if !terms
            next if terms.empty?

            str = terms.map {|sym| sym.id.s_value }.join(", ")
            io << "    read #{nterm.id.s_value}  shift #{str}\n"
          end
          io << "\n"


          # Reprot reads_relation
          io << "  [Reads Relation]\n"
          @states.nterms.each do |nterm|
            a = @states.reads_relation[[state.id, nterm.token_id]]
            next if !a

            a.each do |state_id2, nterm_id2|
              n = @states.nterms.find {|n| n.token_id == nterm_id2 }
              io << "    (State #{state_id2}, #{n.id.s_value})\n"
            end
          end
          io << "\n"


          # Reprot read_sets
          io << "  [Read sets]\n"
          read_sets = @states.read_sets
          @states.nterms.each do |nterm|
            terms = read_sets[[state.id, nterm.token_id]]
            next if !terms
            next if terms.empty?

            terms.each do |sym|
              io << "    #{sym.id.s_value}\n"
            end
          end
          io << "\n"


          # Reprot includes_relation
          io << "  [Includes Relation]\n"
          @states.nterms.each do |nterm|
            a = @states.includes_relation[[state.id, nterm.token_id]]
            next if !a

            a.each do |state_id2, nterm_id2|
              n = @states.nterms.find {|n| n.token_id == nterm_id2 }
              io << "    (State #{state.id}, #{nterm.id.s_value}) -> (State #{state_id2}, #{n.id.s_value})\n"
            end
          end
          io << "\n"


          # Report lookback_relation
          io << "  [Lookback Relation]\n"
          @states.rules.each do |rule|
            a = @states.lookback_relation[[state.id, rule.id]]
            next if !a

            a.each do |state_id2, nterm_id2|
              n = @states.nterms.find {|n| n.token_id == nterm_id2 }
              io << "    (Rule: #{rule.to_s}) -> (State #{state_id2}, #{n.id.s_value})\n"
            end
          end
          io << "\n"


          # Reprot follow_sets
          io << "  [Follow sets]\n"
          follow_sets = @states.follow_sets
          @states.nterms.each do |nterm|
            terms = follow_sets[[state.id, nterm.token_id]]

            next if !terms

            terms.each do |sym|
              io << "    #{nterm.id.s_value} -> #{sym.id.s_value}\n"
            end
          end
          io << "\n"


          # Report LA
          io << "  [Look-Ahead Sets]\n"
          tmp = []
          max_len = 0
          @states.rules.each do |rule|
            syms = @states.la[[state.id, rule.id]]
            next if !syms

            tmp << [rule, syms]
            max_len = ([max_len] + syms.map {|s| s.id.s_value.length }).max
          end
          tmp.each do |rule, syms|
            syms.each do |sym|
              io << "    #{sym.id.s_value.ljust(max_len)}  reduce using rule #{rule.id} (#{rule.lhs.id.s_value})\n"
            end
          end
          io << "\n" if !tmp.empty?
        end


        # End of Report State
        io << "\n"
      end
    end
  end
end

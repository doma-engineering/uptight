defmodule Uptight.ParseStackTraceTest do
  use ExUnit.Case, async: true

  # alias Uptight.Result

  describe("encoding stacktrace") do
    setup do
      %{
        trace: %Uptight.Trace{
          exception: %MatchError{term: 0},
          stacktrace: [
            {:erl_eval, :expr, 5, [file: 'erl_eval.erl', line: 450]},
            {Uptight.Result, :new, 1, [file: 'lib/uptight/result.ex', line: 42]},
            {:erl_eval, :do_apply, 6, [file: 'erl_eval.erl', line: 685]},
            {:erl_eval, :expr, 5, [file: 'erl_eval.erl', line: 446]},
            {:elixir, :recur_eval, 3, [file: 'src/elixir.erl', line: 296]},
            {:elixir, :eval_forms, 3, [file: 'src/elixir.erl', line: 274]},
            {IEx.Evaluator, :handle_eval, 3, [file: 'lib/iex/evaluator.ex', line: 310]},
            {IEx.Evaluator, :do_eval, 3, [file: 'lib/iex/evaluator.ex', line: 285]}
          ]
        }
      }
    end

    test "encode trace", %{trace: trace} do
      encoded = Jason.encode!(trace)

      Enum.map(trace.stacktrace, fn entry ->
        file = to_string(elem(entry, 3)[:file])

        assert String.contains?(encoded, file),
               "don't find file: #{file} \nfrom entry #{inspect(entry)}\nencode result:#{inspect(encoded)}"
      end)
    end
  end
end

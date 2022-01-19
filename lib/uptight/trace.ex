defmodule Uptight.Trace do
  @moduledoc """
  Defdata for exception along with stacktrace.
  """
  import Algae

  @type entry :: {atom(), atom(), non_neg_integer(), keyword()}

  defdata do
    exception :: any()
    stacktrace :: list(entry())
  end
end

require Protocol
# TODO: Implement encoder for both exceptions and stacktraces!
# This way we won't lose data and will be able to make a fuzzy printer for errors some day :)
Protocol.derive(Jason.Encoder, Uptight.Trace, only: [:exception])
Protocol.derive(Jason.Encoder, MatchError)
Protocol.derive(Jason.Encoder, ArgumentError)
Protocol.derive(Jason.Encoder, FunctionClauseError)
Protocol.derive(Jason.Encoder, UndefinedFunctionError)
Protocol.derive(Jason.Encoder, BadMapError)

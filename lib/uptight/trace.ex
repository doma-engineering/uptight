defmodule Uptight.Trace do
  @moduledoc """
  Defdata for exception along with stacktrace.
  """
  import Algae

  defdata do
    exception :: any()
    stacktrace :: list(Exception.stacktrace_entry())
  end

  def location_to_map(file: f, line: l) do
    %{file: to_string(f), line: l}
  end

  def location_to_map(_) do
    %{unknown: true}
  end

  def arity_or_args_to_int(xs) when is_list(xs) do
    length(xs)
  end

  def arity_or_args_to_int(x) when is_integer(x) do
    x
  end

  def arity_or_args_to_int(_) do
    -1
  end

  def stacktrace_entry_to_map({m, f, a, l}) when is_atom(m) and is_atom(f) do
    %{
      module: m,
      function: f,
      arity: arity_or_args_to_int(a),
      location: location_to_map(l)
    }
  end

  def stacktrace_entry_to_map({m, _, a, l}) when is_atom(m) do
    stacktrace_entry_to_map({m, :anonymous, a, l})
  end

  def stacktrace_entry_to_map({_, f, a, l}) when is_atom(f) do
    stacktrace_entry_to_map({Unknown, f, a, l})
  end

  def stacktrace_entry_to_map({_, _, a, l}) do
    stacktrace_entry_to_map({Unknown, :anonymous, a, l})
  end

  def stacktrace_entry_to_map({_, a, l}) do
    stacktrace_entry_to_map({Unknown, :anonymous, a, l})
  end

  def stacktrace_to_map(stacktrace) do
    Enum.map(stacktrace, fn entry ->
      stacktrace_entry_to_map(entry)
    end)
  end
end

require Protocol
Protocol.derive(Jason.Encoder, MatchError)
Protocol.derive(Jason.Encoder, ArgumentError)
Protocol.derive(Jason.Encoder, FunctionClauseError)
Protocol.derive(Jason.Encoder, UndefinedFunctionError)
Protocol.derive(Jason.Encoder, BadMapError)

defimpl Jason.Encoder, for: Uptight.Trace do
  def encode(%Uptight.Trace{exception: exception, stacktrace: stacktrace}, opts) do
    Jason.Encode.map(
      %{
        exception: exception,
        stacktrace: Uptight.Trace.stacktrace_to_map(stacktrace)
      },
      opts
    )
  end
end

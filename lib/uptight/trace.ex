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
    # TODO: Encode me :begging:
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

defimpl Jason.Encoder, for: Uptight.Trace do
  use Quark

  # credo:disable-for-lines:1000 /\.Complexity/
  def encode(%Uptight.Trace{exception: exception, stacktrace: stacktrace}, opts) do
    # Go through the keys of the exception struct and only keep those for which Jason.Encoder is implemented.

    # credo:disable-for-lines:1000 /\.Nesting/
    best_effort_encode = fn best_effort_encode ->
      fn
        chunk ->
          # Normalise tuples
          chunk =
            if is_tuple(chunk) do
              Tuple.to_list(chunk)
            else
              chunk
            end

          # Normalise structs
          chunk =
            case chunk do
              %{} ->
                if is_nil(Map.get(chunk, :__struct__)) do
                  chunk
                else
                  struct = chunk.__struct__
                  chunk |> Map.from_struct() |> Map.put(:__elixir_struct__, struct)
                end

              _ ->
                chunk
            end

          case chunk do
            [] ->
              []

            [_ | _] ->
              Enum.reduce(
                chunk,
                [],
                fn x, acc ->
                  x =
                    if is_tuple(x) do
                      Tuple.to_list(x)
                    else
                      x
                    end

                  case Jason.Encoder.impl_for(x) do
                    Jason.Encoder.Any ->
                      acc

                    _ ->
                      [best_effort_encode.(x) | acc]
                  end
                end
              )

            %{} ->
              Enum.reduce(
                Map.keys(chunk),
                %{},
                fn key, acc ->
                  val = Map.get(chunk, key)

                  val =
                    if is_tuple(val) do
                      Tuple.to_list(val)
                    else
                      val
                    end

                  case Jason.Encoder.impl_for(val) do
                    Jason.Encoder.Any ->
                      acc

                    _ ->
                      # IO.inspect("key: #{inspect(key)}")
                      Map.put(acc, key, best_effort_encode.(val))
                  end
                end
              )

            _ ->
              # IO.inspect(
              # "!!! PROCESSING LEAF: #{inspect(chunk)} !!! TYPE: #{Jason.Encoder.impl_for(chunk)} !!!"
              # )

              # Best effort, but on a safe side
              if Jason.Encoder.impl_for(chunk) in [
                   # Jason.Encoder.DateTime,
                   # Jason.Encoder.Decimal,
                   Jason.Encoder.Atom,
                   Jason.Encoder.BitString,
                   Jason.Encoder.Integer,
                   Jason.Encoder.Float
                 ] do
                chunk
              else
                nil
              end
          end
      end
    end

    Jason.Encode.map(
      %{
        exception:
          fix(best_effort_encode).(exception) |> Map.put(:__trace_for__, exception.__struct__),
        stacktrace: Uptight.Trace.stacktrace_to_map(stacktrace)
      },
      opts
    )
  end
end

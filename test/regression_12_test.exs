defmodule Uptight.Regression12Test do
  @moduledoc """
  Regression:

  iex(8)> Uptight.Result.new(fn -> Jason.encode!({}) end) |> Jason.encode
  {:error,
   %Protocol.UndefinedError{
     protocol: Jason.Encoder,
     value: %Protocol.UndefinedError{
       protocol: Jason.Encoder,
       value: {},
       description: "Jason.Encoder protocol must always be explicitly implemented"
     },
     description: "Jason.Encoder protocol must always be explicitly implemented.\n\nIf you own the struct, you can derive the implementation specifying which fields should be encoded to JSON:\n\n    @derive {Jason.Encoder, only: [....]}\n    defstruct ...\n\nIt is also possible to encode all fields, although this should be used carefully to avoid accidentally leaking private information when new fields are added:\n\n    @derive Jason.Encoder\n    defstruct ...\n\nFinally, if you don't own the struct you want to encode to JSON, you may use Protocol.derive/3 placed outside of any module:\n\n    Protocol.derive(Jason.Encoder, NameOfTheStruct, only: [...])\n    Protocol.derive(Jason.Encoder, NameOfTheStruct)\n"
   }}
  iex(9)> Uptight.Result.new(fn -> 1 / 0 end) |> Jason.encode
  {:error,
   %Protocol.UndefinedError{
     protocol: Jason.Encoder,
     value: %ArithmeticError{message: "bad argument in arithmetic expression"},
     description: "Jason.Encoder protocol must always be explicitly implemented.\n\nIf you own the struct, you can derive the implementation specifying which fields should be encoded to JSON:\n\n    @derive {Jason.Encoder, only: [....]}\n    defstruct ...\n\nIt is also possible to encode all fields, although this should be used carefully to avoid accidentally leaking private information when new fields are added:\n\n    @derive Jason.Encoder\n    defstruct ...\n\nFinally, if you don't own the struct you want to encode to JSON, you may use Protocol.derive/3 placed outside of any module:\n\n    Protocol.derive(Jason.Encoder, NameOfTheStruct, only: [...])\n    Protocol.derive(Jason.Encoder, NameOfTheStruct)\n"
   }}

  """

  use ExUnit.Case, async: true

  test "arithmetic and encoding errors don't crash" do
    assert (Jason.encode!(Uptight.Result.new(fn -> 1 / 0 end))
            |> Jason.decode!())["err"]["exception"]["__trace_for__"] == "Elixir.ArithmeticError"

    # Elaborate fail
    x = Uptight.Result.new(fn -> Jason.encode!({}) end)
    # IO.inspect(x)
    y = Jason.encode!(x)
    # IO.inspect(y)
    w = Jason.decode!(y)
    # IO.inspect(w)

    assert w["err"]["exception"]["__trace_for__"] == "Elixir.Protocol.UndefinedError"

    # Oopsie, we have lost the tupleness! But it's ok.
    assert w["err"]["exception"]["value"] == []
  end
end

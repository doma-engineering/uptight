defmodule Uptight.Regression.Regression15 do
  alias Algae.Either
  alias Uptight.Result

  @spec ok() :: Result.Ok.t()
  def ok do
    Result.ok(42)
  end

  # Can't solve the constraints
  @spec ook() :: Result.ok(atom())
  def ook() do
    Result.ok(42)
  end

  @spec good_ok() :: Result.ok(non_neg_integer())
  def good_ok() do
    %Result.Ok{ok: 42}
  end

  @doc """
  Dialyzer isn't smart enough to note that we don't touch 42 in ook(), so it can't be atom.

  But it's smart enough to track the contract!
  For example, if we change the return type of use_ook/1 to the correct type: non_neg_integer(), then dialyzer will complain because the contracted types won't match.
  """
  @spec use_ook(Result.ok(atom())) :: atom()
  def use_ook(_x) do
    ook().ok
  end

  @spec use_ook1() :: nil | non_neg_integer()
  def use_ook1() do
    use_ook1_do(ook())
  end

  @spec use_ook1_do(Result.ok(atom())) :: nil | non_neg_integer()
  def use_ook1_do(%Result.Ok{ok: x}) when is_integer(x) do
    x
  end

  def use_ook1_do(%Result.Ok{ok: _}) do
    nil
  end

  @doc """
  Regression test!
  """
  def f(x) do
    case Result.new(fn -> 4 = 2 + x end) do
      %Result.Ok{ok: ok} -> ok
      %Result.Err{err: _err} -> nil
    end
  end

  def left(x) do
    Either.Left.new(x)
  end

  def right(x) do
    Either.Right.new(x)
  end

  def g(_x) do
    case Either.Right.new(5) do
      # %Either.Left{left: left} -> nil
      %Either.Right{right: right} -> right
    end
  end
end

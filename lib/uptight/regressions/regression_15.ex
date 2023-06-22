defmodule Uptight.Regression.Regression15 do
  alias Uptight.Result

  def f(x) do
    case(Result.new(fn -> 4 = 2 + x end)) do
      %Result.Ok{ok: ok} -> ok
      %Result.Err{err: err} -> nil
    end
  end
end

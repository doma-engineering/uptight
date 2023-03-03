defmodule AutoUnwrapResultTest do
  use ExUnit.Case

  use Witchcraft
  alias Uptight.Result
  import Witchcraft.Comonad

  test "auto unwrap result" do
    assert Result.new(fn -> 42 end)
           ~> (&(&1 + 1))
           |> extract() == 43

    assert Result.new(fn -> 5 = 2 + 2 end)
           ~> (&(&1 + 1))
           |> Result.is_err?()
  end
end

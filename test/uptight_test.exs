defmodule UptightTest do
  use ExUnit.Case
  doctest Uptight

  test "greets the world" do
    assert Uptight.hello() == :world
  end
end

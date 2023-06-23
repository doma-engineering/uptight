defmodule Uptight.Regression15Test do
  @moduledoc """
  Regression:

  ```
  def f(x) do
    case Result.new(fn -> 4 = 2 + x end) do
      %Result.Ok{ok: ok} -> ok
      %Result.Err{err: err} -> err
    end
  end
  ```

  This currently doesn't typecheck.
  """

  use ExUnit.Case
  @moduletag timeout: 180_000

  test "module has no dialyzer warnings" do
    # Ensure the code is compiled and the PLT is created
    Mix.Task.run("compile")
    Mix.Task.run("dialyzer", ["--plt"])

    args = [
      # You might want to set this to `true` if you want to ensure the PLT is always valid
      {:check_plt, false},
      {:init_plt, String.to_charlist(Dialyxir.Project.plt_file())},
      {:files, Dialyxir.Project.dialyzer_files() |> IO.inspect()},
      # Use all available warnings
      {:warnings, [:unknown]},
      {:format, "dialyzer"},
      {:raw, false},
      {:list_unused_filters, false},
      {:ignore_exit_status, false}
      # {:quiet_with_result, false}
    ]

    {_status, _, messages} =
      Dialyxir.Dialyzer.dialyze(args, Dialyxir.Dialyzer.Runner, Dialyxir.Project)

    file_name = "lib/uptight/regressions/regression_15.ex"

    file_warnings =
      Enum.filter(messages, fn message ->
        String.contains?(message |> IO.iodata_to_binary(), file_name)
      end)
      |> Enum.map(fn message ->
        message |> IO.iodata_to_binary()
      end)

    assert file_warnings == []
  end
end

defmodule Uptight.Binary do
  @moduledoc """
  Newtype wrapper for pure binary data.
  """
  alias Uptight.Result
  import Algae
  defdata(binary())

  @dialyzer {:nowarn_function, new: 1}

  # @spec new(binary) :: Result.t()
  def new(<<x::binary>>) do
    Result.new(fn -> new!(x) end)
  end

  @spec new!(binary) :: __MODULE__.t()
  def new!(<<x::binary>>) do
    %__MODULE__{binary: x}
  end

  @spec un(__MODULE__.t()) :: binary()
  def un(%__MODULE__{binary: x}) do
    x
  end
end

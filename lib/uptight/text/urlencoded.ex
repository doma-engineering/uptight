defmodule Uptight.Text.Urlencoded do
  @moduledoc """
  Urlencoded text encoding and decoding.
  """

  alias Uptight.Text, as: T
  alias Uptight.Result
  import Algae

  @dialyzer {:nowarn_function, new: 1}

  @doc """
  Defensive constructor.

  ## Examples
    iex> Uptight.Text.Urlencoded.new(Uptight.Text.new!("上~海+中.國"))
    %Uptight.Result.Ok{ok:
      %Uptight.Text.Urlencoded{
        encoded: %Uptight.Text{text: "%E4%B8%8A~%E6%B5%B7%2B%E4%B8%AD.%E5%9C%8B"},
        raw: %Uptight.Text{text: "上~海+中.國"}
      }
    }
  """
  def new(text) do
    Result.new(fn -> new!(text) end)
  end

  # This is a very ugly hack to get around the fact that we can't disable `new` function generation by default in witchcraft.
  # Some day we'll make it configurable and then we'll be able to put this `defdata` back up.
  defdata do
    encoded :: T.t()
    raw :: T.t()
  end

  def new!(x = %T{}) do
    %__MODULE__{
      encoded: T.new!(URI.encode_www_form(x.text)),
      raw: x
    }
  end
end

require Protocol
import TypeClass
use Witchcraft

defimpl Jason.Encoder, for: Uptight.Text.Urlencoded do
  @spec encode(Uptight.Text.Urlencoded.t(), Jason.Encode.opts()) :: [
          binary | maybe_improper_list(any, binary | []) | byte,
          ...
        ]
  def encode(value, opts) do
    Jason.Encode.string(Map.get(value, :encoded), opts)
  end
end

defimpl String.Chars, for: Uptight.Text.Urlencoded do
  @spec to_string(Uptight.Text.Urlencoded.t()) :: String.t()
  def to_string(value) do
    Map.get(value, :encoded)
  end
end

defimpl TypeClass.Property.Generator, for: Uptight.Text.Urlencoded do
  @spec generate(Uptight.Text.Urlencoded.t()) :: Uptight.Text.Urlencoded.t()
  def generate(_) do
    "generate me a string!"
    # This is how dispatch happens
    |> TypeClass.Property.Generator.generate()
    |> Uptight.Text.new!()
    |> Uptight.Text.Urlencoded.new!()
  end
end

##########
# Setoid #
##########

definst Witchcraft.Setoid, for: Uptight.Text.Urlencoded do
  @spec equivalent?(Uptight.Text.Urlencoded.t(), Uptight.Text.Urlencoded.t()) :: boolean()
  def equivalent?(a, b) do
    Witchcraft.Setoid.equivalent?(Map.get(a, :raw), Map.get(b, :raw))
  end
end

#############
# Semigroup #
#############

definst Witchcraft.Semigroup, for: Uptight.Text.Urlencoded do
  @spec append(Uptight.Text.Urlencoded.t(), Uptight.Text.Urlencoded.t()) ::
          Uptight.Text.Urlencoded.t()
  def append(a, b) do
    Witchcraft.Semigroup.append(Map.get(a, :raw), Map.get(b, :raw))
    |> Uptight.Text.Urlencoded.new!()
  end
end

##########
# Monoid #
##########

definst Witchcraft.Monoid, for: Uptight.Text.Urlencoded do
  @spec empty(Uptight.Text.Urlencoded.t()) :: Uptight.Text.Urlencoded.t()
  def empty(%Uptight.Text.Urlencoded{raw: x}) do
    Witchcraft.Monoid.empty(x)
    |> Uptight.Text.Urlencoded.new!()
  end
end

###########
# Functor #
###########

definst Witchcraft.Functor, for: Uptight.Text.Urlencoded do
  @spec map(Uptight.Text.Urlencoded.t(), (Uptight.Text.t() -> Uptight.Text.t())) ::
          Uptight.Text.Urlencoded.t()
  def map(%Uptight.Text.Urlencoded{raw: x}, f) do
    Witchcraft.Functor.map(x, f)
    |> Uptight.Text.Urlencoded.new!()
  end
end

############
# Foldable #
############

definst Witchcraft.Foldable, for: Uptight.Text.Urlencoded do
  @spec right_fold(Uptight.Text.Urlencoded.t(), any(), (any(), any() -> any())) ::
          any()
  def right_fold(%Uptight.Text.Urlencoded{raw: x}, acc, f) do
    Witchcraft.Foldable.right_fold(x, acc, f) |> Uptight.Text.Urlencoded.new!()
  end
end

defmodule Uptight.Text do
  @moduledoc """
  Newtype for textual data.

  It does what you expect, except it has one peculiarity:

   - `map` just applies function to the underlying binary string as is
   - `right_fold` and other folds from Foldable iterate through UTF-8 characters

  This behaviour probably should be unified to work over UTF-8 characters one way or another and a custom class Newtype should be devised to provide naive fmap functionality.
  """
  import Algae
  alias Uptight.Result
  defdata(binary())

  @dialyzer {:nowarn_function, new: 1}

  @doc """
  Defensive constructor.

  ## Examples
      iex> Uptight.Text.new(<<5555>>) |> Uptight.Result.is_err?()
      true

      iex> Uptight.Text.new(<<322>>)
      %Uptight.Result.Ok{ok: %Uptight.Text{text: "B"}}

      iex> Uptight.Text.new(<<228>>) |> Uptight.Result.is_err?()
      true

      iex> Uptight.Text.new("hello") |> Uptight.Result.from_ok() |> Witchcraft.Foldable.right_fold("", fn x, acc -> x <> acc end)
      "olleh"
  """
  # @spec new(binary()) :: Result.t()
  def new(x) do
    Result.new(fn -> new!(x) end)
  end

  @doc """
  Offensive constructor.
  """
  @spec new!(binary()) :: __MODULE__.t()
  def new!(<<x::binary>>) do
    new_do!(x, x) |> (&%__MODULE__{text: &1}).()
  end

  @spec un(__MODULE__.t()) :: binary()
  def un(%__MODULE__{text: t}), do: t

  defp new_do!(<<_tick::utf8, rest::bits>>, x) do
    new_do!(rest, x)
  end

  defp new_do!(<<>>, x) do
    x
  end

  defp new_do!(fail, _x) do
    raise fail
  end
end

require Protocol
import TypeClass
import Quark
use Witchcraft

defimpl Jason.Encoder, for: Uptight.Text do
  @spec encode(Uptight.Text.t(), Jason.Encode.opts()) :: [
          binary | maybe_improper_list(any, binary | []) | byte,
          ...
        ]
  def encode(value, opts) do
    Jason.Encode.string(Map.get(value, :text), opts)
  end
end

#############
# Generator #
#############

defimpl TypeClass.Property.Generator, for: Uptight.Text do
  @spec generate(Uptight.Text.t()) :: Uptight.Text.t()
  def generate(_) do
    "" |> TypeClass.Property.Generator.generate() |> Base.encode64() |> Uptight.Text.new!()
  end
end

##########
# Setoid #
##########

definst Witchcraft.Setoid, for: Uptight.Text do
  @spec equivalent?(Uptight.Text.t(), Uptight.Text.t()) :: boolean()
  def equivalent?(%Uptight.Text{text: x0}, %Uptight.Text{text: x1}),
    do: Witchcraft.Setoid.equivalent?(x0, x1)
end

#######
# Ord #
#######

definst Witchcraft.Ord, for: Uptight.Text do
  @spec compare(Uptight.Text.t(), Uptight.Text.t()) :: :greater | :lesser | :equal
  def compare(%Uptight.Text{text: x0}, %Uptight.Text{text: x1}),
    do: Witchcraft.Ord.compare(x0, x1)
end

#############
# Semigroup #
#############

definst Witchcraft.Semigroup, for: Uptight.Text do
  @spec append(Uptight.Text.t(), Uptight.Text.t()) :: Uptight.Text.t()
  def append(%Uptight.Text{text: x0}, %Uptight.Text{text: x1}), do: %Uptight.Text{text: x0 <> x1}
end

##########
# Monoid #
##########

definst Witchcraft.Monoid, for: Uptight.Text do
  @spec empty(Uptight.Text.t()) :: Uptight.Text.t()
  def empty(%Uptight.Text{text: x}), do: %Uptight.Text{text: Witchcraft.Monoid.empty(x)}
end

###########
# Functor #
###########

definst Witchcraft.Functor, for: Uptight.Text do
  @spec map(Uptight.Text.t(), (binary() -> binary())) :: Uptight.Text.t()
  def map(%Uptight.Text{text: x}, f), do: f.(x) |> Uptight.Text.new!()
end

############
# Foldable #
############

definst Witchcraft.Foldable, for: Uptight.Text do
  @spec right_fold(Uptight.Text.t(), any, (any, any -> any)) :: any
  def right_fold(%Uptight.Text{text: x}, acc, f) do
    # credo:disable-for-lines:14 /\.Nesting/
    recursion_payload = fn recursion_payload ->
      fn
        <<>> ->
          fn acc ->
            fn _ -> acc end
          end

        <<x::utf8, rest::binary>> ->
          fn acc ->
            fn f ->
              recursion_payload.(rest).(f.(<<x::utf8>>, acc)).(f)
            end
          end
      end
    end

    fold = fix(recursion_payload)
    fold.(x).(acc).(f)
  end
end

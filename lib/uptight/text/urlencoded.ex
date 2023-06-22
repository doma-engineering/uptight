defmodule Uptight.Text.Urlencoded do
  alias Uptight.Result

  defstruct encoded: "", raw: <<>>

  @type t :: %__MODULE__{
          encoded: String.t(),
          raw: binary()
        }

  @doc """
  Defensive constructor.

  ## Examples
      iex> Uptight.Text.Urlencoded.new(<<5555>>) |> Uptight.Result.is_err?()
      false

      iex> Uptight.Text.Urlencoded.new("goo")
      %Uptight.Result.Ok{ok: %Uptight.Text.Urlencoded{encoded: "goo", raw: <<131, 109, 0, 0, 0, 3, 103, 111, 111>>}}

      iex> Uptight.Text.Urlencoded.new(<<0xF7>>) |> Uptight.Result.is_err?()
      false

      iex> Uptight.Text.Urlencoded.new("hello") |> Uptight.Result.from_ok() |> Witchcraft.Foldable.right_fold("", fn x, acc -> x <> acc end)
      "olleh"
  """
  # @spec new(binary()) :: Result.t()
  def new(x) do
    Result.new(fn -> new!(x) end)
  end

  @doc """
  Offensive constructor.

  ## Examples
    iex> Uptight.Text.Urlencoded.new!("on_the_map@elixir@phoenix+ecto+commanded+uptight@postrgresql")
    %Uptight.Text.Urlencoded{
      encoded: "on_the_map@elixir@phoenix+ecto+commanded+uptight@postrgresql",
      raw: <<131, 109, 0, 0, 0, 60, 111, 110, 95, 116, 104, 101, 95, 109, 97, 112, 64, 101,
          108, 105, 120, 105, 114, 64, 112, 104, 111, 101, 110, 105, 120, 43, 101, 99,
          116, 111, 43, 99, 111, 109, 109, 97, 110, 100, 101, 100, 43, 117, 112, 116,
          105, 103, 104, 116, 64, 112, 111, 115, 116, 114, 103, 114, 101, 115, 113,
          108>>
    }
  """
  @spec new!(binary()) :: __MODULE__.t()
  def new!(<<x::binary>>) do
    %__MODULE__{encoded: URI.encode(x), raw: :erlang.term_to_binary(x)}
  end

  @spec un(__MODULE__.t()) :: String.t()
  def un(%__MODULE__{encoded: e}), do: e
end

require Protocol
import TypeClass
import Quark
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
  @spec to_string(Uptight.Text.t()) :: String.t()
  def to_string(value) do
    Map.get(value, :encoded)
  end
end

#############
# Generator #
#############

defimpl TypeClass.Property.Generator, for: Uptight.Text.Urlencoded do
  @spec generate(Uptight.Text.Urlencoded.t()) :: Uptight.Text.Urlencoded.t()
  def generate(_) do
    ""
    |> TypeClass.Property.Generator.generate()
    |> Base.encode64()
    |> Uptight.Text.Urlencoded.new!()
  end
end

##########
# Setoid #
##########

definst Witchcraft.Setoid, for: Uptight.Text.Urlencoded do
  @spec equivalent?(Uptight.Text.Urlencoded.t(), Uptight.Text.Urlencoded.t()) :: boolean()
  def equivalent?(%Uptight.Text.Urlencoded{encoded: x0}, %Uptight.Text.Urlencoded{encoded: x1}),
    do: Witchcraft.Setoid.equivalent?(x0, x1)
end

#######
# Ord #
#######

definst Witchcraft.Ord, for: Uptight.Text.Urlencoded do
  @spec compare(Uptight.Text.Urlencoded.t(), Uptight.Text.Urlencoded.t()) ::
          :greater | :lesser | :equal
  def compare(%Uptight.Text.Urlencoded{encoded: x0}, %Uptight.Text.Urlencoded{encoded: x1}),
    do: Witchcraft.Ord.compare(x0, x1)
end

#############
# Semigroup #
#############

definst Witchcraft.Semigroup, for: Uptight.Text.Urlencoded do
  @spec append(Uptight.Text.Urlencoded.t(), Uptight.Text.Urlencoded.t()) ::
          Uptight.Text.Urlencoded.t()
  def append(%Uptight.Text.Urlencoded{encoded: x0}, %Uptight.Text.Urlencoded{encoded: x1}),
    do: %Uptight.Text.Urlencoded{encoded: x0 <> x1}
end

##########
# Monoid #
##########

definst Witchcraft.Monoid, for: Uptight.Text.Urlencoded do
  @spec empty(Uptight.Text.Urlencoded.t()) :: Uptight.Text.Urlencoded.t()
  def empty(%Uptight.Text.Urlencoded{encoded: x}),
    do: %Uptight.Text.Urlencoded{encoded: Witchcraft.Monoid.empty(x)}
end

###########
# Functor #
###########

definst Witchcraft.Functor, for: Uptight.Text.Urlencoded do
  @spec map(Uptight.Text.Urlencoded.t(), (binary() -> binary())) :: Uptight.Text.Urlencoded.t()
  def map(%Uptight.Text.Urlencoded{encoded: x}, f), do: f.(x) |> Uptight.Text.Urlencoded.new!()
end

############
# Foldable #
############

definst Witchcraft.Foldable, for: Uptight.Text.Urlencoded do
  @spec right_fold(Uptight.Text.Urlencoded.t(), any, (any, any -> any)) :: any
  def right_fold(%Uptight.Text.Urlencoded{encoded: x}, acc, f) do
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

defmodule Uptight.Result do
  @moduledoc """
  Alternative Either. Differences from Alage Either:

   1. Overloaded new that takes a nullary function, runs it and if it raises an error, it returns Err holding Uptight.Trace, it returns Ok otherwise.
   2. As data, not biased neither towrards Ok nor Err, whereas Algae version is biased towards Right: https://github.com/witchcrafters/algae/blob/067e2b0a02c5c0c4183051807dfa733e2ee43fe4/lib/algae/either.ex#L140.
   3. As operation, biased neither towards Ok nor Err (unlike Algae version, which is biased towards Left). Thus, Result instances adhere to all the typeclass laws.
  """

  import Algae
  alias Uptight.Result.{Err, Ok}
  alias Uptight.Trace
  require Logger

  defsum do
    defdata(Err :: any())
    defdata(Ok :: any())
  end

  @doc """
  Run failable function, capturing return value into Ok and a runtime error into Err.

  ## Examples
      iex> Uptight.Result.new(fn () -> :erlang.system_flag(:backtrace_depth, 0); raise "oopsie" end) |> Uptight.Result.is_err?()
      true

      iex> Uptight.Result.new(fn () -> :erlang.system_flag(:backtrace_depth, 20); raise "is_err!" end) |> Uptight.Result.is_err?()
      true

      iex> Uptight.Result.new(fn () -> 42 end)
      %Uptight.Result.Ok{ok: 42}

      iex> Uptight.Result.new(fn () -> 42 end) |> Uptight.Result.is_ok?()
      true

      iex> Uptight.Result.new(fn () -> 42 end) |> Uptight.Result.is_err?()
      false
  """
  @spec new((() -> any())) :: t()
  def new(f) do
    try do
      Ok.new(f.())
    rescue
      e ->
        trace = Trace.new(e, __STACKTRACE__)
        Err.new(trace)
    end
  end

  @spec from_ok(__MODULE__.t()) :: any()
  def from_ok(%__MODULE__.Ok{ok: x}), do: x

  def from_ok(err) do
    Logger.error("#{inspect(err, pretty: true)}")
    :error = err
  end

  @spec is_err?(__MODULE__.t()) :: boolean()
  def is_err?(_ = %Err{}), do: true
  def is_err?(_), do: false

  @spec is_ok?(__MODULE__.t()) :: boolean()
  def is_ok?(_ = %Ok{}), do: true
  def is_ok?(_), do: false

  @spec cont(__MODULE__.t(), (any() -> any())) :: __MODULE__.t()
  def cont(%Ok{ok: x}, f) do
    case f.(x) do
      %Err{} = e -> e
      otherwise -> %Ok{ok: otherwise}
    end
  end

  def cont(e = %Err{}, _), do: e

  @spec cont_end(__MODULE__.t()) :: __MODULE__.t()
  def cont_end(res = %Ok{}) do
    res |> from_ok()
  end

  def cont_end(err = %Err{}) do
    err
  end

  @spec new_ok :: __MODULE__.Ok.t()
  def new_ok() do
    %__MODULE__.Ok{ok: true}
  end
end

alias Uptight.Result.{Err, Ok}
import TypeClass
use Witchcraft
require Protocol
Protocol.derive(Jason.Encoder, Uptight.Result.Ok)
Protocol.derive(Jason.Encoder, Uptight.Result.Err)

# RELEVANT DERIVATIONS

Protocol.derive(Jason.Encoder, Algae.Maybe.Just)
Protocol.derive(Jason.Encoder, Algae.Maybe.Nothing)
Protocol.derive(Jason.Encoder, Algae.Either.Left)
Protocol.derive(Jason.Encoder, Algae.Either.Right)

#############
# Generator #
#############

defimpl TypeClass.Property.Generator, for: Uptight.Result.Err do
  @spec generate(Uptight.Result.Err.t()) :: Uptight.Result.Err.t()
  def generate(_) do
    [] |> TypeClass.Property.Generator.generate() |> Err.new()
  end
end

defimpl TypeClass.Property.Generator, for: Uptight.Result.Ok do
  @spec generate(Uptight.Result.Ok.t()) :: Uptight.Result.Ok.t()
  def generate(_) do
    [] |> TypeClass.Property.Generator.generate() |> Ok.new()
  end
end

##########
# Setoid #
##########

definst Witchcraft.Setoid, for: Uptight.Result.Err do
  @spec equivalent?(Uptight.Result.Err.t(), Uptight.Result.t()) :: boolean()
  def equivalent?(%Err{err: x0}, %Err{err: x1}), do: Witchcraft.Setoid.equivalent?(x0, x1)
  def equivalent?(_, %Ok{}), do: false
end

definst Witchcraft.Setoid, for: Uptight.Result.Ok do
  @spec equivalent?(Uptight.Result.Ok.t(), Uptight.Result.t()) :: boolean()
  def equivalent?(%Ok{ok: x0}, %Ok{ok: x1}), do: Witchcraft.Setoid.equivalent?(x0, x1)
  def equivalent?(_, %Err{}), do: false
end

#######
# Ord #
#######

definst Witchcraft.Ord, for: Uptight.Result.Err do
  @spec compare(%Err{}, Uptight.Result.t()) :: :lesser | :greater | :equal
  def compare(_, %Ok{}), do: :lesser
  def compare(%Err{err: x0}, %Err{err: x1}), do: Witchcraft.Ord.compare(x0, x1)
end

definst Witchcraft.Ord, for: Uptight.Result.Ok do
  @spec compare(Uptight.Result.Ok.t(), Uptight.Result.t()) :: :equal | :lesser | :greater
  def compare(_, %Err{}), do: :greater
  def compare(%Ok{ok: x0}, %Ok{ok: x1}), do: Witchcraft.Ord.compare(x0, x1)
end

#############
# Semigroup #
#############

definst Witchcraft.Semigroup, for: Uptight.Result.Err do
  @spec append(Uptight.Result.Err.t(), Uptight.Result.t()) :: Uptight.Result.t()
  def append(%Err{err: x0}, %Ok{ok: x1}), do: %Err{err: x0 <> x1}
  def append(%Err{err: x0}, %Err{err: x1}), do: %Err{err: x0 <> x1}
end

definst Witchcraft.Semigroup, for: Uptight.Result.Ok do
  @spec append(Uptight.Result.Ok.t(), Uptight.Result.t()) :: Uptight.Result.t()
  def append(%Ok{ok: x0}, %Err{err: x1}), do: %Err{err: x0 <> x1}
  def append(%Ok{ok: x0}, %Ok{ok: x1}), do: %Ok{ok: x0 <> x1}
end

##########
# Monoid #
##########

definst Witchcraft.Monoid, for: Uptight.Result.Err do
  @spec empty(Uptight.Result.Err.t()) :: Uptight.Result.Err.t()
  def empty(%Err{err: x}), do: %Err{err: Witchcraft.Monoid.empty(x)}
end

definst Witchcraft.Monoid, for: Uptight.Result.Ok do
  @spec empty(Uptight.Result.Ok.t()) :: Uptight.Result.Ok.t()
  def empty(%Ok{ok: x}), do: %Ok{ok: Witchcraft.Monoid.empty(x)}
end

###########
# Functor #
###########

definst Witchcraft.Functor, for: Uptight.Result.Err do
  @spec map(Uptight.Result.Err.t(), (any() -> any())) :: Uptight.Result.Err.t()
  def map(%{err: x}, f), do: x |> f.() |> Err.new()
end

definst Witchcraft.Functor, for: Uptight.Result.Ok do
  @spec map(Uptight.Result.Ok.t(), (any() -> any())) :: Uptight.Result.Ok.t()
  def map(%{ok: x}, f), do: x |> f.() |> Ok.new()
end

############
# Foldable #
############

definst Witchcraft.Foldable, for: Uptight.Result.Err do
  @spec right_fold(%Err{}, any(), (any(), any() -> any())) :: any()
  def right_fold(%{err: x}, acc0, f) do
    f.(x, acc0)
  end
end

definst Witchcraft.Foldable, for: Uptight.Result.Ok do
  @spec right_fold(%Ok{}, any(), (any(), any() -> any())) :: any()
  def right_fold(%{ok: x}, acc0, f) do
    f.(x, acc0)
  end
end

###############
# Traversable #
###############

definst Witchcraft.Traversable, for: Uptight.Result.Err do
  @spec traverse(%Err{}, (any() -> Witchcraft.Traversable.t())) :: Witchcraft.Traversable.t()
  def traverse(%{err: err}, f) do
    map(f.(err), &Err.new/1)
  end
end

definst Witchcraft.Traversable, for: Uptight.Result.Ok do
  @spec traverse(%Ok{}, (any() -> Witchcraft.Traversable.t())) :: Witchcraft.Traversable.t()
  def traverse(%{ok: ok}, f) do
    map(f.(ok), &Ok.new/1)
  end
end

#########
# Apply #
#########

# (<*>) :: f (a -> b) -> f a -> f b
# convey :: f a -> f (a -> b) -> f b

definst Witchcraft.Apply, for: Uptight.Result.Err do
  @spec convey(Uptight.Result.t(), %{
          :err => (Uptight.Result.t() -> any()),
          optional(any()) => any()
        }) ::
          %Uptight.Result.Err{}
  def convey(x, %Err{err: f}), do: Witchcraft.Functor.map(x, f)
end

definst Witchcraft.Apply, for: Uptight.Result.Ok do
  @spec convey(Uptight.Result.t(), %{
          :ok => (Uptight.Result.t() -> any()),
          optional(any()) => any()
        }) ::
          Uptight.Result.t()
  def convey(x, %Ok{ok: f}), do: Witchcraft.Functor.map(x, f)
end

###############
# Applicative #
###############

## Can't get this to propcheck for the time being

definst Witchcraft.Applicative, for: Uptight.Result.Err do
  @spec of(Uptight.Result.Err.t(), any()) :: Uptight.Result.Err.t()
  def of(_, x), do: x |> Err.new()
end

definst Witchcraft.Applicative, for: Uptight.Result.Ok do
  @spec of(Uptight.Result.Ok.t(), any()) :: Uptight.Result.Ok.t()
  def of(_, x), do: x |> Ok.new()
end

#########
# Chain #
#########

definst Witchcraft.Chain, for: Uptight.Result.Err do
  @spec chain(Uptight.Result.Err.t(), (any() -> Uptight.Result.t())) :: Uptight.Result.t()
  def chain(%Uptight.Result.Err{err: x}, f), do: f.(x)
end

definst Witchcraft.Chain, for: Uptight.Result.Ok do
  @spec chain(Uptight.Result.Ok.t(), (any() -> Uptight.Result.t())) :: Uptight.Result.t()
  def chain(%Uptight.Result.Ok{ok: x}, f), do: f.(x)
end

#########
# Monad #
#########

# Monad breaks everything: https://github.com/witchcrafters/witchcraft/issues/82

# definst Witchcraft.Monad, for: Uptight.Result.Err
# definst Witchcraft.Monad, for: Uptight.Result.Ok

defmodule Uptight.Result do
  @moduledoc """
  Alternative Either. Differences from Alage Either:

   1. Overloaded new that takes a nullary function, runs it and if it raises an error, it returns Err holding Uptight.Trace, it returns Ok otherwise.
   2. As data, not biased neither towrards Ok nor Err, whereas Algae version is biased towards Right: https://github.com/witchcrafters/algae/blob/067e2b0a02c5c0c4183051807dfa733e2ee43fe4/lib/algae/either.ex#L140.
   3. As operation, biased neither towards Ok nor Err (unlike Algae version, which is biased towards Left). Thus, Result instances adhere to all the typeclass laws.
  """

  import Algae
  alias Uptight.Trace

  @type err(e_t) :: %{
          required(:__struct__) => Elixir.Uptight.Result.Err,
          required(:err) => %{
            required(:exception) => e_t,
            required(:stacktrace) => list(any()),
            required(:__struct__) => Elixir.Uptight.Trace
          }
        }

  @type ok(a_t) :: %{
          required(:__struct__) => Elixir.Uptight.Result.Ok,
          required(:ok) => a_t
        }

  @type sum(e_t, a_t) :: err(e_t) | ok(a_t)

  @type possibly(a_t) :: sum(any(), a_t)

  @type r :: any()
  @type l :: any()
  @type y :: any()

  defunion do
    defprod(Err :: Uptight.Result.err(any()))
    defprod(Ok :: Uptight.Result.ok(any()))
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
  @spec new((() -> y)) :: sum(any(), any())
  def new(f) do
    try do
      %__MODULE__.Ok{ok: f.()}
    rescue
      e ->
        trace = Trace.new(e, __STACKTRACE__)
        %__MODULE__.Err{err: trace}
    end
  end

  @spec ok(y) :: ok(y)
  def ok(x), do: %__MODULE__.Ok{ok: x}

  @spec from_ok(__MODULE__.sum(l, r)) :: r | __MODULE__.err(l)
  def from_ok(%__MODULE__.Ok{ok: x}), do: x

  def from_ok(err) do
    require Logger
    Logger.error("#{inspect(err, pretty: true)}")
    :error = err
  end

  @spec from_ok(__MODULE__.sum(l, r), y) :: r | y
  def from_ok(%__MODULE__.Ok{ok: r}, _), do: r
  def from_ok(_, y), do: y

  @spec is_err?(__MODULE__.t()) :: boolean()
  def is_err?(_ = %__MODULE__.Err{}), do: true
  def is_err?(_), do: false

  @spec is_ok?(__MODULE__.t()) :: boolean()
  def is_ok?(_ = %__MODULE__.Ok{}), do: true
  def is_ok?(_), do: false

  # TODO: Implement this `cont` in terms of `Witchcraft.Bifunctor`.
  #
  # Reasoning:
  # This continuation operator must have some abstract counterpart.
  # In Haskell it would have had the type: cont :: (Either e a) -> (a -> Either e b) -> Either e b
  # Which generalises to bimap, which has the type: bimap :: (a -> c) -> (b -> d) -> Either a b -> Either c d
  # This `cont` function is, namely, a special case of bimap, where the first function is the identity function.
  # Also known as `second` in Data.Bifunctor.
  @spec cont(__MODULE__.t(), (any() -> any())) :: __MODULE__.t()
  def cont(%__MODULE__.Ok{ok: x}, f) do
    case f.(x) do
      %__MODULE__.Err{} = e -> e
      otherwise -> %__MODULE__.Ok{ok: otherwise}
    end
  end

  def cont(e = %__MODULE__.Err{}, _), do: e

  @spec cont_end(__MODULE__.t()) :: __MODULE__.t()
  def cont_end(res = %__MODULE__.Ok{}) do
    res |> from_ok()
  end

  def cont_end(err = %__MODULE__.Err{}) do
    err
  end

  @spec new_ok :: __MODULE__.ok(true)
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

# SOMEWHAT RELEVANT DERIVATIONS

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
    %Uptight.Result.Err{err: [] |> TypeClass.Property.Generator.generate()}
  end
end

defimpl TypeClass.Property.Generator, for: Uptight.Result.Ok do
  @spec generate(Uptight.Result.Ok.t()) :: Uptight.Result.Ok.t()
  def generate(_) do
    %Uptight.Result.Ok{ok: [] |> TypeClass.Property.Generator.generate()}
  end
end

# Lawful typeclasses

#######
# Ord #
#######

definst Witchcraft.Ord, for: Uptight.Result.Err do
  @spec compare(Uptight.Result.err(any()), Uptight.Result.t()) :: :lesser | :greater | :equal
  def compare(_, %Ok{}), do: :lesser
  def compare(%Err{err: x0}, %Err{err: x1}), do: Witchcraft.Ord.compare(x0, x1)
end

definst Witchcraft.Ord, for: Uptight.Result.Ok do
  @spec compare(Uptight.Result.ok(any()), Uptight.Result.t()) :: :equal | :lesser | :greater
  def compare(_, %Err{}), do: :greater
  def compare(%Ok{ok: x0}, %Ok{ok: x1}), do: Witchcraft.Ord.compare(x0, x1)
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

###########
# Comonad #
###########

definst Witchcraft.Comonad, for: Uptight.Result.Err do
  @spec extract(Uptight.Result.Err.t()) :: any()
  def extract(%Uptight.Result.Err{err: x}), do: x
end

definst Witchcraft.Comonad, for: Uptight.Result.Ok do
  @spec extract(Uptight.Result.Ok.t()) :: any()
  def extract(%Uptight.Result.Ok{ok: x}), do: x
end

###########
# Functor #
###########

definst Witchcraft.Functor, for: Uptight.Result.Err do
  @type l :: any()
  # Functor.map now stops computation when it encounters an error
  @spec map(Uptight.Result.err(l), (any() -> any())) :: Uptight.Result.err(l)
  def map(%{err: x}, _f), do: %Err{err: x}
end

definst Witchcraft.Functor, for: Uptight.Result.Ok do
  @type r :: any()
  @type y :: any()
  @spec map(Uptight.Result.Ok.t(), (r -> y)) :: Uptight.Result.possibly(y)
  def map(%{ok: x}, f) do
    Uptight.Result.new(fn -> f.(x) end)
  end
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
    map(f.(err), fn x -> %Err{err: x} end)
  end
end

definst Witchcraft.Traversable, for: Uptight.Result.Ok do
  @spec traverse(%Ok{}, (any() -> Witchcraft.Traversable.t())) :: Witchcraft.Traversable.t()
  def traverse(%{ok: ok}, f) do
    map(f.(ok), fn x -> %Ok{ok: x} end)
  end
end

#########
# Apply #
#########

# (<*>) :: f (a -> b) -> f a -> f b
# convey :: f a -> f (a -> b) -> f b

definst Witchcraft.Apply, for: Uptight.Result.Err do
  @type r :: any()
  @type l :: any()
  @type y :: any()
  @spec convey(Uptight.Result.sum(l, r), Uptight.Result.err((l | r -> y))) ::
          Uptight.Result.sum(y, any())
  def convey(x, %Err{err: f}) do
    Uptight.Result.new(fn -> Witchcraft.Functor.map(x, f) end)
    |> case do
      ok = %Ok{} -> ok
      err = %Err{} -> %Err{err: err}
    end
  end
end

definst Witchcraft.Apply, for: Uptight.Result.Ok do
  @type r :: any()
  @type l :: any()
  @type y :: any()
  @spec convey(Uptight.Result.sum(l, r), Uptight.Result.ok((l | r -> y))) ::
          Uptight.Result.sum(any(), y)
  def convey(x, %Ok{ok: f}) do
    Uptight.Result.new(fn -> Witchcraft.Functor.map(x, f) end)
  end
end

###############
# Applicative #
###############

definst Witchcraft.Applicative, for: Uptight.Result.Err do
  @spec of(Uptight.Result.Err.t(), any()) :: Uptight.Result.Err.t()
  def of(%Uptight.Result.Err{}, x), do: %Err{err: x}
end

definst Witchcraft.Applicative, for: Uptight.Result.Ok do
  @spec of(Uptight.Result.Ok.t(), any()) :: Uptight.Result.Ok.t()
  def of(%Uptight.Result.Ok{}, x), do: %Ok{ok: x}
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

definst(Witchcraft.Monad, for: Uptight.Result.Err)
definst(Witchcraft.Monad, for: Uptight.Result.Ok)

##########
# Extend #
##########

definst Witchcraft.Extend, for: Uptight.Result.Err do
  @spec nest(Uptight.Result.Err.t()) :: Uptight.Result.Err.t()
  def nest(%Uptight.Result.Err{err: x}),
    do: %Uptight.Result.Err{
      err: %Uptight.Result.Err{err: x}
    }
end

definst Witchcraft.Extend, for: Uptight.Result.Ok do
  @spec nest(Uptight.Result.Ok.t()) :: Uptight.Result.Ok.t()
  def nest(%Uptight.Result.Ok{ok: x}),
    do: %Uptight.Result.Ok{
      ok: %Uptight.Result.Ok{ok: x}
    }
end

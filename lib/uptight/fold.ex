defmodule Uptight.Fold do
  @moduledoc """
  Foldable plus.
  """

  import Witchcraft.Foldable
  import Kernel, except: [<>: 2]
  import Witchcraft.Semigroup
  import Witchcraft.Monoid
  import Witchcraft.Applicative

  @doc """
  Folds by gluing the elements. Constraints in typespec are fake and don't do anything except for suggesting required typeclasses.

  ## Example
      iex> Uptight.Result.new(fn -> Uptight.Fold.intercalate([1,2,3], "") end) |> Uptight.Result.is_err?()
      true

      # iex> Uptight.Fold.intercalate(Witchcraft.Functor.map([1,2,3], &Uptight.Add.new/1), 1)
      # 9

      iex> Uptight.Fold.intercalate([], 1)
      0

      iex> Uptight.Fold.intercalate([Uptight.Text.new!("."), Uptight.Text.new!("a.out")], Uptight.Text.new!("/"))
      %Uptight.Text{text: "./a.out"}

      iex> Uptight.Fold.intercalate([Uptight.Text.new!(".")], Uptight.Text.new!("lol nvm"))
      %Uptight.Text{text: "."}
  """
  @spec intercalate(
          Witchcraft.Foldable.t() | :and | Witchcraft.Semigroup.t(),
          Witchcraft.Monoid.t()
        ) :: Witchcraft.Monoid.t()
  def intercalate(foldable_semigroup, glue) do
    if foldable_semigroup == empty(foldable_semigroup) do
      empty(glue)
    else
      fold(intersperse(foldable_semigroup, glue))
    end
  end

  @doc """
  Inserts glue between each pair of elements. Constraints in typespec are fake and don't do anything except for suggesting required typeclasses.

  ## Example
      iex> Uptight.Fold.intersperse([1,2,3], "the power of elixir")
      [1, "the power of elixir", 2, "the power of elixir", 3]

      iex> Uptight.Fold.intersperse([Uptight.Text.new!("."), Uptight.Text.new!("a.out")], Uptight.Text.new!("/"))
      [%Uptight.Text{text: "."}, %Uptight.Text{text: "/"}, %Uptight.Text{text: "a.out"}]

      iex> Uptight.Fold.intersperse([Uptight.Text.new!(".")], Uptight.Text.new!("lol nvm"))
      [%Uptight.Text{text: "."}]
  """
  @spec intersperse(
          Witchcraft.Foldable.t() | :and | Witchcraft.Semigroup.t(),
          Witchcraft.Monoid.t()
        ) ::
          Witchcraft.Foldable.t() | :and | Witchcraft.Semigroup.t()

  def intersperse(foldable_semigroup, glue) do
    right_glued(foldable_semigroup, glue)
  end

  @spec right_glued(
          Witchcraft.Foldable.t() | :and | Witchcraft.Semigroup.t(),
          Witchcraft.Monoid.t()
        ) ::
          Witchcraft.Foldable.t() | :and | Witchcraft.Semigroup.t()
  def right_glued(foldable_semigroup, glue) do
    case right_fold(
           foldable_semigroup,
           nil,
           &glued_once(foldable_semigroup, glue, &1, &2)
         ) do
      nil -> foldable_semigroup
      x -> x
    end
  end

  defp glued_once(foldable_semigroup, glue, x, acc) do
    if acc == nil do
      x |> to(foldable_semigroup)
    else
      (x |> to(foldable_semigroup)) <> (glue |> to(foldable_semigroup)) <> acc
    end
  end
end

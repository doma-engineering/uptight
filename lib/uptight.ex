defmodule Uptight do
  @moduledoc """
  Facilities for tightening loosey goosey types.
  """
  alias Uptight.Text, as: T
  alias Uptight.Base, as: B
  alias Uptight.Binary
  alias Uptight.Result

  import Witchcraft.Functor

  @spec tighten(any) :: any
  def tighten(x) when is_binary(x) do
    candidate = T.new(x)

    candidate =
      if Result.is_err?(candidate) do
        %Result.Ok{ok: Binary.new!(x)}
      else
        candidate
      end

    candidate.ok
  end

  def tighten([x]) do
    [tighten(x)]
  end

  def tighten([x | rest]) do
    [tighten(x) | tighten(rest)]
  end

  def tighten({t, x}) do
    {t, tighten(x)}
  end

  def tighten(%{} = kv) do
    map(kv, &tighten/1)
  end

  def tighten(x), do: x

  @spec into_text_or_urlsafe(binary) :: T.t() | B.Urlsafe.t()
  def into_text_or_urlsafe(x) do
    case tighten(x) do
      x = %Binary{} -> B.binary_to_urlsafe(x)
      x = %T{} -> x
    end
  end
end

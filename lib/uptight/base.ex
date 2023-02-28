defmodule Uptight.Base do
  @moduledoc """
  Type wrappers for BaseN representations of binary data.
  """
  import Algae
  import Witchcraft
  import Witchcraft.Foldable
  alias Uptight.Binary
  alias Uptight.Result
  alias Uptight.Result.{Ok}
  alias Uptight.Base.{Sixteen, ThirtyTwo, SixtyFour, Urlsafe}

  @dialyzer {:no_return, {:new, 0}}
  @dialyzer {:no_return, {:new, 1}}

  defsum do
    defdata Sixteen do
      encoded :: String.t() \\ ""
      raw :: binary() \\ <<>>
    end

    defdata ThirtyTwo do
      encoded :: String.t() \\ ""
      raw :: binary() \\ <<>>
    end

    defdata SixtyFour do
      encoded :: String.t() \\ ""
      raw :: binary() \\ <<>>
    end

    defdata Urlsafe do
      encoded :: String.t() \\ ""
      raw :: binary() \\ <<>>
    end
  end

  @doc """
  Defensive constructor.

  ## Examples
      iex> Uptight.Base.new("0L/Ri9GJIG9sb2xvINGPINCy0L7QtNC40YLQtdC70Ywg0J3Qm9CeIQ==")
      %Uptight.Result.Ok{
        ok: %Uptight.Base.SixtyFour{
          encoded: "0L/Ri9GJIG9sb2xvINGPINCy0L7QtNC40YLQtdC70Ywg0J3Qm9CeIQ==",
          raw: "пыщ ololo я водитель НЛО!"
        }
      }

      iex> Uptight.Base.new("0L/Ri9GJIG9sb2xvINGPINCy0L7QtNC40YLQtdC70Ywg0J3Qm9CeIQ==") |> Uptight.Result.is_ok?()
      true
  """
  @spec new(binary()) :: Result.t()
  def new(x), do: Result.new(fn -> new!(x) end)

  @spec new!(binary()) :: __MODULE__.t()
  def new!(<<x::binary>>) do
    # There must be some `ap`/`apply` trick here
    %Ok{ok: res} =
      [&mk16/1, &mk32/1, &mk_url/1, &mk64/1]
      |> left_fold(:cont, fn acc, f ->
        case acc do
          y = %Ok{} -> y
          _ -> f.(x)
        end
      end)

    res
  end

  @doc """
  Perhaps, constructs a representation of a hex string.

  ## Example
      iex> Uptight.Base.mk16("1337C0DE")
      %Uptight.Result.Ok{ok: %Uptight.Base.Sixteen{encoded: "1337C0DE", raw: <<19, 55, 192, 222>>}}
  """
  @spec mk16(binary()) :: Result.t()
  def mk16(x) do
    Result.new(fn -> Base.decode16!(x) end)
    |> Result.cont(fn res -> %Sixteen{encoded: x, raw: res} end)
  end

  @spec mk32(binary()) :: Result.t()
  def mk32(x) do
    Result.new(fn -> Base.decode32!(x) end)
    |> Result.cont(fn res -> %ThirtyTwo{encoded: x, raw: res} end)
  end

  @spec mk64(binary()) :: Result.t()
  def mk64(x) do
    Result.new(fn -> Base.decode64!(x) end)
    |> Result.cont(fn res -> %SixtyFour{encoded: x, raw: res} end)
  end

  @spec mk_url(binary()) :: Result.t()
  def mk_url(x) do
    Result.new(fn -> Base.url_decode64!(x) end)
    |> Result.cont(fn res -> %Urlsafe{encoded: x, raw: res} end)
  end

  @spec mk_url!(binary()) :: __MODULE__.Urlsafe.t()
  def mk_url!(x) do
    mk_url(x) |> Result.from_ok()
  end

  @spec raw_to_urlsafe(binary) :: Result.t()
  def raw_to_urlsafe(<<x::binary>>) do
    x |> Base.url_encode64() |> mk_url()
  end

  @spec binary_to_urlsafe(Binary.t()) :: Result.t()
  def binary_to_urlsafe(%Binary{} = x) do
    x |> Binary.un() |> raw_to_urlsafe()
  end

  @spec raw_to_urlsafe!(binary) :: __MODULE__.Urlsafe.t()
  def raw_to_urlsafe!(<<x::binary>>) do
    raw_to_urlsafe(x) |> Result.from_ok()
  end

  @spec binary_to_urlsafe!(Binary.t()) :: Urlsafe.t()
  def binary_to_urlsafe!(%Binary{} = x) do
    x |> Binary.un() |> raw_to_urlsafe!()
  end

  @spec safe(Uptight.Binary.t()) :: Result.t()
  defdelegate safe(binary), to: __MODULE__, as: :binary_to_urlsafe

  @spec safe!(Uptight.Binary.t()) :: __MODULE__.Urlsafe.t()
  defdelegate safe!(binary), to: __MODULE__, as: :binary_to_urlsafe!
end

require Protocol

defimpl Jason.Encoder, for: Uptight.Base.Sixteen do
  @spec encode(Uptight.Base.Sixteen.t(), Jason.Encode.opts()) :: [
          binary | maybe_improper_list(any, binary | []) | byte,
          ...
        ]
  def encode(value, opts) do
    Jason.Encode.string(Map.get(value, :encoded), opts)
  end
end

defimpl Jason.Encoder, for: Uptight.Base.ThirtyTwo do
  @spec encode(Uptight.Base.ThirtyTwo.t(), Jason.Encode.opts()) :: [
          binary | maybe_improper_list(any, binary | []) | byte,
          ...
        ]
  def encode(value, opts) do
    Jason.Encode.string(Map.get(value, :encoded), opts)
  end
end

defimpl Jason.Encoder, for: Uptight.Base.SixtyFour do
  @spec encode(Uptight.Base.SixtyFour.t(), Jason.Encode.opts()) :: [
          binary | maybe_improper_list(any, binary | []) | byte,
          ...
        ]
  def encode(value, opts) do
    Jason.Encode.string(Map.get(value, :encoded), opts)
  end
end

defimpl Jason.Encoder, for: Uptight.Base.Urlsafe do
  @spec encode(Uptight.Base.Urlsafe.t(), Jason.Encode.opts()) :: [
          binary | maybe_improper_list(any, binary | []) | byte,
          ...
        ]
  def encode(value, opts) do
    Jason.Encode.string(Map.get(value, :encoded), opts)
  end
end

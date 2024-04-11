defmodule Uptight.Base do
  @moduledoc """
  Type wrappers for BaseN representations of binary data.
  """
  import Algae
  import Witchcraft
  # import Witchcraft.Foldable
  alias Uptight.Binary
  alias Uptight.Result
  alias Uptight.Result.{Ok}
  alias Uptight.Base.{Sixteen, ThirtyTwo, SixtyFour, Urlsafe}

  import Uptight.Assertions

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

    defdata FiftyEight do
      encoded :: String.t() \\ ""
      raw :: binary() \\ <<>>
    end

    defdata Urlsafe do
      encoded :: String.t() \\ ""
      raw :: binary() \\ <<>>
    end
  end

  alias __MODULE__.Sixteen
  alias __MODULE__.ThirtyTwo
  alias __MODULE__.FiftyEight
  alias __MODULE__.SixtyFour
  alias __MODULE__.Urlsafe

  @doc """
  Defensive constructor. We use Base58 by default.

  ## Examples
      iex> Uptight.Base.new("7PXzX6h5NRWkaoucwYo8wkPcSQEk9Q5R77Ri")
      %Uptight.Result.Ok{
        ok: %Uptight.Base.FiftyEight{
          encoded: "7PXzX6h5NRWkaoucwYo8wkPcSQEk9Q5R77Ri",
          raw: "Слава Україні!"
        }
      }

      iex> Uptight.Base.new("7PXzX6h5NRWkaoucwYo8wkPcSQEk9Q5R77Ri") |> Uptight.Result.is_ok?()
      true
  """
  @spec new(binary()) :: Result.possibly(FiftyEight.t())
  def new(x), do: Result.new(fn -> new!(x) end)

  @spec new!(binary()) :: FiftyEight.t()
  def new!(<<x::binary>>) do
    %Ok{ok: res} = mk58(x)

    res
  end

  @doc """
  Perhaps, constructs a representation of a hex string.

  ## Example
      iex> Uptight.Base.mk16("1337C0DE")
      %Uptight.Result.Ok{ok: %Uptight.Base.Sixteen{encoded: "1337C0DE", raw: <<19, 55, 192, 222>>}}
  """
  @spec mk16(binary()) :: Result.possibly(Sixteen.t())
  def mk16(x) do
    Result.new(fn -> Base.decode16!(x) end)
    |> Result.cont(fn res -> %Sixteen{encoded: x, raw: res} end)
  end

  @spec mk32(binary()) :: Result.possibly(ThirtyTwo.t())
  def mk32(x) do
    Result.new(fn -> Base.decode32!(x) end)
    |> Result.cont(fn res -> %ThirtyTwo{encoded: x, raw: res} end)
  end

  @spec mk58(binary()) :: Result.possibly(FiftyEight.t())
  def mk58(x) do
    Result.new(fn ->
      mk58!(x)
    end)
  end

  @spec mk58!(binary()) :: FiftyEight.t()
  def mk58!(<<x::binary>>) do
    Result.new(fn ->
      %FiftyEight{
        encoded: x,
        raw: decode58(x)
      }
    end)
    |> tap(fn y ->
      assert Result.is_ok?(y),
             "Base58-decode failed to decode #{inspect(x)}. Invalid characters?"
    end)
    |> Result.from_ok()
  end

  @spec mk64(String.t()) :: Result.possibly(SixtyFour.t())
  def mk64(x) do
    Result.new(fn -> Base.decode64!(x) end)
    |> Result.cont(fn res -> %SixtyFour{encoded: x, raw: res} end)
  end

  @spec mk_url(String.t()) :: Result.possibly(Urlsafe.t())
  def mk_url(x) do
    Result.new(fn ->
      %Urlsafe{raw: Base.url_decode64!(x), encoded: x}
    end)
  end

  @spec mk_url!(String.t()) :: Urlsafe.t()
  def mk_url!(<<x::binary>>) do
    mk_url(x) |> Result.from_ok()
  end

  @spec raw_to_urlsafe(binary()) :: Result.possibly(Urlsafe.t())
  def raw_to_urlsafe(x) do
    Result.new(fn ->
      x |> Base.url_encode64() |> mk_url!()
    end)
  end

  @spec binary_to_urlsafe(Binary.t()) :: Result.possibly(Urlsafe.t())
  def binary_to_urlsafe(x) do
    Result.new(fn ->
      x |> Binary.un() |> raw_to_urlsafe!()
    end)
  end

  @spec binary_to_58(Binary.t()) :: Result.possibly(FiftyEight.t())
  def binary_to_58(x) do
    Result.new(fn ->
      xun = x |> Binary.un()

      %FiftyEight{
        encoded: encode58(xun),
        raw: xun
      }
    end)
  end

  @spec raw_to_urlsafe!(binary) :: Urlsafe.t()
  def raw_to_urlsafe!(<<x::binary>>) do
    raw_to_urlsafe(x) |> Result.from_ok()
  end

  @spec binary_to_urlsafe!(Binary.t()) :: Urlsafe.t()
  def binary_to_urlsafe!(%Binary{} = x) do
    x |> Binary.un() |> raw_to_urlsafe!()
  end

  @spec binary_to_58!(Binary.t()) :: FiftyEight.t()
  def binary_to_58!(%Binary{} = x) do
    xun = x |> Binary.un()

    %FiftyEight{
      encoded: encode58(xun),
      raw: xun
    }
  end

  @spec safe(Binary.t()) :: Result.possibly(Urlsafe.t())
  defdelegate safe(binary_t), to: __MODULE__, as: :binary_to_urlsafe

  @spec safe!(Binary.t()) :: Urlsafe.t()
  defdelegate safe!(binary_t), to: __MODULE__, as: :binary_to_urlsafe!

  @spec supersafe(Binary.t()) :: Result.possibly(FiftyEight.t())
  defdelegate supersafe(binary_t), to: __MODULE__, as: :binary_to_58

  @spec supersafe!(Binary.t()) :: FiftyEight.t()
  defdelegate supersafe!(binary_t), to: __MODULE__, as: :binary_to_58!

  @spec from_url(String.t()) :: Result.possibly(Urlsafe.t())
  defdelegate from_url(url_t), to: __MODULE__, as: :mk_url

  @spec from_url!(String.t()) :: Urlsafe.t()
  defdelegate from_url!(url_t), to: __MODULE__, as: :mk_url!

  @spec from_58(String.t()) :: Result.possibly(FiftyEight.t())
  defdelegate from_58(fifty_eight_t), to: __MODULE__, as: :mk58

  @spec from_58!(String.t()) :: FiftyEight.t()
  defdelegate from_58!(fifty_eight_t), to: __MODULE__, as: :mk58!

  @alnum ~c(123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz)

  ### BASE58 GPL2 CODE TODO: REWRITE THIS OURSELVES TO REMOVE GPL2 LICENSE ###

  @doc """
  ## Examples

    iex> Uptight.Base.encode58("hello")
    "Cn8eVZg"

    iex> Uptight.Base.encode58(42)
    "4yP"
  """
  def encode58(e) when is_integer(e) or is_float(e) or is_atom(e), do: encode58("#{e}")
  # see https://github.com/dwyl/base58/issues/5#issuecomment-459088540
  def encode58(<<0, binary::binary>>), do: "1" <> encode58(binary)
  def encode58(""), do: ""
  # see https://github.com/dwyl/base58/pull/3#discussion_r252291127
  def encode58(binary), do: encode58(:binary.decode_unsigned(binary), "")
  def encode58(0, acc), do: acc
  def encode58(n, acc), do: encode58(div(n, 58), <<Enum.at(@alnum, rem(n, 58))>> <> acc)

  @doc """
  `decode58/1` decodes the given Base58 string back to binary.
  ## Examples

    iex> Uptight.Base.encode58("hello") |> Uptight.Base.decode58()
    "hello"
  """

  # return empty string unmodified
  def decode58(""), do: ""
  # treat null values as empty
  def decode58("\0"), do: ""

  def decode58(binary) do
    {zeroes, binary} = handle_leading_zeroes(binary)
    zeroes <> decode58(binary, 0)
  end

  def decode58("", 0), do: ""
  def decode58("", acc), do: :binary.encode_unsigned(acc)

  def decode58(<<head, tail::binary>>, acc),
    do: decode58(tail, acc * 58 + Enum.find_index(@alnum, &(&1 == head)))

  defp handle_leading_zeroes(binary) do
    # avoid dropping leading zeros -- see https://github.com/dwyl/base58/issues/27
    origlen = String.length(binary)
    binary = String.trim_leading(binary, <<List.first(@alnum)>>)
    newlen = String.length(binary)
    {String.duplicate(<<0>>, origlen - newlen), binary}
  end

  @doc """
  `decode_to_int/1` decodes the given Base58 string back to an Integer.
  ## Examples

    iex> Uptight.Base.encode58(42) |> Uptight.Base.decode_to_int()
    42
  """
  def decode_to_int(encoded), do: encoded |> decode58() |> String.to_integer()
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

defimpl Jason.Encoder, for: Uptight.Base.FiftyEight do
  @spec encode(Uptight.Base.FiftyEight.t(), Jason.Encode.opts()) :: [
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

### String.Chars ###
defimpl String.Chars, for: Uptight.Base.Sixteen do
  @spec to_string(Uptight.Base.Sixteen.t()) :: String.t()
  def to_string(value) do
    Map.get(value, :encoded)
  end
end

defimpl String.Chars, for: Uptight.Base.ThirtyTwo do
  @spec to_string(Uptight.Base.ThirtyTwo.t()) :: String.t()
  def to_string(value) do
    Map.get(value, :encoded)
  end
end

defimpl String.Chars, for: Uptight.Base.SixtyFour do
  @spec to_string(Uptight.Base.SixtyFour.t()) :: String.t()
  def to_string(value) do
    Map.get(value, :encoded)
  end
end

defimpl String.Chars, for: Uptight.Base.FiftyEight do
  @spec to_string(Uptight.Base.FiftyEight.t()) :: String.t()
  def to_string(value) do
    Map.get(value, :encoded)
  end
end

defimpl String.Chars, for: Uptight.Base.Urlsafe do
  @spec to_string(Uptight.Base.Urlsafe.t()) :: String.t()
  def to_string(value) do
    Map.get(value, :encoded)
  end
end

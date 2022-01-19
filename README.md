# Uptight

Uptight is an infectious (as in IO monad) library answers two pain points of Elixir programming:

 1. Insufficiently tight types when it comes to distinguishing texts from binaries, as well as detachment of Base-encodings from binaries.
 2. Lack of an iron-gauntlet approach to errors and failure in Erlang and Elixir.

To address (1), we present the following types:

 * `Uptight.Text`, which is roughly equivalent to Haskell's `Text`. If something is made using "offensive" constructor (meaining that it will crash if you try to give it something weird), it's guaranteed to only contain valid UTF-8 codepoints.
 * `Uptight.Binary`, which is simply a wrapper for anything that should be treated as raw binary.
 * `Uptight.Base`, which is also a cool one. It has several subtypes defined, ranging from `Sixteen` to `SixtyFour` as well as `Urlsafe`. When you run a rarely used `new!` function of `Uptight.Base`, it tries to decode the Base-encoded binary representation given as an argument starting from the smallest alphabet (mk16), then medium (mk32), then restricted large (mk_url), and finally it tries the large one (mk64). That said, most often we use `safe` and `safe!` functions, which takes a wrapped raw binary of type `Uptight.Binary` and returns something of `Urlsafe` type. In the opposite direction, the most used function is `mk_url` and `mk_url!`, which takes an _unwrapped_ urlencoded string and stores it in `Uptight.Base` value.
 * `Uptight.Fold` is related to binary processing, namely text processing at the moment (but probably it should become an Elixir adaptation of Control.Foldl, perhaps in another library even). The only cool thing it allows for currently is generic `intersperse` and `intercalate`, which uses monoidal glue to  glue semigroup bits in some foldable data structure. Practically speaking, it means that we can intersperse texts (like `%Uptight.Text{text: "/"}`) between a list of other texts (like [%Uptight.Text{text: "."}, %Uptight.Text{text: "a.out"}]) because list is a foldable data structure and string concatenation forms semigroup over texts.
 * `Uptight` is a module which allows to transform naked binary, binary in a list, binary in second element of a tuple or binary values in a map into either Text (if it only consists of UTF-8 codepoints) or Binary. You probably shouldn't use this function because it's actually pretty lose and can cause surprises. Always prefer an explicit constructor.

To address (2), we present the following types:

 * `Uptight.Result` is something that is already used in defensive (non-bang) versions of functions you saw in the previous paragraph. It's basically Erlang's `{:ok, Value}` | `{:error, Reason}` tuple, but rewritten in Witchcraft and named after Rust: `Uptight.Result.Ok` and `Uptight.Result.Err`. But it's more than just that. If that was it, we could've simply used Witchcraft's `Either`. `Uptight.Result` is also good for enabling offensive programming!

## Offensive programming in Elixir

We often want to propagate an error to third parties, be it frontend programmers, end users or colleagues. It means that along with whatever context information BEAM generates for error handling, which often (but not always) is readable by Erlang/Elixir developers, we would like to also provide human-readable description of what went wrong, ideally together with some values.

In absence of blessed way to do so, I have ~~reinvented `assert`~~ came up with my own. It's a bit clumsy thus far, but all you need for it are `Uptight.Result` and `Uptight.Trace`. Here's the "pattern" for writing failable functions in such way that error getting propagated all the way the frontend is still handlable:

```
  defp poc_submission_output_to_raw_score(xkv, _opts) do
    Uptight.Result.new(fn ->

      # Demonstration that we can match against Ok, extracting the values
      %{"has `order` field set" => %Ok{ok: vertices}} = %{
        "has `order` field set" => Uptight.Result.new(fn -> xkv["order"] end)
      }
      %{"has `distance` field set" => %Ok{ok: distance}} = %{
        "has `distance` field set" => Uptight.Result.new(fn -> xkv["distance"] end)
      }

      # We can do all the matches we would normally be able to do in Elixir
      %{"solution vertices exist in the data set" => %Ok{ok: [{x0, y0} | ctail]}} = %{
        "solution vertices exist in the data set" =>
          Uptight.Result.new(fn -> path_to_coordinates(vertices, poc_data()) end)
      }
      {ref_distance, xf, yf} =
        Enum.reduce(ctail, {0.0, x0, y0}, fn {x1, y1}, {d, x0, y0} ->
          {d + distance({x0, y0}, {x1, y1}), x1, y1}
        end)
      ref_distance = ref_distance + distance({xf, yf}, {x0, y0})

      # Even exploit one of my favorite capabilities of Erlang/Elixir's pattern matching:
      # ** equality matching **! Note that rounded_distance and rounded_distance must be equal!
      %{"distance reported is correct" => {rounded_distance, rounded_distance}} = %{
        "distance reported is correct" =>
          {(1_000 * ref_distance) |> round(), (1000 * distance) |> round()}
      }

      # Note that at no point are we actually doing any validation. We just state our intent,
      # tagging matches with human-readable strings and let it crash, deferring the responsibility
      # of catching the failure to `new` function of Result and deferring the responsibility to
      # crash again to the user of our function. Paradoxically, having a somewhat defensive wrapper
      # allowed us to crash as loudly as we want while writing code. It's an amazing feeling.

      rounded_distance
    end)
  end
```

There's [an issue in Doma's megalith repository](https://github.com/doma-engineering/megalith/issues/46) aiming to fix error reporting ergonomics. According to Elixir macro gurus, it's possible to turn this pattern to a macro, because there are non-hermetic macros in Elixir!

Code.require_file("../test_helper.exs", __DIR__)

require Uptight.Assertions
alias Uptight.Assertions, as: A

defmodule Uptight.AssertionsTest.Value do
  def tuple, do: {2, 1}
  def falsy, do: nil
  def truthy, do: :truthy
  def binary, do: <<5, "Frank the Walrus">>
end

defmodule Uptight.AssertionsTest.BrokenError do
  defexception [:message]

  @impl true
  def message(_) do
    raise "error"
  end
end

alias Uptight.AssertionsTest.{BrokenError, Value}

defmodule Uptight.AssertionsTest do
  use ExUnit.Case, async: true

  defmacro sigil_l({:<<>>, _, [string]}, _), do: Code.string_to_quoted!(string, [])
  defmacro argless_macro(), do: raise("should not be invoked")

  defmacrop assert_ok(arg) do
    quote do
      A.assert({:ok, val} = ok(unquote(arg)))
    end
  end

  defmacrop assert_ok_with_pin_from_quoted_var(arg) do
    quote do
      kind = :ok
      A.assert({^kind, value} = unquote(arg))
    end
  end

  require Record
  Record.defrecordp(:vec, x: 0, y: 0, z: 0)

  defguardp is_zero(zero) when zero == 0

  # Doma-introduced macro which allows to propagate errors well all the way to the frontend / end users
  test "failed assertions are encodable with Jason" do
    y =
      Uptight.Result.new(fn ->
        A.assert(
          %Uptight.Result.Err{err: 42} |> Uptight.Result.is_ok?(),
          "Hello, my name is Mario."
        )
      end)
      |> Jason.encode!()
      |> Jason.decode!()

    assert y["err"]["exception"]["message"] == "Hello, my name is Mario."
  end

  test "assert inside macro" do
    assert_ok(42)
  end

  test "assert inside macro with pins" do
    try do
      assert_ok_with_pin_from_quoted_var({:error, :oops})
    rescue
      error in [Uptight.AssertionError] ->
        "match (=) failed" = error.message
    end
  end

  test "assert with truthy value" do
    :truthy = A.assert(Value.truthy())
  end

  test "assert with message when value is falsy" do
    try do
      "This should never be tested" = A.assert(Value.falsy(), "This should be truthy")
    rescue
      error in [Uptight.AssertionError] ->
        "This should be truthy" = error.message
    end
  end

  test "assert when value evaluates to falsy" do
    try do
      "This should never be tested" = A.assert(Value.falsy())
    rescue
      error in [Uptight.AssertionError] ->
        "assert Value.falsy()" = error.expr |> Macro.to_string()
        "Expected truthy, got nil" = error.message
    end
  end

  test "assert arguments in special form" do
    true =
      A.assert(
        case :ok do
          :ok -> true
        end
      )
  end

  test "assert arguments semantics on function call" do
    x = 1
    true = A.assert(not_equal(x = 2, x))
    2 = x
  end

  test "assert arguments are not kept for operators" do
    try do
      "This should never be tested" = A.assert(!Value.truthy())
    rescue
      error in [Uptight.AssertionError] ->
        false = is_list(error.args)
    end
  end

  test "assert with equality" do
    try do
      "This should never be tested" = A.assert(1 + 1 == 1)
    rescue
      error in [Uptight.AssertionError] ->
        1 = error.right
        2 = error.left
        "assert 1 + 1 == 1" = error.expr |> Macro.to_string()
    end
  end

  test "assert with equality in reverse" do
    try do
      "This should never be tested" = A.assert(1 == 1 + 1)
    rescue
      error in [Uptight.AssertionError] ->
        1 = error.left
        2 = error.right
        "assert 1 == 1 + 1" = error.expr |> Macro.to_string()
    end
  end

  test "assert exposes nested macro variables in matches" do
    A.assert(~l(a) = 1)
    A.assert(a == 1)

    A.assert({~l(b), ~l(c)} = {2, 3})
    A.assert(b == 2)
    A.assert(c == 3)
  end

  test "assert does not expand variables" do
    A.assert(argless_macro = 1)
    A.assert(argless_macro == 1)
  end

  test "refute when value is falsy" do
    false = A.refute(false)
    nil = A.refute(Value.falsy())
  end

  test "refute when value evaluates to truthy" do
    try do
      A.refute(Value.truthy())
      raise "refute was supposed to fail"
    rescue
      error in [Uptight.AssertionError] ->
        "refute Value.truthy()" = Macro.to_string(error.expr)
        "Expected false or nil, got :truthy" = error.message
    end
  end

  test "assert match when equal" do
    {2, 1} = A.assert({2, 1} = Value.tuple())

    # With dup vars
    A.assert({tuple, tuple} = {Value.tuple(), Value.tuple()})

    A.assert(
      <<name_size::size(8), _::binary-size(name_size), " the ", _::binary>> = Value.binary()
    )
  end

  test "assert match with unused var" do
    A.assert(
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.eval_string("""
        defmodule ExSample do
          import Uptight.Assertions

          def run do
            {2, 1} = assert {2, var} = Uptight.AssertionsTest.Value.tuple()
          end
        end
        """)
      end) =~ "variable \"var\" is unused"
    )
  after
    :code.delete(ExSample)
    :code.purge(ExSample)
  end

  test "assert match expands argument in match context" do
    {x, y, z} = {1, 2, 3}
    A.assert(vec(x: ^x, y: ^y) = vec(x: x, y: y, z: z))
  end

  @test_mod_attribute %{key: :value}
  test "assert match with module attribute" do
    try do
      A.assert({@test_mod_attribute, 1} = Value.tuple())
    rescue
      error in [Uptight.AssertionError] ->
        A.assert("{%{key: :value}, 1}" == Macro.to_string(error.left))
    end
  end

  test "assert match with pinned variable" do
    a = 1
    {2, 1} = A.assert({2, ^a} = Value.tuple())

    try do
      A.assert({^a, 1} = Value.tuple())
    rescue
      error in [Uptight.AssertionError] ->
        "match (=) failed\n" <> "The following variables were pinned:\n" <> "  a = 1" =
          error.message

        "assert {^a, 1} = Value.tuple()" = Macro.to_string(error.expr)
    end
  end

  test "assert match with pinned variable from another context" do
    var!(a, Elixir) = 1
    {2, 1} = A.assert({2, ^var!(a, Elixir)} = Value.tuple())

    try do
      A.assert({^var!(a, Elixir), 1} = Value.tuple())
    rescue
      error in [Uptight.AssertionError] ->
        "match (=) failed" = error.message
        "assert {^var!(a, Elixir), 1} = Value.tuple()" = Macro.to_string(error.expr)
    end
  end

  test "assert match?" do
    true = A.assert(match?({2, 1}, Value.tuple()))

    try do
      "This should never be tested" = A.assert(match?({:ok, _}, error(true)))
    rescue
      error in [Uptight.AssertionError] ->
        "match (match?) failed" = error.message
        "assert match?({:ok, _}, error(true))" = Macro.to_string(error.expr)
        "{:error, true}" = Macro.to_string(error.right)
    end
  end

  test "assert match? with guards" do
    true = A.assert(match?(tuple when is_tuple(tuple), Value.tuple()))

    try do
      "This should never be tested" =
        A.assert(match?(tuple when not is_tuple(tuple), error(true)))
    rescue
      error in [Uptight.AssertionError] ->
        "match (match?) failed" = error.message

        "assert match?(tuple when not is_tuple(tuple), error(true))" = Macro.to_string(error.expr)

        "{:error, true}" = Macro.to_string(error.right)
    end
  end

  test "refute match?" do
    false = A.refute(match?({1, 1}, Value.tuple()))

    try do
      "This should never be tested" = A.refute(match?({:error, _}, error(true)))
    rescue
      error in [ExUnit.AssertionError] ->
        "match (match?) succeeded, but should have failed" = error.message
        "refute match?({:error, _}, error(true))" = Macro.to_string(error.expr)
        "{:error, true}" = Macro.to_string(error.right)
    end
  end

  test "assert match? with pinned variable" do
    a = 1

    try do
      "This should never be tested" = A.assert(match?({^a, 1}, Value.tuple()))
    rescue
      error in [Uptight.AssertionError] ->
        "match (match?) failed\nThe following variables were pinned:\n  a = 1" = error.message

        "assert match?({^a, 1}, Value.tuple())" = Macro.to_string(error.expr)
    end
  end

  test "refute match? with pinned variable" do
    a = 2

    try do
      "This should never be tested" = A.refute(match?({^a, 1}, Value.tuple()))
    rescue
      error in [ExUnit.AssertionError] ->
        """
        match (match?) succeeded, but should have failed
        The following variables were pinned:
          a = 2\
        """ = error.message

        "refute match?({^a, 1}, Value.tuple())" = Macro.to_string(error.expr)
    end
  end

  test "assert receive waits" do
    parent = self()
    spawn(fn -> send(parent, :hello) end)
    :hello = A.assert_receive(:hello)
  end

  @string "hello"

  test "assert receive with interpolated compile-time string" do
    parent = self()
    spawn(fn -> send(parent, "string: hello") end)
    "string: #{@string}" = A.assert_receive("string: #{@string}")
  end

  test "assert receive accepts custom failure message" do
    send(self(), :hello)
    A.assert_receive(message, 0, "failure message")
    :hello = message
  end

  test "assert receive with message in mailbox after timeout, but before reading mailbox tells user to increase timeout" do
    parent = self()
    # This is testing a race condition, so it's not
    # guaranteed this works under all loads of the system
    timeout = 100
    spawn(fn -> Process.send_after(parent, :hello, timeout) end)

    try do
      A.assert_receive(:hello, timeout)
    rescue
      error in [Uptight.AssertionError] ->
        true =
          error.message =~ "Found message matching :hello after 100ms" or
            error.message =~ "no matching message after 100ms"
    end
  end

  test "assert_receive exposes nested macro variables" do
    send(self(), {:hello})
    A.assert_receive({~l(a)}, 0, "failure message")

    A.assert(a == :hello)
  end

  test "assert_receive raises on invalid timeout" do
    timeout = ok(1)

    try do
      A.assert_receive({~l(_a)}, timeout)
    rescue
      error in [ArgumentError] ->
        "timeout must be a non-negative integer, got: {:ok, 1}" = error.message
    end
  end

  test "assert_receive expands argument in match context" do
    {x, y, z} = {1, 2, 3}
    send(self(), vec(x: x, y: y, z: z))
    A.assert_receive(vec(x: ^x, y: ^y))
  end

  test "assert_receive expands argument in guard context" do
    send(self(), {:ok, 0, :other})
    A.assert_receive({:ok, val, atom} when is_zero(val) and is_atom(atom))
  end

  test "assert received does not wait" do
    send(self(), :hello)
    :hello = A.assert_received(:hello)
  end

  @received :hello

  test "assert received with module attribute" do
    send(self(), :hello)
    :hello = A.assert_received(@received)
  end

  test "assert received with pinned variable" do
    status = :valid
    send(self(), {:status, :invalid})

    try do
      "This should never be tested" = A.assert_received({:status, ^status})
    rescue
      error in [Uptight.AssertionError] ->
        """
        Assertion failed, no matching message after 0ms
        The following variables were pinned:
          status = :valid
        Showing 1 of 1 message in the mailbox\
        """ = error.message

        "assert_received {:status, ^status}" = Macro.to_string(error.expr)
        "{:status, ^status}" = Macro.to_string(error.left)
    end
  end

  test "assert received with multiple identical pinned variables" do
    status = :valid
    send(self(), {:status, :invalid, :invalid})

    try do
      "This should never be tested" = A.assert_received({:status, ^status, ^status})
    rescue
      error in [Uptight.AssertionError] ->
        """
        Assertion failed, no matching message after 0ms
        The following variables were pinned:
          status = :valid
        Showing 1 of 1 message in the mailbox\
        """ = error.message

        "assert_received {:status, ^status, ^status}" = Macro.to_string(error.expr)
        "{:status, ^status, ^status}" = Macro.to_string(error.left)
        "\n\nAssertion failed" <> _ = Exception.message(error)
    end
  end

  test "assert received with multiple unique pinned variables" do
    status = :valid
    other_status = :invalid
    send(self(), {:status, :invalid, :invalid})

    try do
      "This should never be tested" = A.assert_received({:status, ^status, ^other_status})
    rescue
      error in [Uptight.AssertionError] ->
        """
        Assertion failed, no matching message after 0ms
        The following variables were pinned:
          status = :valid
          other_status = :invalid
        Showing 1 of 1 message in the mailbox\
        """ = error.message

        "assert_received {:status, ^status, ^other_status}" = Macro.to_string(error.expr)
        "{:status, ^status, ^other_status}" = Macro.to_string(error.left)
    end
  end

  test "assert received when empty mailbox" do
    try do
      "This should never be tested" = A.assert_received(:hello)
    rescue
      error in [Uptight.AssertionError] ->
        "Assertion failed, no matching message after 0ms\nThe process mailbox is empty." =
          error.message

        "assert_received :hello" = Macro.to_string(error.expr)
    end
  end

  test "assert received when different message" do
    send(self(), {:message, :not_expected, :at_all})

    try do
      "This should never be tested" = A.assert_received(:hello)
    rescue
      error in [Uptight.AssertionError] ->
        """
        Assertion failed, no matching message after 0ms
        Showing 1 of 1 message in the mailbox\
        """ = error.message

        "assert_received :hello" = Macro.to_string(error.expr)
        ":hello" = Macro.to_string(error.left)
    end
  end

  test "assert received when different message having more than 10 on mailbox" do
    for i <- 1..11, do: send(self(), {:message, i})

    try do
      "This should never be tested" = A.assert_received(x when x == :hello)
    rescue
      error in [Uptight.AssertionError] ->
        """
        Assertion failed, no matching message after 0ms
        Showing 10 of 11 messages in the mailbox\
        """ = error.message

        "assert_received x when x == :hello" = Macro.to_string(error.expr)
        "x when x == :hello" = Macro.to_string(error.left)
    end
  end

  test "assert received binds variables" do
    send(self(), {:hello, :world})
    A.assert_received({:hello, world})
    :world = world
  end

  test "assert received does not leak external variables used in guards" do
    send(self(), {:hello, :world})
    guard_world = :world
    A.assert_received({:hello, world} when world == guard_world)
    :world = world
  end

  test "refute received does not wait" do
    false = A.refute_received(:hello)
  end

  test "refute receive waits" do
    false = A.refute_receive(:hello)
  end

  test "refute received when equal" do
    send(self(), :hello)

    try do
      "This should never be tested" = A.refute_received(:hello)
    rescue
      error in [ExUnit.AssertionError] ->
        "Unexpectedly received message :hello (which matched :hello)" = error.message
    end
  end

  test "assert in when member" do
    true = A.assert('foo' in ['foo', 'bar'])
  end

  test "assert in when is not member" do
    try do
      "This should never be tested" = A.assert('foo' in 'bar')
    rescue
      error in [Uptight.AssertionError] ->
        'foo' = error.left
        'bar' = error.right
        "assert 'foo' in 'bar'" = Macro.to_string(error.expr)
    end
  end

  test "refute in when is not member" do
    false = A.refute('baz' in ['foo', 'bar'])
  end

  test "refute in when is member" do
    try do
      "This should never be tested" = A.refute('foo' in ['foo', 'bar'])
    rescue
      error in [Uptight.AssertionError] ->
        'foo' = error.left
        ['foo', 'bar'] = error.right
        "refute 'foo' in ['foo', 'bar']" = Macro.to_string(error.expr)
    end
  end

  test "assert match" do
    {:ok, true} = A.assert({:ok, _} = ok(true))
  end

  test "assert match with bitstrings" do
    "foobar" = A.assert("foo" <> bar = "foobar")
    "bar" = bar
  end

  test "assert match when no match" do
    try do
      A.assert({:ok, _} = error(true))
    rescue
      error in [Uptight.AssertionError] ->
        "match (=) failed" = error.message
        "assert {:ok, _} = error(true)" = Macro.to_string(error.expr)
        "{:error, true}" = Macro.to_string(error.right)
    end
  end

  test "assert match when falsy but not match" do
    try do
      A.assert({:ok, _x} = nil)
    rescue
      # NB! This is a clear hint that there's a bug somewhere.
      # Other stuff throws ExUnit.AssertionError, whereas plain assert throws Uptight version.
      # TODO: Perhaps, I need to prefix all this stuff in assertions.ex
      error in [Uptight.AssertionError] ->
        "match (=) failed" = error.message
        "assert {:ok, _x} = nil" = Macro.to_string(error.expr)
        "nil" = Macro.to_string(error.right)
    end
  end

  test "assert match when falsy" do
    try do
      A.assert(_x = nil)
    rescue
      error in [Uptight.AssertionError] ->
        "Expected truthy, got nil" = error.message
        "assert _x = nil" = Macro.to_string(error.expr)
    end
  end

  test "refute match when no match" do
    try do
      "This should never be tested" = A.refute(_ = ok(true))
    rescue
      error in [Uptight.AssertionError] ->
        "refute _ = ok(true)" = Macro.to_string(error.expr)
        "Expected false or nil, got {:ok, true}" = error.message
    end
  end

  test "assert regex match" do
    true = A.assert("foo" =~ ~r/o/)
  end

  test "assert regex match when no match" do
    try do
      "This should never be tested" = A.assert("foo" =~ ~r/a/)
    rescue
      error in [Uptight.AssertionError] ->
        "foo" = error.left
        ~r{a} = error.right
    end
  end

  test "refute regex match" do
    false = A.refute("foo" =~ ~r/a/)
  end

  test "refute regex match when match" do
    try do
      "This should never be tested" = A.refute("foo" =~ ~r/o/)
    rescue
      error in [Uptight.AssertionError] ->
        "foo" = error.left
        ~r"o" = error.right
    end
  end

  test "assert raise with no error" do
    "This should never be tested" = A.assert_raise(ArgumentError, fn -> nil end)
  rescue
    error in [Uptight.AssertionError] ->
      "Expected exception ArgumentError but nothing was raised" = error.message
  end

  test "assert raise with error" do
    error = A.assert_raise(ArgumentError, fn -> raise ArgumentError, "test error" end)
    "test error" = error.message
  end

  @compile {:no_warn_undefined, Not.Defined}

  test "assert raise with some other error" do
    "This should never be tested" =
      A.assert_raise(ArgumentError, fn -> Not.Defined.function(1, 2, 3) end)
  rescue
    error in [Uptight.AssertionError] ->
      "Expected exception ArgumentError but got UndefinedFunctionError " <>
        "(function Not.Defined.function/3 is undefined (module Not.Defined is not available))" =
        error.message
  end

  test "assert raise with some other error includes stacktrace from original error" do
    "This should never be tested" =
      A.assert_raise(ArgumentError, fn -> Not.Defined.function(1, 2, 3) end)
  rescue
    Uptight.AssertionError ->
      [{Not.Defined, :function, [1, 2, 3], _} | _] = __STACKTRACE__
  end

  test "assert raise with Erlang error" do
    A.assert_raise(SyntaxError, fn ->
      List.flatten(1)
    end)
  rescue
    error in [Uptight.AssertionError] ->
      "Expected exception SyntaxError but got FunctionClauseError (no function clause matching in :lists.flatten/1)" =
        error.message
  end

  test "assert raise comparing messages (for equality)" do
    A.assert_raise(RuntimeError, "foo", fn ->
      raise RuntimeError, "bar"
    end)
  rescue
    error in [Uptight.AssertionError] ->
      """
      Wrong message for RuntimeError
      expected:
        "foo"
      actual:
        "bar"\
      """ = error.message
  end

  test "assert raise comparing messages (with a regex)" do
    A.assert_raise(RuntimeError, ~r/ba[zk]/, fn ->
      raise RuntimeError, "bar"
    end)
  rescue
    error in [Uptight.AssertionError] ->
      """
      Wrong message for RuntimeError
      expected:
        ~r/ba[zk]/
      actual:
        "bar"\
      """ = error.message
  end

  test "assert raise with an exception with bad message/1 implementation" do
    A.assert_raise(BrokenError, fn ->
      raise BrokenError
    end)
  rescue
    error in [Uptight.AssertionError] ->
      """
      Got exception Uptight.AssertionsTest.BrokenError but it failed to produce a message with:

      ** (RuntimeError) error
      """ <> _ = error.message
  end

  test "assert greater-than operator" do
    true = A.assert(2 > 1)
  end

  test "assert greater-than operator error" do
    "This should never be tested" = A.assert(1 > 2)
  rescue
    error in [Uptight.AssertionError] ->
      1 = error.left
      2 = error.right
      "assert 1 > 2" = Macro.to_string(error.expr)
  end

  test "assert less or equal than operator" do
    true = A.assert(1 <= 2)
  end

  test "assert less or equal than operator error" do
    "This should never be tested" = A.assert(2 <= 1)
  rescue
    error in [Uptight.AssertionError] ->
      "assert 2 <= 1" = Macro.to_string(error.expr)
      2 = error.left
      1 = error.right
  end

  test "assert operator with expressions" do
    greater = 5
    true = A.assert(1 + 2 < greater)
  end

  test "assert operator with custom message" do
    "This should never be tested" = A.assert(1 > 2, "assertion")
  rescue
    error in [Uptight.AssertionError] ->
      "assertion" = error.message
  end

  test "assert lack of equality" do
    try do
      "This should never be tested" = A.assert("one" != "one")
    rescue
      error in [Uptight.AssertionError] ->
        "Assertion with != failed, both sides are exactly equal" = error.message
        "one" = error.left
    end

    try do
      "This should never be tested" = A.assert(2 != 2.0)
    rescue
      error in [Uptight.AssertionError] ->
        "Assertion with != failed" = error.message
        2 = error.left
        2.0 = error.right
    end
  end

  test "refute equality" do
    try do
      "This should never be tested" = A.refute("one" == "one")
    rescue
      error in [Uptight.AssertionError] ->
        "Refute with == failed, both sides are exactly equal" = error.message
        "one" = error.left
    end

    try do
      "This should never be tested" = A.refute(2 == 2.0)
    rescue
      error in [Uptight.AssertionError] ->
        "Refute with == failed" = error.message
        2 = error.left
        2.0 = error.right
    end
  end

  test "assert in delta" do
    true = A.assert_in_delta(1.1, 1.2, 0.2)
  end

  test "assert in delta raises when passing a negative delta" do
    A.assert_raise(ArgumentError, fn ->
      A.assert_in_delta(1.1, 1.2, -0.2)
    end)
  end

  test "assert in delta works with equal values and a delta of zero" do
    A.assert_in_delta(10, 10, 0)
  end

  test "assert in delta error" do
    "This should never be tested" = A.assert_in_delta(10, 12, 1)
  rescue
    error in [Uptight.AssertionError] ->
      "Expected the difference between 10 and 12 (2) to be less than or equal to 1" =
        error.message
  end

  test "assert in delta with message" do
    "This should never be tested" = A.assert_in_delta(10, 12, 1, "test message")
  rescue
    error in [Uptight.AssertionError] ->
      "test message" = error.message
  end

  test "refute in delta" do
    false = A.refute_in_delta(1.1, 1.5, 0.2)
  end

  test "refute in delta error" do
    "This should never be tested" = A.refute_in_delta(10, 11, 2)
  rescue
    error in [Uptight.AssertionError] ->
      "Expected the difference between 10 and 11 (1) to be more than 2" = error.message
  end

  test "refute in delta with message" do
    "This should never be tested" = A.refute_in_delta(10, 11, 2, "test message")
  rescue
    error in [Uptight.AssertionError] ->
      "test message (difference between 10 and 11 is less than 2)" = error.message
  end

  test "catch_throw with no throw" do
    A.catch_throw(1)
  rescue
    # This is really awkward. I expect our AssertionErrors to be Uptight, not ExUnit!
    error in [ExUnit.AssertionError] ->
      "Expected to catch throw, got nothing" = error.message
  end

  test "catch_error with no error" do
    A.catch_error(1)
  rescue
    error in [Uptight.AssertionError] ->
      "Expected to catch error, got nothing" = error.message
  end

  test "catch_exit with no exit" do
    A.catch_exit(1)
  rescue
    error in [ExUnit.AssertionError] ->
      "Expected to catch exit, got nothing" = error.message
  end

  test "catch_throw with throw" do
    1 = A.catch_throw(throw(1))
  end

  test "catch_exit with exit" do
    1 = A.catch_exit(exit(1))
  end

  test "catch_error with error" do
    :function_clause = A.catch_error(List.flatten(1))
  end

  test "flunk" do
    "This should never be tested" = A.flunk()
  rescue
    error in [Uptight.AssertionError] ->
      "Flunked!" = error.message
  end

  test "flunk with message" do
    "This should never be tested" = A.flunk("This should raise an error")
  rescue
    error in [Uptight.AssertionError] ->
      "This should raise an error" = error.message
  end

  test "flunk with wrong argument type" do
    "This should never be tested" = A.flunk(["flunk takes a binary, not a list"])
  rescue
    error ->
      "no function clause matching in Uptight.Assertions.flunk/1" =
        FunctionClauseError.message(error)
  end

  test "AssertionError.message/1 is nicely formatted" do
    A.assert(:a = :b)
  rescue
    error in [Uptight.AssertionError] ->
      """


      match (=) failed
      code:  assert :a = :b
      left:  :a
      right: :b
      """ = Exception.message(error)
  end

  defp ok(val), do: {:ok, val}
  defp error(val), do: {:error, val}
  defp not_equal(left, right), do: left != right
end
